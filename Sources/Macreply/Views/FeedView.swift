import SwiftUI

public struct FeedView: View {
    @EnvironmentObject private var appState: AppState
    public let section: SidebarSection

    @State private var entries: [SubEntry] = []
    @State private var currentPage: Int = 1
    @State private var canLoadMore: Bool = false
    @State private var isLoading: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var errorMessage: String?
    @State private var searchQuery: String = ""

    private let pageSize = 16

    public init(section: SidebarSection) {
        self.section = section
    }

    public var body: some View {
        RefreshableScrollView {
            await loadFeed(reset: true)
            await appState.refreshNotifications()
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                if section == .feed {
                    if appState.isAuthenticated {
                        ComposerView(placeholder: "Share something...") { content in
                            let created = try await appState.apiClient.createThread(content: content)
                            entries.insert(created, at: 0)
                        }
                    } else {
                        PlaceholderBannerView(
                            text: "your account to share",
                            actionLabel: "Login"
                        ) {
                            appState.selectSection(.login)
                        }
                    }
                } else if section == .discover {
                    SearchQueryBar(
                        placeholder: "Search posts, #hashtags or @mentions...",
                        query: $searchQuery
                    ) {
                        appState.discoverSearchQuery = searchQuery
                        Task { await loadFeed(reset: true) }
                    }
                }

                if isLoading && entries.isEmpty {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading...")
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                    }
                    .padding(.vertical, 16)
                } else if let errorMessage, entries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
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
                    .padding(.vertical, 12)
                } else if entries.isEmpty {
                    Text("Uh, nothing here yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .padding(.vertical, 12)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(entries.indices, id: \.self) { index in
                            let prevParentID: Int? = index > 0 ? entries[index - 1].parent?.id : nil
                            StreamEntryView(
                                entry: $entries[index],
                                previousParentID: prevParentID,
                                isFirstInList: index == 0
                            )
                        }

                        if canLoadMore && searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                            Divider().overlay(SubTheme.whitesmoke)
                            HStack {
                                Spacer()
                                Button {
                                    Task { await loadFeed(reset: false) }
                                } label: {
                                    Text(isLoadingMore ? "Loading..." : "Load more")
                                        .font(.system(size: 14))
                                        .foregroundStyle(SubTheme.gray)
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
            .frame(maxWidth: SubTheme.contentWidth, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(SubTheme.background)
        .task(id: "\(section.rawValue)-\(appState.feedRefreshTrigger.uuidString)") {
            if section == .discover {
                searchQuery = appState.discoverSearchQuery
            }
            await loadFeed(reset: true)
        }
    }

    private func loadFeed(reset: Bool) async {
        guard let apiPath = section.apiPath else { return }
        if reset {
            isLoading = true
            errorMessage = nil
        } else {
            isLoadingMore = true
        }

        let targetPage = reset ? 1 : currentPage + 1
        let activeQuery = section == .discover ? searchQuery : nil

        do {
            let response = try await appState.apiClient.fetchEntries(
                path: apiPath,
                page: targetPage,
                query: activeQuery
            )
            if reset {
                entries = response.entries
            } else {
                entries.append(contentsOf: response.entries)
            }
            currentPage = response.page
            canLoadMore = response.entries.count == pageSize
            if section == .mentions || section == .replies {
                appState.clearNotificationCount(for: section)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
        isLoadingMore = false
    }
}
