import SwiftUI

struct RecordingsLibraryView: View {
    @EnvironmentObject private var iptvStore: IPTVStore
    @Environment(\.dismiss) private var dismiss
    @State private var deleteCandidate: LocalMediaItem?
    @State private var query = ""
    @State private var filter: LocalMediaFilter = .all
    @State private var sortMode: LocalMediaSortMode = .newest

    private var summary: LocalMediaSummary {
        LocalMediaBrowser.summary(for: iptvStore.localMediaItems)
    }

    private var visibleItems: [LocalMediaItem] {
        LocalMediaBrowser.visibleItems(
            from: iptvStore.localMediaItems,
            filter: filter,
            query: query,
            sortMode: sortMode
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            controls
            Divider()

            if let issue = iptvStore.localMediaIssue {
                Label(issue, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.thinMaterial)
            }

            if iptvStore.localMediaItems.isEmpty {
                emptyState
            } else if visibleItems.isEmpty {
                noMatchesState
            } else {
                fileList
            }
        }
        .frame(minWidth: 720, idealWidth: 820, minHeight: 520, idealHeight: 560)
        .task {
            iptvStore.refreshLocalMediaLibrary()
        }
        .confirmationDialog(
            "Delete Local File?",
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { isPresented in
                    if !isPresented {
                        deleteCandidate = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete File", role: .destructive) {
                if let deleteCandidate {
                    iptvStore.deleteLocalMedia(deleteCandidate)
                    self.deleteCandidate = nil
                }
            }

            Button("Cancel", role: .cancel) {
                deleteCandidate = nil
            }
        } message: {
            if let deleteCandidate {
                Text("This removes \(deleteCandidate.name) from local storage.")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.thinMaterial)
                Image(systemName: "tray.full")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("Local Library")
                    .font(.title3.weight(.semibold))
                HStack(spacing: 8) {
                    Text("\(summary.itemCount) files")
                    Text(summary.byteCountText)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 16)

            Button {
                iptvStore.refreshLocalMediaLibrary()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }

            Button {
                iptvStore.openLocalMediaFolder()
            } label: {
                Label("Open Folder", systemImage: "folder")
            }

            Button {
                dismiss()
            } label: {
                Label("Close", systemImage: "xmark")
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                LibraryStatPill(title: "Recordings", value: summary.recordingCount, systemImage: "video", tint: .red)
                LibraryStatPill(title: "Playlists", value: summary.playlistCount, systemImage: "music.note.list", tint: .blue)
                LibraryStatPill(title: "Downloads", value: summary.downloadCount, systemImage: "doc", tint: .secondary)
                Spacer(minLength: 0)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    searchField
                    filterPicker
                    sortMenu
                }

                VStack(alignment: .leading, spacing: 8) {
                    searchField
                    HStack(spacing: 10) {
                        filterPicker
                        sortMenu
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search local files", text: $query)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7))
        .frame(minWidth: 220, maxWidth: .infinity)
    }

    private var filterPicker: some View {
        Picker("Kind", selection: $filter) {
            ForEach(LocalMediaFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 360)
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $sortMode) {
                ForEach(LocalMediaSortMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
        } label: {
            Label(sortMode.title, systemImage: "arrow.up.arrow.down")
        }
        .help("Sort local files")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No local files yet")
                .font(.headline)
            Text("Recordings and saved playlists appear here.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var noMatchesState: some View {
        ContentUnavailableView(
            "No matching files",
            systemImage: "line.3.horizontal.decrease.circle",
            description: Text("Adjust the search or media type filter.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(visibleItems) { item in
                    LocalMediaRow(
                        item: item,
                        open: { iptvStore.openLocalMedia(item) },
                        reveal: { iptvStore.revealLocalMedia(item) },
                        delete: { deleteCandidate = item }
                    )
                }
            }
            .padding(16)
        }
        .background(Color.primary.opacity(0.04))
    }
}

private struct LibraryStatPill: View {
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
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.quaternary, in: Capsule())
    }
}

private struct LocalMediaRow: View {
    let item: LocalMediaItem
    let open: () -> Void
    let reveal: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(nsColor: .controlBackgroundColor))
                Image(systemName: item.kind.symbolName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(item.kind.tint)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    Label(item.kind.rawValue, systemImage: "tag")
                    Text(item.byteCountText)
                    Text(item.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 12)

            HStack(spacing: 4) {
                Button(action: open) {
                    Image(systemName: "play.rectangle")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help("Open")

                Button(action: reveal) {
                    Image(systemName: "folder")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help("Reveal in Finder")

                Button(action: delete) {
                    Image(systemName: "trash")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .help("Delete local file")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private extension LocalMediaKind {
    var symbolName: String {
        switch self {
        case .recording:
            return "video"
        case .playlist:
            return "music.note.list"
        case .download:
            return "doc"
        }
    }

    var tint: Color {
        switch self {
        case .recording:
            return .red
        case .playlist:
            return .blue
        case .download:
            return .secondary
        }
    }
}
