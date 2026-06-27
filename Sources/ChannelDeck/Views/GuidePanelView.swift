import SwiftUI

struct GuidePanelView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var iptvStore: IPTVStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 680, idealWidth: 760, minHeight: 520, idealHeight: 600)
    }

    private var header: some View {
        HStack(spacing: 14) {
            if let channel = iptvStore.currentChannel {
                ChannelArtwork(url: channel.iconURL)
                    .frame(width: 58, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(channel.name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(iptvStore.categoryName(for: channel.categoryID))
                        Text("\(iptvStore.epgPrograms.count) guide items")
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } else {
                Label("Guide", systemImage: "calendar")
                    .font(.title3.weight(.semibold))
            }

            Spacer(minLength: 12)

            Button {
                iptvStore.refreshCurrentEPG(account: accountStore.credentials)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(iptvStore.currentChannel == nil || iptvStore.epgState == .loading)

            Button {
                dismiss()
            } label: {
                Label("Close", systemImage: "xmark")
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(20)
    }

    @ViewBuilder
    private var content: some View {
        if iptvStore.currentChannel == nil {
            ContentUnavailableView(
                "No Channel Playing",
                systemImage: "calendar",
                description: Text("Play a channel to load guide information.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch iptvStore.epgState {
            case .idle:
                guideMessage("Guide will load when playback starts.", systemImage: "calendar")
            case .loading where iptvStore.epgPrograms.isEmpty:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading guide")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded, .loading:
                if iptvStore.epgPrograms.isEmpty {
                    guideMessage("No guide data returned for this channel.", systemImage: "calendar.badge.exclamationmark")
                } else {
                    programList
                }
            case .unavailable:
                guideMessage("No guide data returned for this channel.", systemImage: "calendar.badge.exclamationmark")
            case .failed(let issue):
                guideMessage(issue.isEmpty ? "Guide unavailable." : issue, systemImage: "exclamationmark.triangle")
            }
        }
    }

    private var programList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(iptvStore.epgPrograms.enumerated()), id: \.element.id) { index, program in
                    GuidePanelProgramRow(
                        label: label(for: index, program: program),
                        program: program,
                        isCurrent: index == 0
                    )
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.22))
    }

    private func guideMessage(_ text: String, systemImage: String) -> some View {
        ContentUnavailableView(
            "Guide",
            systemImage: systemImage,
            description: Text(text)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func label(for index: Int, program: EPGProgram) -> String {
        if index == 0 {
            return "Now"
        }

        if index == 1 {
            return "Next"
        }

        if let start = program.start {
            return start.formatted(date: .omitted, time: .shortened)
        }

        return "Later"
    }
}

private struct GuidePanelProgramRow: View {
    let label: String
    let program: EPGProgram
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isCurrent ? .green : .secondary)
                    .frame(width: 54, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text(program.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)

                    Text(program.timeRangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
            }

            if isCurrent, let progress = progress {
                ProgressView(value: progress)
                    .tint(.green)
            }

            if !program.description.isEmpty {
                Text(program.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCurrent ? Color.green.opacity(0.35) : Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var progress: Double? {
        guard let start = program.start,
              let end = program.end,
              end > start else {
            return nil
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(start)
        let duration = end.timeIntervalSince(start)
        return min(max(elapsed / duration, 0), 1)
    }
}
