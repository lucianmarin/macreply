import SwiftUI

/// Handles `/people`, `/following`, and `/followers` native feeds
public struct PeopleListView: View {
    @EnvironmentObject private var appState: AppState
    public let section: SidebarSection

    @State private var users: [SubUser] = []
    @State private var currentPage: Int = 1
    @State private var canLoadMore: Bool = false
    @State private var isLoading: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var errorMessage: String?
    @State private var searchQuery: String = ""

    private let pageSize = 24

    public init(section: SidebarSection) {
        self.section = section
    }

    public var body: some View {
        RefreshableScrollView {
            await loadUsers(reset: true)
            await appState.refreshNotifications()
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                if section == .people {
                    SearchQueryBar(
                        placeholder: "Find people by name, @username, city or bio...",
                        query: $searchQuery
                    ) {
                        appState.peopleSearchQuery = searchQuery
                        Task { await loadUsers(reset: true) }
                    }
                }

                if isLoading && users.isEmpty {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading...")
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                    }
                    .padding(.vertical, 16)
                } else if let errorMessage, users.isEmpty {
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
                } else if users.isEmpty {
                    Text("Uh, nothing here yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .padding(.vertical, 12)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(users.indices, id: \.self) { index in
                            if index > 0 {
                                Divider().overlay(SubTheme.whitesmoke)
                            }
                            UserRowView(member: users[index])
                        }

                        if canLoadMore && searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                            Divider().overlay(SubTheme.whitesmoke)
                            HStack {
                                Spacer()
                                Button {
                                    Task { await loadUsers(reset: false) }
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
            if section == .people {
                searchQuery = appState.peopleSearchQuery
            }
            await loadUsers(reset: true)
        }
    }

    private func loadUsers(reset: Bool) async {
        guard let apiPath = section.apiPath else { return }
        if reset {
            isLoading = true
            errorMessage = nil
        } else {
            isLoadingMore = true
        }

        let targetPage = reset ? 1 : currentPage + 1
        let activeQuery = section == .people ? searchQuery : nil

        do {
            let response = try await appState.apiClient.fetchUsers(
                path: apiPath,
                page: targetPage,
                query: activeQuery
            )
            if reset {
                users = response.entries
            } else {
                users.append(contentsOf: response.entries)
            }
            currentPage = response.page
            canLoadMore = response.entries.count == pageSize

            if section == .following {
                for user in response.entries {
                    appState.markFollowing(user.username, following: true)
                }
            } else if section == .followers {
                appState.clearNotificationCount(for: .followers)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
        isLoadingMore = false
    }
}
