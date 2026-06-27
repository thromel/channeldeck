import Foundation

enum LocalMediaKind: String, CaseIterable, Identifiable {
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

enum LocalMediaFilter: String, CaseIterable, Identifiable {
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

    func includes(_ kind: LocalMediaKind) -> Bool {
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

enum LocalMediaSortMode: String, CaseIterable, Identifiable {
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

struct LocalMediaItem: Identifiable, Hashable {
    let id: URL
    let url: URL
    let name: String
    let kind: LocalMediaKind
    let createdAt: Date
    let modifiedAt: Date
    let byteCount: Int64

    var byteCountText: String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}

struct LocalMediaSummary: Equatable {
    let itemCount: Int
    let recordingCount: Int
    let playlistCount: Int
    let downloadCount: Int
    let byteCount: Int64

    var byteCountText: String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}

enum LocalMediaBrowser {
    static func summary(for items: [LocalMediaItem]) -> LocalMediaSummary {
        LocalMediaSummary(
            itemCount: items.count,
            recordingCount: items.filter { $0.kind == .recording }.count,
            playlistCount: items.filter { $0.kind == .playlist }.count,
            downloadCount: items.filter { $0.kind == .download }.count,
            byteCount: items.reduce(Int64(0)) { $0 + $1.byteCount }
        )
    }

    static func visibleItems(
        from items: [LocalMediaItem],
        filter: LocalMediaFilter,
        query: String,
        sortMode: LocalMediaSortMode
    ) -> [LocalMediaItem] {
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

enum LocalMediaLibrary {
    static var directoryURL: URL {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return movies.appendingPathComponent("ChannelDeck", isDirectory: true)
    }

    static func ensureDirectory() throws -> URL {
        let directory = directoryURL
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func scan() throws -> [LocalMediaItem] {
        let directory = try ensureDirectory()
        let resourceKeys: Set<URLResourceKey> = [
            .contentModificationDateKey,
            .creationDateKey,
            .fileSizeKey,
            .isRegularFileKey
        ]

        return try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(resourceKeys))
            .compactMap { url -> LocalMediaItem? in
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
                return LocalMediaItem(
                    id: url,
                    url: url,
                    name: url.lastPathComponent,
                    kind: LocalMediaKind(fileExtension: fileExtension),
                    createdAt: createdAt,
                    modifiedAt: modifiedAt,
                    byteCount: byteCount
                )
            }
            .sorted { lhs, rhs in
                lhs.modifiedAt > rhs.modifiedAt
            }
    }

    static func remove(_ item: LocalMediaItem) throws {
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
