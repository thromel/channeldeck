import XCTest
@testable import ChannelDeckIOS

final class MobileChannelDeckTests: XCTestCase {
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
}
