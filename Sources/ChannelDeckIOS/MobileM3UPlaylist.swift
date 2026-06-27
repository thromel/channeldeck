import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct MobileM3UImportResult {
    let sourceURL: URL
    let categories: [MobileIPTVCategory]
    let channels: [MobileIPTVChannel]
}

enum MobilePlaylistFileTypes {
    static let m3u = UTType(filenameExtension: "m3u") ?? .plainText
    static let m3u8 = UTType(filenameExtension: "m3u8") ?? .plainText
    static let readable = [m3u, m3u8, .plainText]
}

enum MobileM3UPlaylistParser {
    static func parse(text: String, sourceURL: URL) -> MobileM3UImportResult {
        var pendingMetadata = MobileM3UEntryMetadata()
        var activeGroupName: String?
        var categoriesByName: [String: MobileIPTVCategory] = [:]
        var categoryOrder: [String] = []
        var channels: [MobileIPTVChannel] = []
        var usedIDs: Set<Int> = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line == "#EXTM3U" {
                continue
            }

            if line.hasPrefix("#EXTINF:") {
                pendingMetadata = MobileM3UEntryMetadata(extinfLine: line)
                continue
            }

            if line.hasPrefix("#EXTGRP:") {
                activeGroupName = String(line.dropFirst("#EXTGRP:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            if line.hasPrefix("#") {
                continue
            }

            guard let streamURL = URL(string: line, relativeTo: sourceURL.deletingLastPathComponent())?.absoluteURL else {
                pendingMetadata = MobileM3UEntryMetadata()
                continue
            }

            let groupName = pendingMetadata.groupTitle.ifEmpty(activeGroupName ?? "Imported")
            if categoriesByName[groupName] == nil {
                let category = MobileIPTVCategory(id: "m3u:\(groupName.stablePlaylistID)", name: groupName)
                categoriesByName[groupName] = category
                categoryOrder.append(groupName)
            }

            let categoryID = categoriesByName[groupName]?.id ?? MobileIPTVCategory.allID
            let fallbackName = streamURL.deletingPathExtension().lastPathComponent.ifEmpty("Channel \(channels.count + 1)")
            let name = pendingMetadata.title.ifEmpty(fallbackName)
            let id = stableChannelID(name: name, streamURL: streamURL, usedIDs: &usedIDs)

            channels.append(MobileIPTVChannel(
                id: id,
                name: name,
                categoryID: categoryID,
                iconURL: pendingMetadata.logoURL,
                directSource: streamURL,
                added: Date()
            ))
            pendingMetadata = MobileM3UEntryMetadata()
        }

        return MobileM3UImportResult(
            sourceURL: sourceURL,
            categories: categoryOrder.compactMap { categoriesByName[$0] },
            channels: channels.sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        )
    }

    private static func stableChannelID(name: String, streamURL: URL, usedIDs: inout Set<Int>) -> Int {
        let seed = "\(name)|\(streamURL.absoluteString)"
        var id = -Int(seed.fnv1a32 & 0x3fffffff) - 1
        while usedIDs.contains(id) {
            id -= 1
        }
        usedIDs.insert(id)
        return id
    }
}

enum MobileM3UPlaylistExporter {
    static func makePlaylist(channels: [MobileIPTVChannel], credentials: MobileIPTVCredentials) -> String {
        var lines = ["#EXTM3U"]

        for channel in channels {
            guard let url = channel.streamURL(credentials: credentials) else {
                continue
            }

            lines.append("#EXTINF:-1 tvg-id=\"\(channel.id)\" group-title=\"\(channel.categoryID)\",\(channel.name)")
            lines.append(url.absoluteString)
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    static func defaultFilename(date: Date = Date()) -> String {
        "ChannelDeck-\(DateFormatter.mobilePlaylistTimestamp.string(from: date)).m3u"
    }
}

struct MobileM3UPlaylistDocument: FileDocument {
    static var readableContentTypes: [UTType] { MobilePlaylistFileTypes.readable }
    static var writableContentTypes: [UTType] { [MobilePlaylistFileTypes.m3u, .plainText] }

    var text: String

    init(text: String = "#EXTM3U\n") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

private struct MobileM3UEntryMetadata {
    var title = ""
    var groupTitle = ""
    var logoURL: URL?

    init() {}

    init(extinfLine: String) {
        let content = String(extinfLine.dropFirst("#EXTINF:".count))
        let parts = content.splitFirstUnquotedComma()
        title = parts.title.trimmingCharacters(in: .whitespacesAndNewlines)

        let attributes = parts.metadata.m3uAttributes
        groupTitle = attributes["group-title"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let logo = attributes["tvg-logo"]?.trimmingCharacters(in: .whitespacesAndNewlines), !logo.isEmpty {
            logoURL = URL(string: logo)
        }
    }
}

private extension String {
    var stablePlaylistID: String {
        let allowed = CharacterSet.alphanumerics
        let scalars = unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar).lowercased() : "-"
        }
        let joined = scalars.joined()
        let collapsed = joined
            .split(separator: "-")
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return collapsed.isEmpty ? "imported" : collapsed
    }

    var fnv1a32: UInt32 {
        var hash: UInt32 = 2_166_136_261
        for byte in utf8 {
            hash ^= UInt32(byte)
            hash &*= 16_777_619
        }
        return hash
    }

    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }

    func splitFirstUnquotedComma() -> (metadata: String, title: String) {
        var insideQuote = false
        for index in indices {
            let character = self[index]
            if character == "\"" {
                insideQuote.toggle()
            }
            if character == ",", !insideQuote {
                return (
                    metadata: String(self[..<index]),
                    title: String(self[self.index(after: index)...])
                )
            }
        }

        return (metadata: self, title: "")
    }

    var m3uAttributes: [String: String] {
        var attributes: [String: String] = [:]
        let pattern = #"([A-Za-z0-9_-]+)=("[^"]*"|[^,\s]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return attributes
        }

        let range = NSRange(startIndex..<endIndex, in: self)
        for match in regex.matches(in: self, range: range) {
            guard match.numberOfRanges == 3,
                  let keyRange = Range(match.range(at: 1), in: self),
                  let valueRange = Range(match.range(at: 2), in: self) else {
                continue
            }

            let key = String(self[keyRange]).lowercased()
            var value = String(self[valueRange])
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value.removeFirst()
                value.removeLast()
            }
            attributes[key] = value
        }
        return attributes
    }
}

private extension DateFormatter {
    static let mobilePlaylistTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
