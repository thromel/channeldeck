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

struct MobileEPGProgram: Identifiable, Equatable, Decodable {
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

struct MobileEPGResponse: Decodable {
    let programs: [MobileEPGProgram]

    init(from decoder: Decoder) throws {
        if let programs = try? [MobileEPGProgram](from: decoder) {
            self.programs = programs
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        programs = (try? container.decode([MobileEPGProgram].self, forKey: .programs)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case programs = "epg_listings"
    }
}

enum MobileEPGLoadState: Equatable {
    case idle
    case loading
    case loaded
    case unavailable
    case failed(String)

    var title: String {
        switch self {
        case .idle:
            "Guide"
        case .loading:
            "Loading guide"
        case .loaded:
            "Guide"
        case .unavailable:
            "Guide unavailable"
        case .failed:
            "Guide failed"
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

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ssXXXXX"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: fallback) {
                return date
            }
        }

        return nil
    }
}
