import AVKit
import Foundation

@MainActor
final class IPTVStore: ObservableObject {
    @Published private(set) var categories: [IPTVCategory] = []
    @Published private(set) var channels: [IPTVChannel] = []
    @Published private(set) var accountSummary: AccountSummary?
    @Published private(set) var currentChannel: IPTVChannel?
    @Published private(set) var pinnedChannels: [IPTVChannel] = []
    @Published private(set) var recentChannels: [IPTVChannel] = []
    @Published private(set) var favoriteChannelIDs: Set<IPTVChannel.ID>
    @Published private(set) var epgPrograms: [EPGProgram] = []
    @Published private(set) var epgState: EPGLoadState = .idle
    @Published private(set) var state: IPTVLoadState = .idle
    @Published var isTheaterMode = false
    @Published var isChannelBrowserVisible = true
    @Published var isAccountInspectorVisible = false
    @Published var selectedCategoryID = IPTVCategory.allID
    @Published var selectedChannelID: IPTVChannel.ID?
    @Published var searchText = ""

    let player = AVPlayer()

    private let service: IPTVService
    private let defaults: UserDefaults
    private var lastLoadedAccount: IPTVCredentials?
    private var epgTask: Task<Void, Never>?
    private var pinnedChannelIDs: [IPTVChannel.ID]
    private var recentChannelIDs: [IPTVChannel.ID]

    init(service: IPTVService = IPTVService(), defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        favoriteChannelIDs = Set(defaults.array(forKey: Keys.favoriteChannelIDs) as? [IPTVChannel.ID] ?? [])
        pinnedChannelIDs = defaults.array(forKey: Keys.pinnedChannelIDs) as? [IPTVChannel.ID] ?? []
        recentChannelIDs = defaults.array(forKey: Keys.recentChannelIDs) as? [IPTVChannel.ID] ?? []
    }

    var filteredChannels: [IPTVChannel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let categoryChannels: [IPTVChannel]
        switch selectedCategoryID {
        case IPTVCategory.allID:
            categoryChannels = channels
        case IPTVCategory.pinnedID:
            categoryChannels = pinnedChannels
        case IPTVCategory.favoritesID:
            categoryChannels = channels.filter { favoriteChannelIDs.contains($0.id) }
        case IPTVCategory.recentID:
            categoryChannels = recentChannels
        default:
            categoryChannels = channels.filter { $0.categoryID == selectedCategoryID }
        }

        return categoryChannels.filter { channel in
            let searchMatches = query.isEmpty || channel.name.lowercased().contains(query)
            return searchMatches
        }
    }

    var visibleCategories: [IPTVCategory] {
        [
            IPTVCategory(id: IPTVCategory.allID, name: "All Channels"),
            IPTVCategory(id: IPTVCategory.pinnedID, name: "Pinned"),
            IPTVCategory(id: IPTVCategory.favoritesID, name: "Favorites"),
            IPTVCategory(id: IPTVCategory.recentID, name: "Recently Played")
        ] + categories
    }

    func categoryName(for id: String) -> String {
        if id == IPTVCategory.allID {
            return "All Channels"
        }
        if id == IPTVCategory.pinnedID {
            return "Pinned"
        }
        if id == IPTVCategory.favoritesID {
            return "Favorites"
        }
        if id == IPTVCategory.recentID {
            return "Recently Played"
        }

        return categories.first(where: { $0.id == id })?.name ?? "Uncategorized"
    }

    func channelCount(for categoryID: String) -> Int {
        if categoryID == IPTVCategory.allID {
            return channels.count
        }
        if categoryID == IPTVCategory.pinnedID {
            return pinnedChannels.count
        }
        if categoryID == IPTVCategory.favoritesID {
            return channels.filter { favoriteChannelIDs.contains($0.id) }.count
        }
        if categoryID == IPTVCategory.recentID {
            return recentChannels.count
        }

        return channels.filter { $0.categoryID == categoryID }.count
    }

    func loadIfReady(account: IPTVCredentials) async {
        guard account.isComplete, lastLoadedAccount != account else {
            return
        }

        await load(account: account)
    }

    func load(account: IPTVCredentials) async {
        guard account.isComplete else {
            state = .failed("Enter server, ID, and password.")
            return
        }

        state = .loading

        do {
            async let summary = service.authenticate(account: account)
            async let fetchedCategories = service.liveCategories(account: account)
            async let fetchedChannels = service.liveStreams(account: account)

            accountSummary = try await summary
            categories = try await fetchedCategories.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            channels = try await fetchedChannels.sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            restorePinnedChannels()
            restoreRecentChannels()
            lastLoadedAccount = account
            state = .loaded(Date())

            if !visibleCategories.contains(where: { $0.id == selectedCategoryID }) {
                selectedCategoryID = IPTVCategory.allID
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func play(_ channel: IPTVChannel, account: IPTVCredentials) {
        guard let url = channel.streamURL(account: account) else {
            state = .failed("Could not create a stream URL for \(channel.name).")
            return
        }

        currentChannel = channel
        selectedChannelID = channel.id
        rememberRecent(channel)
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.play()
        loadEPG(for: channel, account: account)
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentChannel = nil
        epgTask?.cancel()
        epgTask = nil
        epgPrograms = []
        epgState = .idle
        isTheaterMode = false
    }

    func togglePlayback() {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    func playNext(account: IPTVCredentials) {
        playAdjacent(offset: 1, account: account)
    }

    func playPrevious(account: IPTVCredentials) {
        playAdjacent(offset: -1, account: account)
    }

    func enterTheaterMode(account: IPTVCredentials) {
        if currentChannel == nil,
           let firstChannel = filteredChannels.first {
            play(firstChannel, account: account)
        }

        guard currentChannel != nil else {
            return
        }

        isTheaterMode = true
    }

    func exitTheaterMode() {
        isTheaterMode = false
    }

    func toggleChannelBrowser() {
        isChannelBrowserVisible.toggle()
    }

    func toggleAccountInspector() {
        isAccountInspectorVisible.toggle()
    }

    func isFavorite(_ channel: IPTVChannel) -> Bool {
        favoriteChannelIDs.contains(channel.id)
    }

    func isPinned(_ channel: IPTVChannel) -> Bool {
        pinnedChannelIDs.contains(channel.id)
    }

    func toggleFavorite(_ channel: IPTVChannel) {
        if favoriteChannelIDs.contains(channel.id) {
            favoriteChannelIDs.remove(channel.id)
        } else {
            favoriteChannelIDs.insert(channel.id)
        }

        persistFavorites()
    }

    func togglePin(_ channel: IPTVChannel) {
        if let index = pinnedChannelIDs.firstIndex(of: channel.id) {
            pinnedChannelIDs.remove(at: index)
            pinnedChannels.removeAll { $0.id == channel.id }
        } else {
            pinnedChannelIDs.insert(channel.id, at: 0)
            pinnedChannels.removeAll { $0.id == channel.id }
            pinnedChannels.insert(channel, at: 0)
        }

        persistPinnedChannels()
    }

    func toggleFavoriteForCurrentChannel() {
        guard let currentChannel else {
            return
        }

        toggleFavorite(currentChannel)
    }

    func togglePinForCurrentChannel() {
        guard let currentChannel else {
            return
        }

        togglePin(currentChannel)
    }

    func clearPinnedChannels() {
        pinnedChannelIDs = []
        pinnedChannels = []
        persistPinnedChannels()
    }

    func clearRecentChannels() {
        recentChannelIDs = []
        recentChannels = []
        persistRecentChannels()
    }

    func refreshCurrentEPG(account: IPTVCredentials) {
        guard let currentChannel else {
            return
        }

        loadEPG(for: currentChannel, account: account)
    }

    private func playAdjacent(offset: Int, account: IPTVCredentials) {
        let visibleChannels = filteredChannels
        guard !visibleChannels.isEmpty else {
            return
        }

        let currentID = currentChannel?.id ?? selectedChannelID
        let currentIndex = currentID.flatMap { id in
            visibleChannels.firstIndex(where: { $0.id == id })
        } ?? 0

        let nextIndex = (currentIndex + offset + visibleChannels.count) % visibleChannels.count
        play(visibleChannels[nextIndex], account: account)
    }

    private func rememberRecent(_ channel: IPTVChannel) {
        recentChannelIDs.removeAll { $0 == channel.id }
        recentChannelIDs.insert(channel.id, at: 0)
        if recentChannelIDs.count > 15 {
            recentChannelIDs.removeLast(recentChannelIDs.count - 15)
        }
        persistRecentChannels()

        recentChannels.removeAll { $0.id == channel.id }
        recentChannels.insert(channel, at: 0)
        if recentChannels.count > 15 {
            recentChannels.removeLast(recentChannels.count - 15)
        }
    }

    private func restorePinnedChannels() {
        let channelByID = Dictionary(uniqueKeysWithValues: channels.map { ($0.id, $0) })
        pinnedChannels = pinnedChannelIDs.compactMap { channelByID[$0] }

        let restoredIDs = pinnedChannels.map(\.id)
        if restoredIDs != pinnedChannelIDs {
            pinnedChannelIDs = restoredIDs
            persistPinnedChannels()
        }
    }

    private func restoreRecentChannels() {
        let channelByID = Dictionary(uniqueKeysWithValues: channels.map { ($0.id, $0) })
        recentChannels = recentChannelIDs.compactMap { channelByID[$0] }

        let restoredIDs = recentChannels.map(\.id)
        if restoredIDs != recentChannelIDs {
            recentChannelIDs = restoredIDs
            persistRecentChannels()
        }
    }

    private func loadEPG(for channel: IPTVChannel, account: IPTVCredentials) {
        epgTask?.cancel()
        epgPrograms = []
        epgState = .loading

        epgTask = Task { @MainActor in
            do {
                let programs = try await service.shortEPG(account: account, streamID: channel.id)
                guard !Task.isCancelled,
                      currentChannel?.id == channel.id else {
                    return
                }

                epgPrograms = programs
                epgState = programs.isEmpty ? .unavailable : .loaded
            } catch {
                guard !Task.isCancelled,
                      currentChannel?.id == channel.id else {
                    return
                }

                epgPrograms = []
                epgState = .failed(error.localizedDescription)
            }
        }
    }

    private func persistFavorites() {
        defaults.set(Array(favoriteChannelIDs).sorted(), forKey: Keys.favoriteChannelIDs)
    }

    private func persistPinnedChannels() {
        defaults.set(pinnedChannelIDs, forKey: Keys.pinnedChannelIDs)
    }

    private func persistRecentChannels() {
        defaults.set(recentChannelIDs, forKey: Keys.recentChannelIDs)
    }
}

private enum Keys {
    static let favoriteChannelIDs = "player.favoriteChannelIDs"
    static let pinnedChannelIDs = "player.pinnedChannelIDs"
    static let recentChannelIDs = "player.recentChannelIDs"
}
