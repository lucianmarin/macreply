import SwiftUI

/// Mirrors `templates/common/messages.html` (`GET /api/messages`)
public struct MessagesInboxView: View {
    @EnvironmentObject private var appState: AppState

    @State private var chats: [SubChat] = []
    @State private var currentPage: Int = 1
    @State private var canLoadMore: Bool = false
    @State private var isLoading: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var loadMoreError: Bool = false
    @State private var errorMessage: String?

    private let pageSize = 16

    public init() {}

    public var body: some View {
        RefreshableScrollView {
            await loadInbox(reset: true)
            await appState.refreshNotifications()
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                if isLoading && chats.isEmpty {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading messages...")
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
                } else if let errorMessage, chats.isEmpty {
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
                } else if chats.isEmpty {
                    Text("Uh, nothing here yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .padding(.vertical, 12)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(chats.indices, id: \.self) { index in
                            if index > 0 {
                                Divider().overlay(SubTheme.whitesmoke)
                            }
                            MessageInboxRow(chat: chats[index])
                        }

                        if canLoadMore {
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
            await loadInbox(reset: true)
        }
    }

    private func loadInbox(reset: Bool) async {
        if reset {
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
            currentPage = response.page
            canLoadMore = response.entries.count == pageSize
            loadMoreError = false
        } catch {
            if reset {
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

    private var isBlockedWaitingForResponse: Bool {
        if let isBlockedFromServer {
            return isBlockedFromServer
        }
        guard let current = appState.currentUser?.username.lowercased(), !messages.isEmpty else {
            return false
        }
        let hasForward = messages.contains { $0.createdBy.username.lowercased() == current }
        let hasBackward = messages.contains { $0.createdBy.username.lowercased() == username.lowercased() }
        return hasForward && !hasBackward && current != username.lowercased()
    }

    public var body: some View {
        RefreshableScrollView {
            await loadConversation(reset: true)
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                if isBlockedWaitingForResponse {
                    PlaceholderBannerView(
                        text: "Please wait for @\(username) to respond"
                    )
                } else {
                    ComposerView(
                        placeholder: "Message @\(username)",
                        focusTrigger: appState.feedRefreshTrigger
                    ) { content in
                        let sent = try await appState.apiClient.sendMessage(
                            username: username,
                            content: content
                        )
                        messages.insert(sent, at: 0)
                        appState.hasMessages = true
                        if let current = appState.currentUser?.username.lowercased(),
                           current != username.lowercased() {
                            let hasBackward = messages.contains { $0.createdBy.username.lowercased() == username.lowercased() }
                            isBlockedFromServer = !hasBackward
                        }
                        isCleared = false
                        clearError = false
                    }
                }

                if isLoading && messages.isEmpty {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading conversation...")
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
                } else if let errorMessage, messages.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.alert)
                        .padding(.vertical, 12)
                } else if messages.isEmpty {
                    Text("Uh, nothing here yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .padding(.vertical, 12)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(messages.indices, id: \.self) { index in
                            if index > 0 {
                                Divider().overlay(SubTheme.whitesmoke)
                            }
                            ConversationMessageRow(chat: messages[index])
                        }

                        if canLoadMore {
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
        .task(id: "\(username.lowercased())-\(appState.feedRefreshTrigger.uuidString)") {
            await loadConversation(reset: true)
        }
    }

    private func loadConversation(reset: Bool) async {
        if reset {
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
