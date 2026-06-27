import XCTest
@testable import ChannelDeck

final class LocalMediaBrowserTests: XCTestCase {
    func testSummaryCountsKindsAndTotalBytes() {
        let items = sampleItems()

        let summary = LocalMediaBrowser.summary(for: items)

        XCTAssertEqual(summary.itemCount, 4)
        XCTAssertEqual(summary.recordingCount, 2)
        XCTAssertEqual(summary.playlistCount, 1)
        XCTAssertEqual(summary.downloadCount, 1)
        XCTAssertEqual(summary.byteCount, 8_250)
    }

    func testVisibleItemsFiltersSearchesAndSorts() {
        let items = sampleItems()

        let playlists = LocalMediaBrowser.visibleItems(
            from: items,
            filter: .playlists,
            query: "",
            sortMode: .newest
        )
        XCTAssertEqual(playlists.map(\.name), ["saved-news.m3u"])

        let searchedRecordings = LocalMediaBrowser.visibleItems(
            from: items,
            filter: .recordings,
            query: "sports",
            sortMode: .newest
        )
        XCTAssertEqual(searchedRecordings.map(\.name), ["sports.ts"])

        let largest = LocalMediaBrowser.visibleItems(
            from: items,
            filter: .all,
            query: "",
            sortMode: .largest
        )
        XCTAssertEqual(largest.map(\.name), ["news.ts", "sports.ts", "saved-news.m3u", "notes.txt"])

        let byName = LocalMediaBrowser.visibleItems(
            from: items,
            filter: .all,
            query: "",
            sortMode: .name
        )
        XCTAssertEqual(byName.map(\.name), ["news.ts", "notes.txt", "saved-news.m3u", "sports.ts"])
    }

    private func sampleItems() -> [LocalMediaItem] {
        [
            item(name: "sports.ts", kind: .recording, modifiedOffset: 40, byteCount: 2_000),
            item(name: "saved-news.m3u", kind: .playlist, modifiedOffset: 30, byteCount: 250),
            item(name: "news.ts", kind: .recording, modifiedOffset: 20, byteCount: 6_000),
            item(name: "notes.txt", kind: .download, modifiedOffset: 10, byteCount: 0)
        ]
    }

    private func item(
        name: String,
        kind: LocalMediaKind,
        modifiedOffset: TimeInterval,
        byteCount: Int64
    ) -> LocalMediaItem {
        let modifiedAt = Date(timeIntervalSince1970: modifiedOffset)
        let url = URL(fileURLWithPath: "/tmp/\(name)")
        return LocalMediaItem(
            id: url,
            url: url,
            name: name,
            kind: kind,
            createdAt: modifiedAt,
            modifiedAt: modifiedAt,
            byteCount: byteCount
        )
    }
}
