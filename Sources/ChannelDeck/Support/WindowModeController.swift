import AppKit

@MainActor
enum WindowModeController {
    private struct WindowState {
        let frame: NSRect
        let styleMask: NSWindow.StyleMask
        let level: NSWindow.Level
        let presentationOptions: NSApplication.PresentationOptions
    }

    private static var savedState: WindowState?

    static func enterFullScreen() {
        guard let window = activeWindow else {
            return
        }

        guard savedState == nil else {
            return
        }

        savedState = WindowState(
            frame: window.frame,
            styleMask: window.styleMask,
            level: window.level,
            presentationOptions: NSApp.presentationOptions
        )

        let screenFrame = window.screen?.frame ?? NSScreen.main?.frame ?? window.frame
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        window.styleMask = [.borderless]
        window.level = .normal
        window.setFrame(screenFrame, display: true, animate: false)
        window.makeKeyAndOrderFront(nil)
    }

    static func exitFullScreen() {
        guard let window = activeWindow else {
            return
        }

        guard let state = savedState else {
            return
        }

        window.styleMask = state.styleMask
        window.level = state.level
        window.setFrame(state.frame, display: true, animate: false)
        NSApp.presentationOptions = state.presentationOptions
        savedState = nil
    }

    static var isFullScreenActive: Bool {
        savedState != nil
    }

    private static var activeWindow: NSWindow? {
        NSApp.keyWindow
            ?? NSApp.mainWindow
            ?? NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain })
    }
}
