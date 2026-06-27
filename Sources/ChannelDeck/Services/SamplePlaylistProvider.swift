import Foundation

enum SamplePlaylistProvider {
    static let displayName = "ChannelDeck Sample Playlist.m3u"

    static func makeResult() -> M3UImportResult {
        M3UPlaylistParser.parse(
            text: playlistText,
            sourceURL: URL(fileURLWithPath: "/\(displayName)")
        )
    }

    private static let playlistText = """
    #EXTM3U
    #EXTINF:-1 tvg-logo="https://peach.blender.org/wp-content/uploads/title_anouncement.jpg?x11217" group-title="Sample",Big Buck Bunny
    https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8
    #EXTINF:-1 tvg-logo="https://durian.blender.org/wp-content/uploads/2010/05/sintel_poster.jpg" group-title="Sample",Sintel
    https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8
    """
}
