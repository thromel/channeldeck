import Foundation

struct IPTVService {
    func authenticate(account: IPTVCredentials) async throws -> AccountSummary {
        let response: PlayerAPIResponse = try await fetch(account: account, action: nil)

        guard response.userInfo?.auth == 1 else {
            throw IPTVServiceError.authenticationFailed
        }

        let summary = response.accountSummary
        guard summary.isActive else {
            throw IPTVServiceError.inactiveAccount(summary.status)
        }

        return summary
    }

    func liveCategories(account: IPTVCredentials) async throws -> [IPTVCategory] {
        try await fetch(account: account, action: "get_live_categories")
    }

    func liveStreams(account: IPTVCredentials) async throws -> [IPTVChannel] {
        try await fetch(account: account, action: "get_live_streams")
    }

    func shortEPG(account: IPTVCredentials, streamID: IPTVChannel.ID, limit: Int = 4) async throws -> [EPGProgram] {
        let response: EPGResponse = try await fetch(
            account: account,
            action: "get_short_epg",
            queryItems: [
                URLQueryItem(name: "stream_id", value: String(streamID)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        )
        return response.programs
    }

    private func fetch<T: Decodable>(
        account: IPTVCredentials,
        action: String?,
        queryItems additionalQueryItems: [URLQueryItem] = []
    ) async throws -> T {
        guard var components = URLComponents(string: account.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/player_api.php") else {
            throw IPTVServiceError.invalidServerURL
        }

        var queryItems = [
            URLQueryItem(name: "username", value: account.username),
            URLQueryItem(name: "password", value: account.password)
        ]

        if let action {
            queryItems.append(URLQueryItem(name: "action", value: action))
        }

        queryItems.append(contentsOf: additionalQueryItems)
        components.queryItems = queryItems

        guard let url = components.url else {
            throw IPTVServiceError.invalidServerURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("ChannelDeck/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IPTVServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw IPTVServiceError.httpStatus(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw IPTVServiceError.decodingFailed
        }
    }
}

enum IPTVServiceError: LocalizedError {
    case invalidServerURL
    case invalidResponse
    case httpStatus(Int)
    case authenticationFailed
    case inactiveAccount(String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            "The server URL is invalid."
        case .invalidResponse:
            "The IPTV server returned an invalid response."
        case .httpStatus(let status):
            "The IPTV server returned HTTP \(status)."
        case .authenticationFailed:
            "The IPTV server rejected the ID/password."
        case .inactiveAccount(let status):
            "The account is not active. Status: \(status)."
        case .decodingFailed:
            "The IPTV response could not be decoded."
        }
    }
}
