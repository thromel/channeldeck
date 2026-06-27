import XCTest
@testable import ChannelDeckIOS

final class MobileChannelDeckTests: XCTestCase {
    func testMobileNavigationTabsExposeStableAdaptiveShellOrder() {
        XCTAssertEqual(
            MobileAppTab.allCases.map(\.title),
            ["Home", "Browse", "Player", "Multiview", "Settings"]
        )
        XCTAssertEqual(
            MobileAppTab.allCases.map(\.navigationTitle),
            ["ChannelDeck", "Channels", "Player", "Multiview", "Settings"]
        )
        XCTAssertEqual(
            MobileAppTab.allCases.map(\.systemImage),
            ["house", "rectangle.grid.1x2", "play.rectangle", "rectangle.grid.2x2", "gearshape"]
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

    func testMobileEPGResponseDecodesProviderListingsAndBase64Text() throws {
        let data = """
        {
          "epg_listings": [
            {
              "id": "program-1",
              "title": "TW9ybmluZyBOZXdz",
              "description": "TGl2ZSB1cGRhdGVz",
              "start_timestamp": "1719820800",
              "stop_timestamp": 1719824400
            },
            {
              "title": "Plain Title",
              "description": "",
              "start": "2024-07-01 12:00:00",
              "end": "2024-07-01 13:00:00"
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(MobileEPGResponse.self, from: data)

        XCTAssertEqual(response.programs.count, 2)
        XCTAssertEqual(response.programs[0].id, "program-1")
        XCTAssertEqual(response.programs[0].title, "Morning News")
        XCTAssertEqual(response.programs[0].description, "Live updates")
        XCTAssertEqual(response.programs[0].start, Date(timeIntervalSince1970: 1_719_820_800))
        XCTAssertEqual(response.programs[0].end, Date(timeIntervalSince1970: 1_719_824_400))
        XCTAssertEqual(response.programs[1].title, "Plain Title")
        XCTAssertEqual(response.programs[1].fallbackStartText, "2024-07-01 12:00:00")
    }

    @MainActor
    func testMobileGuideMarksDirectSampleStreamsUnavailable() {
        let store = MobileIPTVStore(credentialStore: MobileCredentialStore(defaults: isolatedDefaults()))
        store.loadSamplePlaylist()

        store.play(MobileSamplePlaylistProvider.channels[0])

        XCTAssertEqual(store.epgPrograms, [])
        XCTAssertEqual(store.epgState, .unavailable)
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
    func testMobileStorePersistsPinsFavoritesAndRecentsAcrossLaunches() {
        let defaults = isolatedDefaults()
        let firstStore = MobileIPTVStore(
            credentialStore: MobileCredentialStore(defaults: defaults),
            defaults: defaults
        )
        firstStore.loadSamplePlaylist()

        let bunny = MobileSamplePlaylistProvider.channels[0]
        let sintel = MobileSamplePlaylistProvider.channels[1]
        firstStore.togglePin(bunny)
        firstStore.toggleFavorite(sintel)
        firstStore.play(sintel)
        firstStore.play(bunny)

        XCTAssertEqual(firstStore.visibleCategories.map(\.id).prefix(4), [
            MobileIPTVCategory.allID,
            MobileIPTVCategory.pinnedID,
            MobileIPTVCategory.favoritesID,
            MobileIPTVCategory.recentID
        ])
        XCTAssertEqual(firstStore.categoryCount(for: MobileIPTVCategory.pinnedID), 1)
        XCTAssertEqual(firstStore.categoryCount(for: MobileIPTVCategory.favoritesID), 1)
        XCTAssertEqual(firstStore.categoryCount(for: MobileIPTVCategory.recentID), 2)

        firstStore.selectedCategoryID = MobileIPTVCategory.pinnedID
        XCTAssertEqual(firstStore.visibleChannels.map(\.name), ["Big Buck Bunny"])
        firstStore.selectedCategoryID = MobileIPTVCategory.favoritesID
        XCTAssertEqual(firstStore.visibleChannels.map(\.name), ["Sintel"])
        firstStore.selectedCategoryID = MobileIPTVCategory.recentID
        XCTAssertEqual(firstStore.visibleChannels.map(\.name), ["Big Buck Bunny", "Sintel"])

        let secondStore = MobileIPTVStore(
            credentialStore: MobileCredentialStore(defaults: defaults),
            defaults: defaults
        )
        secondStore.loadSamplePlaylist()

        XCTAssertEqual(secondStore.pinnedChannels.map(\.name), ["Big Buck Bunny"])
        XCTAssertEqual(secondStore.favoriteChannels.map(\.name), ["Sintel"])
        XCTAssertEqual(secondStore.recentChannels.map(\.name), ["Big Buck Bunny", "Sintel"])
    }

    @MainActor
    func testMobileStoreClearsSavedChannelBuckets() {
        let defaults = isolatedDefaults()
        let store = MobileIPTVStore(
            credentialStore: MobileCredentialStore(defaults: defaults),
            defaults: defaults
        )
        store.loadSamplePlaylist()

        let bunny = MobileSamplePlaylistProvider.channels[0]
        store.togglePin(bunny)
        store.toggleFavorite(bunny)
        store.play(bunny)

        store.clearPinnedChannels()
        store.clearFavorites()
        store.clearRecentChannels()

        XCTAssertTrue(store.pinnedChannels.isEmpty)
        XCTAssertTrue(store.favoriteChannelIDs.isEmpty)
        XCTAssertTrue(store.recentChannels.isEmpty)
        XCTAssertEqual(store.categoryCount(for: MobileIPTVCategory.pinnedID), 0)
        XCTAssertEqual(store.categoryCount(for: MobileIPTVCategory.favoritesID), 0)
        XCTAssertEqual(store.categoryCount(for: MobileIPTVCategory.recentID), 0)
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
