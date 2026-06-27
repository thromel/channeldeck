import Foundation

struct MobileIPTVCredentials: Equatable {
    var serverURL: String
    var username: String
    var password: String
    var streamFormat: MobileStreamFormat

    var isComplete: Bool {
        !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
    }

    var trimmedServerURL: String {
        serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum MobileStreamFormat: String, CaseIterable, Identifiable {
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

struct MobileAccountSummary: Equatable {
    let status: String
    let expiresAt: Date?
    let activeConnections: Int?
    let maxConnections: Int?

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

struct MobileIPTVCategory: Identifiable, Hashable, Decodable {
    static let allID = "__all__"
    static let pinnedID = "__pinned__"
    static let favoritesID = "__favorites__"
    static let recentID = "__recent__"
    static let sampleID = "__sample__"

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

struct MobileIPTVChannel: Identifiable, Hashable, Decodable {
    let id: Int
    let name: String
    let streamType: String
    let categoryID: String
    let iconURL: URL?
    let directSource: URL?
    let added: Date?

    init(
        id: Int,
        name: String,
        streamType: String = "live",
        categoryID: String,
        iconURL: URL? = nil,
        directSource: URL?,
        added: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.streamType = streamType
        self.categoryID = categoryID
        self.iconURL = iconURL
        self.directSource = directSource
        self.added = added
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeLossyInt(forKey: .streamID)
        name = container.decodeLossyString(forKey: .name).ifEmpty("Untitled channel")
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

    func streamURL(credentials: MobileIPTVCredentials) -> URL? {
        if let directSource {
            return directSource
        }

        let server = credentials.trimmedServerURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !server.isEmpty else {
            return nil
        }

        let username = credentials.username.pathEncoded
        let password = credentials.password.pathEncoded
        return URL(string: "\(server)/live/\(username)/\(password)/\(id).\(credentials.streamFormat.rawValue)")
    }

    var sourceLabel: String {
        guard let directSource else {
            return "Stream \(id)"
        }

        switch directSource.pathExtension.lowercased() {
        case "m3u8":
            return "Direct HLS"
        case "ts":
            return "Direct TS"
        default:
            return "Direct Stream"
        }
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

enum MobileLoadState: Equatable {
    case idle
    case loading
    case loaded(Date)
    case failed(String)

    var title: String {
        switch self {
        case .idle:
            "Not loaded"
        case .loading:
            "Loading"
        case .loaded:
            "Loaded"
        case .failed:
            "Needs attention"
        }
    }

    var detail: String {
        switch self {
        case .idle:
            "Add an account or open the sample playlist."
        case .loading:
            "Contacting the provider API."
        case .loaded(let date):
            "Updated \(date.formatted(date: .omitted, time: .shortened))"
        case .failed(let message):
            message
        }
    }

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
}

struct MobilePlayerAPIResponse: Decodable {
    let userInfo: MobileUserInfo?

    var accountSummary: MobileAccountSummary {
        MobileAccountSummary(
            status: userInfo?.status ?? "Unknown",
            expiresAt: userInfo?.expirationDate,
            activeConnections: userInfo?.activeConnections,
            maxConnections: userInfo?.maxConnections
        )
    }

    private enum CodingKeys: String, CodingKey {
        case userInfo = "user_info"
    }
}

struct MobileUserInfo: Decodable {
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

    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
