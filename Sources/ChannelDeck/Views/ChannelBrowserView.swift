import SwiftUI

struct ChannelBrowserView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var iptvStore: IPTVStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .navigationTitle(iptvStore.categoryName(for: iptvStore.selectedCategoryID))
        .navigationSplitViewColumnWidth(min: 320, ideal: 390, max: 470)
        .searchable(text: $iptvStore.searchText, placement: .toolbar, prompt: "Search channels")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(iptvStore.categoryName(for: iptvStore.selectedCategoryID))
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)

                    Text("\(iptvStore.filteredChannels.count) visible of \(iptvStore.channelCount(for: iptvStore.selectedCategoryID))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if iptvStore.state == .loading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(spacing: 8) {
                BrowserStatPill(title: "Favorites", value: iptvStore.favoriteChannelIDs.count, systemImage: "star.fill", tint: .yellow)
                BrowserStatPill(title: "Recent", value: iptvStore.recentChannels.count, systemImage: "clock.arrow.circlepath", tint: .blue)

                Spacer(minLength: 0)

                if iptvStore.selectedCategoryID == IPTVCategory.recentID,
                   !iptvStore.recentChannels.isEmpty {
                    Button {
                        iptvStore.clearRecentChannels()
                    } label: {
                        Label("Clear Recents", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Clear recently played channels")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        if iptvStore.state == .loading && iptvStore.channels.isEmpty {
            ContentUnavailableView("Loading Channels", systemImage: "antenna.radiowaves.left.and.right", description: Text("Fetching categories and live streams."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if iptvStore.filteredChannels.isEmpty {
            ContentUnavailableView(emptyTitle, systemImage: emptyIcon, description: Text(emptyDescription))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: $iptvStore.selectedChannelID) {
                ForEach(iptvStore.filteredChannels) { channel in
                    ChannelRow(
                        channel: channel,
                        categoryName: iptvStore.categoryName(for: channel.categoryID),
                        isPlaying: iptvStore.currentChannel?.id == channel.id,
                        isFavorite: iptvStore.isFavorite(channel),
                        onFavoriteToggle: {
                            iptvStore.toggleFavorite(channel)
                        }
                    )
                    .tag(channel.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        iptvStore.play(channel, account: accountStore.credentials)
                    }
                    .contextMenu {
                        Button("Play") {
                            iptvStore.play(channel, account: accountStore.credentials)
                        }

                        if let url = channel.streamURL(account: accountStore.credentials) {
                            Button("Copy Stream URL") {
                                PasteboardWriter.copy(url.absoluteString)
                            }

                            Button("Open Stream URL") {
                                WorkspaceOpener.open(url)
                            }
                        }

                        Divider()

                        Button(iptvStore.isFavorite(channel) ? "Remove from Favorites" : "Add to Favorites") {
                            iptvStore.toggleFavorite(channel)
                        }

                        if iptvStore.selectedCategoryID == IPTVCategory.recentID {
                            Button("Clear Recently Played") {
                                iptvStore.clearRecentChannels()
                            }
                        }
                    }
                    .listRowBackground(
                        iptvStore.currentChannel?.id == channel.id
                            ? Color.accentColor.opacity(0.10)
                            : Color.clear
                    )
                }
            }
            .listStyle(.inset)
        }
    }

    private var emptyTitle: String {
        if !iptvStore.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No Search Results"
        }

        switch iptvStore.selectedCategoryID {
        case IPTVCategory.favoritesID:
            return "No Favorites Yet"
        case IPTVCategory.recentID:
            return "No Recent Channels"
        default:
            return "No Channels"
        }
    }

    private var emptyIcon: String {
        switch iptvStore.selectedCategoryID {
        case IPTVCategory.favoritesID:
            return "star"
        case IPTVCategory.recentID:
            return "clock.arrow.circlepath"
        default:
            return "tv"
        }
    }

    private var emptyDescription: String {
        if !iptvStore.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Try a different search term or switch categories."
        }

        switch iptvStore.selectedCategoryID {
        case IPTVCategory.favoritesID:
            return "Use the star button on any channel to save it here."
        case IPTVCategory.recentID:
            return "Played channels will appear here and stay available after relaunch."
        default:
            return "Change the category or reload channels."
        }
    }
}

private struct BrowserStatPill: View {
    let title: String
    let value: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        Label {
            Text("\(title) \(value)")
                .monospacedDigit()
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary, in: Capsule())
    }
}

struct CollapsedChannelRailView: View {
    @EnvironmentObject private var iptvStore: IPTVStore

    let onExpand: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Button {
                onExpand()
            } label: {
                Image(systemName: "list.bullet")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .help("Show channel list")

            Divider()

            VStack(spacing: 6) {
                Image(systemName: "tv")
                    .foregroundStyle(.secondary)

                Text("\(iptvStore.filteredChannels.count)")
                    .font(.headline)
                    .monospacedDigit()

                Text("shown")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !iptvStore.favoriteChannelIDs.isEmpty {
                Divider()

                VStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)

                    Text("\(iptvStore.favoriteChannelIDs.count)")
                        .font(.headline)
                        .monospacedDigit()

                    Text("saved")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if iptvStore.currentChannel != nil {
                Divider()

                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(.green)
                    .help("Playing")
            }

            Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal, 8)
        .navigationSplitViewColumnWidth(min: 58, ideal: 62, max: 66)
    }
}

private struct ChannelRow: View {
    let channel: IPTVChannel
    let categoryName: String
    let isPlaying: Bool
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ChannelArtwork(url: channel.iconURL)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(channel.name)
                        .font(.callout.weight(isPlaying ? .semibold : .regular))
                        .lineLimit(1)

                    if isPlaying {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                HStack(spacing: 8) {
                    Text(categoryName)
                        .lineLimit(1)

                    Text("Stream \(channel.id)")
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                onFavoriteToggle()
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundStyle(isFavorite ? AnyShapeStyle(.yellow) : AnyShapeStyle(.tertiary))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help(isFavorite ? "Remove from favorites" : "Add to favorites")

            Image(systemName: "play.fill")
                .font(.caption)
                .foregroundStyle(isPlaying ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
        }
        .padding(.vertical, 6)
    }
}

struct ChannelArtwork: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .padding(3)
            default:
                Image(systemName: "tv")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 44, height: 34)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }
}
