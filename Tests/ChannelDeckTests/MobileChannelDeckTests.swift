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

    func testMobileM3UParserKeepsGroupsLogosRelativeURLsAndQuotedCommas() {
        let sourceURL = URL(fileURLWithPath: "/tmp/mobile-playlists/news/list.m3u")
        let result = MobileM3UPlaylistParser.parse(
            text: """
            #EXTM3U
            #EXTINF:-1 tvg-logo="https://example.com/somoy.png" group-title="News, Local",Somoy TV
            https://example.com/somoy.m3u8
            #EXTGRP:Kids
            #EXTINF:-1,Bunny Junior
            streams/bunny.m3u8
            """,
            sourceURL: sourceURL
        )

        XCTAssertEqual(result.categories.map(\.name), ["News, Local", "Kids"])
        XCTAssertEqual(result.channels.map(\.name), ["Bunny Junior", "Somoy TV"])
        XCTAssertEqual(result.channels.first { $0.name == "Somoy TV" }?.iconURL?.host, "example.com")
        XCTAssertEqual(
            result.channels.first { $0.name == "Bunny Junior" }?.directSource?.absoluteString,
            "file:///tmp/mobile-playlists/news/streams/bunny.m3u8"
        )
        XCTAssertTrue(result.channels.allSatisfy { $0.id < 0 })
    }

    func testMobileM3UExporterIncludesDirectAndAccountStreamURLs() {
        let channels = [
            MobileIPTVChannel(
                id: -1,
                name: "Direct HLS",
                categoryID: "m3u:direct",
                directSource: URL(string: "https://example.com/direct.m3u8")
            ),
            MobileIPTVChannel(
                id: 42,
                name: "Account Channel",
                categoryID: "news",
                directSource: nil
            )
        ]
        let credentials = MobileIPTVCredentials(
            serverURL: "http://example.com:8880",
            username: "user",
            password: "pass",
            streamFormat: .transportStream
        )

        let playlist = MobileM3UPlaylistExporter.makePlaylist(channels: channels, credentials: credentials)

        XCTAssertTrue(playlist.hasPrefix("#EXTM3U\n"))
        XCTAssertTrue(playlist.contains("group-title=\"m3u:direct\",Direct HLS"))
        XCTAssertTrue(playlist.contains("https://example.com/direct.m3u8"))
        XCTAssertTrue(playlist.contains("group-title=\"news\",Account Channel"))
        XCTAssertTrue(playlist.contains("http://example.com:8880/live/user/pass/42.ts"))
    }

    @MainActor
    func testMobileStoreImportsLocalPlaylistAsDirectChannels() throws {
        let store = MobileIPTVStore(credentialStore: MobileCredentialStore(defaults: isolatedDefaults()))
        let playlistURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("channeldeck-mobile-\(UUID().uuidString)")
            .appendingPathExtension("m3u")
        try """
        #EXTM3U
        #EXTINF:-1 group-title="Imported News",Alpha News
        https://example.com/alpha.m3u8
        #EXTINF:-1 group-title="Imported News",Beta News
        https://example.com/beta.m3u8
        """.write(to: playlistURL, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: playlistURL)
        }

        let count = try store.importPlaylist(from: playlistURL)

        XCTAssertEqual(count, 2)
        XCTAssertEqual(store.playlistSourceName, playlistURL.lastPathComponent)
        XCTAssertEqual(store.categories.map(\.name), ["All", "Imported News"])
        XCTAssertEqual(store.selectedCategoryID, "m3u:imported-news")
        XCTAssertEqual(store.channels.map(\.name), ["Alpha News", "Beta News"])
        XCTAssertTrue(store.channels.allSatisfy { $0.directSource != nil })
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
