import Foundation

enum LocalMediaKind: String {
    case recording = "Recording"
    case playlist = "Playlist"
    case download = "Download"

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
