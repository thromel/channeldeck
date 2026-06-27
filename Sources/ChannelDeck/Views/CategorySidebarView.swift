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
                .foregroundStyle(iconStyle)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text("\(iptvStore.channelCount(for: category.id))")
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
        }
        .padding(.vertical, 4)
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

    private var iconStyle: AnyShapeStyle {
        switch category.id {
        case IPTVCategory.favoritesID:
            AnyShapeStyle(.yellow)
        case IPTVCategory.recentID:
            AnyShapeStyle(.blue)
        default:
            AnyShapeStyle(.secondary)
        }
    }

    private var subtitle: String {
        switch category.id {
        case IPTVCategory.allID:
            "Every loaded channel"
        case IPTVCategory.favoritesID:
            "Saved locally"
        case IPTVCategory.recentID:
            "Persists across launches"
        default:
            "Live category"
        }
    }
}

private struct SidebarStatusView: View {
    @EnvironmentObject private var iptvStore: IPTVStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

            if !iptvStore.channels.isEmpty {
                HStack(spacing: 6) {
                    SidebarMetric(label: "Fav", value: iptvStore.favoriteChannelIDs.count)
                    SidebarMetric(label: "Recent", value: iptvStore.recentChannels.count)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
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

private struct SidebarMetric: View {
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
            Text("\(value)")
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: Capsule())
    }
}
