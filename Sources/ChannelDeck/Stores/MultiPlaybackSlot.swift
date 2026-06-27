import AVKit
import Foundation

struct MultiPlaybackLayout: Codable {
    let slotCount: Int
    let slots: [MultiPlaybackLayoutSlot]
}

struct MultiPlaybackLayoutSlot: Codable {
    let id: Int
    let channelID: IPTVChannel.ID
    let volume: Double
    let isMuted: Bool
}

@MainActor
final class MultiPlaybackSlot: ObservableObject, Identifiable {
    let id: Int
    let player = AVPlayer()

    @Published private(set) var channel: IPTVChannel?
    @Published private(set) var streamURL: URL?
    @Published private(set) var volume: Double
    @Published private(set) var isMuted: Bool
    @Published private(set) var recording: LocalStreamRecording?

    init(id: Int, volume: Double = 0.65, isMuted: Bool = false) {
        self.id = id
        self.volume = min(max(volume, 0), 1)
        self.isMuted = isMuted
        player.volume = Float(self.volume)
        player.isMuted = isMuted
    }

    var isEmpty: Bool {
        channel == nil
    }

    func play(channel: IPTVChannel, url: URL) {
        self.channel = channel
        streamURL = url
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.volume = Float(volume)
        player.isMuted = isMuted
        player.play()
    }

    func toggleMute() {
        isMuted.toggle()
        player.isMuted = isMuted
    }

    func setMuted(_ isMuted: Bool) {
        self.isMuted = isMuted
        player.isMuted = isMuted
    }

    func setVolume(_ volume: Double) {
        self.volume = min(max(volume, 0), 1)
        player.volume = Float(self.volume)
    }

    func setRecording(_ recording: LocalStreamRecording?) {
        self.recording = recording
    }

    func clear() {
        recording?.stop()
        recording = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        channel = nil
        streamURL = nil
    }
}
