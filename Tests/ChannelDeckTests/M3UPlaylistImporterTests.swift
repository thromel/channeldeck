import XCTest
@testable import ChannelDeck

final class M3UPlaylistImporterTests: XCTestCase {
    func testParsesGroupsLogosAndDirectStreamURLs() {
        let playlist = """
        #EXTM3U
        #EXTINF:-1 tvg-id="news-one" tvg-logo="https://example.com/news.png" group-title="News",News One
        https://stream.example.com/news/index.m3u8
        #EXTGRP:Sports
        #EXTINF:-1,Match Channel
        relative.ts
        """

        let sourceURL = URL(fileURLWithPath: "/tmp/source/playlist.m3u")
        let result = M3UPlaylistParser.parse(text: playlist, sourceURL: sourceURL)

        XCTAssertEqual(result.channels.count, 2)
        XCTAssertEqual(result.categories.map(\.name), ["News", "Sports"])
        XCTAssertEqual(result.channels.map(\.name), ["Match Channel", "News One"])

        let news = result.channels.first { $0.name == "News One" }
        XCTAssertEqual(news?.iconURL, URL(string: "https://example.com/news.png"))
        XCTAssertEqual(news?.directSource, URL(string: "https://stream.example.com/news/index.m3u8"))
        XCTAssertEqual(news?.categoryID, result.categories.first { $0.name == "News" }?.id)

        let sports = result.channels.first { $0.name == "Match Channel" }
        XCTAssertEqual(sports?.directSource, URL(fileURLWithPath: "/tmp/source/relative.ts"))
        XCTAssertEqual(sports?.categoryID, result.categories.first { $0.name == "Sports" }?.id)
    }

    func testKeepsCommasInsideQuotedAttributesOutOfTheTitleSplit() {
        let playlist = """
        #EXTM3U
        #EXTINF:-1 group-title="News, Local",Channel, With Comma
        https://example.com/channel.ts
        """

        let result = M3UPlaylistParser.parse(
            text: playlist,
            sourceURL: URL(fileURLWithPath: "/tmp/playlist.m3u")
        )

        XCTAssertEqual(result.categories.map(\.name), ["News, Local"])
        XCTAssertEqual(result.channels.first?.name, "Channel, With Comma")
    }
}
