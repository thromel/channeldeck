import AVKit
import SwiftUI

enum MobileAppTab: String, CaseIterable, Identifiable, Hashable {
    case browse
    case player
    case multiview
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
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
    @State private var selectedTab: MobileAppTab = .browse
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
