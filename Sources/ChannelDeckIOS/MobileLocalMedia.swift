import Foundation

enum MobileRecordingState: String, Equatable {
    case recording = "Recording"
    case stopping = "Stopping"
    case stopped = "Stopped"
    case failed = "Failed"
}

@MainActor
final class MobileLocalStreamRecording: ObservableObject, Identifiable {
    let id = UUID()
    let channelName: String
    let streamID: MobileIPTVChannel.ID
    let fileURL: URL
    let startedAt = Date()

    @Published private(set) var state: MobileRecordingState = .recording
    @Published private(set) var byteCount = 0
    @Published private(set) var issue: String?

    private let streamURL: URL
    private var task: Task<Void, Never>?

    init(channel: MobileIPTVChannel, streamURL: URL, fileURL: URL) {
        channelName = channel.name
        streamID = channel.id
        self.streamURL = streamURL
        self.fileURL = fileURL
    }

    var isActive: Bool {
        state == .recording || state == .stopping
    }

    var byteCountText: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }

    func start() {
        task?.cancel()
        task = Task {
            do {
                try prepareOutputFile()

                if streamURL.pathExtension.lowercased() == "m3u8" {
                    try await recordHLSPlaylist()
                } else {
                    try await recordByteStream()
                }

                if state != .failed {
                    state = .stopped
                }
            } catch is CancellationError {
                state = .stopped
            } catch {
                issue = error.localizedDescription
                state = .failed
            }
        }
    }

    func stop() {
        guard isActive else {
            return
        }

        state = .stopping
        task?.cancel()
    }

    private func prepareOutputFile() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
    }

    private func recordByteStream() async throws {
        let (bytes, _) = try await URLSession.shared.bytes(from: streamURL)
        let handle = try FileHandle(forWritingTo: fileURL)
        defer {
            try? handle.close()
        }

        var buffer = Data()
        buffer.reserveCapacity(64 * 1024)

        for try await byte in bytes {
            try Task.checkCancellation()
            buffer.append(byte)

            if buffer.count >= 64 * 1024 {
                try handle.write(contentsOf: buffer)
                byteCount += buffer.count
                buffer.removeAll(keepingCapacity: true)
            }
        }

        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
            byteCount += buffer.count
        }
    }

    private func recordHLSPlaylist() async throws {
        let handle = try FileHandle(forWritingTo: fileURL)
        defer {
            try? handle.close()
        }

        var playlistURL = streamURL
        var downloadedSegments = Set<URL>()
        var downloadedMaps = Set<URL>()

        while !Task.isCancelled {
            let (playlistData, _) = try await URLSession.shared.data(from: playlistURL)
            let playlist = String(data: playlistData, encoding: .utf8) ?? ""
            let media = MobileHLSMediaReferences(playlist: playlist, playlistURL: playlistURL)

            if media.segmentURLs.isEmpty,
               let variantURL = media.variantPlaylistURLs.first {
                playlistURL = variantURL
                downloadedSegments.removeAll()
                downloadedMaps.removeAll()
                continue
            }

            for mapURL in media.mapURLs where !downloadedMaps.contains(mapURL) {
                try Task.checkCancellation()
                let data = try await downloadedData(from: mapURL)
                try handle.write(contentsOf: data)
                byteCount += data.count
                downloadedMaps.insert(mapURL)
            }

            for segmentURL in media.segmentURLs where !downloadedSegments.contains(segmentURL) {
                try Task.checkCancellation()
                let data = try await downloadedData(from: segmentURL)
                try handle.write(contentsOf: data)
                byteCount += data.count
                downloadedSegments.insert(segmentURL)
            }

            if media.hasEndList {
                break
            }

            try await Task.sleep(for: .seconds(max(media.targetDuration, 2)))
        }
    }

    private func downloadedData(from url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    static func defaultOutputURL(channel: MobileIPTVChannel, streamURL: URL) throws -> URL {
        let directory = try MobileLocalMediaLibrary.ensureDirectory()
        let timestamp = DateFormatter.mobileRecordingTimestamp.string(from: Date())
        let filename = "\(channel.name.safeMobileRecordingFilename)-\(channel.id)-\(timestamp).ts"
        return directory.appendingPathComponent(filename)
    }
}

private struct MobileHLSMediaReferences {
    let segmentURLs: [URL]
    let mapURLs: [URL]
    let variantPlaylistURLs: [URL]
    let targetDuration: Double
    let hasEndList: Bool

    init(playlist: String, playlistURL: URL) {
        var segments: [URL] = []
        var maps: [URL] = []
        var variants: [URL] = []
        var targetDuration = 2.0
        var hasEndList = false
        var nextURIIsVariant = false

        for rawLine in playlist.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                continue
            }

            if line.hasPrefix("#EXT-X-TARGETDURATION:"),
               let duration = Double(line.replacingOccurrences(of: "#EXT-X-TARGETDURATION:", with: "")) {
                targetDuration = duration
                continue
            }

            if line == "#EXT-X-ENDLIST" {
                hasEndList = true
                continue
            }

            if line.hasPrefix("#EXT-X-STREAM-INF:") {
                nextURIIsVariant = true
                continue
            }

            if line.hasPrefix("#EXT-X-MAP:"),
               let uri = line.hlsAttribute(named: "URI"),
               let url = URL(string: uri, relativeTo: playlistURL)?.absoluteURL {
                maps.append(url)
                continue
            }

            if !line.hasPrefix("#"),
               let url = URL(string: line, relativeTo: playlistURL)?.absoluteURL {
                if nextURIIsVariant {
                    variants.append(url)
                    nextURIIsVariant = false
                } else {
                    segments.append(url)
                }
            }
        }

        segmentURLs = segments
        mapURLs = maps
        variantPlaylistURLs = variants
        self.targetDuration = targetDuration
        self.hasEndList = hasEndList
    }
}

enum MobileLocalMediaKind: String, CaseIterable, Identifiable {
    case recording = "Recording"
    case playlist = "Playlist"
    case download = "Download"

    var id: String { rawValue }

    init(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "m3u", "m3u8":
            self = .playlist
        case "ts", "mp4", "mov", "m4v":
            self = .recording
        default:
            self = .download
        }
    }
}

enum MobileLocalMediaFilter: String, CaseIterable, Identifiable {
    case all
    case recordings
    case playlists
    case downloads

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "All"
        case .recordings:
            "Recordings"
        case .playlists:
            "Playlists"
        case .downloads:
            "Downloads"
        }
    }

    func includes(_ kind: MobileLocalMediaKind) -> Bool {
        switch self {
        case .all:
            true
        case .recordings:
            kind == .recording
        case .playlists:
            kind == .playlist
        case .downloads:
            kind == .download
        }
    }
}

enum MobileLocalMediaSortMode: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case name
    case largest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest:
            "Newest"
        case .oldest:
            "Oldest"
        case .name:
            "Name"
        case .largest:
            "Largest"
        }
    }
}

struct MobileLocalMediaItem: Identifiable, Hashable {
    let id: URL
    let url: URL
    let name: String
    let kind: MobileLocalMediaKind
    let createdAt: Date
    let modifiedAt: Date
    let byteCount: Int64

    var byteCountText: String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}

struct MobileLocalMediaSummary: Equatable {
    let itemCount: Int
    let recordingCount: Int
    let playlistCount: Int
    let downloadCount: Int
    let byteCount: Int64

    var byteCountText: String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}

enum MobileLocalMediaBrowser {
    static func summary(for items: [MobileLocalMediaItem]) -> MobileLocalMediaSummary {
        MobileLocalMediaSummary(
            itemCount: items.count,
            recordingCount: items.filter { $0.kind == .recording }.count,
            playlistCount: items.filter { $0.kind == .playlist }.count,
            downloadCount: items.filter { $0.kind == .download }.count,
            byteCount: items.reduce(Int64(0)) { $0 + $1.byteCount }
        )
    }

    static func visibleItems(
        from items: [MobileLocalMediaItem],
        filter: MobileLocalMediaFilter,
        query: String,
        sortMode: MobileLocalMediaSortMode
    ) -> [MobileLocalMediaItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = items.filter { item in
            filter.includes(item.kind)
                && (
                    normalizedQuery.isEmpty
                        || item.name.lowercased().contains(normalizedQuery)
                        || item.kind.rawValue.lowercased().contains(normalizedQuery)
                )
        }

        return filtered.sorted { lhs, rhs in
            switch sortMode {
            case .newest:
                if lhs.modifiedAt != rhs.modifiedAt {
                    return lhs.modifiedAt > rhs.modifiedAt
                }
            case .oldest:
                if lhs.modifiedAt != rhs.modifiedAt {
                    return lhs.modifiedAt < rhs.modifiedAt
                }
            case .name:
                let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }
            case .largest:
                if lhs.byteCount != rhs.byteCount {
                    return lhs.byteCount > rhs.byteCount
                }
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

enum MobileLocalMediaLibrary {
    static var directoryURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return documents.appendingPathComponent("ChannelDeck", isDirectory: true)
    }

    static func ensureDirectory() throws -> URL {
        try ensureDirectory(at: directoryURL)
    }

    static func ensureDirectory(at directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func scan() throws -> [MobileLocalMediaItem] {
        try scan(in: try ensureDirectory())
    }

    static func scan(in directory: URL) throws -> [MobileLocalMediaItem] {
        let resourceKeys: Set<URLResourceKey> = [
            .contentModificationDateKey,
            .creationDateKey,
            .fileSizeKey,
            .isRegularFileKey
        ]

        return try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(resourceKeys))
            .compactMap { url -> MobileLocalMediaItem? in
                let fileExtension = url.pathExtension.lowercased()
                guard supportedExtensions.contains(fileExtension) else {
                    return nil
                }

                let values = try url.resourceValues(forKeys: resourceKeys)
                guard values.isRegularFile == true else {
                    return nil
                }

                let modifiedAt = values.contentModificationDate ?? Date.distantPast
                let createdAt = values.creationDate ?? modifiedAt
                let byteCount = Int64(values.fileSize ?? 0)
                return MobileLocalMediaItem(
                    id: url,
                    url: url,
                    name: url.lastPathComponent,
                    kind: MobileLocalMediaKind(fileExtension: fileExtension),
                    createdAt: createdAt,
                    modifiedAt: modifiedAt,
                    byteCount: byteCount
                )
            }
            .sorted { lhs, rhs in
                lhs.modifiedAt > rhs.modifiedAt
            }
    }

    static func remove(_ item: MobileLocalMediaItem) throws {
        try FileManager.default.removeItem(at: item.url)
    }

    private static let supportedExtensions: Set<String> = [
        "m3u",
        "m3u8",
        "m4v",
        "mov",
        "mp4",
        "ts"
    ]
}

private extension String {
    var safeMobileRecordingFilename: String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
            .union(.newlines)
            .union(.controlCharacters)
        let parts = components(separatedBy: invalid)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let base = parts.joined(separator: "-")
        let trimmed = String(base.prefix(80))
        return trimmed.isEmpty ? "Channel" : trimmed
    }

    func hlsAttribute(named name: String) -> String? {
        let marker = "\(name)=\""
        guard let startRange = range(of: marker) else {
            return nil
        }

        let valueStart = startRange.upperBound
        guard let end = self[valueStart...].firstIndex(of: "\"") else {
            return nil
        }

        return String(self[valueStart..<end])
    }
}

private extension DateFormatter {
    static let mobileRecordingTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
