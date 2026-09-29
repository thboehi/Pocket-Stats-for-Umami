import Foundation

/// REST client for Umami v2/v3 (self-hosted) and Umami Cloud.
///
/// Self-hosted: `POST /api/auth/login` returns a bearer token. The password is
/// kept in the Keychain so the client can transparently sign in again when the
/// token is rejected (401).
/// Cloud: every request carries `x-umami-api-key`, base `https://api.umami.is/v1`.
/// Share link: `GET /api/share/<id>` returns a token for one website, sent as
/// `x-umami-share-token` and fetched again when rejected.
struct UmamiClient: AnalyticsService {
    let account: Account
    var session: URLSession = Self.session

    /// Statistics must always be fresh: no HTTP cache, and a request stuck on
    /// a dead connection (common right after the app comes back from the
    /// background) fails quickly and is retried instead of waiting 60 seconds.
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15
        return URLSession(configuration: configuration)
    }()

    // MARK: Authentication

    static func login(serverURL: URL, username: String, password: String, session: URLSession = Self.session) async throws -> LoginResponse {
        var request = URLRequest(url: serverURL.appending(path: "api/auth/login"), timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(["username": username, "password": password])

        let (data, response) = try await perform(request, session: session)
        switch response.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(LoginResponse.self, from: data)
            } catch {
                throw UmamiError.notAnUmamiServer
            }
        case 401, 403:
            throw UmamiError.invalidCredentials
        case 404, 405:
            throw UmamiError.notAnUmamiServer
        default:
            throw error(for: response.statusCode, data: data)
        }
    }

    /// Resolves a share link (`GET /api/share/<id>`) to its website and token.
    static func share(serverURL: URL, shareID: String, session: URLSession = Self.session) async throws -> ShareResponse {
        var request = URLRequest(url: serverURL.appending(path: "api/share").appending(path: shareID), timeoutInterval: 30)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await perform(request, session: session)
        switch response.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(ShareResponse.self, from: data)
            } catch {
                throw UmamiError.notAnUmamiServer
            }
        case 404:
            throw UmamiError.shareNotFound
        default:
            throw error(for: response.statusCode, data: data)
        }
    }

    /// Verifies the credentials and returns the signed-in user (`GET /me`).
    func currentUser() async throws -> UmamiUser? {
        let data = try await send("GET", "me")
        struct Me: Decodable { let user: UmamiUser? }
        return try? Self.decoder.decode(Me.self, from: data).user
    }

    // MARK: Websites

    func websites(scope: WebsiteScope) async throws -> [Website] {
        if account.kind == .share {
            guard let websiteID = account.sharedWebsiteID else { return [] }
            return [try await get("websites/\(websiteID)")]
        }
        let path = scope == .all ? "admin/websites" : "websites"
        var websites: [Website] = []
        var page = 1
        while page <= 20 {
            var query = [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "pageSize", value: "100")]
            if scope == .mine { query.append(URLQueryItem(name: "includeTeams", value: "true")) }
            let response: PagedResponse<Website> = try await get(path, query: query)
            websites += response.data
            if response.data.isEmpty || websites.count >= (response.count ?? 0) { break }
            page += 1
        }
        return websites.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func teams() async throws -> [TeamSummary] {
        guard account.canManageWebsites else { return [] }
        let data: Data
        do {
            data = try await send("GET", "me/teams", query: [URLQueryItem(name: "pageSize", value: "100")])
        } catch UmamiError.notFound {
            data = try await send("GET", "teams")
        }
        if let page = try? Self.decoder.decode(PagedResponse<TeamSummary>.self, from: data) { return page.data }
        return try Self.decoder.decode([TeamSummary].self, from: data)
    }

    func createWebsite(name: String, domain: String, teamID: String?) async throws -> Website {
        try await send("POST", "websites", body: WebsiteBody(name: name, domain: domain, teamId: teamID))
    }

    func updateWebsite(id: String, name: String, domain: String) async throws -> Website {
        try await send("POST", "websites/\(id)", body: WebsiteBody(name: name, domain: domain, teamId: nil))
    }

    func deleteWebsite(id: String) async throws {
        _ = try await send("DELETE", "websites/\(id)")
    }

    func resetWebsite(id: String) async throws {
        _ = try await send("POST", "websites/\(id)/reset")
    }

    // MARK: Statistics

    func stats(websiteID: String, interval: DateInterval) async throws -> WebsiteStats {
        let data = try await send("GET", "websites/\(websiteID)/stats", query: Self.range(interval))
        return try WebsiteStats.parse(data)
    }

    func traffic(websiteID: String, interval: DateInterval, unit: TimeUnit) async throws -> TrafficSeries {
        let timeZone = TimeZone.current
        let query = Self.range(interval) + [
            URLQueryItem(name: "unit", value: unit.rawValue),
            URLQueryItem(name: "timezone", value: timeZone.identifier),
        ]
        let data = try await send("GET", "websites/\(websiteID)/pageviews", query: query)
        return try TrafficSeries.parse(data, timeZone: timeZone)
    }

    func metrics(websiteID: String, type: MetricType, interval: DateInterval, limit: Int) async throws -> [MetricItem] {
        func fetch(_ typeName: String) async throws -> [MetricItem] {
            let query = Self.range(interval) + [
                URLQueryItem(name: "type", value: typeName),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
            return try MetricItem.parse(try await send("GET", "websites/\(websiteID)/metrics", query: query))
        }
        do {
            return try await fetch(type.rawValue)
        } catch UmamiError.badRequest(let message) {
            // Umami v2 names some metric types differently (`url` instead of `path`).
            guard let legacy = type.legacyName else { throw UmamiError.badRequest(message) }
            return try await fetch(legacy)
        }
    }

    func activeVisitors(websiteID: String) async throws -> Int {
        let data = try await send("GET", "websites/\(websiteID)/active")
        let object = try JSONSerialization.jsonObject(with: data)
        // v3: { visitors }, v2: { x }, older v2: [{ x }]
        let dictionary = (object as? [String: Any]) ?? (object as? [[String: Any]])?.first ?? [:]
        let value = JSONNumber.double(dictionary["visitors"]) ?? JSONNumber.double(dictionary["x"]) ?? 0
        return Int(value)
    }

    // MARK: - Transport

    private struct WebsiteBody: Encodable {
        let name: String
        let domain: String
        let teamId: String?
    }

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        let data = try await send("GET", path, query: query)
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw UmamiError.decoding(path)
        }
    }

    private func send<T: Decodable>(_ method: String, _ path: String, body: some Encodable) async throws -> T {
        let data = try await send(method, path, body: try JSONEncoder().encode(body))
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw UmamiError.decoding(path)
        }
    }

    /// Runs off the main actor: reading the Keychain and waiting for the network
    /// never holds up the UI.
    @concurrent
    private func send(_ method: String, _ path: String, query: [URLQueryItem] = [], body: Data? = nil, retryOnUnauthorized: Bool = true) async throws -> Data {
        var url = account.apiBaseURL.appending(path: path)
        if !query.isEmpty { url.append(queryItems: query) }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        switch account.kind {
        case .cloud:
            request.setValue(CredentialStore.get(.apiKey, for: account.id), forHTTPHeaderField: "x-umami-api-key")
        case .selfHosted:
            if let token = CredentialStore.get(.token, for: account.id) {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        case .share:
            request.setValue(CredentialStore.get(.token, for: account.id), forHTTPHeaderField: "x-umami-share-token")
        case .demo:
            break
        }

        let (data, response) = try await Self.perform(request, session: session)
        if (200..<300).contains(response.statusCode) { return data }

        if response.statusCode == 401, retryOnUnauthorized, [.selfHosted, .share].contains(account.kind), try await refreshToken() {
            return try await send(method, path, query: query, body: body, retryOnUnauthorized: false)
        }
        throw Self.error(for: response.statusCode, data: data)
    }

    /// Signs in again with the stored password, or fetches a new share token.
    /// Returns `false` when nothing is stored to do so.
    /// Concurrent 401s (a dashboard fires several requests at once) share one sign-in.
    private func refreshToken() async throws -> Bool {
        let account = account
        let session = session
        return try await TokenRefresher.shared.refresh(accountID: account.id) {
            if account.kind == .share {
                guard let shareID = account.shareID else { return false }
                let share = try await Self.share(serverURL: account.serverURL, shareID: shareID, session: session)
                CredentialStore.set(share.token, .token, for: account.id)
                return true
            }
            guard let username = account.username,
                  let password = CredentialStore.get(.password, for: account.id) else { return false }
            do {
                let login = try await Self.login(serverURL: account.serverURL, username: username, password: password, session: session)
                CredentialStore.set(login.token, .token, for: account.id)
                return true
            } catch UmamiError.invalidCredentials {
                throw UmamiError.unauthorized
            }
        }
    }

    private static func perform(_ request: URLRequest, session: URLSession, isRetry: Bool = false) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw UmamiError.notAnUmamiServer }
            return (data, http)
        } catch let error as UmamiError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError where !isRetry && [.timedOut, .networkConnectionLost].contains(error.code) {
            // A connection that died while the app was in the background: try once more on a new one.
            return try await perform(request, session: session, isRetry: true)
        } catch let error as URLError where error.code == .appTransportSecurityRequiresSecureConnection {
            throw UmamiError.insecureConnection
        } catch {
            throw UmamiError.network(error.localizedDescription)
        }
    }

    private static func error(for statusCode: Int, data: Data) -> UmamiError {
        let message = serverMessage(from: data)
        return switch statusCode {
        case 400: .badRequest(message)
        case 401: .unauthorized
        case 403: .forbidden
        case 404: .notFound
        default: .server(statusCode, message)
        }
    }

    /// Extracts `{"error":{"message":…}}`, `{"error":"…"}` or a short plain-text body.
    private static func serverMessage(from data: Data) -> String? {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = object["error"] as? [String: Any], let message = error["message"] as? String { return message }
            if let message = object["error"] as? String { return message }
            if let message = object["message"] as? String { return message }
        }
        guard let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty, text.count < 200, !text.hasPrefix("<") else { return nil }
        return text
    }

    private static func range(_ interval: DateInterval) -> [URLQueryItem] {
        [
            URLQueryItem(name: "startAt", value: "\(Int64(interval.start.timeIntervalSince1970 * 1000))"),
            URLQueryItem(name: "endAt", value: "\(Int64(interval.end.timeIntervalSince1970 * 1000))"),
        ]
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            guard let date = UmamiDate.parse(string) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid date \(string)"))
            }
            return date
        }
        return decoder
    }
}

/// Serializes token refreshes per account.
private actor TokenRefresher {
    static let shared = TokenRefresher()

    private var running: [UUID: Task<Bool, any Error>] = [:]

    func refresh(accountID: UUID, _ signIn: @escaping @Sendable () async throws -> Bool) async throws -> Bool {
        if let task = running[accountID] { return try await task.value }
        let task = Task { try await signIn() }
        running[accountID] = task
        defer { running[accountID] = nil }
        return try await task.value
    }
}
