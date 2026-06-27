import AppKit
import SwiftUI

@MainActor
final class AppServices {
    static let shared = AppServices()

    let accountStore: AccountStore
    let iptvStore: IPTVStore
    let pictureInPictureService: PictureInPictureService

    private init() {
        accountStore = AccountStore()
        iptvStore = IPTVStore()
        pictureInPictureService = PictureInPictureService(player: iptvStore.player)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var fallbackWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        repairOffscreenWindowFrames()
        ensureWindowPresented()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            ensureWindowPresented()
        }

        return true
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldSaveApplicationState(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldRestoreApplicationState(_ sender: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
        false
    }

    func application(_ application: NSApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
        false
    }

    private func ensureWindowPresented() {
        for delay in [0.2, 0.7, 1.4] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.presentOrRepairWindows()
            }
        }
    }

    private func presentOrRepairWindows() {
        if NSApp.windows.isEmpty {
            NSApp.sendAction(Selector(("newWindow:")), to: nil, from: nil)
        }

        repairPresentedWindows()
        presentFallbackWindowIfNeeded()
    }

    private func repairPresentedWindows() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        for window in NSApp.windows where window.level == .normal {
            let appearsOnMainScreen = window.frame.intersects(screen.visibleFrame)
            let isUnusableSize = window.frame.width < 640 || window.frame.height < 420

            if window.styleMask.contains(.borderless) {
                window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            }

            if isUnusableSize || !appearsOnMainScreen {
                window.setFrame(centeredFrame(in: screen.visibleFrame), display: true)
            }

            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private func presentFallbackWindowIfNeeded() {
        if hasUsableWindow {
            return
        }

        if let fallbackWindow {
            fallbackWindow.setFrame(centeredFrame(in: (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .zero), display: true)
            fallbackWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let screenFrame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1180, height: 760)
        let window = NSWindow(
            contentRect: centeredFrame(in: screenFrame),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ChannelDeck"
        window.minSize = NSSize(width: 1040, height: 680)
        window.contentView = NSHostingView(rootView: RootChannelDeckView())
        window.isReleasedWhenClosed = false
        fallbackWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private var hasUsableWindow: Bool {
        NSApp.windows.contains { window in
            window.level == .normal
                && window.isVisible
                && window.frame.width >= 640
                && window.frame.height >= 420
        }
    }

    private func centeredFrame(in visibleFrame: NSRect) -> NSRect {
        let width = min(1180, visibleFrame.width)
        let height = min(760, visibleFrame.height)
        return NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func repairOffscreenWindowFrames() {
        let defaults = UserDefaults.standard
        let screenFrames = NSScreen.screens.map(\.visibleFrame)
        guard !screenFrames.isEmpty else {
            return
        }

        for (key, value) in defaults.dictionaryRepresentation() {
            if key.contains("main-AppWindow") {
                defaults.removeObject(forKey: key)
                continue
            }

            guard key.hasPrefix("NSWindow Frame") else {
                continue
            }

            guard let frameString = value as? String,
                  let frame = NSRect(windowFrameString: frameString) else {
                continue
            }

            let appearsOnScreen = screenFrames.contains { screenFrame in
                frame.intersects(screenFrame)
            }

            if !appearsOnScreen {
                defaults.removeObject(forKey: key)
            }
        }
    }

}

private extension NSRect {
    init?(windowFrameString: String) {
        let values = windowFrameString
            .split(separator: " ")
            .compactMap { Double($0) }

        guard values.count >= 4 else {
            return nil
        }

        self.init(x: values[0], y: values[1], width: values[2], height: values[3])
    }
}

@main
struct ChannelDeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let accountStore = AppServices.shared.accountStore
    private let iptvStore = AppServices.shared.iptvStore
    private let pictureInPictureService = AppServices.shared.pictureInPictureService

    var body: some Scene {
        Window("ChannelDeck", id: "main") {
            RootChannelDeckView()
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandMenu("Playback") {
                Button("Reload Channels") {
                    Task {
                        await iptvStore.load(account: accountStore.credentials)
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(iptvStore.state == .loading)

                Divider()

                Button("Play/Pause") {
                    iptvStore.togglePlayback()
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(iptvStore.currentChannel == nil)

                Button("Previous Channel") {
                    iptvStore.playPrevious(account: accountStore.credentials)
                }
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(iptvStore.channels.isEmpty)

                Button("Next Channel") {
                    iptvStore.playNext(account: accountStore.credentials)
                }
                .keyboardShortcut("]", modifiers: [.command])
                .disabled(iptvStore.channels.isEmpty)

                Button("Stop") {
                    iptvStore.stop()
                    WindowModeController.exitFullScreen()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(iptvStore.currentChannel == nil)

                Divider()

                Button(iptvStore.currentChannel.map { iptvStore.isFavorite($0) } == true ? "Remove Current Channel from Favorites" : "Add Current Channel to Favorites") {
                    iptvStore.toggleFavoriteForCurrentChannel()
                }
                .keyboardShortcut("d", modifiers: [.command])
                .disabled(iptvStore.currentChannel == nil)

                Button(iptvStore.currentChannel.map { iptvStore.isPinned($0) } == true ? "Unpin Current Channel" : "Pin Current Channel") {
                    iptvStore.togglePinForCurrentChannel()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(iptvStore.currentChannel == nil)

                Button("Copy Playback Diagnostics") {
                    PasteboardWriter.copy(iptvStore.playbackDiagnostics.copyText)
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
                .disabled(iptvStore.currentChannel == nil)

                Button(pictureInPictureService.label) {
                    pictureInPictureService.toggle()
                }
                .keyboardShortcut("p", modifiers: [.command, .option])
                .disabled(iptvStore.currentChannel == nil || !pictureInPictureService.canToggle)

                Button(iptvStore.primaryRecording?.isActive == true ? "Stop Recording Current Stream" : "Record Current Stream") {
                    iptvStore.togglePrimaryRecording(account: accountStore.credentials)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(iptvStore.currentChannel == nil)

                Divider()

                Button(iptvStore.isTheaterMode ? "Exit Full Screen Player" : "Full Screen Player") {
                    if iptvStore.isTheaterMode {
                        iptvStore.exitTheaterMode()
                        WindowModeController.exitFullScreen()
                    } else {
                        iptvStore.isChannelBrowserVisible = false
                        iptvStore.isAccountInspectorVisible = false
                        iptvStore.enterTheaterMode(account: accountStore.credentials)
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(120))
                            WindowModeController.enterFullScreen()
                        }
                    }
                }
                .keyboardShortcut("f", modifiers: [.command, .control])
                .disabled(iptvStore.channels.isEmpty)
            }

            CommandMenu("Channels") {
                Button("Quick Open Channel") {
                    iptvStore.showQuickSwitcher()
                }
                .keyboardShortcut("k", modifiers: [.command])
                .disabled(iptvStore.channels.isEmpty)

                Button("Show Current Guide") {
                    iptvStore.showGuidePanel(account: accountStore.credentials)
                }
                .keyboardShortcut("g", modifiers: [.command, .option])
                .disabled(iptvStore.currentChannel == nil)

                Divider()

                Button("Show Multiview") {
                    iptvStore.isTheaterMode = false
                    iptvStore.isMultiPlaybackMode = true
                }
                .keyboardShortcut("m", modifiers: [.command, .option])
                .disabled(iptvStore.channels.isEmpty)

                Button("Save Multiview Layout") {
                    iptvStore.saveMultiPlaybackLayout()
                }
                .disabled(iptvStore.activeMultiPlaybackCount == 0)

                Button("Restore Multiview Layout") {
                    iptvStore.restoreMultiPlaybackLayout(account: accountStore.credentials)
                }
                .disabled(!iptvStore.hasSavedMultiPlaybackLayout || iptvStore.channels.isEmpty)

                Button("Clear Multiview") {
                    iptvStore.clearMultiPlayback()
                }
                .disabled(iptvStore.activeMultiPlaybackCount == 0)

                Divider()

                Button("Save M3U Playlist") {
                    iptvStore.saveM3UPlaylist(account: accountStore.credentials)
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(iptvStore.channels.isEmpty)

                Button("Show Local Library") {
                    iptvStore.showLocalLibrary()
                }
                .keyboardShortcut("j", modifiers: [.command, .option])

                Divider()

                Button(iptvStore.isChannelBrowserVisible ? "Collapse Channels" : "Show Channels") {
                    iptvStore.toggleChannelBrowser()
                }
                .keyboardShortcut("l", modifiers: [.command, .option])

                Button(iptvStore.isAccountInspectorVisible ? "Hide Account" : "Show Account") {
                    iptvStore.toggleAccountInspector()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(accountStore)
                .padding(20)
                .frame(width: 500)
        }
    }
}

private struct RootChannelDeckView: View {
    @ObservedObject private var accountStore = AppServices.shared.accountStore
    @ObservedObject private var iptvStore = AppServices.shared.iptvStore
    @ObservedObject private var pictureInPictureService = AppServices.shared.pictureInPictureService

    var body: some View {
        ContentView()
            .environmentObject(accountStore)
            .environmentObject(iptvStore)
            .environmentObject(pictureInPictureService)
            .frame(minWidth: 1040, minHeight: 680)
            .background(WindowRepairView())
            .task {
                await accountStore.restoreSavedPassword()
                await iptvStore.loadIfReady(account: accountStore.credentials)
            }
    }
}

private struct WindowRepairView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        scheduleRepair(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        scheduleRepair(for: nsView)
    }

    private func scheduleRepair(for view: NSView) {
        for delay in [0.0, 0.3, 0.9] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                repair(window: view.window)
            }
        }
    }

    private func repair(window: NSWindow?) {
        guard let window,
              let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        if window.styleMask.contains(.borderless) {
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        }

        let needsFrameRepair = window.frame.width < 640
            || window.frame.height < 420
            || !window.frame.intersects(screen.visibleFrame)

        if needsFrameRepair {
            let width = min(1180, screen.visibleFrame.width)
            let height = min(760, screen.visibleFrame.height)
            let frame = NSRect(
                x: screen.visibleFrame.midX - width / 2,
                y: screen.visibleFrame.midY - height / 2,
                width: width,
                height: height
            )
            window.setFrame(frame, display: true)
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
