import SwiftUI

struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var sections: [ShortcutSection] {
        KeyboardShortcutCatalog.filteredSections(query: query)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if sections.isEmpty {
                ContentUnavailableView(
                    "No shortcuts found",
                    systemImage: "keyboard",
                    description: Text("Try another command or shortcut name.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(sections) { section in
                            ShortcutSectionView(section: section)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(minWidth: 660, idealWidth: 760, minHeight: 560, idealHeight: 620)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.thinMaterial)
                Image(systemName: "keyboard")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("Keyboard Shortcuts")
                    .font(.title3.weight(.semibold))
                Text("\(KeyboardShortcutCatalog.sections.flatMap(\.shortcuts).count) commands")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 14)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search shortcuts", text: $query)
                    .textFieldStyle(.plain)
            }
            .frame(width: 230)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7))

            Button {
                dismiss()
            } label: {
                Label("Close", systemImage: "xmark")
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(20)
    }
}

private struct ShortcutSectionView: View {
    let section: ShortcutSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(section.shortcuts) { item in
                    ShortcutRow(item: item)
                    if item.id != section.shortcuts.last?.id {
                        Divider()
                            .padding(.leading, 132)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
    }
}

private struct ShortcutRow: View {
    let item: ShortcutItem

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(item.shortcut)
                .font(.caption.weight(.semibold).monospaced())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: 118, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.action)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
