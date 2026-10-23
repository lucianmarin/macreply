import SwiftUI

/// Mirrors `templates/common/user.html`
public struct UserRowView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    public let member: SubUser
    public var isMemberHeader: Bool = false

    @State private var isFollowingState: Bool = false

    public init(member: SubUser, isMemberHeader: Bool = false) {
        self.member = member
        self.isMemberHeader = isMemberHeader
    }

    private var isSelf: Bool {
        guard let current = appState.currentUser?.username.lowercased() else { return false }
        return current == member.username.lowercased()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    appState.openMember(member.username)
                } label: {
                    Text(member.fullName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.subLink)

                Button {
                    appState.openMember(member.username)
                } label: {
                    Text("@\(member.username)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(SubTheme.gray)
                }
                .buttonStyle(.subLink)

                if appState.isAuthenticated {
                    Text("•")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(SubTheme.gray)

                    if isSelf {
                        Button("logout") {
                            appState.logout()
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(SubTheme.gray)
                        .buttonStyle(.subLink)
                    } else {
                        Button(isFollowingState ? "unfollow" : "follow") {
                            toggleFollow()
                        }
                        .font(.system(size: 14, weight: isFollowingState ? .regular : .medium))
                        .foregroundStyle(isFollowingState ? SubTheme.gray : SubTheme.accent)
                        .buttonStyle(.subLink)
                    }
                }

                Spacer(minLength: 0)

                if isMemberHeader {
                    if appState.isAuthenticated && !isSelf {
                        Button {
                            appState.openConversation(member.username)
                        } label: {
                            Text("MESSAGE")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(SubTheme.silver)
                        }
                        .buttonStyle(.subLink)
                    }
                } else if member.createdAt > 0 {
                    Button {
                        appState.openMember(member.username)
                    } label: {
                        Text(ContentParser.timeAgo(since: member.createdAt))
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.silver)
                    }
                    .buttonStyle(.subLink)
                }
            }

            if !member.description.isEmpty {
                RichContentView(content: member.description)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !member.link.isEmpty || !member.birthday.isEmpty || !member.location.isEmpty {
                HStack(spacing: 5) {
                    if !member.link.isEmpty, let url = URL(string: member.link) {
                        Button {
                            openURL(url)
                        } label: {
                            Text(ContentParser.hostname(from: member.link))
                                .font(.system(size: 13))
                                .foregroundStyle(SubTheme.gray)
                        }
                        .buttonStyle(.subLink)
                    }

                    if let age = ContentParser.age(from: member.birthday) {
                        Text("~ \(age)y old")
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                    }

                    if !member.cityLabel.isEmpty {
                        HStack(spacing: 3) {
                            Text("from")
                                .font(.system(size: 13))
                                .foregroundStyle(SubTheme.gray)
                            Button {
                                appState.openLocationSearch(member.cityLabel)
                            } label: {
                                Text(member.cityLabel)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(SubTheme.gray)
                            }
                            .buttonStyle(.subLink)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            isFollowingState = appState.isFollowing(member.username)
        }
        .onChange(of: appState.followedUsernames) { _, _ in
            isFollowingState = appState.isFollowing(member.username)
        }
    }

    private func toggleFollow() {
        let target = !isFollowingState
        isFollowingState = target
        appState.markFollowing(member.username, following: target)
        Task {
            do {
                let confirmed = try await appState.apiClient.setFollowing(
                    username: member.username,
                    follow: target
                )
                isFollowingState = confirmed
                appState.markFollowing(member.username, following: confirmed)
            } catch {
                isFollowingState = !target
                appState.markFollowing(member.username, following: !target)
            }
        }
    }
}

/// Mirrors `templates/pages/regular.html` (`view == 'member'`) and `templates/common/status.html`
public struct MemberView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    public let username: String

    @State private var member: SubUser?
    @State private var entries: [SubEntry] = []
    @State private var currentPage: Int = 1
    @State private var canLoadMore: Bool = false
    @State private var isLoading: Bool = true
    @State private var isLoadingMore: Bool = false
    @State private var errorMessage: String?

    private let pageSize = 16

    public init(username: String) {
        self.username = username
    }

    public var body: some View {
        RefreshableScrollView {
            await loadMember(reset: true)
            await appState.refreshNotifications()
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                if isLoading && member == nil {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading @\(username)...")
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                    }
                    .padding(.vertical, 16)
                } else if let errorMessage, member == nil {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.alert)
                        .padding(.vertical, 12)
                } else if let member {
                    UserRowView(member: member, isMemberHeader: true)

                    let links = member.allLinks
                    if !links.isEmpty {
                        Divider().overlay(SubTheme.whitesmoke)
                        memberLinksRow(links: links)
                    }

                    if member.createdAt > 0 {
                        Divider().overlay(SubTheme.whitesmoke)
                        Text("Joined \(ContentParser.timeAgo(since: member.createdAt)) ago.")
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                            .padding(.vertical, 6)
                    }

                    if entries.isEmpty && !isLoading {
                        Divider().overlay(SubTheme.whitesmoke)
                        Text("Uh, nothing here yet.")
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .padding(.vertical, 10)
                    } else {
                        ForEach(entries.indices, id: \.self) { index in
                            let prevParentID: Int? = index > 0 ? entries[index - 1].parent?.id : nil
                            StreamEntryView(
                                entry: $entries[index],
                                previousParentID: prevParentID,
                                isFirstInList: false
                            )
                        }

                        if canLoadMore {
                            Divider().overlay(SubTheme.whitesmoke)
                            HStack {
                                Spacer()
                                Button {
                                    Task { await loadMember(reset: false) }
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
                }
            }
            .subFeedContainer()
        }
        .background(SubTheme.background)
        .task(id: "\(username.lowercased())-\(appState.feedRefreshTrigger.uuidString)") {
            await loadMember(reset: true)
        }
    }

    private func memberLinksRow(links: [(name: String, url: URL)]) -> some View {
        HStack(spacing: 0) {
            Text("Also on ")
                .font(.system(size: 13))
                .foregroundStyle(SubTheme.gray)

            ForEach(links.indices, id: \.self) { idx in
                if idx > 0 {
                    Text(idx == links.count - 1 ? " and " : ", ")
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.gray)
                }
                Button {
                    openURL(links[idx].url)
                } label: {
                    Text(links[idx].name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SubTheme.gray)
                }
                .buttonStyle(.subLink)
            }

            Text(".")
                .font(.system(size: 13))
                .foregroundStyle(SubTheme.gray)
        }
        .padding(.vertical, 6)
    }

    private func loadMember(reset: Bool) async {
        guard !username.isEmpty else { return }
        if reset {
            isLoading = true
            errorMessage = nil
        } else {
            isLoadingMore = true
        }

        let targetPage = reset ? 1 : currentPage + 1
        do {
            let response = try await appState.apiClient.fetchMember(
                username: username,
                page: targetPage
            )
            member = response.member
            if reset {
                entries = response.entries
            } else {
                entries.append(contentsOf: response.entries)
            }
            currentPage = response.page
            canLoadMore = response.entries.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        isLoadingMore = false
    }
}
