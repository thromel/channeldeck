import Foundation

@MainActor
final class AccountStore: ObservableObject {
    @Published var serverURL: String {
        didSet { defaults.set(serverURL, forKey: Keys.serverURL) }
    }

    @Published var username: String {
        didSet { defaults.set(username, forKey: Keys.username) }
    }

    @Published var password: String {
        didSet {
            guard !isRestoringPassword else {
                return
            }

            try? KeychainService.save(password, account: Keys.passwordAccount)
        }
    }

    @Published var streamFormat: StreamFormat {
        didSet { defaults.set(streamFormat.rawValue, forKey: Keys.streamFormat) }
    }

    private let defaults: UserDefaults
    private var isRestoringPassword = false
    private var didRestorePassword = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        serverURL = defaults.string(forKey: Keys.serverURL)
            ?? ""
        username = defaults.string(forKey: Keys.username)
            ?? ""
        password = ""

        let rawFormat = defaults.string(forKey: Keys.streamFormat)
            ?? StreamFormat.hls.rawValue
        streamFormat = StreamFormat(rawValue: rawFormat) ?? .hls

        defaults.set(serverURL, forKey: Keys.serverURL)
        defaults.set(username, forKey: Keys.username)
        defaults.set(streamFormat.rawValue, forKey: Keys.streamFormat)
    }

    func restoreSavedPassword() async {
        guard !didRestorePassword else {
            return
        }

        didRestorePassword = true
        let savedPassword = await Task.detached(priority: .userInitiated) {
            (try? KeychainService.read(account: Keys.passwordAccount)) ?? ""
        }.value

        isRestoringPassword = true
        password = savedPassword
        isRestoringPassword = false
    }

    var credentials: IPTVCredentials {
        IPTVCredentials(
            serverURL: serverURL.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            streamFormat: streamFormat
        )
    }

    func clearCredentials() {
        username = ""
        password = ""
        try? KeychainService.delete(account: Keys.passwordAccount)
    }
}

private enum Keys {
    static let serverURL = "account.serverURL"
    static let username = "account.username"
    static let passwordAccount = "iptv-password"
    static let streamFormat = "player.streamFormat"
}
