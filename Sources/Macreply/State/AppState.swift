import Foundation
import SwiftUI
import AppKit

public enum SidebarSection: String, CaseIterable, Identifiable, Hashable, Sendable {
    // Authenticated items
    case feed
    case following
    case followers
    case mentions
    case messages
    case replies
    case saved
    case profile
    case options

    // Unauthenticated items
    case about
    case login
    case register

    // Public discovery items
    case people
    case trending
    case discover

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .feed: return "Feed"
        case .following: return "Following"
        case .followers: return "Followers"
        case .mentions: return "Mentions"
        case .messages: return "Messages"
        case .replies: return "Replies"
        case .saved: return "Saved"
        case .profile: return "Profile"
        case .options: return "Options"
        case .about: return "About"
        case .login: return "Login"
        case .register: return "Register"
        case .people: return "People"
        case .trending: return "Trending"
        case .discover: return "Discover"
        }
    }

    public var systemImage: String {
        switch self {
        case .feed: return "bolt"
        case .following: return "arrow.turn.left.up"
        case .followers: return "arrow.turn.right.down"
        case .mentions: return "at"
        case .messages: return "bubble.left"
        case .replies: return "arrowshape.turn.up.left"
        case .saved: return "bookmark"
        case .profile: return "person.crop.circle"
        case .options: return "slider.horizontal.3"
        case .about: return "info.circle"
        case .login: return "lock"
        case .register: return "person.badge.plus"
        case .people: return "person.2"
        case .trending: return "chart.line.uptrend.xyaxis"
        case .discover: return "globe"
        }
    }

    public var apiPath: String? {
        switch self {
        case .feed: return "/feed"
        case .following: return "/following"
        case .followers: return "/followers"
        case .mentions: return "/mentions"
        case .messages: return "/messages"
        case .replies: return "/replies"
        case .saved: return "/saved"
        case .people: return "/people"
        case .trending: return "/trending"
        case .discover: return "/discover"
        default: return nil
        }
    }

    public static func visibleSections(isAuthenticated: Bool) -> [SidebarSection] {
        if isAuthenticated {
            return [
                .feed,
                .following,
                .followers,
                .mentions,
                .messages,
                .replies,
                .saved,
                .profile,
                .options,
                .people,
                .trending,
                .discover
            ]
        } else {
            return [
                .about,
                .login,
                .register,
                .people,
                .trending,
                .discover
            ]
        }
    }
}

public enum NavigationDestination: Hashable, Sendable {
    case reply(Int)
    case member(String)
    case conversation(String)
    case editEntry(SubEntry)
}

@MainActor
public final class AppState: ObservableObject {
    @Published public var selectedSection: SidebarSection
    @Published public var navigationPath: [NavigationDestination] = []
    @Published public var currentUser: SubUser?
    @Published public var currentEmail: String
    @Published public var token: String?
    @Published public var apiBaseURL: String
    @Published public var notifications: SubNotifications = SubNotifications() {
        didSet {
            updateDockBadge()
        }
    }
    @Published public var discoverSearchQuery: String = ""
    @Published public var peopleSearchQuery: String = ""
    @Published public var feedRefreshTrigger: UUID = UUID()
    @Published public var notificationPollingMinutes: Int
    @Published public var isCompactSidebar: Bool {
        didSet {
            defaults.set(isCompactSidebar, forKey: StorageKeys.compactSidebar)
        }
    }

    public let apiClient: APIClient
    private let defaults: UserDefaults
    private var notificationTask: Task<Void, Never>?

    private enum StorageKeys {
        static let token = "macreply.auth.token"
        static let userJSON = "macreply.auth.user"
        static let email = "macreply.auth.email"
        static let apiBaseURL = "macreply.config.apiBaseURL"
        static let notificationPollingMinutes = "macreply.config.notificationPollingMinutes"
        static let compactSidebar = "macreply.ui.compactSidebar"
    }

    public var isAuthenticated: Bool {
        token != nil && currentUser != nil
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedBaseURL = defaults.string(forKey: StorageKeys.apiBaseURL) ?? "https://subreply.com/api"
        let savedToken = defaults.string(forKey: StorageKeys.token)
        let savedEmail = defaults.string(forKey: StorageKeys.email) ?? ""
        let savedPolling = defaults.integer(forKey: StorageKeys.notificationPollingMinutes)

        var savedUser: SubUser?
        if let userData = defaults.data(forKey: StorageKeys.userJSON) {
            savedUser = try? JSONDecoder().decode(SubUser.self, from: userData)
        }

        self.apiBaseURL = APIClient.normalizeBaseURL(savedBaseURL)
        self.token = savedToken
        self.currentUser = savedUser
        self.currentEmail = !(savedUser?.email.isEmpty ?? true) ? (savedUser?.email ?? "") : savedEmail
        self.notificationPollingMinutes = savedPolling > 0 ? savedPolling : 2
        self.isCompactSidebar = defaults.bool(forKey: StorageKeys.compactSidebar)
        self.selectedSection = (savedToken != nil && savedUser != nil) ? .feed : .trending
        self.apiClient = APIClient(baseURLString: savedBaseURL, token: savedToken)

        if isAuthenticated {
            startNotificationPolling()
        }
        updateDockBadge()
    }

    public func selectSection(_ section: SidebarSection) {
        navigationPath.removeAll()
        selectedSection = section
    }

    public func openMember(_ username: String) {
        let clean = username.lowercased()
        if let current = currentUser?.username.lowercased(), clean == current, navigationPath.isEmpty {
            selectedSection = .profile
            return
        }
        navigationPath.append(.member(clean))
    }

    public func openReply(_ id: Int) {
        navigationPath.append(.reply(id))
    }

    public func openConversation(_ username: String) {
        navigationPath.append(.conversation(username.lowercased()))
    }

    public func openEdit(_ entry: SubEntry) {
        navigationPath.append(.editEntry(entry))
    }

    public func openHashtag(_ tag: String) {
        let formatted = tag.hasPrefix("#") ? tag : "#\(tag)"
        discoverSearchQuery = formatted
        navigationPath.removeAll()
        selectedSection = .discover
        feedRefreshTrigger = UUID()
    }

    public func openLocationSearch(_ city: String) {
        peopleSearchQuery = city
        navigationPath.removeAll()
        selectedSection = .people
        feedRefreshTrigger = UUID()
    }

    public func applyAuthSession(token: String, user: SubUser, email: String? = nil) {
        self.token = token
        self.currentUser = user
        if !user.email.isEmpty {
            self.currentEmail = user.email
        } else if let email, !email.isEmpty {
            self.currentEmail = email
        }
        persistSession()
        Task {
            await apiClient.setConfiguration(baseURLString: apiBaseURL, token: token)
            await refreshNotifications()
        }
        navigationPath.removeAll()
        selectedSection = .feed
        startNotificationPolling()
    }

    public func updateCurrentUser(_ user: SubUser, email: String? = nil) {
        self.currentUser = user
        if !user.email.isEmpty {
            self.currentEmail = user.email
        } else if let email, !email.isEmpty {
            self.currentEmail = email
        }
        persistSession()
    }

    public func updateAPIBaseURL(_ newURL: String) {
        let normalized = APIClient.normalizeBaseURL(newURL)
        self.apiBaseURL = normalized
        defaults.set(normalized, forKey: StorageKeys.apiBaseURL)
        Task {
            await apiClient.setConfiguration(baseURLString: normalized, token: token)
            if isAuthenticated {
                await refreshNotifications()
            }
            feedRefreshTrigger = UUID()
        }
    }

    public func updateNotificationPollingMinutes(_ minutes: Int) {
        let clamped = max(1, minutes)
        self.notificationPollingMinutes = clamped
        defaults.set(clamped, forKey: StorageKeys.notificationPollingMinutes)
        if isAuthenticated {
            startNotificationPolling()
        }
    }

    public func logout() {
        notificationTask?.cancel()
        notificationTask = nil
        token = nil
        currentUser = nil
        notifications = SubNotifications()
        persistSession()
        Task {
            await apiClient.setConfiguration(baseURLString: apiBaseURL, token: nil)
        }
        navigationPath.removeAll()
        selectedSection = .login
    }

    public func refreshNotifications() async {
        guard isAuthenticated else { return }
        do {
            let latest = try await apiClient.fetchNotifications()
            self.notifications = latest
        } catch APIError.unauthorized {
            logout()
        } catch {
            // Keep existing counts on transient network error
        }
    }

    public func clearNotificationCount(for section: SidebarSection) {
        switch section {
        case .followers:
            notifications.followers = 0
        case .mentions:
            notifications.mentions = 0
        case .replies:
            notifications.replies = 0
        case .messages:
            notifications.messages = 0
        default:
            break
        }
    }

    public var dockBadgeLabel: String? {
        let total = notifications.total
        return total > 0 ? "\(total)" : nil
    }

    public func updateDockBadge() {
        NSApplication.shared.dockTile.badgeLabel = dockBadgeLabel
    }

    public func badgeCount(for section: SidebarSection) -> Int {
        switch section {
        case .followers: return notifications.followers
        case .mentions: return notifications.mentions
        case .replies: return notifications.replies
        case .messages: return notifications.messages
        default: return 0
        }
    }

    private func startNotificationPolling() {
        notificationTask?.cancel()
        notificationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refreshNotifications()
                let intervalSeconds = max(1, self.notificationPollingMinutes) * 60
                try? await Task.sleep(for: .seconds(intervalSeconds))
            }
        }
    }

    private func persistSession() {
        if let token {
            defaults.set(token, forKey: StorageKeys.token)
        } else {
            defaults.removeObject(forKey: StorageKeys.token)
        }
        if let currentUser, let data = try? JSONEncoder().encode(currentUser) {
            defaults.set(data, forKey: StorageKeys.userJSON)
        } else {
            defaults.removeObject(forKey: StorageKeys.userJSON)
        }
        defaults.set(currentEmail, forKey: StorageKeys.email)
    }
}
