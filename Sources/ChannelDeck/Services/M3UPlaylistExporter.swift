import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum M3UPlaylistExporter {
    static func save(channels: [IPTVChannel], account: IPTVCredentials) {
        guard !channels.isEmpty else {
            return
        }

        let panel = NSSavePanel()
        panel.title = "Save M3U Playlist"
        panel.nameFieldStringValue = "ChannelDeck-\(DateFormatter.playlistTimestamp.string(from: Date())).m3u"
        panel.allowedContentTypes = [UTType(filenameExtension: "m3u") ?? .plainText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        do {
            let playlist = makePlaylist(channels: channels, account: account)
            try playlist.write(to: url, atomically: true, encoding: .utf8)
            WorkspaceOpener.reveal(url)
        } catch {
            NSSound.beep()
        }
    }

    private static func makePlaylist(channels: [IPTVChannel], account: IPTVCredentials) -> String {
        var lines = ["#EXTM3U"]

        for channel in channels {
            guard let url = channel.streamURL(account: account) else {
                continue
            }

            lines.append("#EXTINF:-1 tvg-id=\"\(channel.id)\" group-title=\"\(channel.categoryID)\",\(channel.name)")
            lines.append(url.absoluteString)
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }
}

private extension DateFormatter {
    static let playlistTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
