import Foundation
import Security

struct MobileIPTVService {
    func authenticate(credentials: MobileIPTVCredentials) async throws -> MobileAccountSummary {
        let response: MobilePlayerAPIResponse = try await fetch(credentials: credentials, action: nil)

        guard response.userInfo?.auth == 1 else {
            throw MobileIPTVServiceError.authenticationFailed
        }

        let summary = response.accountSummary
        guard summary.isActive else {
            throw MobileIPTVServiceError.inactiveAccount(summary.status)
        }

        return summary
    }

    func liveCategories(credentials: MobileIPTVCredentials) async throws -> [MobileIPTVCategory] {
        try await fetch(credentials: credentials, action: "get_live_categories")
    }

    func liveStreams(credentials: MobileIPTVCredentials) async throws -> [MobileIPTVChannel] {
        try await fetch(credentials: credentials, action: "get_live_streams")
    }

    private func fetch<T: Decodable>(
        credentials: MobileIPTVCredentials,
        action: String?
    ) async throws -> T {
        let server = credentials.trimmedServerURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: "\(server)/player_api.php") else {
            throw MobileIPTVServiceError.invalidServerURL
        }

        var queryItems = [
            URLQueryItem(name: "username", value: credentials.username),
            URLQueryItem(name: "password", value: credentials.password)
        ]

        if let action {
            queryItems.append(URLQueryItem(name: "action", value: action))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw MobileIPTVServiceError.invalidServerURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("ChannelDeck iOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MobileIPTVServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw MobileIPTVServiceError.httpStatus(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw MobileIPTVServiceError.decodingFailed
        }
    }
}

enum MobileIPTVServiceError: LocalizedError {
    case invalidServerURL
    case invalidResponse
    case httpStatus(Int)
    case authenticationFailed
    case inactiveAccount(String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            "The server URL is invalid."
        case .invalidResponse:
            "The IPTV server returned an invalid response."
        case .httpStatus(let status):
            "The IPTV server returned HTTP \(status)."
        case .authenticationFailed:
            "The IPTV server rejected the ID/password."
        case .inactiveAccount(let status):
            "The account is not active. Status: \(status)."
        case .decodingFailed:
            "The IPTV response could not be decoded."
        }
    }
}

enum MobileSamplePlaylistProvider {
    static let categories = [
        MobileIPTVCategory(id: MobileIPTVCategory.allID, name: "All"),
        MobileIPTVCategory(id: MobileIPTVCategory.sampleID, name: "Sample")
    ]

    static let channels = [
        MobileIPTVChannel(
            id: -1,
            name: "Big Buck Bunny",
            categoryID: MobileIPTVCategory.sampleID,
            iconURL: URL(string: "https://peach.blender.org/wp-content/uploads/title_anouncement.jpg?x11217"),
            directSource: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")
        ),
        MobileIPTVChannel(
            id: -2,
            name: "Sintel",
            categoryID: MobileIPTVCategory.sampleID,
            iconURL: URL(string: "https://durian.blender.org/wp-content/uploads/2010/05/sintel_poster.jpg"),
            directSource: URL(string: "https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8")
        )
    ]
}

struct MobileCredentialStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> MobileIPTVCredentials {
        let formatRaw = defaults.string(forKey: DefaultsKey.streamFormat) ?? MobileStreamFormat.hls.rawValue
        let format = MobileStreamFormat(rawValue: formatRaw) ?? .hls

        return MobileIPTVCredentials(
            serverURL: defaults.string(forKey: DefaultsKey.serverURL) ?? "",
            username: defaults.string(forKey: DefaultsKey.username) ?? "",
            password: (try? MobileKeychainService.read(account: KeychainAccount.password)) ?? "",
            streamFormat: format
        )
    }

    func save(_ credentials: MobileIPTVCredentials) throws {
        defaults.set(credentials.serverURL, forKey: DefaultsKey.serverURL)
        defaults.set(credentials.username, forKey: DefaultsKey.username)
        defaults.set(credentials.streamFormat.rawValue, forKey: DefaultsKey.streamFormat)
        try MobileKeychainService.save(credentials.password, account: KeychainAccount.password)
    }

    private enum DefaultsKey {
        static let serverURL = "channeldeck.ios.serverURL"
        static let username = "channeldeck.ios.username"
        static let streamFormat = "channeldeck.ios.streamFormat"
    }

    private enum KeychainAccount {
        static let password = "channeldeck.ios.password"
    }
}

enum MobileKeychainService {
    private static let service = "com.channeldeck.ios.credentials"

    static func save(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            return
        }

        try? delete(account: account)

        let query = query(account: account, returningData: false).merging([
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]) { _, new in new }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw MobileKeychainError.unhandledStatus(status)
        }
    }

    static func read(account: String) throws -> String? {
        let query = query(account: account, returningData: true)
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw MobileKeychainError.unhandledStatus(status)
        }

        guard let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String) throws {
        let status = SecItemDelete(query(account: account, returningData: false) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw MobileKeychainError.unhandledStatus(status)
        }
    }

    private static func query(account: String, returningData: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if returningData {
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
        }

        return query
    }
}

enum MobileKeychainError: LocalizedError {
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandledStatus(let status):
            "Keychain returned status \(status)."
        }
    }
}
