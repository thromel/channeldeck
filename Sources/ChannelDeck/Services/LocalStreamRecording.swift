import Foundation

enum RecordingState: String, Equatable {
    case recording = "Recording"
    case stopping = "Stopping"
    case stopped = "Stopped"
    case failed = "Failed"
}

@MainActor
final class LocalStreamRecording: ObservableObject, Identifiable {
    let id = UUID()
    let channelName: String
    let streamID: IPTVChannel.ID
    let fileURL: URL
    let startedAt = Date()

    @Published private(set) var state: RecordingState = .recording
    @Published private(set) var byteCount = 0
    @Published private(set) var issue: String?

    private let streamURL: URL
    private var task: Task<Void, Never>?

    init(channel: IPTVChannel, streamURL: URL, fileURL: URL) {
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
            let media = HLSMediaReferences(playlist: playlist, playlistURL: playlistURL)

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

    static func defaultOutputURL(channel: IPTVChannel, streamURL: URL) throws -> URL {
        let directory = try LocalMediaLibrary.ensureDirectory()
        let timestamp = DateFormatter.recordingTimestamp.string(from: Date())
        let filename = "\(channel.name.safeRecordingFilename)-\(channel.id)-\(timestamp).ts"
        return directory.appendingPathComponent(filename)
    }
}

private struct HLSMediaReferences {
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

private extension String {
    var safeRecordingFilename: String {
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
    static let recordingTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
