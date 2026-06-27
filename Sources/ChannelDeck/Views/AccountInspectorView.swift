import SwiftUI

struct AccountInspectorView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var iptvStore: IPTVStore

    var body: some View {
        Form {
            Section("Account") {
                TextField("Server URL", text: $accountStore.serverURL)
                TextField("ID", text: $accountStore.username)
                SecureField("Password", text: $accountStore.password)
            }

            Section("Playback") {
                Picker("Stream format", selection: $accountStore.streamFormat) {
                    ForEach(StreamFormat.allCases) { format in
                        Text(format.label)
                            .tag(format)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    Task {
                        await iptvStore.load(account: accountStore.credentials)
                    }
                } label: {
                    Label("Load Channels", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(iptvStore.state == .loading)
            }

            if let summary = iptvStore.accountSummary {
                Section("Status") {
                    AccountStatusRow(summary: summary)

                    if let expiresAt = summary.expiresAt {
                        LabeledContent("Expires", value: expiresAt.formatted(date: .abbreviated, time: .omitted))
                    }

                    if let protocolName = summary.serverProtocol,
                       let port = summary.serverPort {
                        LabeledContent("Server", value: "\(protocolName) :\(port)")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }
}

private struct AccountStatusRow: View {
    let summary: AccountSummary

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: summary.isActive ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(summary.isActive ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.status)
                    .font(.callout.weight(.semibold))

                Text(summary.connectionLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
