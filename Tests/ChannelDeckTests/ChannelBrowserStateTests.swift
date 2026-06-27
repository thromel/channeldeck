import XCTest
@testable import ChannelDeck

final class ChannelBrowserStateTests: XCTestCase {
    @MainActor
    func testSamplePlaylistCanBeFilteredByDirectSourceAndSearch() {
        let store = IPTVStore(defaults: isolatedDefaults())

        store.loadSamplePlaylist()

        XCTAssertEqual(store.filteredChannels.map(\.name), ["Big Buck Bunny", "Sintel"])

        store.channelSourceFilter = .account
        XCTAssertTrue(store.filteredChannels.isEmpty)

        store.channelSourceFilter = .direct
        store.searchText = "sintel"
        XCTAssertEqual(store.filteredChannels.map(\.name), ["Sintel"])

        store.searchText = "direct hls"
        XCTAssertEqual(Set(store.filteredChannels.map(\.name)), ["Big Buck Bunny", "Sintel"])

        store.resetChannelViewFilters()
        XCTAssertEqual(store.channelSourceFilter, .all)
        XCTAssertEqual(store.channelSortMode, .smart)
        XCTAssertTrue(store.searchText.isEmpty)
    }

    func testChannelSourceLabelNamesAccountAndDirectStreams() {
        let accountChannel = IPTVChannel(
            id: 42,
            name: "Account Channel",
            categoryID: "news",
            directSource: nil
        )
        let directHLS = IPTVChannel(
            id: -1,
            name: "Direct HLS",
            categoryID: "sample",
            directSource: URL(string: "https://example.com/live/index.m3u8")
        )
        let directTS = IPTVChannel(
            id: -2,
            name: "Direct TS",
            categoryID: "sample",
            directSource: URL(string: "https://example.com/live/channel.ts")
        )

        XCTAssertEqual(accountChannel.sourceLabel, "Stream 42")
        XCTAssertEqual(directHLS.sourceLabel, "Direct HLS")
        XCTAssertEqual(directTS.sourceLabel, "Direct TS")
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "ChannelBrowserStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
