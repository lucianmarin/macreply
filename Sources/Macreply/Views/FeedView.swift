import SwiftUI

public struct FeedView: View {
    @EnvironmentObject private var appState: AppState
    public let section: SidebarSection

    @State private var entries: [SubEntry] = []
    @State private var loadedKey: String?
    @State private var hasLoadedOnce: Bool = false
    @State private var currentPage: Int = 1
    @State private var canLoadMore: Bool = false
    @State private var isLoading: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var loadMoreError: Bool = false
    @State private var errorMessage: String?
    @State private var searchQuery: String = ""

    private let pageSize = 16

    public init(section: SidebarSection) {
        self.section = section
    }

    private var activeQuery: String? {
        guard section == .discover else { return nil }
        return loadedKey == section.rawValue ? searchQuery : appState.discoverSearchQuery
    }

    private var cachedResponse: PaginatedEntriesResponse? {
        guard let apiPath = section.apiPath else { return nil }
        return appState.apiClient.cachedEntries(path: apiPath, page: 1, query: activeQuery)
    }

    private var displayedEntries: [SubEntry] {
        if loadedKey == section.rawValue {
            return entries
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
            await loadFeed(reset: true)
            await appState.refreshNotifications()
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                if section == .feed {
                    if appState.isAuthenticated {
                        ComposerView(
                            placeholder: "Start a thread",
                            focusTrigger: appState.feedRefreshTrigger
                        ) { content in
                            let created = try await appState.apiClient.createThread(content: content)
                            entries.insert(created, at: 0)
                        }
                    } else {
                        PlaceholderBannerView(
                            text: "your account to share",
                            actionLabel: "Login",
                            onAction: { appState.selectSection(.login) },
                            secondaryActionLabel: "register",
                            onSecondaryAction: { appState.selectSection(.register) }
                        )
                    }
                } else if section == .discover {
                    SearchQueryBar(
                        placeholder: "Search topics",
                        query: $searchQuery,
                        focusTrigger: appState.feedRefreshTrigger
                    ) {
                        appState.discoverSearchQuery = searchQuery
                        Task { await loadFeed(reset: true) }
                    }
                }

                let visibleEntries = displayedEntries
                let isWaitingForFirstLoad = (isLoading || loadedKey != section.rawValue || !hasLoadedOnce)

                if visibleEntries.isEmpty && isWaitingForFirstLoad && errorMessage == nil {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading...")
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 15)
                } else if let errorMessage, visibleEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.alert)
                        Button("Retry") {
                            Task { await loadFeed(reset: true) }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .buttonStyle(.subLink)
                        .foregroundStyle(SubTheme.accent)
                    }
                    .padding(.vertical, 10)
                } else if visibleEntries.isEmpty {
                    Text("Uh, nothing here yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .padding(.vertical, 10)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(visibleEntries.indices, id: \.self) { index in
                            let prevParentID: Int? = index > 0 ? visibleEntries[index - 1].parent?.id : nil
                            let entryBinding = Binding<SubEntry>(
                                get: {
                                    let current = displayedEntries
                                    return index < current.count ? current[index] : visibleEntries[index]
                                },
                                set: { updated in
                                    if loadedKey != section.rawValue {
                                        entries = visibleEntries
                                        loadedKey = section.rawValue
                                    }
                                    if index < entries.count {
                                        entries[index] = updated
                                    }
                                }
                            )
                            StreamEntryView(
                                entry: entryBinding,
                                previousParentID: prevParentID,
                                isFirstInList: index == 0
                            )
                        }

                        if displayedCanLoadMore && (activeQuery?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) {
                            Divider().overlay(SubTheme.whitesmoke)
                            HStack {
                                Spacer()
                                Button {
                                    Task { await loadFeed(reset: false) }
                                } label: {
                                    Text(loadMoreError ? "Retry" : "Load more")
                                        .font(.system(size: 14))
                                        .foregroundStyle(loadMoreError ? SubTheme.alert : SubTheme.gray)
                                }
                                .buttonStyle(.subLink)
                                .disabled(isLoadingMore)
                                Spacer()
                            }
                            .padding(.vertical, 7)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            .subFeedContainer()
        }
        .background(SubTheme.background)
        .task(id: "\(section.rawValue)-\(appState.feedRefreshTrigger.uuidString)") {
            if section == .discover {
                searchQuery = appState.discoverSearchQuery
            } else {
                searchQuery = ""
            }
            applyCachedFeedIfNeeded()
            await loadFeed(reset: true)
        }
    }

    private func applyCachedFeedIfNeeded() {
        guard let apiPath = section.apiPath else { return }
        let query = section == .discover ? searchQuery : nil
        if let cached = appState.apiClient.cachedEntries(path: apiPath, page: 1, query: query) {
            entries = cached.entries
            currentPage = cached.page
            canLoadMore = cached.entries.count == pageSize
            loadedKey = section.rawValue
            hasLoadedOnce = true
        } else if loadedKey != section.rawValue {
            entries = []
            currentPage = 1
            canLoadMore = false
            loadedKey = section.rawValue
            hasLoadedOnce = false
        }
    }

    private func loadFeed(reset: Bool) async {
        guard let apiPath = section.apiPath else { return }
        let query = section == .discover ? searchQuery : nil
        if reset {
            if let cached = appState.apiClient.cachedEntries(path: apiPath, page: 1, query: query) {
                if loadedKey != section.rawValue || entries.isEmpty {
                    entries = cached.entries
                    currentPage = cached.page
                    canLoadMore = cached.entries.count == pageSize
                    loadedKey = section.rawValue
                    hasLoadedOnce = true
                }
            } else {
                entries = []
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
            let response = try await appState.apiClient.fetchEntries(
                path: apiPath,
                page: targetPage,
                query: query
            )
            if reset {
                entries = response.entries
            } else {
                entries.append(contentsOf: response.entries)
            }
            loadedKey = section.rawValue
            hasLoadedOnce = true
            currentPage = response.page
            canLoadMore = response.entries.count == pageSize
            loadMoreError = false
            if section == .mentions || section == .replies {
                appState.clearNotificationCount(for: section)
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
