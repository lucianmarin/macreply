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

public final class EndpointCache: @unchecked Sendable {
    public static let keyPrefix = "macreply.cache.endpoint."

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var memoryCache: [String: Data] = [:]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public static func splitPathAndQuery(_ rawPath: String) -> (path: String, queryItems: [URLQueryItem]) {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixed = trimmed.hasPrefix("/") ? trimmed : "/" + trimmed
        if let components = URLComponents(string: prefixed) {
            let cleanPath = normalizedPath(components.path.isEmpty ? "/" : components.path)
            return (cleanPath, components.queryItems ?? [])
        }
        return (normalizedPath(prefixed), [])
    }

    public static func normalizedPath(_ path: String) -> String {
        var trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if let qIndex = trimmed.firstIndex(of: "?") {
            trimmed = String(trimmed[..<qIndex])
        }
        while trimmed.hasSuffix("/") && trimmed.count > 1 {
            trimmed.removeLast()
        }
        if !trimmed.hasPrefix("/") {
            trimmed = "/" + trimmed
        }
        return trimmed.lowercased()
    }

    public static func cacheKey(forPath path: String, queryItems: [URLQueryItem] = []) -> String? {
        let split = splitPathAndQuery(path)
        let allItems = split.queryItems + queryItems
        for item in allItems {
            let name = item.name.lowercased()
            let value = (item.value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if name == "q", !value.isEmpty {
                return nil
            }
            if name == "p", !value.isEmpty, value != "1" {
                return nil
            }
        }
        return split.path
    }

    public static func cacheKey(forPath path: String, page: Int = 1, query: String? = nil) -> String? {
        guard page == 1 else { return nil }
        if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        return cacheKey(forPath: path, queryItems: [])
    }

    private func storageKey(for key: String) -> String {
        Self.keyPrefix + Self.normalizedPath(key)
    }

    public func storeData(_ data: Data, forPath path: String) {
        guard let key = Self.cacheKey(forPath: path) else { return }
        lock.lock()
        memoryCache[key] = data
        lock.unlock()
        defaults.set(data, forKey: storageKey(for: key))
    }

    public func store<T: Encodable>(_ value: T, forPath path: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        storeData(data, forPath: path)
    }

    public func loadData(forPath path: String, page: Int = 1, query: String? = nil) -> Data? {
        guard let key = Self.cacheKey(forPath: path, page: page, query: query) else {
            return nil
        }
        lock.lock()
        if let cached = memoryCache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let stored = defaults.data(forKey: storageKey(for: key)) else {
            return nil
        }
        lock.lock()
        memoryCache[key] = stored
        lock.unlock()
        return stored
    }

    public func load<T: Decodable>(_ type: T.Type, forPath path: String, page: Int = 1, query: String? = nil) -> T? {
        guard let data = loadData(forPath: path, page: page, query: query) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    public func clearAll() {
        lock.lock()
        let memoryKeys = Array(memoryCache.keys)
        memoryCache.removeAll()
        lock.unlock()

        for key in memoryKeys {
            defaults.removeObject(forKey: storageKey(for: key))
        }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Self.keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}

public actor APIClient {
    private var baseURLString: String
    private var token: String?
    private let session: URLSession
    public nonisolated let cache: EndpointCache

    public init(
        baseURLString: String = "https://subreply.com/api",
        token: String? = nil,
        session: URLSession = .shared,
        cache: EndpointCache = EndpointCache()
    ) {
        self.baseURLString = Self.normalizeBaseURL(baseURLString)
        self.token = token
        self.session = session
        self.cache = cache
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
        let split = EndpointCache.splitPathAndQuery(path)
        guard var components = URLComponents(string: baseURLString + split.path) else {
            throw APIError.invalidURL
        }
        let allItems = split.queryItems + queryItems
        let filteredItems = allItems.filter { item in
            guard let val = item.value?.trimmingCharacters(in: .whitespacesAndNewlines), !val.isEmpty else {
                return false
            }
            if item.name.lowercased() == "p" && val == "1" {
                return false
            }
            return true
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

    // MARK: - Cache Helpers

    public nonisolated func cachedEntries(path: String, page: Int = 1, query: String? = nil) -> PaginatedEntriesResponse? {
        cache.load(PaginatedEntriesResponse.self, forPath: path, page: page, query: query)
    }

    public nonisolated func cachedUsers(path: String, page: Int = 1, query: String? = nil) -> PaginatedUsersResponse? {
        cache.load(PaginatedUsersResponse.self, forPath: path, page: page, query: query)
    }

    public nonisolated func cachedMemberDetail(username: String) -> SubUser? {
        let cleanUsername = username.lowercased()
        return cache.load(MemberResponse.self, forPath: "/\(cleanUsername)")?.member
    }

    public nonisolated func cachedMemberPosts(username: String, page: Int = 1) -> PaginatedEntriesResponse? {
        let cleanUsername = username.lowercased()
        return cache.load(PaginatedEntriesResponse.self, forPath: "/\(cleanUsername)/posts", page: page)
    }

    public nonisolated func cachedReplyDetail(id: Int) -> ReplyDetailResponse? {
        cache.load(ReplyDetailResponse.self, forPath: "/reply/\(id)")
    }

    public nonisolated func cachedMessages(page: Int = 1) -> PaginatedChatsResponse? {
        cache.load(PaginatedChatsResponse.self, forPath: "/messages", page: page)
    }

    public nonisolated func cachedConversation(username: String, page: Int = 1) -> PaginatedChatsResponse? {
        let cleanUsername = username.lowercased()
        return cache.load(PaginatedChatsResponse.self, forPath: "/\(cleanUsername)/message", page: page)
    }

    public nonisolated func cachedNotifications() -> SubNotifications? {
        cache.load(SubNotifications.self, forPath: "/notifications")
    }

    public nonisolated func clearCache() {
        cache.clearAll()
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
        let response = try decode(PaginatedEntriesResponse.self, from: data)
        if let key = EndpointCache.cacheKey(forPath: path, page: page, query: query) {
            cache.storeData(data, forPath: key)
        }
        return response
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
        let response = try decode(PaginatedUsersResponse.self, from: data)
        if let key = EndpointCache.cacheKey(forPath: path, page: page, query: query) {
            cache.storeData(data, forPath: key)
        }
        return response
    }

    public func fetchMemberDetail(username: String) async throws -> SubUser {
        let cleanUsername = username.lowercased()
        let path = "/\(cleanUsername)"
        let data = try await performRequest(path: path)
        let response = try decode(MemberResponse.self, from: data)
        cache.storeData(data, forPath: path)
        return response.member
    }

    public func fetchMemberPosts(username: String, page: Int = 1) async throws -> PaginatedEntriesResponse {
        var items: [URLQueryItem] = []
        if page > 1 {
            items.append(URLQueryItem(name: "p", value: String(page)))
        }
        let cleanUsername = username.lowercased()
        let path = "/\(cleanUsername)/posts"
        let data = try await performRequest(path: path, queryItems: items)
        let response = try decode(PaginatedEntriesResponse.self, from: data)
        if let key = EndpointCache.cacheKey(forPath: path, page: page) {
            cache.storeData(data, forPath: key)
        }
        return response
    }

    public func fetchMember(username: String, page: Int = 1) async throws -> MemberFeedResponse {
        let cleanUsername = username.lowercased()
        async let memberTask = fetchMemberDetail(username: cleanUsername)
        async let postsTask = fetchMemberPosts(username: cleanUsername, page: page)
        let (member, postsResponse) = try await (memberTask, postsTask)
        return MemberFeedResponse(page: postsResponse.page, member: member, entries: postsResponse.entries)
    }

    public func fetchReplyDetail(id: Int) async throws -> ReplyDetailResponse {
        let path = "/reply/\(id)"
        let data = try await performRequest(path: path)
        let response = try decode(ReplyDetailResponse.self, from: data)
        cache.storeData(data, forPath: path)
        return response
    }

    public func fetchMessages(page: Int = 1) async throws -> PaginatedChatsResponse {
        let items = page > 1 ? [URLQueryItem(name: "p", value: String(page))] : []
        let path = "/messages"
        let data = try await performRequest(path: path, queryItems: items)
        let response = try decode(PaginatedChatsResponse.self, from: data)
        if let key = EndpointCache.cacheKey(forPath: path, page: page) {
            cache.storeData(data, forPath: key)
        }
        return response
    }

    public func fetchConversation(username: String, page: Int = 1) async throws -> PaginatedChatsResponse {
        let items = page > 1 ? [URLQueryItem(name: "p", value: String(page))] : []
        let cleanUsername = username.lowercased()
        let path = "/\(cleanUsername)/message"
        let data = try await performRequest(path: path, queryItems: items)
        let response = try decode(PaginatedChatsResponse.self, from: data)
        if let key = EndpointCache.cacheKey(forPath: path, page: page) {
            cache.storeData(data, forPath: key)
        }
        return response
    }

    public func fetchNotifications() async throws -> SubNotifications {
        let path = "/notifications"
        let data = try await performRequest(path: path)
        let response = try decode(SubNotifications.self, from: data)
        cache.storeData(data, forPath: path)
        return response
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

    public func clearConversation(username: String) async throws -> Bool {
        let cleanUsername = username.lowercased()
        let data = try await performRequest(path: "/\(cleanUsername)/clear", method: "POST")
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
