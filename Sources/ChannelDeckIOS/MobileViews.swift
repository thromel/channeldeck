import AVKit
import SwiftUI

enum MobileAppTab: String, CaseIterable, Identifiable {
    case browse
    case player
    case settings

    var id: String { rawValue }

    @ViewBuilder
    var label: some View {
        switch self {
        case .browse:
            Label("Browse", systemImage: "rectangle.grid.1x2")
        case .player:
            Label("Player", systemImage: "play.rectangle")
        case .settings:
            Label("Settings", systemImage: "gearshape")
        }
    }
}

struct MobileRootView: View {
    @StateObject private var store = MobileIPTVStore()
    @State private var selectedTab: MobileAppTab = .browse

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MobileBrowseView(store: store, selectedTab: $selectedTab)
                    .navigationTitle("Channels")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                Task {
                                    await store.loadAccount()
                                }
                            } label: {
                                Label("Reload", systemImage: "arrow.clockwise")
                            }
                            .disabled(!store.canLoadAccount)
                        }
                    }
            }
            .tabItem { MobileAppTab.browse.label }
            .tag(MobileAppTab.browse)

            NavigationStack {
                MobilePlayerView(store: store)
                    .navigationTitle("Player")
            }
            .tabItem { MobileAppTab.player.label }
            .tag(MobileAppTab.player)

            NavigationStack {
                MobileSettingsView(store: store)
                    .navigationTitle("Settings")
            }
            .tabItem { MobileAppTab.settings.label }
            .tag(MobileAppTab.settings)
        }
        .task {
            if store.channels.isEmpty, store.loadState == .idle {
                store.loadSamplePlaylist()
            }
        }
    }
}

struct MobileBrowseView: View {
    @ObservedObject var store: MobileIPTVStore
    @Binding var selectedTab: MobileAppTab

    var body: some View {
        VStack(spacing: 0) {
            MobileCategoryStrip(store: store)

            List {
                Section {
                    if store.visibleChannels.isEmpty {
                        MobileEmptyChannelsView(loadState: store.loadState)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(store.visibleChannels) { channel in
                            Button {
                                store.play(channel)
                                selectedTab = .player
                            } label: {
                                MobileChannelRow(
                                    channel: channel,
                                    isPlaying: store.currentChannel?.id == channel.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    MobileChannelStatusHeader(store: store)
                }
            }
            .listStyle(.plain)
        }
        .searchable(text: $store.searchText, prompt: "Search channels")
        .safeAreaInset(edge: .bottom) {
            if let channel = store.currentChannel {
                MobileNowPlayingBar(channel: channel) {
                    selectedTab = .player
                } stopAction: {
                    store.stopPlayback()
                }
            }
        }
    }
}

struct MobileCategoryStrip: View {
    @ObservedObject var store: MobileIPTVStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(store.categories) { category in
                    let isSelected = category.id == store.selectedCategoryID

                    Button {
                        store.selectedCategoryID = category.id
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(category.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text("\(store.categoryCount(for: category))")
                                .font(.caption)
                                .foregroundStyle(isSelected ? .white.opacity(0.78) : .secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }
}

struct MobileChannelStatusHeader: View {
    @ObservedObject var store: MobileIPTVStore

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.loadState.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(store.loadState.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }

            Spacer(minLength: 16)

            Text(store.channelCountLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
        .padding(.vertical, 4)
    }
}

struct MobileChannelRow: View {
    let channel: MobileIPTVChannel
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            MobileChannelArtwork(url: channel.iconURL)

            VStack(alignment: .leading, spacing: 5) {
                Text(channel.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(channel.sourceLabel)
                    if isPlaying {
                        Label("Playing", systemImage: "waveform")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(.caption)
                .foregroundStyle(isPlaying ? Color.accentColor : .secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 12)

            Image(systemName: "play.fill")
                .font(.callout.weight(.bold))
                .foregroundStyle(Color.accentColor)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
    }
}

struct MobileChannelArtwork: View {
    let url: URL?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.14))

            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Image(systemName: "tv")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MobileEmptyChannelsView: View {
    let loadState: MobileLoadState

    var body: some View {
        ContentUnavailableView {
            Label("No Channels", systemImage: "tv.slash")
        } description: {
            Text(loadState.detail)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }
}

struct MobileNowPlayingBar: View {
    let channel: MobileIPTVChannel
    let openAction: () -> Void
    let stopAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            MobileChannelArtwork(url: channel.iconURL)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(channel.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("Now playing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button(action: openAction) {
                Label("Open", systemImage: "arrow.up.forward.app")
            }
            .labelStyle(.iconOnly)

            Button(role: .destructive, action: stopAction) {
                Label("Stop", systemImage: "stop.fill")
            }
            .labelStyle(.iconOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

struct MobilePlayerView: View {
    @ObservedObject var store: MobileIPTVStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    VideoPlayer(player: store.player)
                        .background(Color.black)

                    if store.currentChannel == nil {
                        VStack(spacing: 12) {
                            Image(systemName: "play.rectangle")
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text("Choose a channel")
                                .font(.headline)
                        }
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                if let channel = store.currentChannel {
                    MobileCurrentChannelPanel(channel: channel) {
                        store.stopPlayback()
                    }
                } else {
                    MobilePlayerPlaceholder()
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.stopPlayback()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(store.currentChannel == nil)
            }
        }
    }
}

struct MobileCurrentChannelPanel: View {
    let channel: MobileIPTVChannel
    let stopAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                MobileChannelArtwork(url: channel.iconURL)

                VStack(alignment: .leading, spacing: 5) {
                    Text(channel.name)
                        .font(.title3.weight(.bold))
                        .lineLimit(2)
                    Text(channel.sourceLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)
            }

            Button(role: .destructive, action: stopAction) {
                Label("Stop Playback", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MobilePlayerPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing playing")
                .font(.headline)
            Text("Open Browse and choose a channel. The public sample playlist is loaded automatically on first launch.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MobileSettingsView: View {
    @ObservedObject var store: MobileIPTVStore

    var body: some View {
        Form {
            Section("Account") {
                TextField("Server URL", text: $store.credentials.serverURL)
                    .textContentType(.URL)
                    .channelDeckURLInput()

                TextField("ID", text: $store.credentials.username)
                    .textContentType(.username)
                    .channelDeckPlainInput()

                SecureField("Password", text: $store.credentials.password)
                    .textContentType(.password)

                Picker("Stream Format", selection: $store.credentials.streamFormat) {
                    ForEach(MobileStreamFormat.allCases) { format in
                        Text(format.label).tag(format)
                    }
                }
            }

            Section {
                Button {
                    Task {
                        await store.loadAccount()
                    }
                } label: {
                    Label("Load Channels", systemImage: "arrow.down.circle")
                }
                .disabled(!store.canLoadAccount)

                Button {
                    store.loadSamplePlaylist()
                } label: {
                    Label("Load Sample Playlist", systemImage: "play.rectangle.on.rectangle")
                }
            }

            Section("Status") {
                MobileStatusRow(title: store.loadState.title, detail: store.loadState.detail)
                MobileStatusRow(title: "Channels", detail: store.channelCountLabel)

                if let summary = store.accountSummary {
                    MobileStatusRow(title: "Account", detail: summary.status)
                    MobileStatusRow(title: "Connections", detail: summary.connectionLine)
                    if let expiresAt = summary.expiresAt {
                        MobileStatusRow(
                            title: "Expires",
                            detail: expiresAt.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                }
            }

            Section {
                Text("ChannelDeck does not include subscriptions, credentials, or private playlists. Use only streams you are authorized to access.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct MobileStatusRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer(minLength: 16)
            Text(detail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private extension View {
    @ViewBuilder
    func channelDeckURLInput() -> some View {
        #if os(iOS)
        keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }

    @ViewBuilder
    func channelDeckPlainInput() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }
}

#Preview("Mobile Root") {
    MobileRootView()
}
