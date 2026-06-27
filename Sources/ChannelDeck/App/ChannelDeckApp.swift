import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct ChannelDeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var accountStore = AccountStore()
    @StateObject private var iptvStore = IPTVStore()

    var body: some Scene {
        WindowGroup("ChannelDeck", id: "main") {
            ContentView()
                .environmentObject(accountStore)
                .environmentObject(iptvStore)
                .frame(minWidth: 1040, minHeight: 680)
                .task {
                    await iptvStore.loadIfReady(account: accountStore.credentials)
                }
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
