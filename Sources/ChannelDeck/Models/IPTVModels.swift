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
    static let pinnedID = "__pinned__"
    static let favoritesID = "__favorites__"
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

struct EPGProgram: Identifiable, Equatable, Decodable {
    let id: String
    let title: String
    let description: String
    let start: Date?
    let end: Date?
    let fallbackStartText: String
    let fallbackEndText: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawID = container.decodeLossyString(forKey: .id)
        let rawTitle = container.decodeLossyString(forKey: .title)
        let rawDescription = container.decodeLossyString(forKey: .description)
        let rawStart = container.decodeLossyString(forKey: .start)
        let rawEnd = container.decodeLossyString(forKey: .end)
            .ifEmpty(container.decodeLossyString(forKey: .stop))
        let startTimestamp = container.decodeOptionalLossyInt(forKey: .startTimestamp)
        let stopTimestamp = container.decodeOptionalLossyInt(forKey: .stopTimestamp)
            ?? container.decodeOptionalLossyInt(forKey: .endTimestamp)

        title = rawTitle.decodedEPGText.ifEmpty("Untitled program")
        description = rawDescription.decodedEPGText
        start = Date.epgDate(timestamp: startTimestamp, fallback: rawStart)
        end = Date.epgDate(timestamp: stopTimestamp, fallback: rawEnd)
        fallbackStartText = rawStart
        fallbackEndText = rawEnd
        id = rawID.isEmpty ? "\(title)-\(rawStart)-\(rawEnd)" : rawID
    }

    var timeRangeText: String {
        if let start, let end {
            let formatter = DateIntervalFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: start, to: end)
        }

        if !fallbackStartText.isEmpty && !fallbackEndText.isEmpty {
            return "\(fallbackStartText) - \(fallbackEndText)"
        }

        if !fallbackStartText.isEmpty {
            return fallbackStartText
        }

        return "Time unavailable"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case start
        case end
        case stop
        case startTimestamp = "start_timestamp"
        case endTimestamp = "end_timestamp"
        case stopTimestamp = "stop_timestamp"
    }
}

struct EPGResponse: Decodable {
    let programs: [EPGProgram]

    init(from decoder: Decoder) throws {
        if let programs = try? [EPGProgram](from: decoder) {
            self.programs = programs
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        programs = (try? container.decode([EPGProgram].self, forKey: .programs)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case programs = "epg_listings"
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

enum EPGLoadState: Equatable {
    case idle
    case loading
    case loaded
    case unavailable
    case failed(String)
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

    var decodedEPGText: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4,
              trimmed.count % 4 == 0,
              trimmed.range(of: #"^[A-Za-z0-9+/]+={0,2}$"#, options: .regularExpression) != nil,
              let data = Data(base64Encoded: trimmed, options: .ignoreUnknownCharacters),
              let decoded = String(data: data, encoding: .utf8) else {
            return trimmed
        }

        let cleaned = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              cleaned.unicodeScalars.allSatisfy({ scalar in
                  !CharacterSet.controlCharacters.contains(scalar) || scalar == "\n" || scalar == "\t"
              }) else {
            return trimmed
        }

        return cleaned
    }

    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

private extension Date {
    static func epgDate(timestamp: Int?, fallback: String) -> Date? {
        if let timestamp, timestamp > 0 {
            return Date(timeIntervalSince1970: TimeInterval(timestamp))
        }

        let trimmed = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss Z",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }
}
