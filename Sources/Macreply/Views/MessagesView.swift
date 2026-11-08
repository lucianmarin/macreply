import SwiftUI

/// Mirrors `templates/common/messages.html` (`GET /api/messages`)
public struct MessagesInboxView: View {
    @EnvironmentObject private var appState: AppState

    @State private var chats: [SubChat] = []
    @State private var hasLoadedOnce: Bool = false
    @State private var currentPage: Int = 1
    @State private var canLoadMore: Bool = false
    @State private var isLoading: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var loadMoreError: Bool = false
    @State private var errorMessage: String?

    private let pageSize = 16

    public init() {}

    private var cachedResponse: PaginatedChatsResponse? {
        appState.apiClient.cachedMessages(page: 1)
    }

    private var displayedChats: [SubChat] {
        if hasLoadedOnce {
            return chats
        }
        return cachedResponse?.entries ?? []
    }

    private var displayedCanLoadMore: Bool {
        if hasLoadedOnce {
            return canLoadMore
        }
        return (cachedResponse?.entries.count ?? 0) == pageSize
    }

    public var body: some View {
        RefreshableScrollView {
            await loadInbox(reset: true)
            await appState.refreshNotifications()
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                let visibleChats = displayedChats
                let isWaitingForFirstLoad = (isLoading || (!hasLoadedOnce && cachedResponse == nil))

                if visibleChats.isEmpty && isWaitingForFirstLoad && errorMessage == nil {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading messages...")
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
                } else if let errorMessage, visibleChats.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.alert)
                        Button("Retry") {
                            Task { await loadInbox(reset: true) }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .buttonStyle(.subLink)
                        .foregroundStyle(SubTheme.accent)
                    }
                    .padding(.vertical, 12)
                } else if visibleChats.isEmpty {
                    Text("Uh, nothing here yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .padding(.vertical, 12)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(visibleChats.indices, id: \.self) { index in
                            if index > 0 {
                                Divider().overlay(SubTheme.whitesmoke)
                            }
                            MessageInboxRow(chat: visibleChats[index])
                        }

                        if displayedCanLoadMore {
                            Divider().overlay(SubTheme.whitesmoke)
                            HStack {
                                Spacer()
                                Button {
                                    Task { await loadInbox(reset: false) }
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
        .task(id: appState.feedRefreshTrigger) {
            if !hasLoadedOnce, let cached = cachedResponse {
                chats = cached.entries
                currentPage = cached.page
                canLoadMore = cached.entries.count == pageSize
                hasLoadedOnce = true
            }
            await loadInbox(reset: true)
        }
    }

    private func loadInbox(reset: Bool) async {
        if reset {
            if !hasLoadedOnce, let cached = cachedResponse {
                chats = cached.entries
                currentPage = cached.page
                canLoadMore = cached.entries.count == pageSize
                hasLoadedOnce = true
            }
            isLoading = true
            errorMessage = nil
            loadMoreError = false
        } else {
            isLoadingMore = true
        }
        let targetPage = reset ? 1 : currentPage + 1
        do {
            let response = try await appState.apiClient.fetchMessages(page: targetPage)
            if reset {
                chats = response.entries
            } else {
                chats.append(contentsOf: response.entries)
            }
            hasLoadedOnce = true
            currentPage = response.page
            canLoadMore = response.entries.count == pageSize
            loadMoreError = false
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

private struct MessageInboxRow: View {
    @EnvironmentObject private var appState: AppState
    let chat: SubChat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RichContentView(author: chat.createdBy, content: chat.content)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Button("message") {
                    appState.openConversation(chat.createdBy.username)
                }
                .font(.system(size: 13))
                .foregroundStyle(SubTheme.gray)
                .buttonStyle(.subLink)

                Text(chat.seen ? "read" : "unread")
                    .font(.system(size: 13))
                    .foregroundStyle(chat.seen ? SubTheme.silver : SubTheme.accent)

                Spacer(minLength: 0)

                Button {
                    appState.openConversation(chat.createdBy.username)
                } label: {
                    Text(chat.timestamp)
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.silver)
                }
                .buttonStyle(.subLink)
            }
        }
        .padding(.vertical, 6)
    }
}

/// Mirrors `templates/common/message.html` and `templates/input/message.html` (`GET /api/{username}/message`)
public struct ConversationView: View {
    @EnvironmentObject private var appState: AppState
    public let username: String

    @State private var messages: [SubChat] = []
    @State private var loadedUsername: String?
    @State private var hasLoadedOnce: Bool = false
    @State private var isBlockedFromServer: Bool?
    @State private var currentPage: Int = 1
    @State private var canLoadMore: Bool = false
    @State private var isLoading: Bool = true
    @State private var isLoadingMore: Bool = false
    @State private var loadMoreError: Bool = false
    @State private var errorMessage: String?
    @State private var isConfirmingClear = false
    @State private var isClearing = false
    @State private var isCleared = false
    @State private var clearError = false

    private let pageSize = 16

    public init(username: String) {
        self.username = username
    }

    private var cleanUsername: String {
        username.lowercased()
    }

    private var cachedResponse: PaginatedChatsResponse? {
        appState.apiClient.cachedConversation(username: cleanUsername, page: 1)
    }

    private var displayedMessages: [SubChat] {
        if loadedUsername == cleanUsername && hasLoadedOnce {
            return messages
        }
        return cachedResponse?.entries ?? []
    }

    private var displayedCanLoadMore: Bool {
        if loadedUsername == cleanUsername && hasLoadedOnce {
            return canLoadMore
        }
        return (cachedResponse?.entries.count ?? 0) == pageSize
    }

    private var isBlockedWaitingForResponse: Bool {
        if loadedUsername == cleanUsername, let isBlockedFromServer {
            return isBlockedFromServer
        }
        if let blocked = cachedResponse?.blocked {
            return blocked
        }
        let visibleMessages = displayedMessages
        guard let current = appState.currentUser?.username.lowercased(), !visibleMessages.isEmpty else {
            return false
        }
        let hasForward = visibleMessages.contains { $0.createdBy.username.lowercased() == current }
        let hasBackward = visibleMessages.contains { $0.createdBy.username.lowercased() == cleanUsername }
        return hasForward && !hasBackward && current != cleanUsername
    }

    private var isSelfConversation: Bool {
        guard let current = appState.currentUser?.username.lowercased() else { return false }
        return current == cleanUsername
    }

    public var messagePlaceholder: String {
        isSelfConversation ? "Message yourself" : "Message @\(username)"
    }

    public var body: some View {
        RefreshableScrollView {
            await loadConversation(reset: true)
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                let visibleMessages = displayedMessages
                let isWaitingForFirstLoad = (isLoading && (loadedUsername != cleanUsername || !hasLoadedOnce) && cachedResponse == nil)

                if isBlockedWaitingForResponse {
                    PlaceholderBannerView(
                        text: "Please wait for @\(username) to respond"
                    )
                } else {
                    ComposerView(
                        placeholder: messagePlaceholder,
                        focusTrigger: appState.feedRefreshTrigger
                    ) { content in
                        let sent = try await appState.apiClient.sendMessage(
                            username: username,
                            content: content
                        )
                        if loadedUsername != cleanUsername || !hasLoadedOnce {
                            messages = visibleMessages
                            loadedUsername = cleanUsername
                            hasLoadedOnce = true
                        }
                        messages.insert(sent, at: 0)
                        appState.hasMessages = true
                        if let current = appState.currentUser?.username.lowercased(),
                           current != cleanUsername {
                            let hasBackward = messages.contains { $0.createdBy.username.lowercased() == cleanUsername }
                            isBlockedFromServer = !hasBackward
                        }
                        isCleared = false
                        clearError = false
                    }
                }

                if visibleMessages.isEmpty && isWaitingForFirstLoad && errorMessage == nil {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading conversation...")
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
                } else if let errorMessage, visibleMessages.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.alert)
                        .padding(.vertical, 12)
                } else if visibleMessages.isEmpty {
                    Text("Uh, nothing here yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .padding(.vertical, 12)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(visibleMessages.indices, id: \.self) { index in
                            if index > 0 {
                                Divider().overlay(SubTheme.whitesmoke)
                            }
                            ConversationMessageRow(chat: visibleMessages[index])
                        }

                        if displayedCanLoadMore {
                            Divider().overlay(SubTheme.whitesmoke)
                            HStack {
                                Spacer()
                                Button {
                                    Task { await loadConversation(reset: false) }
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
                        } else if !isBlockedWaitingForResponse {
                            Divider().overlay(SubTheme.whitesmoke)
                            HStack(spacing: 0) {
                                Spacer()
                                if isCleared {
                                    Text("Cleared")
                                        .font(.system(size: 14))
                                        .foregroundStyle(SubTheme.gray)
                                } else if isConfirmingClear {
                                    Button("Undo") {
                                        isConfirmingClear = false
                                        clearError = false
                                    }
                                    .font(.system(size: 14))
                                    .foregroundStyle(SubTheme.accent)
                                    .buttonStyle(.subLink)
                                    .disabled(isClearing)

                                    Text(" — ")
                                        .font(.system(size: 14))
                                        .foregroundStyle(SubTheme.silver)

                                    Button(clearError ? "Retry" : "Yes") {
                                        Task { await performClear() }
                                    }
                                    .font(.system(size: 14))
                                    .foregroundStyle(SubTheme.alert)
                                    .buttonStyle(.subLink)
                                    .disabled(isClearing)
                                } else {
                                    Button("Clear out") {
                                        isConfirmingClear = true
                                    }
                                    .font(.system(size: 14))
                                    .foregroundStyle(SubTheme.gray)
                                    .buttonStyle(.subLink)
                                }
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
        .task(id: "\(cleanUsername)-\(appState.feedRefreshTrigger.uuidString)") {
            applyCachedConversationIfNeeded()
            await loadConversation(reset: true)
        }
    }

    private func applyCachedConversationIfNeeded() {
        if loadedUsername != cleanUsername {
            loadedUsername = cleanUsername
            if let cached = cachedResponse {
                messages = cached.entries
                isBlockedFromServer = cached.blocked
                currentPage = cached.page
                canLoadMore = cached.entries.count == pageSize
                hasLoadedOnce = true
                appState.hasMessages = !cached.entries.isEmpty
            } else {
                messages = []
                isBlockedFromServer = nil
                currentPage = 1
                canLoadMore = false
                hasLoadedOnce = false
            }
        }
    }

    private func loadConversation(reset: Bool) async {
        if reset {
            if loadedUsername != cleanUsername || !hasLoadedOnce {
                applyCachedConversationIfNeeded()
            }
            isLoading = true
            errorMessage = nil
            loadMoreError = false
            isConfirmingClear = false
            isClearing = false
            isCleared = false
            clearError = false
        } else {
            isLoadingMore = true
        }
        let targetPage = reset ? 1 : currentPage + 1
        do {
            let response = try await appState.apiClient.fetchConversation(
                username: username,
                page: targetPage
            )
            if reset {
                messages = response.entries
            } else {
                messages.append(contentsOf: response.entries)
            }
            loadedUsername = cleanUsername
            hasLoadedOnce = true
            appState.hasMessages = !messages.isEmpty
            if let blocked = response.blocked {
                isBlockedFromServer = blocked
            }
            currentPage = response.page
            canLoadMore = response.entries.count == pageSize
            loadMoreError = false
            await appState.refreshNotifications()
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

    private func performClear() async {
        guard !isClearing else { return }
        isClearing = true
        do {
            let ok = try await appState.apiClient.clearConversation(username: username)
            if ok {
                isCleared = true
                isConfirmingClear = false
                clearError = false
            } else {
                clearError = true
            }
        } catch {
            clearError = true
        }
        isClearing = false
    }
}

private struct ConversationMessageRow: View {
    @EnvironmentObject private var appState: AppState
    let chat: SubChat

    @State private var isConfirmingUnsend = false
    @State private var isUnsending = false
    @State private var isUnsent = false
    @State private var unsendError = false

    private var isOutgoing: Bool {
        guard let current = appState.currentUser?.username.lowercased() else { return false }
        return chat.createdBy.username.lowercased() == current
    }

    private var isIncomingFromPartner: Bool {
        guard let current = appState.currentUser?.username.lowercased() else { return false }
        return chat.toUser.username.lowercased() == current && chat.createdBy.username.lowercased() != current
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RichContentView(author: chat.createdBy, content: chat.content)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isOutgoing {
                HStack(spacing: 10) {
                    Text(chat.seen ? "read" : "unread")
                        .font(.system(size: 13))
                        .foregroundStyle(chat.seen ? SubTheme.silver : SubTheme.accent)

                    if isUnsent {
                        Text("unsent")
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.silver)
                    } else if isConfirmingUnsend {
                        Button("undo") {
                            isConfirmingUnsend = false
                            unsendError = false
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.accent)
                        .buttonStyle(.subLink)
                        .disabled(isUnsending)

                        Button(unsendError ? "retry" : "yes") {
                            performUnsend()
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.alert)
                        .buttonStyle(.subLink)
                        .disabled(isUnsending)
                    } else {
                        Button("unsend") {
                            isConfirmingUnsend = true
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.gray)
                        .buttonStyle(.subLink)
                    }

                    Spacer(minLength: 0)

                    Text(chat.timestamp)
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.silver)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.leading, isIncomingFromPartner ? SubTheme.indent : 0)
    }

    private func performUnsend() {
        guard !isUnsending else { return }
        let chatID = chat.id
        isUnsending = true
        Task {
            do {
                let ok = try await appState.apiClient.unsendMessage(id: chatID)
                if ok {
                    isUnsent = true
                    isConfirmingUnsend = false
                    unsendError = false
                } else {
                    unsendError = true
                }
            } catch {
                unsendError = true
            }
            isUnsending = false
        }
    }
}
