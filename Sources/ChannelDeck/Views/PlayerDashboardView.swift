import AVKit
import SwiftUI

struct PlayerDashboardView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var iptvStore: IPTVStore

    var body: some View {
        VStack(spacing: 0) {
            VideoStage()
            PlayerFooter()
        }
        .navigationTitle(iptvStore.currentChannel?.name ?? "ChannelDeck")
    }
}

private struct VideoStage: View {
    @EnvironmentObject private var iptvStore: IPTVStore

    var body: some View {
        ZStack {
            Color.black

            PlayerSurfaceView(player: iptvStore.player)
                .ignoresSafeArea(edges: .bottom)

            if iptvStore.currentChannel == nil {
                EmptyPlayerState()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EmptyPlayerState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 58, weight: .regular))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("Choose a channel")
                    .font(.title2.weight(.semibold))

                Text("Live playback starts here, with channel controls below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
    }
}

private struct PlayerFooter: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var iptvStore: IPTVStore

    var body: some View {
        HStack(spacing: 14) {
            if let channel = iptvStore.currentChannel {
                ChannelArtwork(url: channel.iconURL)

                VStack(alignment: .leading, spacing: 3) {
                    Text(channel.name)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(iptvStore.categoryName(for: channel.categoryID))
                        Text(accountStore.streamFormat.label)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            } else {
                Image(systemName: "tv")
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 34)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Nothing playing")
                        .font(.headline)
                    Text("Select a channel from the center column.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            if let channel = iptvStore.currentChannel,
               let url = channel.streamURL(account: accountStore.credentials) {
                Button {
                    iptvStore.enterTheaterMode(account: accountStore.credentials)
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(120))
                        WindowModeController.enterFullScreen()
                    }
                } label: {
                    Label("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                }

                Button {
                    PasteboardWriter.copy(url.absoluteString)
                } label: {
                    Label("Copy URL", systemImage: "doc.on.doc")
                }

                Button {
                    WorkspaceOpener.open(url)
                } label: {
                    Label("Open URL", systemImage: "arrow.up.right")
                }
            }

            Button {
                iptvStore.stop()
                WindowModeController.exitFullScreen()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .disabled(iptvStore.currentChannel == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
}
