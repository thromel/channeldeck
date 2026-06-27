import SwiftUI

struct CategorySidebarView: View {
    @EnvironmentObject private var iptvStore: IPTVStore

    var body: some View {
        VStack(spacing: 0) {
            SidebarStatusView()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            List(selection: $iptvStore.selectedCategoryID) {
                ForEach(iptvStore.visibleCategories) { category in
                    CategoryRow(category: category)
                    .tag(category.id)
                }
            }
            .listStyle(.sidebar)
        }
        .navigationSplitViewColumnWidth(min: 230, ideal: 270)
    }
}

private struct CategoryRow: View {
    @EnvironmentObject private var iptvStore: IPTVStore

    let category: IPTVCategory

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .lineLimit(1)

                Text("\(iptvStore.channelCount(for: category.id)) channels")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private var iconName: String {
        switch category.id {
        case IPTVCategory.allID:
            "tv"
        case IPTVCategory.favoritesID:
            "star"
        case IPTVCategory.recentID:
            "clock.arrow.circlepath"
        default:
            "rectangle.stack"
        }
    }
}

private struct SidebarStatusView: View {
    @EnvironmentObject private var iptvStore: IPTVStore

    var body: some View {
        HStack(spacing: 10) {
            statusIcon
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(iptvStore.state.label)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch iptvStore.state {
        case .loading:
            ProgressView()
                .controlSize(.small)
        case .loaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .idle:
            Image(systemName: "tv")
                .foregroundStyle(.secondary)
        }
    }

    private var detail: String {
        switch iptvStore.state {
        case .idle:
            ChannelPreviewData.emptyMessage
        case .loading:
            "Contacting the IPTV server."
        case .loaded(let date):
            "\(iptvStore.channels.count) channels, \(iptvStore.categories.count) categories. \(date.formatted(date: .omitted, time: .shortened))"
        case .failed(let message):
            message
        }
    }
}
