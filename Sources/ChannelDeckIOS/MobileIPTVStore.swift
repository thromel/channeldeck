import AVFoundation
import Foundation

@MainActor
final class MobileIPTVStore: ObservableObject {
    @Published var credentials: MobileIPTVCredentials
    @Published var categories: [MobileIPTVCategory] = [
        MobileIPTVCategory(id: MobileIPTVCategory.allID, name: "All")
    ]
    @Published var channels: [MobileIPTVChannel] = []
    @Published var selectedCategoryID = MobileIPTVCategory.allID
    @Published var searchText = ""
    @Published var currentChannel: MobileIPTVChannel?
    @Published var accountSummary: MobileAccountSummary?
    @Published var loadState: MobileLoadState = .idle
    @Published var playlistSourceName: String?
    @Published private(set) var pinnedChannels: [MobileIPTVChannel] = []
    @Published private(set) var recentChannels: [MobileIPTVChannel] = []
    @Published private(set) var favoriteChannelIDs: Set<MobileIPTVChannel.ID>
    @Published private(set) var multiviewSlots: [MobileMultiviewSlot] = (0..<4).map {
        MobileMultiviewSlot(index: $0)
    }

    let player = AVPlayer()

    private let service: MobileIPTVService
    private let credentialStore: MobileCredentialStore
    private let defaults: UserDefaults
    private var pinnedChannelIDs: [MobileIPTVChannel.ID]
    private var recentChannelIDs: [MobileIPTVChannel.ID]

    init(
        service: MobileIPTVService = MobileIPTVService(),
        credentialStore: MobileCredentialStore = MobileCredentialStore(),
        defaults: UserDefaults = .standard
    ) {
        self.service = service
        self.credentialStore = credentialStore
        self.defaults = defaults
        favoriteChannelIDs = Set(defaults.array(forKey: MobileDefaultsKey.favoriteChannelIDs) as? [MobileIPTVChannel.ID] ?? [])
        pinnedChannelIDs = defaults.array(forKey: MobileDefaultsKey.pinnedChannelIDs) as? [MobileIPTVChannel.ID] ?? []
        recentChannelIDs = defaults.array(forKey: MobileDefaultsKey.recentChannelIDs) as? [MobileIPTVChannel.ID] ?? []
        credentials = credentialStore.load()
    }

    var visibleChannels: [MobileIPTVChannel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let categoryChannels: [MobileIPTVChannel]
        switch selectedCategoryID {
        case MobileIPTVCategory.allID:
            categoryChannels = channels
        case MobileIPTVCategory.pinnedID:
            categoryChannels = pinnedChannels
        case MobileIPTVCategory.favoritesID:
            categoryChannels = favoriteChannels
        case MobileIPTVCategory.recentID:
            categoryChannels = recentChannels
        default:
            categoryChannels = channels.filter { $0.categoryID == selectedCategoryID }
        }

        return categoryChannels
            .filter { channel in
                query.isEmpty || channel.name.localizedCaseInsensitiveContains(query)
            }
    }

    var visibleCategories: [MobileIPTVCategory] {
        [
            MobileIPTVCategory(id: MobileIPTVCategory.allID, name: "All"),
            MobileIPTVCategory(id: MobileIPTVCategory.pinnedID, name: "Pinned"),
            MobileIPTVCategory(id: MobileIPTVCategory.favoritesID, name: "Favorites"),
            MobileIPTVCategory(id: MobileIPTVCategory.recentID, name: "Recently Played")
        ] + categories.filter { category in
            ![
                MobileIPTVCategory.allID,
                MobileIPTVCategory.pinnedID,
                MobileIPTVCategory.favoritesID,
                MobileIPTVCategory.recentID
            ].contains(category.id)
        }
    }

    var favoriteChannels: [MobileIPTVChannel] {
        channels.filter { favoriteChannelIDs.contains($0.id) }
    }

    var canLoadAccount: Bool {
        credentials.isComplete && !loadState.isLoading
    }

    var channelCountLabel: String {
        switch channels.count {
        case 0:
            "No channels"
        case 1:
            "1 channel"
        default:
            "\(channels.count) channels"
        }
    }

    var activeMultiviewCount: Int {
        multiviewSlots.filter { !$0.isEmpty }.count
    }

    var multiviewCountLabel: String {
        switch activeMultiviewCount {
        case 0:
            "No multiview channels"
        case 1:
            "1 multiview channel"
        default:
            "\(activeMultiviewCount) multiview channels"
        }
    }

    func categoryCount(for category: MobileIPTVCategory) -> Int {
        categoryCount(for: category.id)
    }

    func categoryCount(for categoryID: String) -> Int {
        if categoryID == MobileIPTVCategory.allID {
            return channels.count
        }
        if categoryID == MobileIPTVCategory.pinnedID {
            return pinnedChannels.count
        }
        if categoryID == MobileIPTVCategory.favoritesID {
            return favoriteChannels.count
        }
        if categoryID == MobileIPTVCategory.recentID {
            return recentChannels.count
        }

        return channels.filter { $0.categoryID == categoryID }.count
    }

    func loadSamplePlaylist() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentChannel = nil
        accountSummary = nil
        playlistSourceName = MobileSamplePlaylistProvider.displayName
        clearMultiview()
        categories = MobileSamplePlaylistProvider.categories
        channels = MobileSamplePlaylistProvider.channels
        restorePinnedChannels()
        restoreRecentChannels()
        selectedCategoryID = MobileIPTVCategory.sampleID
        searchText = ""
        loadState = .loaded(Date())
    }

    func loadAccount() async {
        guard credentials.isComplete else {
            loadState = .failed("Enter server URL, ID, and password.")
            return
        }

        loadState = .loading

        do {
            let summary = try await service.authenticate(credentials: credentials)
            async let liveCategories = service.liveCategories(credentials: credentials)
            async let liveStreams = service.liveStreams(credentials: credentials)

            let fetchedCategories = try await liveCategories
            let fetchedStreams = try await liveStreams
            try credentialStore.save(credentials)

            accountSummary = summary
            playlistSourceName = nil
            categories = [
                MobileIPTVCategory(id: MobileIPTVCategory.allID, name: "All")
            ] + fetchedCategories.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            channels = fetchedStreams.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            restorePinnedChannels()
            restoreRecentChannels()
            selectedCategoryID = MobileIPTVCategory.allID
            searchText = ""
            loadState = .loaded(Date())
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func play(_ channel: MobileIPTVChannel) {
        guard let url = channel.streamURL(credentials: credentials) else {
            loadState = .failed("Unable to build a playable stream URL for \(channel.name).")
            return
        }

        currentChannel = channel
        rememberRecent(channel)
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.play()
    }

    func stopPlayback() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentChannel = nil
    }

    @discardableResult
    func importPlaylist(from url: URL) throws -> Int {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let text = try String(contentsOf: url, encoding: .utf8)
        let result = MobileM3UPlaylistParser.parse(text: text, sourceURL: url)
        guard !result.channels.isEmpty else {
            throw MobilePlaylistStoreError.emptyPlaylist
        }

        applyImportedPlaylist(result)
        return result.channels.count
    }

    func exportPlaylistText() throws -> String {
        guard !channels.isEmpty else {
            throw MobilePlaylistStoreError.emptyPlaylist
        }

        let text = MobileM3UPlaylistExporter.makePlaylist(channels: channels, credentials: credentials)
        guard text.components(separatedBy: .newlines).contains(where: { $0.hasPrefix("http") || $0.hasPrefix("file:") }) else {
            throw MobilePlaylistStoreError.noPlayableURLs
        }

        return text
    }

    func isFavorite(_ channel: MobileIPTVChannel) -> Bool {
        favoriteChannelIDs.contains(channel.id)
    }

    func isPinned(_ channel: MobileIPTVChannel) -> Bool {
        pinnedChannelIDs.contains(channel.id)
    }

    func toggleFavorite(_ channel: MobileIPTVChannel) {
        var updatedIDs = favoriteChannelIDs
        if updatedIDs.contains(channel.id) {
            updatedIDs.remove(channel.id)
        } else {
            updatedIDs.insert(channel.id)
        }

        favoriteChannelIDs = updatedIDs
        persistFavorites()
    }

    func togglePin(_ channel: MobileIPTVChannel) {
        var updatedIDs = pinnedChannelIDs
        var updatedChannels = pinnedChannels
        if let index = pinnedChannelIDs.firstIndex(of: channel.id) {
            updatedIDs.remove(at: index)
            updatedChannels.removeAll { $0.id == channel.id }
        } else {
            updatedIDs.insert(channel.id, at: 0)
            updatedChannels.removeAll { $0.id == channel.id }
            updatedChannels.insert(channel, at: 0)
        }

        pinnedChannelIDs = updatedIDs
        pinnedChannels = updatedChannels
        persistPinnedChannels()
    }

    func clearPinnedChannels() {
        pinnedChannelIDs = []
        pinnedChannels = []
        persistPinnedChannels()
    }

    func clearFavorites() {
        favoriteChannelIDs = []
        persistFavorites()
    }

    func clearRecentChannels() {
        recentChannelIDs = []
        recentChannels = []
        persistRecentChannels()
    }

    func playInMultiview(_ channel: MobileIPTVChannel, slotID: MobileMultiviewSlot.ID? = nil) {
        guard let url = channel.streamURL(credentials: credentials) else {
            loadState = .failed("Unable to build a playable stream URL for \(channel.name).")
            return
        }

        let slot = selectedMultiviewSlot(slotID: slotID)
        slot.play(channel: channel, url: url)
        rememberRecent(channel)
        objectWillChange.send()
    }

    func clearMultiviewSlot(_ slot: MobileMultiviewSlot) {
        slot.clear()
        objectWillChange.send()
    }

    func clearMultiview() {
        multiviewSlots.forEach { $0.clear() }
        objectWillChange.send()
    }

    private func selectedMultiviewSlot(slotID: MobileMultiviewSlot.ID?) -> MobileMultiviewSlot {
        if let slotID,
           let requestedSlot = multiviewSlots.first(where: { $0.id == slotID }) {
            return requestedSlot
        }

        return multiviewSlots.first(where: \.isEmpty) ?? multiviewSlots[0]
    }

    private func applyImportedPlaylist(_ result: MobileM3UImportResult) {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentChannel = nil
        accountSummary = nil
        playlistSourceName = result.sourceURL.lastPathComponent
        clearMultiview()
        categories = [
            MobileIPTVCategory(id: MobileIPTVCategory.allID, name: "All")
        ] + result.categories
        channels = result.channels
        restorePinnedChannels()
        restoreRecentChannels()
        selectedCategoryID = result.categories.first?.id ?? MobileIPTVCategory.allID
        searchText = ""
        loadState = .loaded(Date())
    }

    private func rememberRecent(_ channel: MobileIPTVChannel) {
        var updatedIDs = recentChannelIDs
        updatedIDs.removeAll { $0 == channel.id }
        updatedIDs.insert(channel.id, at: 0)
        if updatedIDs.count > 15 {
            updatedIDs.removeLast(updatedIDs.count - 15)
        }
        recentChannelIDs = updatedIDs
        persistRecentChannels()

        var updatedChannels = recentChannels
        updatedChannels.removeAll { $0.id == channel.id }
        updatedChannels.insert(channel, at: 0)
        if updatedChannels.count > 15 {
            updatedChannels.removeLast(updatedChannels.count - 15)
        }
        recentChannels = updatedChannels
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

    private func persistFavorites() {
        defaults.set(Array(favoriteChannelIDs).sorted(), forKey: MobileDefaultsKey.favoriteChannelIDs)
    }

    private func persistPinnedChannels() {
        defaults.set(pinnedChannelIDs, forKey: MobileDefaultsKey.pinnedChannelIDs)
    }

    private func persistRecentChannels() {
        defaults.set(recentChannelIDs, forKey: MobileDefaultsKey.recentChannelIDs)
    }
}

private enum MobileDefaultsKey {
    static let favoriteChannelIDs = "channeldeck.ios.favoriteChannelIDs"
    static let pinnedChannelIDs = "channeldeck.ios.pinnedChannelIDs"
    static let recentChannelIDs = "channeldeck.ios.recentChannelIDs"
}

enum MobilePlaylistStoreError: LocalizedError {
    case emptyPlaylist
    case noPlayableURLs

    var errorDescription: String? {
        switch self {
        case .emptyPlaylist:
            "The playlist does not contain any playable channels."
        case .noPlayableURLs:
            "No playable stream URLs could be exported from the current channels."
        }
    }
}
