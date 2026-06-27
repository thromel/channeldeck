import SwiftUI

struct MultiPlaybackView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var iptvStore: IPTVStore

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(iptvStore.visibleMultiPlaybackSlots) { slot in
                        MultiPlaybackTile(slot: slot)
                    }
                }
                .padding(12)
            }
            .background(Color.black)
        }
        .navigationTitle("Multiview")
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Multiview")
                    .font(.title3.weight(.semibold))
                Text("\(iptvStore.activeMultiPlaybackCount) playing, \(iptvStore.multiPlaybackSlotCount) slots")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Slots", selection: Binding(
                get: { iptvStore.multiPlaybackSlotCount },
                set: { iptvStore.setMultiPlaybackSlotCount($0) }
            )) {
                Text("2").tag(2)
                Text("3").tag(3)
                Text("4").tag(4)
            }
            .pickerStyle(.segmented)
            .frame(width: 128)

            Button {
                iptvStore.saveMultiPlaybackLayout()
            } label: {
                Label("Save Layout", systemImage: "tray.and.arrow.down")
            }
            .disabled(iptvStore.activeMultiPlaybackCount == 0)

            Button {
                iptvStore.restoreMultiPlaybackLayout(account: accountStore.credentials)
            } label: {
                Label("Restore Layout", systemImage: "tray.and.arrow.up")
            }
            .disabled(!iptvStore.hasSavedMultiPlaybackLayout || iptvStore.channels.isEmpty)

            Button {
                iptvStore.clearMultiPlayback()
            } label: {
                Label("Clear", systemImage: "xmark.circle")
            }
            .disabled(iptvStore.activeMultiPlaybackCount == 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
}

private struct MultiPlaybackTile: View {
    @EnvironmentObject private var iptvStore: IPTVStore
    @ObservedObject var slot: MultiPlaybackSlot

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black

                if slot.channel != nil {
                    PlayerSurfaceView(player: slot.player)
                } else {
                    EmptyMultiviewSlot(slotID: slot.id)
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)

            controls
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.channel?.name ?? "Empty Slot \(slot.id + 1)")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Text(slot.channel.map { "Stream \($0.id)" } ?? "Add a channel from the browser")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    slot.toggleMute()
                } label: {
                    Image(systemName: slot.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help(slot.isMuted ? "Unmute slot" : "Mute slot")
                .disabled(slot.channel == nil)

                Button {
                    iptvStore.toggleRecording(for: slot)
                } label: {
                    Image(systemName: slot.recording?.isActive == true ? "stop.circle.fill" : "record.circle")
                        .foregroundStyle(slot.recording?.isActive == true ? .red : .secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help(slot.recording?.isActive == true ? "Stop local recording" : "Record this slot locally")
                .disabled(slot.channel == nil)

                Button {
                    iptvStore.clearMultiPlaybackSlot(slot)
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help("Clear slot")
                .disabled(slot.channel == nil)
            }

            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.1")
                    .foregroundStyle(.secondary)

                Slider(value: Binding(
                    get: { slot.volume },
                    set: { slot.setVolume($0) }
                ), in: 0...1)
                .disabled(slot.channel == nil)

                Text("\(Int(slot.volume * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

            if let recording = slot.recording {
                RecordingStatusView(recording: recording) {
                    iptvStore.revealRecording(for: slot)
                }
            }
        }
        .padding(10)
        .background(.regularMaterial)
    }
}

private struct EmptyMultiviewSlot: View {
    let slotID: Int

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.grid.2x2")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("Slot \(slotID + 1)")
                .font(.callout.weight(.semibold))
            Text("Use Add to Multiview on a channel.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct RecordingStatusView: View {
    @ObservedObject var recording: LocalStreamRecording
    let reveal: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(tint)
            Text(recording.state.rawValue)
                .font(.caption2.weight(.semibold))
            Text(recording.byteCountText)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button {
                reveal()
            } label: {
                Label("Reveal Recording", systemImage: "folder")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Reveal local recording in Finder")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    private var iconName: String {
        switch recording.state {
        case .recording:
            "record.circle.fill"
        case .stopping:
            "stop.circle"
        case .stopped:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch recording.state {
        case .recording:
            .red
        case .stopping:
            .orange
        case .stopped:
            .green
        case .failed:
            .orange
        }
    }
}
