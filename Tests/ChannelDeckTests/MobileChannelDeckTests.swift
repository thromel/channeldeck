import XCTest
@testable import ChannelDeckIOS

final class MobileChannelDeckTests: XCTestCase {
    func testMobileNavigationTabsExposeStableAdaptiveShellOrder() {
        XCTAssertEqual(
            MobileAppTab.allCases.map(\.title),
            ["Browse", "Player", "Multiview", "Settings"]
        )
        XCTAssertEqual(
            MobileAppTab.allCases.map(\.navigationTitle),
            ["Channels", "Player", "Multiview", "Settings"]
        )
        XCTAssertEqual(
            MobileAppTab.allCases.map(\.systemImage),
            ["rectangle.grid.1x2", "play.rectangle", "rectangle.grid.2x2", "gearshape"]
        )
    }

    func testMobileSamplePlaylistUsesPublicDirectStreams() {
        XCTAssertEqual(MobileSamplePlaylistProvider.categories.map(\.name), ["All", "Sample"])
        XCTAssertEqual(MobileSamplePlaylistProvider.channels.map(\.name), ["Big Buck Bunny", "Sintel"])
        XCTAssertEqual(Set(MobileSamplePlaylistProvider.channels.compactMap { $0.directSource?.host }), [
            "bitdash-a.akamaihd.net",
            "test-streams.mux.dev"
        ])
        XCTAssertTrue(MobileSamplePlaylistProvider.channels.allSatisfy { $0.id < 0 })
    }

    func testMobileAccountChannelBuildsXtreamLiveURL() {
        let channel = MobileIPTVChannel(
            id: 42,
            name: "Somoy TV",
            categoryID: "news",
            directSource: nil
        )
        let credentials = MobileIPTVCredentials(
            serverURL: "http://example.com:8880/",
            username: "user id",
            password: "p@ss word",
            streamFormat: .hls
        )

        XCTAssertEqual(
            channel.streamURL(credentials: credentials)?.absoluteString,
            "http://example.com:8880/live/user%20id/p@ss%20word/42.m3u8"
        )
    }

    @MainActor
    func testMobileMultiviewAddsChannelsToEmptySlots() {
        let store = MobileIPTVStore(credentialStore: MobileCredentialStore(defaults: isolatedDefaults()))
        store.loadSamplePlaylist()

        let channels = MobileSamplePlaylistProvider.channels
        store.playInMultiview(channels[0])
        store.playInMultiview(channels[1])

        XCTAssertEqual(store.activeMultiviewCount, 2)
        XCTAssertEqual(store.multiviewSlots[0].channel?.name, "Big Buck Bunny")
        XCTAssertEqual(store.multiviewSlots[1].channel?.name, "Sintel")
        XCTAssertTrue(store.multiviewSlots[2].isEmpty)
        XCTAssertTrue(store.multiviewSlots[3].isEmpty)
    }

    @MainActor
    func testMobileMultiviewCanReplaceAndControlSlotAudioIndependently() {
        let store = MobileIPTVStore(credentialStore: MobileCredentialStore(defaults: isolatedDefaults()))
        store.loadSamplePlaylist()

        let slot = store.multiviewSlots[1]
        slot.volume = 0.35
        slot.isMuted = true
        store.playInMultiview(MobileSamplePlaylistProvider.channels[0], slotID: slot.id)
        store.playInMultiview(MobileSamplePlaylistProvider.channels[1], slotID: slot.id)

        XCTAssertEqual(slot.channel?.name, "Sintel")
        XCTAssertEqual(slot.volume, 0.35, accuracy: 0.001)
        XCTAssertTrue(slot.isMuted)
        XCTAssertEqual(slot.player.volume, 0.35, accuracy: 0.001)
        XCTAssertTrue(slot.player.isMuted)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "MobileChannelDeckTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
