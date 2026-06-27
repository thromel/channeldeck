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
    @Published private(set) var playbackDiagnostics: PlaybackDiagnostics = .idle
    @Published private(set) var primaryRecording: LocalStreamRecording?
    @Published private(set) var localMediaItems: [LocalMediaItem] = []
    @Published private(set) var localMediaIssue: String?
    @Published private(set) var importedPlaylistName: String?
    @Published private(set) var state: IPTVLoadState = .idle
    @Published private(set) var multiPlaybackSlots: [MultiPlaybackSlot]
    @Published private(set) var hasSavedMultiPlaybackLayout: Bool
    @Published var isTheaterMode = false
    @Published var isMultiPlaybackMode = false
    @Published var isChannelBrowserVisible = true
    @Published var isAccountInspectorVisible = false
    @Published var isLocalLibraryVisible = false
    @Published var isQuickSwitcherVisible = false
    @Published var isGuidePanelVisible = false
    @Published var multiPlaybackSlotCount: Int {
        didSet {
            defaults.set(multiPlaybackSlotCount, forKey: Keys.multiPlaybackSlotCount)
        }
    }
    @Published var selectedCategoryID = IPTVCategory.allID
    @Published var selectedChannelID: IPTVChannel.ID?
    @Published var searchText = ""

    let player = AVPlayer()

    private let service: IPTVService
    private let defaults: UserDefaults
    private var lastLoadedAccount: IPTVCredentials?
    private var currentStreamURL: URL?
    private var epgTask: Task<Void, Never>?
    private var playerTimeControlObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var itemNotificationObservers: [NSObjectProtocol] = []
    private var pinnedChannelIDs: [IPTVChannel.ID]
    private var recentChannelIDs: [IPTVChannel.ID]

    init(service: IPTVService = IPTVService(), defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        multiPlaybackSlots = (0..<4).map { MultiPlaybackSlot(id: $0) }
        multiPlaybackSlotCount = {
            let savedCount = defaults.integer(forKey: Keys.multiPlaybackSlotCount)
            return savedCount == 0 ? 2 : min(max(savedCount, 2), 4)
        }()
        hasSavedMultiPlaybackLayout = defaults.data(forKey: Keys.multiPlaybackLayout) != nil
        favoriteChannelIDs = Set(defaults.array(forKey: Keys.favoriteChannelIDs) as? [IPTVChannel.ID] ?? [])
        pinnedChannelIDs = defaults.array(forKey: Keys.pinnedChannelIDs) as? [IPTVChannel.ID] ?? []
        recentChannelIDs = defaults.array(forKey: Keys.recentChannelIDs) as? [IPTVChannel.ID] ?? []
        observePlayer()
    }

    var visibleMultiPlaybackSlots: [MultiPlaybackSlot] {
        Array(multiPlaybackSlots.prefix(multiPlaybackSlotCount))
    }

    var activeMultiPlaybackCount: Int {
        multiPlaybackSlots.filter { !$0.isEmpty }.count
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
            importedPlaylistName = nil
            state = .loaded(Date())

            if !visibleCategories.contains(where: { $0.id == selectedCategoryID }) {
                selectedCategoryID = IPTVCategory.allID
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func play(_ channel: IPTVChannel, account: IPTVCredentials) {
        clearMultiPlayback()
        guard let url = channel.streamURL(account: account) else {
            state = .failed("Could not create a stream URL for \(channel.name).")
            playbackDiagnostics = PlaybackDiagnostics.idle.updated(
                status: .failed,
                title: "Stream URL unavailable",
                detail: "Could not create a playable URL for this channel.",
                issue: "Missing direct source and account stream URL."
            )
            return
        }

        currentChannel = channel
        currentStreamURL = url
        selectedChannelID = channel.id
        rememberRecent(channel)
        playbackDiagnostics = .preparing(channel: channel, account: account, url: url)
        let item = AVPlayerItem(url: url)
        observe(item: item)
        player.replaceCurrentItem(with: item)
        player.play()
        if channel.directSource == nil, account.isComplete {
            loadEPG(for: channel, account: account)
        } else {
            epgTask?.cancel()
            epgTask = nil
            epgPrograms = []
            epgState = .unavailable
        }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        stopObservingCurrentItem()
        currentChannel = nil
        currentStreamURL = nil
        playbackDiagnostics = .idle
        primaryRecording?.stop()
        primaryRecording = nil
        epgTask?.cancel()
        epgTask = nil
        epgPrograms = []
        epgState = .idle
        isTheaterMode = false
        clearMultiPlayback()
    }

    func togglePrimaryRecording(account: IPTVCredentials) {
        if primaryRecording?.isActive == true {
            primaryRecording?.stop()
            refreshLocalMediaLibrary()
            return
        }

        guard let currentChannel,
              let url = currentStreamURL ?? currentChannel.streamURL(account: account) else {
            return
        }

        primaryRecording = makeRecording(channel: currentChannel, url: url)
        primaryRecording?.start()
        refreshLocalMediaLibrary()
    }

    func revealPrimaryRecording() {
        guard let recording = primaryRecording else {
            return
        }

        WorkspaceOpener.reveal(recording.fileURL)
    }

    func setMultiPlaybackSlotCount(_ count: Int) {
        let boundedCount = min(max(count, 2), 4)
        multiPlaybackSlotCount = boundedCount
        for slot in multiPlaybackSlots.dropFirst(boundedCount) {
            slot.clear()
        }
        if activeMultiPlaybackCount == 0 {
            isMultiPlaybackMode = false
        }
    }

    func playInMultiPlayback(_ channel: IPTVChannel, account: IPTVCredentials, slotID: Int? = nil) {
        guard let url = channel.streamURL(account: account) else {
            state = .failed("Could not create a stream URL for \(channel.name).")
            return
        }

        if currentChannel != nil {
            stopPrimaryPlayerForMultiPlayback()
        }

        let targetSlot = slotForMultiPlayback(slotID: slotID)
        targetSlot.play(channel: channel, url: url)
        rememberRecent(channel)
        selectedChannelID = channel.id
        isTheaterMode = false
        isMultiPlaybackMode = true
    }

    func clearMultiPlaybackSlot(_ slot: MultiPlaybackSlot) {
        slot.clear()
        if activeMultiPlaybackCount == 0 {
            isMultiPlaybackMode = false
        }
    }

    func clearMultiPlayback() {
        for slot in multiPlaybackSlots {
            slot.clear()
        }
        isMultiPlaybackMode = false
    }

    func toggleRecording(for slot: MultiPlaybackSlot) {
        if slot.recording?.isActive == true {
            slot.recording?.stop()
            refreshLocalMediaLibrary()
            return
        }

        guard let channel = slot.channel,
              let url = slot.streamURL else {
            return
        }

        guard let recording = makeRecording(channel: channel, url: url) else {
            return
        }

        slot.setRecording(recording)
        recording.start()
        refreshLocalMediaLibrary()
    }

    func revealRecording(for slot: MultiPlaybackSlot) {
        guard let recording = slot.recording else {
            return
        }

        WorkspaceOpener.reveal(recording.fileURL)
    }

    func saveMultiPlaybackLayout() {
        let layout = MultiPlaybackLayout(
            slotCount: multiPlaybackSlotCount,
            slots: multiPlaybackSlots.compactMap { slot in
                guard let channel = slot.channel else {
                    return nil
                }

                return MultiPlaybackLayoutSlot(
                    id: slot.id,
                    channelID: channel.id,
                    volume: slot.volume,
                    isMuted: slot.isMuted
                )
            }
        )

        guard let data = try? JSONEncoder().encode(layout) else {
            return
        }

        defaults.set(data, forKey: Keys.multiPlaybackLayout)
        hasSavedMultiPlaybackLayout = true
    }

    func restoreMultiPlaybackLayout(account: IPTVCredentials) {
        guard let data = defaults.data(forKey: Keys.multiPlaybackLayout),
              let layout = try? JSONDecoder().decode(MultiPlaybackLayout.self, from: data) else {
            hasSavedMultiPlaybackLayout = false
            return
        }

        clearMultiPlayback()
        setMultiPlaybackSlotCount(layout.slotCount)

        for savedSlot in layout.slots {
            guard multiPlaybackSlots.indices.contains(savedSlot.id),
                  let channel = channels.first(where: { $0.id == savedSlot.channelID }),
                  let url = channel.streamURL(account: account) else {
                continue
            }

            let slot = multiPlaybackSlots[savedSlot.id]
            slot.setVolume(savedSlot.volume)
            slot.setMuted(savedSlot.isMuted)
            slot.play(channel: channel, url: url)
            rememberRecent(channel)
        }

        isMultiPlaybackMode = activeMultiPlaybackCount > 0
        hasSavedMultiPlaybackLayout = true
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
        guard let currentChannel,
              currentChannel.directSource == nil,
              account.isComplete else {
            epgPrograms = []
            epgState = .unavailable
            return
        }

        loadEPG(for: currentChannel, account: account)
    }

    func showGuidePanel(account: IPTVCredentials) {
        isAccountInspectorVisible = false
        isLocalLibraryVisible = false
        isQuickSwitcherVisible = false
        isGuidePanelVisible = true

        if currentChannel != nil, epgPrograms.isEmpty, epgState != .loading {
            refreshCurrentEPG(account: account)
        }
    }

    func saveM3UPlaylist(account: IPTVCredentials) {
        if M3UPlaylistExporter.save(channels: channels, account: account) != nil {
            refreshLocalMediaLibrary()
        }
    }

    func importM3UPlaylist() {
        guard let result = M3UPlaylistImporter.open() else {
            return
        }

        applyPlaylist(result, emptyMessage: "The selected M3U playlist did not contain playable channels.")
    }

    func loadSamplePlaylist() {
        applyPlaylist(
            SamplePlaylistProvider.makeResult(),
            emptyMessage: "The sample playlist did not contain playable channels."
        )
    }

    private func applyPlaylist(_ result: M3UImportResult, emptyMessage: String) {
        guard !result.channels.isEmpty else {
            state = .failed(emptyMessage)
            return
        }

        stop()
        categories = result.categories
        channels = result.channels
        accountSummary = nil
        importedPlaylistName = result.sourceURL.lastPathComponent
        lastLoadedAccount = nil
        selectedCategoryID = IPTVCategory.allID
        selectedChannelID = nil
        searchText = ""
        restorePinnedChannels()
        restoreRecentChannels()
        state = .loaded(Date())
    }

    func showLocalLibrary() {
        isAccountInspectorVisible = false
        isQuickSwitcherVisible = false
        isGuidePanelVisible = false
        refreshLocalMediaLibrary()
        isLocalLibraryVisible = true
    }

    func showQuickSwitcher() {
        isAccountInspectorVisible = false
        isLocalLibraryVisible = false
        isGuidePanelVisible = false
        isQuickSwitcherVisible = true
    }

    func refreshLocalMediaLibrary() {
        do {
            localMediaItems = try LocalMediaLibrary.scan()
            localMediaIssue = nil
        } catch {
            localMediaIssue = error.localizedDescription
        }
    }

    func openLocalMediaFolder() {
        do {
            let directory = try LocalMediaLibrary.ensureDirectory()
            WorkspaceOpener.open(directory)
            localMediaIssue = nil
        } catch {
            localMediaIssue = error.localizedDescription
        }
    }

    func openLocalMedia(_ item: LocalMediaItem) {
        WorkspaceOpener.open(item.url)
    }

    func revealLocalMedia(_ item: LocalMediaItem) {
        WorkspaceOpener.reveal(item.url)
    }

    func deleteLocalMedia(_ item: LocalMediaItem) {
        do {
            try LocalMediaLibrary.remove(item)
            refreshLocalMediaLibrary()
        } catch {
            localMediaIssue = error.localizedDescription
        }
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

    private func stopPrimaryPlayerForMultiPlayback() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        stopObservingCurrentItem()
        currentChannel = nil
        currentStreamURL = nil
        playbackDiagnostics = .idle
        primaryRecording?.stop()
        primaryRecording = nil
        epgTask?.cancel()
        epgTask = nil
        epgPrograms = []
        epgState = .idle
    }

    private func slotForMultiPlayback(slotID: Int?) -> MultiPlaybackSlot {
        if let slotID,
           multiPlaybackSlots.indices.contains(slotID) {
            return multiPlaybackSlots[slotID]
        }

        if let emptySlot = visibleMultiPlaybackSlots.first(where: \.isEmpty) {
            return emptySlot
        }

        return visibleMultiPlaybackSlots.first ?? multiPlaybackSlots[0]
    }

    private func makeRecording(channel: IPTVChannel, url: URL) -> LocalStreamRecording? {
        guard let fileURL = try? LocalStreamRecording.defaultOutputURL(channel: channel, streamURL: url) else {
            state = .failed("Could not create a local recording file.")
            return nil
        }

        return LocalStreamRecording(channel: channel, streamURL: url, fileURL: fileURL)
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
                let programs = try await service.shortEPG(account: account, streamID: channel.id, limit: 8)
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

    private func observePlayer() {
        playerTimeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                self?.recordTimeControlStatus(player.timeControlStatus, reason: player.reasonForWaitingToPlay)
            }
        }
    }

    private func observe(item: AVPlayerItem) {
        stopObservingCurrentItem()

        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                self?.recordItemStatus(item.status, error: item.error)
            }
        }

        let failedObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Task { @MainActor in
                self?.recordPlaybackFailure(error)
            }
        }

        let stalledObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.playbackStalledNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recordPlaybackStall()
            }
        }

        itemNotificationObservers = [failedObserver, stalledObserver]
    }

    private func stopObservingCurrentItem() {
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil

        for observer in itemNotificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        itemNotificationObservers = []
    }

    private func recordItemStatus(_ status: AVPlayerItem.Status, error: Error?) {
        guard currentChannel != nil else {
            return
        }

        switch status {
        case .readyToPlay:
            playbackDiagnostics = playbackDiagnostics.updated(
                status: .ready,
                title: "Stream ready",
                detail: "The stream is ready for playback."
            )
        case .failed:
            recordPlaybackFailure(error)
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    private func recordTimeControlStatus(_ status: AVPlayer.TimeControlStatus, reason: AVPlayer.WaitingReason?) {
        guard currentChannel != nil,
              playbackDiagnostics.status != .failed else {
            return
        }

        switch status {
        case .playing:
            playbackDiagnostics = playbackDiagnostics.updated(
                status: .playing,
                title: "Playing",
                detail: "Live playback is active."
            )
        case .paused:
            playbackDiagnostics = playbackDiagnostics.updated(
                status: .paused,
                title: "Paused",
                detail: "Playback is paused."
            )
        case .waitingToPlayAtSpecifiedRate:
            let detail = reason.map { "Waiting: \($0.rawValue)." } ?? "Waiting for enough stream data to continue."
            playbackDiagnostics = playbackDiagnostics.updated(
                status: .buffering,
                title: "Buffering",
                detail: detail
            )
        @unknown default:
            break
        }
    }

    private func recordPlaybackStall() {
        guard currentChannel != nil else {
            return
        }

        playbackDiagnostics = playbackDiagnostics.updated(
            status: .stalled,
            title: "Playback stalled",
            detail: "The player stopped receiving enough data from the stream.",
            issue: "Network, provider, or stream format interruption."
        )
    }

    private func recordPlaybackFailure(_ error: Error?) {
        guard currentChannel != nil else {
            return
        }

        let issue = redactedIssue(error?.localizedDescription)
        playbackDiagnostics = playbackDiagnostics.updated(
            status: .failed,
            title: "Playback failed",
            detail: "The player could not continue this stream.",
            issue: issue ?? "The stream failed without a detailed AVPlayer error."
        )
    }

    private func redactedIssue(_ issue: String?) -> String? {
        guard var issue = issue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !issue.isEmpty else {
            return nil
        }

        if let account = lastLoadedAccount {
            for secret in [account.username, account.password] where !secret.isEmpty {
                issue = issue.replacingOccurrences(of: secret, with: "[redacted]")
            }
        }

        if issue.count > 220 {
            issue = String(issue.prefix(220)) + "..."
        }

        return issue
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
    static let multiPlaybackSlotCount = "player.multiPlaybackSlotCount"
    static let multiPlaybackLayout = "player.multiPlaybackLayout"
}
