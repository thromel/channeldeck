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
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var iptvStore: IPTVStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center, spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.thinMaterial)
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                    .frame(width: 68, height: 54)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("ChannelDeck")
                            .font(.largeTitle.weight(.semibold))
                        Text(dashboardSubtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 20)

                    if iptvStore.state == .loading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                HStack(spacing: 8) {
                    EmptyStatePill(label: "Pins", value: iptvStore.pinnedChannels.count, systemImage: "pin.fill")
                    EmptyStatePill(label: "Favorites", value: iptvStore.favoriteChannelIDs.count, systemImage: "star.fill")
                    EmptyStatePill(label: "Recent", value: iptvStore.recentChannels.count, systemImage: "clock.arrow.circlepath")
                    EmptyStatePill(label: "Channels", value: iptvStore.channels.count, systemImage: "tv")
                }

                HStack(spacing: 10) {
                    DashboardActionButton(title: "Try Sample", systemImage: "play.square.stack") {
                        iptvStore.loadSamplePlaylist()
                    }

                    DashboardActionButton(title: "Quick Open", systemImage: "magnifyingglass") {
                        iptvStore.showQuickSwitcher()
                    }
                    .disabled(iptvStore.channels.isEmpty)

                    DashboardActionButton(title: "Multiview", systemImage: "rectangle.grid.2x2") {
                        iptvStore.isTheaterMode = false
                        iptvStore.isMultiPlaybackMode = true
                    }
                    .disabled(iptvStore.channels.isEmpty)

                    DashboardActionButton(title: "Local Library", systemImage: "tray.full") {
                        iptvStore.showLocalLibrary()
                    }

                    DashboardActionButton(title: "Reload", systemImage: "arrow.clockwise") {
                        Task {
                            await iptvStore.load(account: accountStore.credentials)
                        }
                    }
                    .disabled(iptvStore.state == .loading || !accountStore.credentials.isComplete)
                }

                DashboardChannelSection(
                    title: "Continue Watching",
                    systemImage: "clock.arrow.circlepath",
                    channels: Array(iptvStore.recentChannels.prefix(6)),
                    emptyText: "Recent channels appear here.",
                    play: play,
                    multiview: addToMultiview,
                    pin: iptvStore.togglePin,
                    favorite: iptvStore.toggleFavorite,
                    isPinned: iptvStore.isPinned,
                    isFavorite: iptvStore.isFavorite
                )

                DashboardChannelSection(
                    title: "Pinned",
                    systemImage: "pin.fill",
                    channels: Array(iptvStore.pinnedChannels.prefix(6)),
                    emptyText: "Pinned channels appear here.",
                    play: play,
                    multiview: addToMultiview,
                    pin: iptvStore.togglePin,
                    favorite: iptvStore.toggleFavorite,
                    isPinned: iptvStore.isPinned,
                    isFavorite: iptvStore.isFavorite
                )

                DashboardChannelSection(
                    title: "Favorites",
                    systemImage: "star.fill",
                    channels: Array(favoriteChannels.prefix(6)),
                    emptyText: "Favorite channels appear here.",
                    play: play,
                    multiview: addToMultiview,
                    pin: iptvStore.togglePin,
                    favorite: iptvStore.toggleFavorite,
                    isPinned: iptvStore.isPinned,
                    isFavorite: iptvStore.isFavorite
                )
            }
            .frame(maxWidth: 920, alignment: .leading)
            .padding(32)
        }
    }

    private var dashboardSubtitle: String {
        if let importedPlaylistName = iptvStore.importedPlaylistName {
            return "\(iptvStore.channels.count) channels from \(importedPlaylistName)"
        }

        if iptvStore.channels.isEmpty {
            return "Load your account to start watching live channels."
        }

        return "\(iptvStore.channels.count) live channels available"
    }

    private var favoriteChannels: [IPTVChannel] {
        iptvStore.channels.filter { iptvStore.favoriteChannelIDs.contains($0.id) }
    }

    private func play(_ channel: IPTVChannel) {
        iptvStore.play(channel, account: accountStore.credentials)
    }

    private func addToMultiview(_ channel: IPTVChannel) {
        iptvStore.playInMultiPlayback(channel, account: accountStore.credentials)
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

private struct DashboardActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(minWidth: 112)
        }
        .controlSize(.large)
    }
}

private struct DashboardChannelSection: View {
    let title: String
    let systemImage: String
    let channels: [IPTVChannel]
    let emptyText: String
    let play: (IPTVChannel) -> Void
    let multiview: (IPTVChannel) -> Void
    let pin: (IPTVChannel) -> Void
    let favorite: (IPTVChannel) -> Void
    let isPinned: (IPTVChannel) -> Bool
    let isFavorite: (IPTVChannel) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.primary)

            if channels.isEmpty {
                Text(emptyText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(channels) { channel in
                        DashboardChannelTile(
                            channel: channel,
                            play: { play(channel) },
                            multiview: { multiview(channel) },
                            pin: { pin(channel) },
                            favorite: { favorite(channel) },
                            isPinned: isPinned(channel),
                            isFavorite: isFavorite(channel)
                        )
                    }
                }
            }
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 260, maximum: 320), spacing: 10)
        ]
    }
}

private struct DashboardChannelTile: View {
    let channel: IPTVChannel
    let play: () -> Void
    let multiview: () -> Void
    let pin: () -> Void
    let favorite: () -> Void
    let isPinned: Bool
    let isFavorite: Bool

    var body: some View {
        VStack(spacing: 10) {
            Button(action: play) {
                HStack(spacing: 10) {
                    ChannelArtwork(url: channel.iconURL)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(channel.name)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text("Stream \(channel.id)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "play.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Button(action: multiview) {
                    Image(systemName: "rectangle.grid.2x2")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help("Add to multiview")

                Button(action: pin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(isPinned ? .orange : .secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help(isPinned ? "Unpin" : "Pin")

                Button(action: favorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? .yellow : .secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help(isFavorite ? "Remove from favorites" : "Add to favorites")

                Spacer()
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct PlayerFooter: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var iptvStore: IPTVStore
    @EnvironmentObject private var pictureInPictureService: PictureInPictureService

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
                        pictureInPictureService.toggle()
                    } label: {
                        Label(pictureInPictureService.label, systemImage: pictureInPictureService.systemImage)
                    }
                    .help(pictureInPictureService.label)
                    .disabled(!pictureInPictureService.canToggle)

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
                    pictureInPictureService.stop()
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
                PictureInPictureStatusStrip()
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

private struct PictureInPictureStatusStrip: View {
    @EnvironmentObject private var pictureInPictureService: PictureInPictureService

    var body: some View {
        if pictureInPictureService.isPendingOrActive || pictureInPictureService.issue != nil {
            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)

                Text(statusText)
                    .font(.caption.weight(.semibold))

                if let issue = pictureInPictureService.issue {
                    Text(issue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if pictureInPictureService.isPendingOrActive {
                    Button {
                        pictureInPictureService.stop()
                    } label: {
                        Label("Stop Picture in Picture", systemImage: "pip.exit")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Stop Picture in Picture")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
        }
    }

    private var statusIcon: String {
        if pictureInPictureService.issue != nil && !pictureInPictureService.isPendingOrActive {
            return "exclamationmark.triangle.fill"
        }

        if pictureInPictureService.isStopping {
            return "pip.exit"
        }

        return "pip.fill"
    }

    private var statusText: String {
        if pictureInPictureService.issue != nil && !pictureInPictureService.isPendingOrActive {
            return "Picture in Picture unavailable"
        }

        if pictureInPictureService.isStopping {
            return "Stopping Picture in Picture"
        }

        if pictureInPictureService.isStarting {
            return "Starting Picture in Picture"
        }

        return "Picture in Picture is active"
    }

    private var statusColor: Color {
        if pictureInPictureService.issue != nil && !pictureInPictureService.isPendingOrActive {
            return .orange
        }

        return .green
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
