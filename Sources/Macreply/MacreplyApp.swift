import SwiftUI
import AppKit

@main
public struct MacreplyApp: App {
    @StateObject private var appState = AppState()

    public init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.applicationIconImage = AppIcon.loadOrRenderImage()
    }

    public var body: some Scene {
        WindowGroup("Macreply") {
            MainSplitView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 764, height: 640)
        .commands {
            CommandGroup(replacing: .sidebar) {
                Toggle("Compact sidebar", isOn: $appState.isCompactSidebar)
            }

            CommandMenu("Navigate") {
                Button("Back") {
                    if !appState.navigationPath.isEmpty {
                        appState.navigationPath.removeLast()
                    }
                }
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(appState.navigationPath.isEmpty)

                Button("Refresh Feed") {
                    appState.feedRefreshTrigger = UUID()
                    Task {
                        await appState.refreshNotifications()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])

                Divider()

                if appState.isAuthenticated {
                    Button("Feed") { appState.selectSection(.feed) }
                        .keyboardShortcut("1", modifiers: [.command])
                    Button("Mentions") { appState.selectSection(.mentions) }
                        .keyboardShortcut("2", modifiers: [.command])
                    Button("Messages") { appState.selectSection(.messages) }
                        .keyboardShortcut("3", modifiers: [.command])
                    Button("Replies") { appState.selectSection(.replies) }
                        .keyboardShortcut("4", modifiers: [.command])
                    Button("Saved") { appState.selectSection(.saved) }
                        .keyboardShortcut("5", modifiers: [.command])
                    Button("Profile") { appState.selectSection(.profile) }
                        .keyboardShortcut("6", modifiers: [.command])
                }

                Button("People") { appState.selectSection(.people) }
                    .keyboardShortcut("7", modifiers: [.command])
                Button("Trending") { appState.selectSection(.trending) }
                    .keyboardShortcut("8", modifiers: [.command])
                Button("Discover") { appState.selectSection(.discover) }
                    .keyboardShortcut("9", modifiers: [.command])
            }
        }
    }
}
