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
        didSet { try? KeychainService.save(password, account: Keys.passwordAccount) }
    }

    @Published var streamFormat: StreamFormat {
        didSet { defaults.set(streamFormat.rawValue, forKey: Keys.streamFormat) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        serverURL = defaults.string(forKey: Keys.serverURL)
            ?? ""
        username = defaults.string(forKey: Keys.username)
            ?? ""
        password = (try? KeychainService.read(account: Keys.passwordAccount)) ?? ""

        let rawFormat = defaults.string(forKey: Keys.streamFormat)
            ?? StreamFormat.hls.rawValue
        streamFormat = StreamFormat(rawValue: rawFormat) ?? .hls

        defaults.set(serverURL, forKey: Keys.serverURL)
        defaults.set(username, forKey: Keys.username)
        defaults.set(streamFormat.rawValue, forKey: Keys.streamFormat)
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
