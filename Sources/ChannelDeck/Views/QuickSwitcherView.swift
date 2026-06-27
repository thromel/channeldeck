import SwiftUI

struct QuickSwitcherView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var iptvStore: IPTVStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool

    @State private var query = ""
    @State private var scope: QuickSwitcherScope = .all
    @State private var selectedChannelID: IPTVChannel.ID?

    private var channels: [IPTVChannel] {
        let base: [IPTVChannel]
        switch scope {
        case .all:
            base = iptvStore.channels
        case .favorites:
            base = iptvStore.channels.filter { iptvStore.favoriteChannelIDs.contains($0.id) }
        case .pinned:
            base = iptvStore.pinnedChannels
        case .recent:
            base = iptvStore.recentChannels
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = base.filter { channel in
            trimmedQuery.isEmpty
                || channel.name.lowercased().contains(trimmedQuery)
                || iptvStore.categoryName(for: channel.categoryID).lowercased().contains(trimmedQuery)
                || "\(channel.id)".contains(trimmedQuery)
        }

        return filtered.sorted { lhs, rhs in
            priority(for: lhs) == priority(for: rhs)
                ? lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                : priority(for: lhs) > priority(for: rhs)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            results
            Divider()
            footer
        }
        .frame(minWidth: 760, idealWidth: 840, minHeight: 560, idealHeight: 620)
        .onAppear {
            selectedChannelID = channels.first?.id
            searchFocused = true
        }
        .onChange(of: query) {
            syncSelection()
        }
        .onChange(of: scope) {
            syncSelection()
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("Search channels, categories, or stream IDs", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($searchFocused)
                    .onSubmit {
                        playSelected()
                    }

                Button {
                    dismiss()
                } label: {
                    Label("Close", systemImage: "xmark")
                }
                .labelStyle(.iconOnly)
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.borderless)
                .help("Close")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Picker("Scope", selection: $scope) {
                    ForEach(QuickSwitcherScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 360)

                Spacer()

                Text("\(channels.count) matches")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
    }

    @ViewBuilder
    private var results: some View {
        if channels.isEmpty {
            ContentUnavailableView(
                "No Channels Found",
                systemImage: "magnifyingglass",
                description: Text("Try another search or switch scopes.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: $selectedChannelID) {
                ForEach(channels.prefix(80)) { channel in
                    QuickSwitcherRow(
                        channel: channel,
                        categoryName: iptvStore.categoryName(for: channel.categoryID),
                        isPlaying: iptvStore.currentChannel?.id == channel.id,
                        isPinned: iptvStore.isPinned(channel),
                        isFavorite: iptvStore.isFavorite(channel),
                        play: {
                            play(channel)
                        },
                        addToMultiview: {
                            iptvStore.playInMultiPlayback(channel, account: accountStore.credentials)
                            dismiss()
                        },
                        pin: {
                            iptvStore.togglePin(channel)
                        },
                        favorite: {
                            iptvStore.toggleFavorite(channel)
                        }
                    )
                    .tag(channel.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedChannelID = channel.id
                    }
                    .onTapGesture(count: 2) {
                        play(channel)
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Label("Return plays selected", systemImage: "return")
            Label("Double-click plays", systemImage: "cursorarrow.click.2")
            Spacer()
            Button {
                playSelected()
            } label: {
                Label("Play Selected", systemImage: "play.fill")
            }
            .disabled(selectedChannel == nil)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private var selectedChannel: IPTVChannel? {
        guard let selectedChannelID else {
            return channels.first
        }

        return channels.first { $0.id == selectedChannelID } ?? channels.first
    }

    private func playSelected() {
        guard let selectedChannel else {
            return
        }

        play(selectedChannel)
    }

    private func play(_ channel: IPTVChannel) {
        iptvStore.play(channel, account: accountStore.credentials)
        dismiss()
    }

    private func syncSelection() {
        if let selectedChannelID,
           channels.contains(where: { $0.id == selectedChannelID }) {
            return
        }

        selectedChannelID = channels.first?.id
    }

    private func priority(for channel: IPTVChannel) -> Int {
        var score = 0
        if iptvStore.currentChannel?.id == channel.id {
            score += 100
        }
        if iptvStore.isPinned(channel) {
            score += 20
        }
        if iptvStore.isFavorite(channel) {
            score += 10
        }
        if iptvStore.recentChannels.contains(where: { $0.id == channel.id }) {
            score += 5
        }
        return score
    }
}

private struct QuickSwitcherRow: View {
    let channel: IPTVChannel
    let categoryName: String
    let isPlaying: Bool
    let isPinned: Bool
    let isFavorite: Bool
    let play: () -> Void
    let addToMultiview: () -> Void
    let pin: () -> Void
    let favorite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ChannelArtwork(url: channel.iconURL)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(channel.name)
                        .font(.callout.weight(isPlaying ? .semibold : .regular))
                        .lineLimit(1)

                    if isPlaying {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                HStack(spacing: 8) {
                    Text(categoryName)
                    Text(channel.sourceLabel)

                    if isPinned {
                        Label("Pinned", systemImage: "pin.fill")
                            .foregroundStyle(.orange)
                    }

                    if isFavorite {
                        Label("Favorite", systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 10)

            HStack(spacing: 4) {
                Button(action: play) {
                    Image(systemName: "play.fill")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help("Play")

                Button(action: addToMultiview) {
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
            }
        }
        .padding(.vertical, 6)
    }
}

private enum QuickSwitcherScope: String, CaseIterable, Identifiable {
    case all
    case favorites
    case pinned
    case recent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "All"
        case .favorites:
            "Favorites"
        case .pinned:
            "Pins"
        case .recent:
            "Recent"
        }
    }
}
