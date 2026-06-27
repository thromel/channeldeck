import AppKit
import SwiftUI

struct TheaterPlayerView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var iptvStore: IPTVStore

    @State private var controlsVisible = true
    @State private var keyMonitor: Any?

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            PlayerSurfaceView(player: iptvStore.player)
                .ignoresSafeArea()

            if controlsVisible {
                overlay
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            controlsVisible.toggle()
            if controlsVisible {
                scheduleOverlayHide()
            }
        }
        .onAppear {
            installEscapeMonitor()
            scheduleOverlayHide()
        }
        .onDisappear {
            removeEscapeMonitor()
        }
    }

    private var overlay: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(iptvStore.currentChannel?.name ?? "ChannelDeck")
                        .font(.headline)
                        .lineLimit(1)

                    if let channel = iptvStore.currentChannel {
                        Text("\(iptvStore.categoryName(for: channel.categoryID))  \(accountStore.streamFormat.label)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

                Spacer()

                Button {
                    exitTheaterMode()
                } label: {
                    Label("Exit", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Spacer()
        }
        .padding(24)
        .animation(.easeInOut(duration: 0.18), value: controlsVisible)
    }

    private func scheduleOverlayHide() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            controlsVisible = false
        }
    }

    private func installEscapeMonitor() {
        removeEscapeMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                Task { @MainActor in
                    exitTheaterMode()
                }
                return nil
            }

            return event
        }
    }

    private func removeEscapeMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func exitTheaterMode() {
        iptvStore.exitTheaterMode()
        WindowModeController.exitFullScreen()
    }
}
