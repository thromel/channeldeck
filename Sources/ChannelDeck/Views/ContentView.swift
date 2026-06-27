import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var iptvStore: IPTVStore

    var body: some View {
        Group {
            if iptvStore.isTheaterMode {
                TheaterPlayerView()
                    .toolbar(.hidden, for: .windowToolbar)
            } else {
                standardPlayerLayout
            }
        }
    }

    private var standardPlayerLayout: some View {
        NavigationSplitView {
            CategorySidebarView()
        } content: {
            if iptvStore.isChannelBrowserVisible {
                ChannelBrowserView()
            } else {
                CollapsedChannelRailView {
                    iptvStore.isChannelBrowserVisible = true
                }
            }
        } detail: {
            PlayerDashboardView()
        }
        .navigationSplitViewStyle(.balanced)
        .inspector(isPresented: $iptvStore.isAccountInspectorVisible) {
            AccountInspectorView()
                .environmentObject(accountStore)
                .environmentObject(iptvStore)
                .inspectorColumnWidth(min: 300, ideal: 340, max: 420)
        }
        .sheet(isPresented: $iptvStore.isLocalLibraryVisible) {
            RecordingsLibraryView()
                .environmentObject(iptvStore)
        }
        .sheet(isPresented: $iptvStore.isQuickSwitcherVisible) {
            QuickSwitcherView()
                .environmentObject(accountStore)
                .environmentObject(iptvStore)
        }
        .sheet(isPresented: $iptvStore.isGuidePanelVisible) {
            GuidePanelView()
                .environmentObject(accountStore)
                .environmentObject(iptvStore)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task {
                        await iptvStore.load(account: accountStore.credentials)
                    }
                } label: {
                    Label("Reload Channels", systemImage: "arrow.clockwise")
                }
                .help("Reload account, categories, and live channels")
                .disabled(iptvStore.state == .loading)

                Button {
                    iptvStore.stop()
                    WindowModeController.exitFullScreen()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .help("Stop playback")

                Button {
                    iptvStore.isTheaterMode = false
                    iptvStore.isMultiPlaybackMode = true
                } label: {
                    Label("Multiview", systemImage: "rectangle.grid.2x2")
                }
                .help("Show multiview player")
                .disabled(iptvStore.channels.isEmpty)

                Button {
                    iptvStore.showQuickSwitcher()
                } label: {
                    Label("Quick Open", systemImage: "magnifyingglass")
                }
                .help("Quickly find and play a channel")
                .disabled(iptvStore.channels.isEmpty)

                Button {
                    iptvStore.showGuidePanel(account: accountStore.credentials)
                } label: {
                    Label("Guide", systemImage: "calendar")
                }
                .help("Show current channel guide")
                .disabled(iptvStore.currentChannel == nil)

                Button {
                    iptvStore.toggleChannelBrowser()
                } label: {
                    Label(iptvStore.isChannelBrowserVisible ? "Hide Channels" : "Show Channels", systemImage: iptvStore.isChannelBrowserVisible ? "sidebar.right" : "list.bullet")
                }
                .help(iptvStore.isChannelBrowserVisible ? "Collapse channel list" : "Show channel list")

                Button {
                    iptvStore.isChannelBrowserVisible = false
                    iptvStore.isAccountInspectorVisible = false
                    iptvStore.enterTheaterMode(account: accountStore.credentials)
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(120))
                        WindowModeController.enterFullScreen()
                    }
                } label: {
                    Label("Full Screen Player", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .help("Enter video full screen")
                .disabled(iptvStore.channels.isEmpty)

                Button {
                    iptvStore.saveM3UPlaylist(account: accountStore.credentials)
                } label: {
                    Label("Save M3U", systemImage: "square.and.arrow.down")
                }
                .help("Save a local M3U playlist")
                .disabled(iptvStore.channels.isEmpty)

                Button {
                    iptvStore.showLocalLibrary()
                } label: {
                    Label("Local Library", systemImage: "tray.full")
                }
                .help("Show local recordings and saved playlists")

                Button {
                    iptvStore.toggleAccountInspector()
                } label: {
                    Label("Account", systemImage: "person.crop.circle")
                }
                .help("Show account and playback settings")
            }
        }
    }
}
