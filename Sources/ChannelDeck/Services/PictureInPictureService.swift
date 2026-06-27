import AppKit
import AVFoundation
import AVKit
import Foundation

@MainActor
final class PictureInPictureService: NSObject, ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var isStarting = false
    @Published private(set) var issue: String?

    private let playerLayer: AVPlayerLayer
    private let controller: AVPictureInPictureController?

    init(player: AVPlayer) {
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect

        if AVPictureInPictureController.isPictureInPictureSupported() {
            let source = AVPictureInPictureController.ContentSource(playerLayer: playerLayer)
            controller = AVPictureInPictureController(contentSource: source)
        } else {
            controller = nil
        }

        super.init()
        controller?.delegate = self
    }

    var isSupported: Bool {
        controller != nil
    }

    var canToggle: Bool {
        isSupported && !isStarting
    }

    var label: String {
        if isActive {
            return "Stop Picture in Picture"
        }

        return "Picture in Picture"
    }

    func toggle() {
        guard let controller else {
            issue = "Picture in Picture is not supported on this Mac."
            return
        }

        if controller.isPictureInPictureActive {
            controller.stopPictureInPicture()
            return
        }

        guard controller.isPictureInPicturePossible else {
            issue = "Picture in Picture is not available for the current stream yet."
            return
        }

        issue = nil
        isStarting = true
        controller.startPictureInPicture()
    }
}

extension PictureInPictureService: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            isStarting = true
            issue = nil
        }
    }

    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            isStarting = false
            isActive = true
            issue = nil
        }
    }

    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        Task { @MainActor in
            isStarting = false
            isActive = false
            issue = error.localizedDescription
        }
    }

    nonisolated func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            isStarting = false
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            isStarting = false
            isActive = false
        }
    }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true)
        Task { @MainActor in
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
