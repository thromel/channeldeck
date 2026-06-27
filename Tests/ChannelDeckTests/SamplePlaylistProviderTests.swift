import XCTest
@testable import ChannelDeck

final class SamplePlaylistProviderTests: XCTestCase {
    func testSamplePlaylistLoadsPublicDirectStreams() {
        let result = SamplePlaylistProvider.makeResult()

        XCTAssertEqual(result.sourceURL.lastPathComponent, SamplePlaylistProvider.displayName)
        XCTAssertEqual(result.categories.map(\.name), ["Sample"])
        XCTAssertEqual(result.channels.map(\.name), ["Big Buck Bunny", "Sintel"])
        XCTAssertEqual(Set(result.channels.compactMap { $0.directSource?.host }), [
            "bitdash-a.akamaihd.net",
            "test-streams.mux.dev"
        ])
        XCTAssertTrue(result.channels.allSatisfy { $0.id < 0 })
        XCTAssertTrue(result.channels.allSatisfy { $0.directSource != nil })
    }
}
