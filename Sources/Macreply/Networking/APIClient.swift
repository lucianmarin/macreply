import Foundation

public enum APIError: LocalizedError, Equatable, Sendable {
    case invalidURL
    case unauthorized
    case notFound
    case validation([String: String])
    case serverStatus(String)
    case httpError(Int)
    case decodingError(String)
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .unauthorized:
            return "Login required"
        case .notFound:
            return "Resource not found"
        case .validation(let errors):
            return errors.values.joined(separator: "\n")
        case .serverStatus(let status):
            return "Action \(status)"
        case .httpError(let code):
            return "Server returned HTTP \(code)"
        case .decodingError(let message):
            return "Failed to parse response: \(message)"
        case .networkError(let message):
            return message
        }
    }

    public var fieldErrors: [String: String] {
        if case .validation(let dict) = self {
            return dict
        }
        return [:]
    }
}

private struct ErrorEnvelope: Decodable {
    let errors: [String: String]?
    let status: String?
}

public actor APIClient {
    private var baseURLString: String
    private var token: String?
    private let session: URLSession

    public init(
        baseURLString: String = "https://subreply.com/api",
        token: String? = nil,
        session: URLSession = .shared
    ) {
        self.baseURLString = Self.normalizeBaseURL(baseURLString)
        self.token = token
        self.session = session
    }

    public static func normalizeBaseURL(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        if trimmed.isEmpty {
            return "https://subreply.com/api"
        }
        return trimmed
    }

    public func setConfiguration(baseURLString: String, token: String?) {
        self.baseURLString = Self.normalizeBaseURL(baseURLString)
        self.token = token
    }

    public func currentBaseURL() -> String {
        baseURLString
    }

    private func makeURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        let normalizedPath = path.hasPrefix("/") ? path : "/" + path
        guard var components = URLComponents(string: baseURLString + normalizedPath) else {
            throw APIError.invalidURL
        }
        let filteredItems = queryItems.filter { item in
            guard let val = item.value else { return false }
            return !val.isEmpty
        }
        if !filteredItems.isEmpty {
            components.queryItems = filteredItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        return url
    }

    private func performRequest(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: [String: String]? = nil
    ) async throws -> Data {
        let url = try makeURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid HTTP response")
        }

        switch http.statusCode {
        case 200..<300:
            return data
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        default:
            throw APIError.httpError(http.statusCode)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data),
           let errors = envelope.errors, !errors.isEmpty {
            throw APIError.validation(errors)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Auth

    public func login(username: String, password: String) async throws -> (token: String, user: SubUser) {
        let data = try await performRequest(
            path: "/login",
            method: "POST",
            body: ["username": username, "password": password]
        )
        let response = try decode(AuthResponse.self, from: data)
        guard let token = response.token, let user = response.user else {
            throw APIError.decodingError("Missing token or user")
        }
        self.token = token
        return (token, user)
    }

    public func register(payload: [String: String]) async throws -> (token: String, user: SubUser) {
        let data = try await performRequest(
            path: "/register",
            method: "POST",
            body: payload
        )
        let response = try decode(AuthResponse.self, from: data)
        guard let token = response.token, let user = response.user else {
            throw APIError.decodingError("Missing token or user")
        }
        self.token = token
        return (token, user)
    }

    // MARK: - GET Feeds

    public func fetchEntries(path: String, page: Int = 1, query: String? = nil) async throws -> PaginatedEntriesResponse {
        var items: [URLQueryItem] = []
        if page > 1 {
            items.append(URLQueryItem(name: "p", value: String(page)))
        }
        if let query, !query.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(URLQueryItem(name: "q", value: query.trimmingCharacters(in: .whitespaces)))
        }
        let data = try await performRequest(path: path, queryItems: items)
        return try decode(PaginatedEntriesResponse.self, from: data)
    }

    public func fetchUsers(path: String, page: Int = 1, query: String? = nil) async throws -> PaginatedUsersResponse {
        var items: [URLQueryItem] = []
        if page > 1 {
            items.append(URLQueryItem(name: "p", value: String(page)))
        }
        if let query, !query.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(URLQueryItem(name: "q", value: query.trimmingCharacters(in: .whitespaces)))
        }
        let data = try await performRequest(path: path, queryItems: items)
        return try decode(PaginatedUsersResponse.self, from: data)
    }

    public func fetchMember(username: String, page: Int = 1) async throws -> MemberFeedResponse {
        var items: [URLQueryItem] = []
        if page > 1 {
            items.append(URLQueryItem(name: "p", value: String(page)))
        }
        let cleanUsername = username.lowercased()
        do {
            let data = try await performRequest(path: "/\(cleanUsername)", queryItems: items)
            return try decode(MemberFeedResponse.self, from: data)
        } catch APIError.unauthorized {
            let usersResponse = try await fetchUsers(path: "/people", page: 1, query: cleanUsername)
            guard let matched = usersResponse.entries.first(where: { $0.username.lowercased() == cleanUsername }) else {
                throw APIError.notFound
            }
            return MemberFeedResponse(page: page, member: matched, entries: [])
        }
    }

    public func fetchReplyDetail(id: Int) async throws -> ReplyDetailResponse {
        let data = try await performRequest(path: "/reply/\(id)")
        return try decode(ReplyDetailResponse.self, from: data)
    }

    public func fetchMessages(page: Int = 1) async throws -> PaginatedChatsResponse {
        let items = page > 1 ? [URLQueryItem(name: "p", value: String(page))] : []
        let data = try await performRequest(path: "/messages", queryItems: items)
        return try decode(PaginatedChatsResponse.self, from: data)
    }

    public func fetchConversation(username: String, page: Int = 1) async throws -> PaginatedChatsResponse {
        let items = page > 1 ? [URLQueryItem(name: "p", value: String(page))] : []
        let cleanUsername = username.lowercased()
        let data = try await performRequest(path: "/\(cleanUsername)/message", queryItems: items)
        return try decode(PaginatedChatsResponse.self, from: data)
    }

    public func fetchNotifications() async throws -> SubNotifications {
        let data = try await performRequest(path: "/notifications")
        return try decode(SubNotifications.self, from: data)
    }

    // MARK: - POST / PATCH Content & Actions

    public func createThread(content: String) async throws -> SubEntry {
        let data = try await performRequest(
            path: "/thread",
            method: "POST",
            body: ["content": content]
        )
        return try decode(SubEntry.self, from: data)
    }

    public func createReply(parentID: Int, content: String) async throws -> SubEntry {
        let data = try await performRequest(
            path: "/reply/\(parentID)",
            method: "POST",
            body: ["content": content]
        )
        return try decode(SubEntry.self, from: data)
    }

    public func editEntry(id: Int, content: String) async throws -> SubEntry {
        let data = try await performRequest(
            path: "/edit/\(id)",
            method: "PATCH",
            body: ["content": content]
        )
        if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
            if let errors = envelope.errors, !errors.isEmpty {
                throw APIError.validation(errors)
            }
            if let status = envelope.status {
                throw APIError.serverStatus(status)
            }
        }
        return try decode(SubEntry.self, from: data)
    }

    public func deleteEntry(id: Int) async throws -> Bool {
        let data = try await performRequest(path: "/delete/\(id)", method: "POST")
        let response = try decode(ActionStatusResponse.self, from: data)
        if response.status == "deleted" {
            return true
        }
        throw APIError.serverStatus(response.status ?? "failed")
    }

    public func setSaved(id: Int, save: Bool) async throws -> Bool {
        let action = save ? "save" : "unsave"
        let expectedReverse = save ? "unsave" : "save"
        let data = try await performRequest(path: "/\(action)/\(id)", method: "POST")
        let response = try decode(ActionStatusResponse.self, from: data)
        if response.status == expectedReverse {
            return save
        }
        throw APIError.serverStatus(response.status ?? "failed")
    }

    public func setFollowing(username: String, follow: Bool) async throws -> Bool {
        let action = follow ? "follow" : "unfollow"
        let expectedReverse = follow ? "unfollow" : "follow"
        let cleanUsername = username.lowercased()
        let data = try await performRequest(path: "/\(action)/\(cleanUsername)", method: "POST")
        let response = try decode(ActionStatusResponse.self, from: data)
        if response.status == expectedReverse {
            return follow
        }
        throw APIError.serverStatus(response.status ?? "failed")
    }

    public func sendMessage(username: String, content: String) async throws -> SubChat {
        let cleanUsername = username.lowercased()
        let data = try await performRequest(
            path: "/\(cleanUsername)/send",
            method: "POST",
            body: ["content": content]
        )
        return try decode(SubChat.self, from: data)
    }

    public func unsendMessage(id: Int) async throws -> Bool {
        let data = try await performRequest(path: "/unsend/\(id)", method: "POST")
        let response = try decode(ActionStatusResponse.self, from: data)
        if response.status == "unsent" {
            return true
        }
        throw APIError.serverStatus(response.status ?? "failed")
    }

    public func clearoutConversation(username: String) async throws -> Bool {
        let cleanUsername = username.lowercased()
        let data = try await performRequest(path: "/\(cleanUsername)/clearout", method: "POST")
        let response = try decode(ActionStatusResponse.self, from: data)
        if response.status == "cleared" {
            return true
        }
        throw APIError.serverStatus(response.status ?? "failed")
    }

    public func updateProfile(payload: [String: String]) async throws -> SubUser {
        let data = try await performRequest(
            path: "/profile",
            method: "PATCH",
            body: payload
        )
        let response = try decode(UserUpdateResponse.self, from: data)
        guard let user = response.user else {
            throw APIError.decodingError("Missing updated user")
        }
        return user
    }

    public func updateDetails(payload: [String: String]) async throws -> SubUser {
        let data = try await performRequest(
            path: "/details",
            method: "PATCH",
            body: payload
        )
        let response = try decode(UserUpdateResponse.self, from: data)
        guard let user = response.user else {
            throw APIError.decodingError("Missing updated user")
        }
        return user
    }
}
