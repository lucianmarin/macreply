import SwiftUI

/// Handles `/people`, `/following`, and `/followers` native feeds
public struct PeopleListView: View {
    @EnvironmentObject private var appState: AppState
    public let section: SidebarSection

    @State private var users: [SubUser] = []
    @State private var loadedKey: String?
    @State private var hasLoadedOnce: Bool = false
    @State private var currentPage: Int = 1
    @State private var canLoadMore: Bool = false
    @State private var isLoading: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var loadMoreError: Bool = false
    @State private var errorMessage: String?
    @State private var searchQuery: String = ""

    private let pageSize = 24

    public init(section: SidebarSection) {
        self.section = section
    }

    private var activeQuery: String? {
        guard section == .people else { return nil }
        return loadedKey == section.rawValue ? searchQuery : appState.peopleSearchQuery
    }

    private var cachedResponse: PaginatedUsersResponse? {
        guard let apiPath = section.apiPath else { return nil }
        return appState.apiClient.cachedUsers(path: apiPath, page: 1, query: activeQuery)
    }

    private var displayedUsers: [SubUser] {
        if loadedKey == section.rawValue {
            return users
        }
        return cachedResponse?.entries ?? []
    }

    private var displayedCanLoadMore: Bool {
        if loadedKey == section.rawValue {
            return canLoadMore
        }
        return (cachedResponse?.entries.count ?? 0) == pageSize
    }

    public var body: some View {
        RefreshableScrollView {
            await loadUsers(reset: true)
            await appState.refreshNotifications()
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                if section == .people {
                    SearchQueryBar(
                        placeholder: "Find people",
                        query: $searchQuery,
                        focusTrigger: appState.feedRefreshTrigger
                    ) {
                        appState.peopleSearchQuery = searchQuery
                        Task { await loadUsers(reset: true) }
                    }
                }

                let visibleUsers = displayedUsers
                let isWaitingForFirstLoad = (isLoading || loadedKey != section.rawValue || !hasLoadedOnce)

                if visibleUsers.isEmpty && isWaitingForFirstLoad && errorMessage == nil {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading...")
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
                } else if let errorMessage, visibleUsers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.alert)
                        Button("Retry") {
                            Task { await loadUsers(reset: true) }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .buttonStyle(.subLink)
                        .foregroundStyle(SubTheme.accent)
                    }
                    .padding(.vertical, 12)
                } else if visibleUsers.isEmpty {
                    Text("Uh, nothing here yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .padding(.vertical, 12)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(visibleUsers.indices, id: \.self) { index in
                            if index > 0 {
                                Divider().overlay(SubTheme.whitesmoke)
                            }
                            let userBinding = Binding<SubUser>(
                                get: {
                                    let current = displayedUsers
                                    return index < current.count ? current[index] : visibleUsers[index]
                                },
                                set: { updated in
                                    if loadedKey != section.rawValue {
                                        users = visibleUsers
                                        loadedKey = section.rawValue
                                    }
                                    if index < users.count {
                                        users[index] = updated
                                    }
                                }
                            )
                            UserRowView(member: userBinding)
                        }

                        if displayedCanLoadMore && (activeQuery?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) {
                            Divider().overlay(SubTheme.whitesmoke)
                            HStack {
                                Spacer()
                                Button {
                                    Task { await loadUsers(reset: false) }
                                } label: {
                                    Text(loadMoreError ? "Retry" : "Load more")
                                        .font(.system(size: 14))
                                        .foregroundStyle(loadMoreError ? SubTheme.alert : SubTheme.gray)
                                }
                                .buttonStyle(.subLink)
                                .disabled(isLoadingMore)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .subFeedContainer()
        }
        .background(SubTheme.background)
        .task(id: "\(section.rawValue)-\(appState.feedRefreshTrigger.uuidString)") {
            if section == .people {
                searchQuery = appState.peopleSearchQuery
            } else {
                searchQuery = ""
            }
            applyCachedUsersIfNeeded()
            await loadUsers(reset: true)
        }
    }

    private func applyCachedUsersIfNeeded() {
        guard let apiPath = section.apiPath else { return }
        let query = section == .people ? searchQuery : nil
        if let cached = appState.apiClient.cachedUsers(path: apiPath, page: 1, query: query) {
            users = cached.entries
            currentPage = cached.page
            canLoadMore = cached.entries.count == pageSize
            loadedKey = section.rawValue
            hasLoadedOnce = true
        } else if loadedKey != section.rawValue {
            users = []
            currentPage = 1
            canLoadMore = false
            loadedKey = section.rawValue
            hasLoadedOnce = false
        }
    }

    private func loadUsers(reset: Bool) async {
        guard let apiPath = section.apiPath else { return }
        let query = section == .people ? searchQuery : nil
        if reset {
            if let cached = appState.apiClient.cachedUsers(path: apiPath, page: 1, query: query) {
                if loadedKey != section.rawValue || users.isEmpty {
                    users = cached.entries
                    currentPage = cached.page
                    canLoadMore = cached.entries.count == pageSize
                    loadedKey = section.rawValue
                    hasLoadedOnce = true
                }
            } else {
                users = []
                currentPage = 1
                canLoadMore = false
                loadedKey = section.rawValue
                hasLoadedOnce = false
            }
            isLoading = true
            errorMessage = nil
            loadMoreError = false
        } else {
            isLoadingMore = true
        }

        let targetPage = reset ? 1 : currentPage + 1

        do {
            let response = try await appState.apiClient.fetchUsers(
                path: apiPath,
                page: targetPage,
                query: query
            )
            if reset {
                users = response.entries
            } else {
                users.append(contentsOf: response.entries)
            }
            loadedKey = section.rawValue
            hasLoadedOnce = true
            currentPage = response.page
            canLoadMore = response.entries.count == pageSize
            loadMoreError = false

            if section == .followers {
                appState.clearNotificationCount(for: .followers)
                await appState.refreshNotifications()
            }
        } catch {
            if reset {
                hasLoadedOnce = true
                errorMessage = error.localizedDescription
            } else {
                loadMoreError = true
            }
        }

        isLoading = false
        isLoadingMore = false
    }
}
