import AppKit
import AVFoundation
import AVKit
import Foundation

@MainActor
final class PictureInPictureService: NSObject, ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var isStarting = false
    @Published private(set) var isStopping = false
    @Published private(set) var issue: String?

    private let playerLayer: AVPlayerLayer
    private let controller: AVPictureInPictureController?
    private var stopAfterStart = false

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

    var isRunning: Bool {
        isActive || controller?.isPictureInPictureActive == true
    }

    var isPendingOrActive: Bool {
        isStarting || isStopping || isRunning
    }

    var canToggle: Bool {
        isSupported
    }

    var label: String {
        if isPendingOrActive {
            return "Stop Picture in Picture"
        }

        return "Picture in Picture"
    }

    var systemImage: String {
        isPendingOrActive ? "pip.exit" : "pip.enter"
    }

    func toggle() {
        if isPendingOrActive {
            stop()
            return
        }

        start()
    }

    func stop() {
        guard let controller else {
            issue = "Picture in Picture is not supported on this Mac."
            return
        }

        issue = nil
        let wasStarting = isStarting
        isStarting = false

        if controller.isPictureInPictureActive {
            stopAfterStart = false
            isStopping = true
            isActive = true
            controller.stopPictureInPicture()
            return
        }

        if isActive || isStopping {
            isActive = false
            isStopping = false
            stopAfterStart = false
            return
        }

        guard wasStarting else {
            stopAfterStart = false
            isStopping = false
            isActive = false
            return
        }

        stopAfterStart = true
        isStopping = true
        controller.stopPictureInPicture()
        clearStaleStoppingStateSoon()
    }

    private func start() {
        guard let controller else {
            issue = "Picture in Picture is not supported on this Mac."
            return
        }

        guard controller.isPictureInPicturePossible else {
            issue = "Picture in Picture is not available for the current stream yet."
            return
        }

        stopAfterStart = false
        issue = nil
        isStarting = true
        isStopping = false
        controller.startPictureInPicture()
    }

    private func handleDidStart() {
        isStarting = false
        isActive = true
        issue = nil

        if stopAfterStart {
            stopAfterStart = false
            isStopping = true
            controller?.stopPictureInPicture()
        } else {
            isStopping = false
        }
    }

    private func clearStaleStoppingStateSoon() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))

            guard let self else {
                return
            }

            if isStopping && controller?.isPictureInPictureActive != true {
                isStopping = false
                isActive = false
            }
        }
    }
}

extension PictureInPictureService: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            isStarting = true
            isStopping = false
            issue = nil
        }
    }

    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            handleDidStart()
        }
    }

    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        Task { @MainActor in
            let wasStopRequested = stopAfterStart
            stopAfterStart = false
            isStarting = false
            isStopping = false
            isActive = false
            issue = wasStopRequested ? nil : error.localizedDescription
        }
    }

    nonisolated func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            isStarting = false
            isStopping = true
            issue = nil
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            stopAfterStart = false
            isStarting = false
            isStopping = false
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
