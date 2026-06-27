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
    @EnvironmentObject private var iptvStore: IPTVStore

    var body: some View {
        VStack(spacing: 16) {
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

            if !iptvStore.channels.isEmpty {
                HStack(spacing: 8) {
                    EmptyStatePill(label: "Pins", value: iptvStore.pinnedChannels.count, systemImage: "pin.fill")
                    EmptyStatePill(label: "Favorites", value: iptvStore.favoriteChannelIDs.count, systemImage: "star.fill")
                    EmptyStatePill(label: "Recent", value: iptvStore.recentChannels.count, systemImage: "clock.arrow.circlepath")
                }
            }
        }
        .padding(28)
    }
}

private struct EmptyStatePill: View {
    let label: String
    let value: Int
    let systemImage: String

    var body: some View {
        Label {
            Text("\(label) \(value)")
                .monospacedDigit()
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary, in: Capsule())
    }
}

private struct PlayerFooter: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var iptvStore: IPTVStore

    var body: some View {
        VStack(spacing: 10) {
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
                        iptvStore.togglePin(channel)
                    } label: {
                        Label(iptvStore.isPinned(channel) ? "Pinned" : "Pin", systemImage: iptvStore.isPinned(channel) ? "pin.fill" : "pin")
                    }
                    .help(iptvStore.isPinned(channel) ? "Unpin channel" : "Pin channel")

                    Button {
                        iptvStore.toggleFavorite(channel)
                    } label: {
                        Label(iptvStore.isFavorite(channel) ? "Favorited" : "Favorite", systemImage: iptvStore.isFavorite(channel) ? "star.fill" : "star")
                    }
                    .help(iptvStore.isFavorite(channel) ? "Remove from favorites" : "Add to favorites")

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

            if iptvStore.currentChannel != nil {
                GuideStrip()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
}

private struct GuideStrip: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var iptvStore: IPTVStore

    var body: some View {
        HStack(spacing: 10) {
            Label("Guide", systemImage: "calendar")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            switch iptvStore.epgState {
            case .idle:
                GuideMessage(text: "Guide will load when playback starts.")
            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading guide")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case .loaded:
                ForEach(Array(iptvStore.epgPrograms.prefix(2).enumerated()), id: \.offset) { index, program in
                    GuideProgramCard(label: index == 0 ? "Now" : "Next", program: program)
                }
            case .unavailable:
                GuideMessage(text: "No guide data returned for this channel.")
            case .failed:
                GuideMessage(text: "Guide unavailable.")
            }

            Button {
                iptvStore.refreshCurrentEPG(account: accountStore.credentials)
            } label: {
                Label("Refresh Guide", systemImage: "arrow.clockwise")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Refresh guide")
            .disabled(iptvStore.epgState == .loading)
        }
    }
}

private struct GuideProgramCard: View {
    let label: String
    let program: EPGProgram

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(label == "Now" ? .green : .secondary)
                Text(program.timeRangeText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(program.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            if !program.description.isEmpty {
                Text(program.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct GuideMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
    }
}
