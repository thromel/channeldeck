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
    @Published private(set) var multiviewSlots: [MobileMultiviewSlot] = (0..<4).map {
        MobileMultiviewSlot(index: $0)
    }

    let player = AVPlayer()

    private let service: MobileIPTVService
    private let credentialStore: MobileCredentialStore

    init(
        service: MobileIPTVService = MobileIPTVService(),
        credentialStore: MobileCredentialStore = MobileCredentialStore()
    ) {
        self.service = service
        self.credentialStore = credentialStore
        credentials = credentialStore.load()
    }

    var visibleChannels: [MobileIPTVChannel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return channels
            .filter { channel in
                selectedCategoryID == MobileIPTVCategory.allID || channel.categoryID == selectedCategoryID
            }
            .filter { channel in
                query.isEmpty || channel.name.localizedCaseInsensitiveContains(query)
            }
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
        if category.id == MobileIPTVCategory.allID {
            return channels.count
        }

        return channels.filter { $0.categoryID == category.id }.count
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

    func playInMultiview(_ channel: MobileIPTVChannel, slotID: MobileMultiviewSlot.ID? = nil) {
        guard let url = channel.streamURL(credentials: credentials) else {
            loadState = .failed("Unable to build a playable stream URL for \(channel.name).")
            return
        }

        let slot = selectedMultiviewSlot(slotID: slotID)
        slot.play(channel: channel, url: url)
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
        selectedCategoryID = result.categories.first?.id ?? MobileIPTVCategory.allID
        searchText = ""
        loadState = .loaded(Date())
    }
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
