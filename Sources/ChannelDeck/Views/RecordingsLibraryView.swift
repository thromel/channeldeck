import SwiftUI

struct RecordingsLibraryView: View {
    @EnvironmentObject private var iptvStore: IPTVStore
    @Environment(\.dismiss) private var dismiss
    @State private var deleteCandidate: LocalMediaItem?

    var body: some View {
        VStack(spacing: 0) {
            header
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
                Text(LocalMediaLibrary.directoryURL.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
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
        .padding(20)
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

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(iptvStore.localMediaItems) { item in
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
        .background(Color(nsColor: .textBackgroundColor).opacity(0.24))
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
