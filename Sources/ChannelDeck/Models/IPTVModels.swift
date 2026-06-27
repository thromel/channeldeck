import Foundation

struct IPTVCredentials: Equatable {
    var serverURL: String
    var username: String
    var password: String
    var streamFormat: StreamFormat

    var isComplete: Bool {
        !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
    }
}

enum StreamFormat: String, CaseIterable, Identifiable {
    case hls = "m3u8"
    case transportStream = "ts"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hls:
            "HLS (.m3u8)"
        case .transportStream:
            "MPEG-TS (.ts)"
        }
    }
}

struct AccountSummary: Equatable {
    let status: String
    let expiresAt: Date?
    let activeConnections: Int?
    let maxConnections: Int?
    let serverProtocol: String?
    let serverPort: String?

    var isActive: Bool {
        status.lowercased() == "active"
    }

    var connectionLine: String {
        guard let activeConnections, let maxConnections else {
            return "Connections unavailable"
        }

        return "\(activeConnections) of \(maxConnections) connections"
    }
}

struct IPTVCategory: Identifiable, Hashable, Decodable {
    static let allID = "__all__"
    static let recentID = "__recent__"

    let id: String
    let name: String

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeLossyString(forKey: .categoryID)
        name = container.decodeLossyString(forKey: .categoryName)
    }

    private enum CodingKeys: String, CodingKey {
        case categoryID = "category_id"
        case categoryName = "category_name"
    }
}

struct IPTVChannel: Identifiable, Hashable, Decodable {
    let id: Int
    let name: String
    let streamType: String
    let categoryID: String
    let iconURL: URL?
    let directSource: URL?
    let added: Date?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeLossyInt(forKey: .streamID)
        name = container.decodeLossyString(forKey: .name)
        streamType = container.decodeLossyString(forKey: .streamType)
        categoryID = container.decodeLossyString(forKey: .categoryID)

        let icon = container.decodeLossyString(forKey: .streamIcon)
        iconURL = URL(string: icon)

        let direct = container.decodeLossyString(forKey: .directSource)
        directSource = direct.isEmpty ? nil : URL(string: direct)

        let addedRaw = container.decodeLossyString(forKey: .added)
        if let seconds = TimeInterval(addedRaw) {
            added = Date(timeIntervalSince1970: seconds)
        } else {
            added = nil
        }
    }

    func streamURL(account: IPTVCredentials) -> URL? {
        if let directSource {
            return directSource
        }

        let server = account.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let username = account.username.pathEncoded
        let password = account.password.pathEncoded

        return URL(string: "\(server)/live/\(username)/\(password)/\(id).\(account.streamFormat.rawValue)")
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case added
        case streamID = "stream_id"
        case streamType = "stream_type"
        case streamIcon = "stream_icon"
        case categoryID = "category_id"
        case directSource = "direct_source"
    }
}

struct PlayerAPIResponse: Decodable {
    let userInfo: UserInfo?
    let serverInfo: ServerInfo?

    var accountSummary: AccountSummary {
        AccountSummary(
            status: userInfo?.status ?? "Unknown",
            expiresAt: userInfo?.expirationDate,
            activeConnections: userInfo?.activeConnections,
            maxConnections: userInfo?.maxConnections,
            serverProtocol: serverInfo?.serverProtocol,
            serverPort: serverInfo?.port
        )
    }

    private enum CodingKeys: String, CodingKey {
        case userInfo = "user_info"
        case serverInfo = "server_info"
    }
}

struct UserInfo: Decodable {
    let auth: Int
    let status: String
    let expirationDate: Date?
    let activeConnections: Int?
    let maxConnections: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        auth = container.decodeLossyInt(forKey: .auth)
        status = container.decodeLossyString(forKey: .status)
        activeConnections = container.decodeOptionalLossyInt(forKey: .activeConnections)
        maxConnections = container.decodeOptionalLossyInt(forKey: .maxConnections)

        let expirationRaw = container.decodeLossyString(forKey: .expirationDate)
        if let seconds = TimeInterval(expirationRaw), seconds > 0 {
            expirationDate = Date(timeIntervalSince1970: seconds)
        } else {
            expirationDate = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case auth
        case status
        case expirationDate = "exp_date"
        case activeConnections = "active_cons"
        case maxConnections = "max_connections"
    }
}

struct ServerInfo: Decodable {
    let serverProtocol: String?
    let port: String?

    private enum CodingKeys: String, CodingKey {
        case serverProtocol = "server_protocol"
        case port
    }
}

enum IPTVLoadState: Equatable {
    case idle
    case loading
    case loaded(Date)
    case failed(String)

    var label: String {
        switch self {
        case .idle:
            "Not loaded"
        case .loading:
            "Loading"
        case .loaded:
            "Loaded"
        case .failed:
            "Failed"
        }
    }
}

extension KeyedDecodingContainer {
    func decodeLossyString(forKey key: Key) -> String {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Double.self, forKey: key) {
            return String(value)
        }
        return ""
    }

    func decodeLossyInt(forKey key: Key) -> Int {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? decode(String.self, forKey: key),
           let intValue = Int(value) {
            return intValue
        }
        return 0
    }

    func decodeOptionalLossyInt(forKey key: Key) -> Int? {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? decode(String.self, forKey: key),
           let intValue = Int(value) {
            return intValue
        }
        return nil
    }
}

private extension String {
    var pathEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self
    }
}
