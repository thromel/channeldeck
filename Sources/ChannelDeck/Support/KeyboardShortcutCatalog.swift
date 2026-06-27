import Foundation

struct ShortcutSection: Identifiable, Equatable {
    let title: String
    let shortcuts: [ShortcutItem]

    var id: String { title }
}

struct ShortcutItem: Identifiable, Equatable {
    let action: String
    let shortcut: String
    let detail: String

    var id: String { "\(shortcut)-\(action)" }
}

enum KeyboardShortcutCatalog {
    static let sections: [ShortcutSection] = [
        ShortcutSection(
            title: "Playback",
            shortcuts: [
                ShortcutItem(action: "Play or pause", shortcut: "Space", detail: "Toggle the current stream."),
                ShortcutItem(action: "Stop playback", shortcut: "Command-.", detail: "Stops playback and exits player full screen."),
                ShortcutItem(action: "Previous channel", shortcut: "Command-[", detail: "Moves to the previous visible channel."),
                ShortcutItem(action: "Next channel", shortcut: "Command-]", detail: "Moves to the next visible channel."),
                ShortcutItem(action: "Full-screen player", shortcut: "Control-Command-F", detail: "Enter or exit the theater player."),
                ShortcutItem(action: "Exit full screen", shortcut: "Escape", detail: "Leave the full-screen player."),
                ShortcutItem(action: "Picture in Picture", shortcut: "Option-Command-P", detail: "Start or stop Picture in Picture."),
                ShortcutItem(action: "Record stream", shortcut: "Command-Shift-R", detail: "Start or stop local recording.")
            ]
        ),
        ShortcutSection(
            title: "Channels",
            shortcuts: [
                ShortcutItem(action: "Reload channels", shortcut: "Command-R", detail: "Refresh account, categories, and live channels."),
                ShortcutItem(action: "Quick open", shortcut: "Command-K", detail: "Open fast channel search."),
                ShortcutItem(action: "Import M3U", shortcut: "Command-O", detail: "Open a local M3U playlist."),
                ShortcutItem(action: "Load sample", shortcut: "Command-Shift-O", detail: "Try public sample streams."),
                ShortcutItem(action: "Favorite current channel", shortcut: "Command-D", detail: "Add or remove the current channel from favorites."),
                ShortcutItem(action: "Pin current channel", shortcut: "Command-Shift-D", detail: "Pin or unpin the current channel."),
                ShortcutItem(action: "Show multiview", shortcut: "Option-Command-M", detail: "Open two to four channel playback."),
                ShortcutItem(action: "Show guide", shortcut: "Option-Command-G", detail: "Open the current channel guide.")
            ]
        ),
        ShortcutSection(
            title: "Library and Layout",
            shortcuts: [
                ShortcutItem(action: "Save M3U", shortcut: "Option-Command-S", detail: "Save the loaded channels as a local playlist."),
                ShortcutItem(action: "Local library", shortcut: "Option-Command-J", detail: "Browse recordings and saved playlists."),
                ShortcutItem(action: "Copy diagnostics", shortcut: "Option-Command-C", detail: "Copy credential-safe playback diagnostics."),
                ShortcutItem(action: "Collapse channels", shortcut: "Option-Command-L", detail: "Hide or show the channel browser."),
                ShortcutItem(action: "Account settings", shortcut: "Option-Command-I", detail: "Show or hide account settings."),
                ShortcutItem(action: "Keyboard shortcuts", shortcut: "Command-/", detail: "Open this guide.")
            ]
        )
    ]

    static func matches(_ item: ShortcutItem, query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else {
            return true
        }

        return item.action.lowercased().contains(normalizedQuery)
            || item.shortcut.lowercased().contains(normalizedQuery)
            || item.detail.lowercased().contains(normalizedQuery)
    }

    static func filteredSections(query: String) -> [ShortcutSection] {
        sections.compactMap { section in
            let filteredShortcuts = section.shortcuts.filter { matches($0, query: query) }
            guard !filteredShortcuts.isEmpty else {
                return nil
            }

            return ShortcutSection(title: section.title, shortcuts: filteredShortcuts)
        }
    }
}
