import SwiftUI

public struct MainSplitView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            SidebarView()

            Divider()
                .ignoresSafeArea()

            NavigationStack(path: $appState.navigationPath) {
                rootSectionView(for: appState.selectedSection)
                    .toolbar(.hidden, for: .windowToolbar)
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        Group {
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
                        .navigationBarBackButtonHidden(true)
                        .toolbar(.hidden, for: .windowToolbar)
                    }
            }
            .frame(
                minWidth: SubTheme.minContentWidth + (SubTheme.horizontalPadding * 2),
                maxWidth: SubTheme.contentWidth + (SubTheme.horizontalPadding * 2)
            )
            .ignoresSafeArea(.container, edges: .top)
            .background(SubTheme.background.ignoresSafeArea())
        }
        .frame(
            minWidth: SubTheme.minWindowWidth(isCompact: appState.isCompactSidebar),
            maxWidth: SubTheme.maxWindowWidth(isCompact: appState.isCompactSidebar),
            minHeight: SubTheme.minWindowHeight(isAuthenticated: appState.isAuthenticated)
        )
        .ignoresSafeArea(.container, edges: .top)
        .background(
            FakeTitleBarWindowConfigurator(
                isCompactSidebar: appState.isCompactSidebar,
                minWindowHeight: SubTheme.minWindowHeight(isAuthenticated: appState.isAuthenticated)
            )
            .frame(width: 0, height: 0)
        )
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
