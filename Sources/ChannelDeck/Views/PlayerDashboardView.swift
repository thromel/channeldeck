import AVKit
import SwiftUI

struct PlayerDashboardView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var iptvStore: IPTVStore

    var body: some View {
        Group {
            if iptvStore.isMultiPlaybackMode {
                MultiPlaybackView()
            } else {
                VStack(spacing: 0) {
                    VideoStage()
                    PlayerFooter()
                }
                .navigationTitle(iptvStore.currentChannel?.name ?? "ChannelDeck")
            }
        }
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

                Button {
                    iptvStore.showQuickSwitcher()
                } label: {
                    Label("Quick Open", systemImage: "magnifyingglass")
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
                        iptvStore.togglePrimaryRecording(account: accountStore.credentials)
                    } label: {
                        Label(iptvStore.primaryRecording?.isActive == true ? "Stop Recording" : "Record", systemImage: iptvStore.primaryRecording?.isActive == true ? "stop.circle.fill" : "record.circle")
                    }
                    .help(iptvStore.primaryRecording?.isActive == true ? "Stop local recording" : "Record this stream locally")

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
                PlaybackDiagnosticsStrip()
                if let recording = iptvStore.primaryRecording {
                    RecordingStatusView(recording: recording) {
                        iptvStore.revealPrimaryRecording()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
}

private struct PlaybackDiagnosticsStrip: View {
    @EnvironmentObject private var iptvStore: IPTVStore

    var body: some View {
        let diagnostics = iptvStore.playbackDiagnostics

        HStack(spacing: 10) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(diagnostics.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Text(diagnostics.issue ?? diagnostics.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } icon: {
                Image(systemName: iconName(for: diagnostics.status))
                    .foregroundStyle(tint(for: diagnostics.status))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let endpoint = diagnostics.endpoint {
                Text(endpoint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let format = diagnostics.format {
                Text(format)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button {
                PasteboardWriter.copy(diagnostics.copyText)
            } label: {
                Label("Copy Diagnostics", systemImage: "doc.on.doc")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Copy playback diagnostics without stream credentials")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(backgroundTint(for: diagnostics), in: RoundedRectangle(cornerRadius: 7))
    }

    private func iconName(for status: PlaybackDiagnosticStatus) -> String {
        switch status {
        case .idle:
            "waveform.path.ecg"
        case .preparing, .ready:
            "dot.radiowaves.left.and.right"
        case .playing:
            "play.circle.fill"
        case .paused, .stopped:
            "pause.circle"
        case .buffering:
            "hourglass"
        case .stalled:
            "exclamationmark.triangle.fill"
        case .failed:
            "xmark.octagon.fill"
        }
    }

    private func tint(for status: PlaybackDiagnosticStatus) -> Color {
        switch status {
        case .playing, .ready:
            .green
        case .buffering, .preparing:
            .blue
        case .stalled:
            .orange
        case .failed:
            .red
        case .idle, .paused, .stopped:
            .secondary
        }
    }

    private func backgroundTint(for diagnostics: PlaybackDiagnostics) -> Color {
        if diagnostics.hasIssue {
            return tint(for: diagnostics.status).opacity(0.16)
        }

        return Color.primary.opacity(0.04)
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

            Button {
                iptvStore.showGuidePanel(account: accountStore.credentials)
            } label: {
                Label("Open Guide", systemImage: "rectangle.and.text.magnifyingglass")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Open full guide")
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
