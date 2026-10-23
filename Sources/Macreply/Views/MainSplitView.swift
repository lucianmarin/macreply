import SwiftUI

public struct MainSplitView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 155, ideal: 175, max: 210)
        } detail: {
            NavigationStack(path: $appState.navigationPath) {
                rootSectionView(for: appState.selectedSection)
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        switch destination {
                        case .reply(let id):
                            ReplyDetailView(replyID: id)
                        case .member(let username):
                            MemberView(username: username)
                        case .conversation(let username):
                            ConversationView(username: username)
                        case .editEntry(let entry):
                            EditEntryView(entry: entry)
                        }
                    }
            }
        }
        .background(SubTheme.background)
    }

    @ViewBuilder
    private func rootSectionView(for section: SidebarSection) -> some View {
        switch section {
        case .feed, .mentions, .replies, .saved, .trending, .discover:
            FeedView(section: section)
        case .following, .followers, .people:
            PeopleListView(section: section)
        case .messages:
            MessagesInboxView()
        case .profile:
            if let username = appState.currentUser?.username {
                MemberView(username: username)
            } else {
                LoginView()
            }
        case .options:
            OptionsView()
        case .about:
            AboutView()
        case .login:
            LoginView()
        case .register:
            RegisterView()
        }
    }
}
