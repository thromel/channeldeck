import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var accountStore: AccountStore

    var body: some View {
        Form {
            Section("Account") {
                TextField("Server URL", text: $accountStore.serverURL)
                TextField("ID", text: $accountStore.username)
                SecureField("Password", text: $accountStore.password)

                Button(role: .destructive) {
                    accountStore.clearCredentials()
                } label: {
                    Label("Clear Saved Login", systemImage: "trash")
                }
            }

            Section("Playback") {
                Picker("Stream format", selection: $accountStore.streamFormat) {
                    ForEach(StreamFormat.allCases) { format in
                        Text(format.label)
                            .tag(format)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
