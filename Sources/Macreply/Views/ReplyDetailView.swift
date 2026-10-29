import SwiftUI

/// Mirrors `templates/pages/reply.html` and `templates/common/threads.html`
public struct ReplyDetailView: View {
    @EnvironmentObject private var appState: AppState
    public let replyID: Int

    @State private var ancestors: [SubEntry] = []
    @State private var mainEntry: SubEntry?
    @State private var kids: [SubEntry] = []
    @State private var duplicateFromServer: Bool?
    @State private var isLoading = true
    @State private var errorMessage: String?

    public init(replyID: Int) {
        self.replyID = replyID
    }

    private var isOwnEntry: Bool {
        guard let current = appState.currentUser?.username.lowercased(),
              let author = mainEntry?.createdBy.username.lowercased() else {
            return false
        }
        return current == author
    }

    private var hasDuplicateReply: Bool {
        if let duplicateFromServer {
            return duplicateFromServer
        }
        guard let current = appState.currentUser?.username.lowercased() else { return false }
        return kids.contains { $0.createdBy.username.lowercased() == current }
    }

    public var body: some View {
        RefreshableScrollView {
            await loadThread()
            await appState.refreshNotifications()
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                if isLoading && mainEntry == nil {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading thread...")
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
                } else if let errorMessage, mainEntry == nil {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.alert)
                        .padding(.vertical, 12)
                } else if var entry = mainEntry {
                    // Ancestors chain + Focus Entry
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(ancestors.indices, id: \.self) { index in
                            if index > 0 {
                                Divider().overlay(SubTheme.whitesmoke)
                            }
                            EntryItemView(
                                entry: $ancestors[index],
                                isSummary: false,
                                isRootOverride: index == 0
                            )
                        }

                        if !ancestors.isEmpty {
                            Divider().overlay(SubTheme.whitesmoke)
                        }

                        let entryBinding = Binding<SubEntry>(
                            get: { mainEntry ?? entry },
                            set: { updated in
                                mainEntry = updated
                                entry = updated
                            }
                        )

                        EntryItemView(
                            entry: entryBinding,
                            isSummary: ancestors.isEmpty,
                            isRootOverride: ancestors.isEmpty,
                            canDeleteAsRecipient: ancestors.last.map {
                                $0.createdBy.username.lowercased() == appState.currentUser?.username.lowercased()
                            } ?? false
                        )
                    }
                    .padding(.vertical, 6)

                    // Reply Input (`templates/input/reply.html`)
                    replyComposerSection(for: entry)

                    // Descendant Threads (`templates/common/threads.html`)
                    if !kids.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(kids.indices, id: \.self) { index in
                                if index > 0 {
                                    Divider().overlay(SubTheme.whitesmoke)
                                }
                                ThreadNodeView(
                                    entry: $kids[index],
                                    parentAuthorUsername: entry.createdBy.username
                                )
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .subFeedContainer()
        }
        .background(SubTheme.background)
        .task(id: "\(replyID)-\(appState.feedRefreshTrigger.uuidString)") {
            await loadThread()
        }
    }

    @ViewBuilder
    private func replyComposerSection(for entry: SubEntry) -> some View {
        if !appState.isAuthenticated {
            PlaceholderBannerView(
                text: "your account to reply",
                actionLabel: "Login",
                onAction: { appState.selectSection(.login) },
                secondaryActionLabel: "register",
                onSecondaryAction: { appState.selectSection(.register) }
            )
        } else if isOwnEntry {
            PlaceholderBannerView(
                text: entry.replyCount == 0 && kids.isEmpty ? "No reply yet" : "Reply back to them"
            )
        } else if hasDuplicateReply {
            PlaceholderBannerView(
                text: "Share reply #\(entry.id) anywhere"
            )
        } else {
            ComposerView(
                placeholder: "Reply to @\(entry.createdBy.username)",
                focusTrigger: appState.feedRefreshTrigger
            ) { content in
                let created = try await appState.apiClient.createReply(
                    parentID: entry.id,
                    content: content
                )
                kids.insert(created, at: 0)
                duplicateFromServer = true
                if var currentMain = mainEntry {
                    var currentKids = currentMain.kids ?? []
                    currentKids.insert(created, at: 0)
                    currentMain.kids = currentKids
                    currentMain.replies = max((currentMain.replies ?? 0) + 1, currentKids.count)
                    mainEntry = currentMain
                }
            }
        }
    }

    private func loadThread() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await appState.apiClient.fetchReplyDetail(id: replyID)
            ancestors = response.ancestors
            duplicateFromServer = response.duplicate
            var hydratedEntry = response.entry
            if hydratedEntry.kids == nil {
                hydratedEntry.kids = response.kids
            }
            mainEntry = hydratedEntry
            kids = response.kids
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct ThreadNodeView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var entry: SubEntry
    let parentAuthorUsername: String

    private var canDeleteAsParentAuthor: Bool {
        guard let current = appState.currentUser?.username.lowercased() else { return false }
        return current == parentAuthorUsername.lowercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EntryItemView(
                entry: $entry,
                isRootOverride: false,
                canDeleteAsRecipient: canDeleteAsParentAuthor
            )

            if let nestedKids = entry.kids, !nestedKids.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(nestedKids.indices, id: \.self) { index in
                        Divider().overlay(SubTheme.whitesmoke)
                        KidEntryBindingRow(
                            parentEntry: $entry,
                            kidID: nestedKids[index].id,
                            canDeleteAsRecipient: true
                        )
                    }
                }
                .padding(.leading, SubTheme.indent)
            }
        }
    }
}

/// Mirrors `templates/pages/edit.html` (`PATCH /api/edit/{id}`)
public struct EditEntryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var entry: SubEntry

    public init(entry: SubEntry) {
        self._entry = State(initialValue: entry)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if var parent = entry.parent {
                    EntryItemView(
                        entry: Binding(
                            get: { entry.parent ?? parent },
                            set: { updated in
                                parent = updated
                                entry.parent = updated
                            }
                        ),
                        isRootOverride: parent.parent == nil
                    )
                    Divider().overlay(SubTheme.whitesmoke)
                }

                EntryItemView(
                    entry: $entry,
                    isRootOverride: entry.parent == nil
                )

                ComposerView(
                    placeholder: "Edit content",
                    initialText: entry.content
                ) { updatedContent in
                    let updated = try await appState.apiClient.editEntry(
                        id: entry.id,
                        content: updatedContent
                    )
                    entry = updated
                    appState.feedRefreshTrigger = UUID()
                    dismiss()
                }
            }
            .subFeedContainer()
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(SubTheme.background)
    }
}
