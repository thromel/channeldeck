import AppKit
import Foundation
import UniformTypeIdentifiers

struct M3UImportResult {
    let sourceURL: URL
    let categories: [IPTVCategory]
    let channels: [IPTVChannel]
}

enum M3UPlaylistParser {
    static func parse(text: String, sourceURL: URL) -> M3UImportResult {
        var pendingMetadata = M3UEntryMetadata()
        var activeGroupName: String?
        var categoriesByName: [String: IPTVCategory] = [:]
        var categoryOrder: [String] = []
        var channels: [IPTVChannel] = []
        var usedIDs: Set<Int> = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line == "#EXTM3U" {
                continue
            }

            if line.hasPrefix("#EXTINF:") {
                pendingMetadata = M3UEntryMetadata(extinfLine: line)
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
                pendingMetadata = M3UEntryMetadata()
                continue
            }

            let groupName = pendingMetadata.groupTitle.ifEmpty(activeGroupName ?? "Imported")
            if categoriesByName[groupName] == nil {
                let category = IPTVCategory(id: "m3u:\(groupName.stablePlaylistID)", name: groupName)
                categoriesByName[groupName] = category
                categoryOrder.append(groupName)
            }

            let categoryID = categoriesByName[groupName]?.id ?? IPTVCategory.allID
            let name = pendingMetadata.title.ifEmpty(streamURL.deletingPathExtension().lastPathComponent.ifEmpty("Channel \(channels.count + 1)"))
            let id = stableChannelID(name: name, streamURL: streamURL, usedIDs: &usedIDs)
            channels.append(IPTVChannel(
                id: id,
                name: name,
                categoryID: categoryID,
                iconURL: pendingMetadata.logoURL,
                directSource: streamURL,
                added: Date()
            ))
            pendingMetadata = M3UEntryMetadata()
        }

        let categories = categoryOrder.compactMap { categoriesByName[$0] }
        return M3UImportResult(
            sourceURL: sourceURL,
            categories: categories,
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

@MainActor
enum M3UPlaylistImporter {
    static func open() -> M3UImportResult? {
        let panel = NSOpenPanel()
        panel.title = "Import M3U Playlist"
        panel.allowedContentTypes = [
            UTType(filenameExtension: "m3u"),
            UTType(filenameExtension: "m3u8"),
            .plainText
        ].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return nil
        }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            return M3UPlaylistParser.parse(text: text, sourceURL: url)
        } catch {
            NSSound.beep()
            return nil
        }
    }
}

private struct M3UEntryMetadata {
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
