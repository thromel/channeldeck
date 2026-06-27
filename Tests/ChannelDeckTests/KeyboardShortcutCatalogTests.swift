import XCTest
@testable import ChannelDeck

final class KeyboardShortcutCatalogTests: XCTestCase {
    func testCatalogHasUniqueNonEmptyShortcutEntries() {
        let sections = KeyboardShortcutCatalog.sections
        let shortcuts = sections.flatMap(\.shortcuts)

        XCTAssertFalse(sections.isEmpty)
        XCTAssertFalse(shortcuts.isEmpty)
        XCTAssertTrue(sections.allSatisfy { !$0.title.isEmpty })
        XCTAssertTrue(shortcuts.allSatisfy { !$0.action.isEmpty && !$0.shortcut.isEmpty && !$0.detail.isEmpty })
        XCTAssertEqual(Set(shortcuts.map(\.id)).count, shortcuts.count)
    }

    func testFilteringMatchesActionShortcutAndDetail() {
        XCTAssertEqual(
            KeyboardShortcutCatalog.filteredSections(query: "multiview").flatMap(\.shortcuts).map(\.action),
            ["Show multiview"]
        )

        XCTAssertEqual(
            KeyboardShortcutCatalog.filteredSections(query: "command-/").flatMap(\.shortcuts).map(\.action),
            ["Keyboard shortcuts"]
        )

        XCTAssertEqual(
            KeyboardShortcutCatalog.filteredSections(query: "credential-safe").flatMap(\.shortcuts).map(\.action),
            ["Copy diagnostics"]
        )
    }
}
