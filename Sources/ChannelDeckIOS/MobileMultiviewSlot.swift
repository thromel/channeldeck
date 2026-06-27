import AVFoundation
import Foundation

@MainActor
final class MobileMultiviewSlot: ObservableObject, Identifiable {
    let id = UUID()
    let index: Int
    let player = AVPlayer()

    @Published private(set) var channel: MobileIPTVChannel?
    @Published var volume: Float = 1 {
        didSet {
            player.volume = volume
        }
    }
    @Published var isMuted = false {
        didSet {
            player.isMuted = isMuted
        }
    }

    init(index: Int) {
        self.index = index
        player.volume = volume
        player.isMuted = isMuted
    }

    var title: String {
        channel?.name ?? "Slot \(index + 1)"
    }

    var isEmpty: Bool {
        channel == nil
    }

    func play(channel: MobileIPTVChannel, url: URL) {
        self.channel = channel
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.volume = volume
        player.isMuted = isMuted
        player.play()
    }

    func clear() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        channel = nil
    }
}
