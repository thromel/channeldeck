import AVKit
import SwiftUI

enum MobileAppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case browse
    case player
    case multiview
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            "Home"
        case .browse:
            "Browse"
        case .player:
            "Player"
        case .multiview:
            "Multiview"
        case .settings:
            "Settings"
        }
    }

    var navigationTitle: String {
        switch self {
        case .home:
            "ChannelDeck"
        case .browse:
            "Channels"
        case .player:
            "Player"
        case .multiview:
            "Multiview"
        case .settings:
            "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house"
        case .browse:
            "rectangle.grid.1x2"
        case .player:
            "play.rectangle"
        case .multiview:
            "rectangle.grid.2x2"
        case .settings:
            "gearshape"
        }
    }

    @ViewBuilder
    var label: some View {
        Label(title, systemImage: systemImage)
    }
}

struct MobileRootView: View {
    @StateObject private var store = MobileIPTVStore()
    @State private var selectedTab: MobileAppTab = .home
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                MobileSplitRootView(store: store, selectedTab: $selectedTab)
            } else {
                MobileTabRootView(store: store, selectedTab: $selectedTab)
            }
        }
        .task {
            if store.channels.isEmpty, store.loadState == .idle {
                store.loadSamplePlaylist()
            }
        }
    }
}

struct MobileTabRootView: View {
    @ObservedObject var store: MobileIPTVStore
    @Binding var selectedTab: MobileAppTab

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(MobileAppTab.allCases) { tab in
                NavigationStack {
                    MobileRootDestinationView(
                        tab: tab,
                        store: store,
                        selectedTab: $selectedTab,
                        showsBrowseReload: true
                    )
                }
                .tabItem { tab.label }
                .tag(tab)
            }
        }
    }
}

struct MobileSplitRootView: View {
    @ObservedObject var store: MobileIPTVStore
    @Binding var selectedTab: MobileAppTab
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedTab) {
                Section("Watch") {
                    ForEach(MobileAppTab.allCases) { tab in
                        MobileSidebarTabRow(tab: tab, store: store)
                            .tag(tab)
                    }
                }

                Section("Status") {
                    MobileSidebarMetricRow(
                        title: "Channels",
                        value: "\(store.channels.count)",
                        systemImage: "tv"
                    )
                    MobileSidebarMetricRow(
                        title: "Multiview",
                        value: "\(store.activeMultiviewCount)/4",
                        systemImage: "rectangle.grid.2x2"
                    )
                    MobileSidebarMetricRow(
                        title: "Pinned",
                        value: "\(store.pinnedChannels.count)",
                        systemImage: "pin"
                    )
                    MobileSidebarMetricRow(
                        title: "Favorites",
                        value: "\(store.favoriteChannelIDs.count)",
                        systemImage: "star"
                    )
                    if let currentChannel = store.currentChannel {
                        MobileSidebarNowPlayingRow(channel: currentChannel)
                    }
                }
            }
            .navigationTitle("ChannelDeck")
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
        } detail: {
            NavigationStack {
                MobileRootDestinationView(
                    tab: selectedTab,
                    store: store,
                    selectedTab: $selectedTab,
                    showsBrowseReload: false
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct MobileRootDestinationView: View {
    let tab: MobileAppTab
    @ObservedObject var store: MobileIPTVStore
    @Binding var selectedTab: MobileAppTab
    let showsBrowseReload: Bool

    var body: some View {
        Group {
            switch tab {
            case .home:
                MobileHomeView(store: store, selectedTab: $selectedTab)
            case .browse:
                if showsBrowseReload {
                    MobileBrowseView(store: store, selectedTab: $selectedTab)
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
                } else {
                    MobileBrowseView(store: store, selectedTab: $selectedTab)
                }
            case .player:
                MobilePlayerView(store: store)
            case .multiview:
                MobileMultiviewView(store: store)
            case .settings:
                MobileSettingsView(store: store)
            }
        }
        .navigationTitle(tab.navigationTitle)
    }
}

struct MobileSidebarTabRow: View {
    let tab: MobileAppTab
    @ObservedObject var store: MobileIPTVStore

    var body: some View {
        Label {
            HStack {
                Text(tab.title)
                Spacer(minLength: 8)
                if let badge = badgeText {
                    Text(badge)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: tab.systemImage)
        }
    }

    private var badgeText: String? {
        switch tab {
        case .home:
            nil
        case .browse:
            store.channels.isEmpty ? nil : "\(store.channels.count)"
        case .player:
            store.currentChannel == nil ? nil : "Live"
        case .multiview:
            store.activeMultiviewCount == 0 ? nil : "\(store.activeMultiviewCount)"
        case .settings:
            nil
        }
    }
}

struct MobileSidebarMetricRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

struct MobileSidebarNowPlayingRow: View {
    let channel: MobileIPTVChannel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Now Playing", systemImage: "waveform")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            Text(channel.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            Text(channel.sourceLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

struct MobileHomeView: View {
    @ObservedObject var store: MobileIPTVStore
    @Binding var selectedTab: MobileAppTab

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MobileHomeHeader(store: store)

                LazyVGrid(columns: metricColumns, spacing: 10) {
                    MobileHomeMetricPill(title: "Pins", value: store.pinnedChannels.count, systemImage: "pin.fill", tint: .orange)
                    MobileHomeMetricPill(title: "Favorites", value: store.favoriteChannelIDs.count, systemImage: "star.fill", tint: .yellow)
                    MobileHomeMetricPill(title: "Recent", value: store.recentChannels.count, systemImage: "clock.arrow.circlepath", tint: .blue)
                    MobileHomeMetricPill(title: "Channels", value: store.channels.count, systemImage: "tv.fill", tint: .green)
                }

                LazyVGrid(columns: actionColumns, spacing: 10) {
                    MobileHomeActionButton(title: "Try Sample", systemImage: "play.square.stack") {
                        store.loadSamplePlaylist()
                    }

                    MobileHomeActionButton(title: "Browse", systemImage: "rectangle.grid.1x2") {
                        selectedTab = .browse
                    }
                    .disabled(store.channels.isEmpty)

                    MobileHomeActionButton(title: "Multiview", systemImage: "rectangle.grid.2x2") {
                        selectedTab = .multiview
                    }
                    .disabled(store.channels.isEmpty)

                    MobileHomeActionButton(title: "Reload", systemImage: "arrow.clockwise") {
                        Task {
                            await store.loadAccount()
                        }
                    }
                    .disabled(!store.canLoadAccount)
                }

                MobileHomeChannelSection(
                    title: "Continue Watching",
                    systemImage: "clock.arrow.circlepath",
                    channels: Array(store.recentChannels.prefix(6)),
                    emptyText: "Recent channels appear after playback starts.",
                    play: play,
                    multiview: addToMultiview,
                    pin: store.togglePin,
                    favorite: store.toggleFavorite,
                    isPinned: store.isPinned,
                    isFavorite: store.isFavorite
                )

                MobileHomeChannelSection(
                    title: "Pinned",
                    systemImage: "pin.fill",
                    channels: Array(store.pinnedChannels.prefix(6)),
                    emptyText: "Pin channels from Browse or channel tiles.",
                    play: play,
                    multiview: addToMultiview,
                    pin: store.togglePin,
                    favorite: store.toggleFavorite,
                    isPinned: store.isPinned,
                    isFavorite: store.isFavorite
                )

                MobileHomeChannelSection(
                    title: "Favorites",
                    systemImage: "star.fill",
                    channels: Array(store.favoriteChannels.prefix(6)),
                    emptyText: "Favorite channels from Browse or channel tiles.",
                    play: play,
                    multiview: addToMultiview,
                    pin: store.togglePin,
                    favorite: store.toggleFavorite,
                    isPinned: store.isPinned,
                    isFavorite: store.isFavorite
                )
            }
            .frame(maxWidth: 960, alignment: .leading)
            .padding()
        }
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

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 150), spacing: 10)]
    }

    private var actionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 150), spacing: 10)]
    }

    private func play(_ channel: MobileIPTVChannel) {
        store.play(channel)
        selectedTab = .player
    }

    private func addToMultiview(_ channel: MobileIPTVChannel) {
        store.playInMultiview(channel)
        selectedTab = .multiview
    }
}

struct MobileHomeHeader: View {
    @ObservedObject var store: MobileIPTVStore

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))

                Image(systemName: "play.rectangle.on.rectangle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 58, height: 48)

            VStack(alignment: .leading, spacing: 5) {
                Text("ChannelDeck")
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if store.loadState.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var subtitle: String {
        if let playlistSourceName = store.playlistSourceName {
            return "\(store.channels.count) channels from \(playlistSourceName)"
        }

        if store.channels.isEmpty {
            return "Load an account or try the sample playlist."
        }

        return "\(store.channels.count) live channels ready"
    }
}

struct MobileHomeMetricPill: View {
    let title: String
    let value: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MobileHomeActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.bordered)
    }
}

struct MobileHomeChannelSection: View {
    let title: String
    let systemImage: String
    let channels: [MobileIPTVChannel]
    let emptyText: String
    let play: (MobileIPTVChannel) -> Void
    let multiview: (MobileIPTVChannel) -> Void
    let pin: (MobileIPTVChannel) -> Void
    let favorite: (MobileIPTVChannel) -> Void
    let isPinned: (MobileIPTVChannel) -> Bool
    let isFavorite: (MobileIPTVChannel) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            if channels.isEmpty {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(channels) { channel in
                        MobileHomeChannelTile(
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
        [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 10)]
    }
}

struct MobileHomeChannelTile: View {
    let channel: MobileIPTVChannel
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
                    MobileChannelArtwork(url: channel.iconURL)
                        .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(channel.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(channel.sourceLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "play.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button(action: multiview) {
                    Label("Add to Multiview", systemImage: "rectangle.grid.2x2")
                        .labelStyle(.iconOnly)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)

                Button(action: pin) {
                    Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.fill" : "pin")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(isPinned ? .orange : .secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)

                Button(action: favorite) {
                    Label(isFavorite ? "Remove Favorite" : "Favorite", systemImage: isFavorite ? "star.fill" : "star")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(isFavorite ? .yellow : .secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)

                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
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
                                    isPlaying: store.currentChannel?.id == channel.id,
                                    isPinned: store.isPinned(channel),
                                    isFavorite: store.isFavorite(channel)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    store.play(channel)
                                    selectedTab = .player
                                } label: {
                                    Label("Play Now", systemImage: "play.fill")
                                }

                                Button {
                                    store.playInMultiview(channel)
                                    selectedTab = .multiview
                                } label: {
                                    Label("Add to Multiview", systemImage: "rectangle.grid.2x2")
                                }

                                Button {
                                    store.togglePin(channel)
                                } label: {
                                    Label(
                                        store.isPinned(channel) ? "Unpin" : "Pin",
                                        systemImage: store.isPinned(channel) ? "pin.slash" : "pin"
                                    )
                                }

                                Button {
                                    store.toggleFavorite(channel)
                                } label: {
                                    Label(
                                        store.isFavorite(channel) ? "Remove Favorite" : "Favorite",
                                        systemImage: store.isFavorite(channel) ? "star.slash" : "star"
                                    )
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    store.toggleFavorite(channel)
                                } label: {
                                    Label("Favorite", systemImage: store.isFavorite(channel) ? "star.slash" : "star")
                                }
                                .tint(.yellow)

                                Button {
                                    store.togglePin(channel)
                                } label: {
                                    Label("Pin", systemImage: store.isPinned(channel) ? "pin.slash" : "pin")
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    store.playInMultiview(channel)
                                    selectedTab = .multiview
                                } label: {
                                    Label("Multiview", systemImage: "rectangle.grid.2x2")
                                }
                                .tint(.blue)
                            }
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
                ForEach(store.visibleCategories) { category in
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
    let isPinned: Bool
    let isFavorite: Bool

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
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(.orange)
                    }
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
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
                    MobileGuidePanel(store: store)
                } else {
                    MobilePlayerPlaceholder()
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Button {
                        store.refreshCurrentEPG()
                    } label: {
                        Label("Refresh Guide", systemImage: "calendar.badge.clock")
                    }
                    .disabled(store.currentChannel == nil || store.epgState == .loading)

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

struct MobileGuidePanel: View {
    @ObservedObject var store: MobileIPTVStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(store.epgState.title, systemImage: "calendar")
                    .font(.headline)

                Spacer(minLength: 12)

                if !store.epgPrograms.isEmpty {
                    Text("\(store.epgPrograms.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Button {
                    store.refreshCurrentEPG()
                } label: {
                    Label("Refresh Guide", systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .disabled(store.currentChannel == nil || store.epgState == .loading)
            }

            switch store.epgState {
            case .idle:
                MobileGuideMessage(text: "Guide data loads when playback starts.", systemImage: "calendar")
            case .loading:
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading provider guide")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            case .loaded:
                LazyVStack(spacing: 10) {
                    ForEach(Array(store.epgPrograms.prefix(6).enumerated()), id: \.element.id) { index, program in
                        MobileGuideProgramCard(label: index == 0 ? "Now" : index == 1 ? "Next" : "Later", program: program)
                    }
                }
            case .unavailable:
                MobileGuideMessage(text: "No guide data returned for this channel.", systemImage: "calendar.badge.exclamationmark")
            case .failed(let message):
                MobileGuideMessage(text: message.isEmpty ? "Guide unavailable." : message, systemImage: "exclamationmark.triangle")
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MobileGuideProgramCard: View {
    let label: String
    let program: MobileEPGProgram

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(label == "Now" ? Color.accentColor : .secondary)
                Text(program.timeRangeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(program.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            if !program.description.isEmpty {
                Text(program.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MobileGuideMessage: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MobileMultiviewView: View {
    @ObservedObject var store: MobileIPTVStore
    @State private var searchText = ""

    private var filteredChannels: [MobileIPTVChannel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return store.channels
        }

        return store.channels.filter { channel in
            channel.name.localizedCaseInsensitiveContains(query)
                || channel.sourceLabel.localizedCaseInsensitiveContains(query)
        }
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 310), spacing: 12, alignment: .top)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MobileMultiviewHeader(store: store)

                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(store.multiviewSlots) { slot in
                        MobileMultiviewTile(store: store, slot: slot)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Add Channel")
                            .font(.headline)
                        Spacer()
                        Text("\(filteredChannels.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    TextField("Search channels", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .channelDeckPlainInput()

                    if filteredChannels.isEmpty {
                        ContentUnavailableView {
                            Label("No Matches", systemImage: "magnifyingglass")
                        } description: {
                            Text("Try another channel name or load an account.")
                        }
                        .padding(.vertical, 24)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredChannels.prefix(80)) { channel in
                                MobileMultiviewChannelPickerRow(store: store, channel: channel)

                                if channel.id != filteredChannels.prefix(80).last?.id {
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.clearMultiview()
                } label: {
                    Label("Clear All", systemImage: "xmark.circle")
                }
                .disabled(store.activeMultiviewCount == 0)
            }
        }
    }
}

struct MobileMultiviewHeader: View {
    @ObservedObject var store: MobileIPTVStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.grid.2x2")
                .font(.title2.weight(.semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(Color.accentColor)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(store.multiviewCountLabel)
                    .font(.headline)
                    .lineLimit(1)
                Text("Watch up to four channels with independent mute and volume per tile.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .padding()
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MobileMultiviewTile: View {
    @ObservedObject var store: MobileIPTVStore
    @ObservedObject var slot: MobileMultiviewSlot

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                VideoPlayer(player: slot.player)
                    .background(Color.black)

                if slot.channel == nil {
                    VStack(spacing: 10) {
                        Image(systemName: "plus.rectangle.on.rectangle")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Add channel")
                            .font(.headline)
                    }
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(slot.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        Text(slot.channel?.sourceLabel ?? "Slot \(slot.index + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Menu {
                        ForEach(store.channels.prefix(80)) { channel in
                            Button(channel.name) {
                                store.playInMultiview(channel, slotID: slot.id)
                            }
                        }
                    } label: {
                        Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .labelStyle(.iconOnly)
                    .disabled(store.channels.isEmpty)
                }

                HStack(spacing: 12) {
                    Button {
                        slot.isMuted.toggle()
                    } label: {
                        Image(systemName: slot.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.bordered)

                    Slider(
                        value: Binding(
                            get: { Double(slot.volume) },
                            set: { slot.volume = Float($0) }
                        ),
                        in: 0...1
                    )
                    .disabled(slot.channel == nil)

                    Text("\(Int(slot.volume * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .trailing)
                }

                Button(role: .destructive) {
                    store.clearMultiviewSlot(slot)
                } label: {
                    Label("Clear Slot", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(slot.channel == nil)
            }
            .padding(12)
        }
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
    }
}

struct MobileMultiviewChannelPickerRow: View {
    @ObservedObject var store: MobileIPTVStore
    let channel: MobileIPTVChannel

    var body: some View {
        HStack(spacing: 12) {
            MobileChannelArtwork(url: channel.iconURL)

            VStack(alignment: .leading, spacing: 5) {
                Text(channel.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(channel.sourceLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button {
                store.playInMultiview(channel)
            } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(10)
    }
}

struct MobileSettingsView: View {
    @ObservedObject var store: MobileIPTVStore
    @State private var isImportingPlaylist = false
    @State private var isExportingPlaylist = false
    @State private var exportDocument = MobileM3UPlaylistDocument()
    @State private var exportFilename = MobileM3UPlaylistExporter.defaultFilename()
    @State private var playlistNotice: MobilePlaylistNotice?

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

            Section("Local Playlists") {
                Button {
                    isImportingPlaylist = true
                } label: {
                    Label("Import M3U Playlist", systemImage: "square.and.arrow.down")
                }

                Button {
                    preparePlaylistExport()
                } label: {
                    Label("Export Current Channels", systemImage: "square.and.arrow.up")
                }
                .disabled(store.channels.isEmpty)

                if let playlistSourceName = store.playlistSourceName {
                    MobileStatusRow(title: "Source", detail: playlistSourceName)
                }
            }

            Section("Saved Channels") {
                MobileStatusRow(title: "Pinned", detail: "\(store.pinnedChannels.count)")
                MobileStatusRow(title: "Favorites", detail: "\(store.favoriteChannelIDs.count)")
                MobileStatusRow(title: "Recently Played", detail: "\(store.recentChannels.count)")

                Button(role: .destructive) {
                    store.clearPinnedChannels()
                } label: {
                    Label("Clear Pinned Channels", systemImage: "pin.slash")
                }
                .disabled(store.pinnedChannels.isEmpty)

                Button(role: .destructive) {
                    store.clearFavorites()
                } label: {
                    Label("Clear Favorites", systemImage: "star.slash")
                }
                .disabled(store.favoriteChannelIDs.isEmpty)

                Button(role: .destructive) {
                    store.clearRecentChannels()
                } label: {
                    Label("Clear Recently Played", systemImage: "clock.badge.xmark")
                }
                .disabled(store.recentChannels.isEmpty)
            }

            Section("Status") {
                MobileStatusRow(title: store.loadState.title, detail: store.loadState.detail)
                MobileStatusRow(title: "Channels", detail: store.channelCountLabel)
                MobileStatusRow(title: "Multiview", detail: store.multiviewCountLabel)

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
        .fileImporter(
            isPresented: $isImportingPlaylist,
            allowedContentTypes: MobilePlaylistFileTypes.readable,
            allowsMultipleSelection: false
        ) { result in
            importPlaylist(result: result)
        }
        .fileExporter(
            isPresented: $isExportingPlaylist,
            document: exportDocument,
            contentType: MobilePlaylistFileTypes.m3u,
            defaultFilename: exportFilename
        ) { result in
            handleExport(result: result)
        }
        .alert(item: $playlistNotice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func importPlaylist(result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                playlistNotice = MobilePlaylistNotice(
                    title: "No Playlist Selected",
                    message: "Choose an M3U or M3U8 file to import."
                )
                return
            }

            let count = try store.importPlaylist(from: url)
            playlistNotice = MobilePlaylistNotice(
                title: "Playlist Imported",
                message: "\(count) channels loaded from \(url.lastPathComponent)."
            )
        } catch {
            playlistNotice = MobilePlaylistNotice(
                title: "Import Failed",
                message: error.localizedDescription
            )
        }
    }

    private func preparePlaylistExport() {
        do {
            exportDocument = MobileM3UPlaylistDocument(text: try store.exportPlaylistText())
            exportFilename = MobileM3UPlaylistExporter.defaultFilename()
            isExportingPlaylist = true
        } catch {
            playlistNotice = MobilePlaylistNotice(
                title: "Export Failed",
                message: error.localizedDescription
            )
        }
    }

    private func handleExport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            playlistNotice = MobilePlaylistNotice(
                title: "Playlist Exported",
                message: "Saved \(url.lastPathComponent)."
            )
        case .failure(let error):
            playlistNotice = MobilePlaylistNotice(
                title: "Export Failed",
                message: error.localizedDescription
            )
        }
    }
}

struct MobilePlaylistNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
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
