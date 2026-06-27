import AVKit
import Foundation

@MainActor
final class IPTVStore: ObservableObject {
    @Published private(set) var categories: [IPTVCategory] = []
    @Published private(set) var channels: [IPTVChannel] = []
    @Published private(set) var accountSummary: AccountSummary?
    @Published private(set) var currentChannel: IPTVChannel?
    @Published private(set) var recentChannels: [IPTVChannel] = []
    @Published private(set) var state: IPTVLoadState = .idle
    @Published var isTheaterMode = false
    @Published var isChannelBrowserVisible = true
    @Published var isAccountInspectorVisible = false
    @Published var selectedCategoryID = IPTVCategory.allID
    @Published var selectedChannelID: IPTVChannel.ID?
    @Published var searchText = ""

    let player = AVPlayer()

    private let service: IPTVService
    private var lastLoadedAccount: IPTVCredentials?

    init(service: IPTVService = IPTVService()) {
        self.service = service
    }

    var filteredChannels: [IPTVChannel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return channels.filter { channel in
            let categoryMatches: Bool
            if selectedCategoryID == IPTVCategory.allID {
                categoryMatches = true
            } else if selectedCategoryID == IPTVCategory.recentID {
                categoryMatches = recentChannels.contains(where: { $0.id == channel.id })
            } else {
                categoryMatches = channel.categoryID == selectedCategoryID
            }
            let searchMatches = query.isEmpty || channel.name.lowercased().contains(query)
            return categoryMatches && searchMatches
        }
    }

    var visibleCategories: [IPTVCategory] {
        [
            IPTVCategory(id: IPTVCategory.allID, name: "All Channels"),
            IPTVCategory(id: IPTVCategory.recentID, name: "Recently Played")
        ] + categories
    }

    func categoryName(for id: String) -> String {
        if id == IPTVCategory.allID {
            return "All Channels"
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
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentChannel = nil
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
        recentChannels.removeAll { $0.id == channel.id }
        recentChannels.insert(channel, at: 0)
        if recentChannels.count > 15 {
            recentChannels.removeLast(recentChannels.count - 15)
        }
    }
}
