import SwiftUI
import AppKit

@main
public struct MacreplyApp: App {
    @StateObject private var appState: AppState

    static func exportIconsetIfRequested() -> Bool {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--export-icon-bundle"), idx + 1 < args.count {
            let dir = URL(fileURLWithPath: args[idx + 1])
            try? AppIcon.writeIconComposerBundle(to: dir)
            return true
        }
        if let idx = args.firstIndex(of: "--export-iconset"), idx + 1 < args.count {
            let dir = URL(fileURLWithPath: args[idx + 1])
            let mode: AppIcon.AppearanceMode = args.contains("--dark") ? .dark : .light
            try? AppIcon.writeIconset(to: dir, mode: mode)
            return true
        }
        return false
    }

    public init() {
        if Self.exportIconsetIfRequested() {
            exit(0)
        }
        _appState = StateObject(wrappedValue: AppState())
        NSApplication.shared.setActivationPolicy(.regular)
        AppIcon.installAppearanceObserver()
    }

    public var body: some Scene {
        WindowGroup("Subreply") {
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
                    Button("Options") { appState.selectSection(.options) }
                        .keyboardShortcut("7", modifiers: [.command])
                }

                Button("People") { appState.selectSection(.people) }
                    .keyboardShortcut("8", modifiers: [.command])
                Button("Trending") { appState.selectSection(.trending) }
                    .keyboardShortcut("9", modifiers: [.command])
                Button("Discover") { appState.selectSection(.discover) }
                    .keyboardShortcut("0", modifiers: [.command])
            }
        }
    }
}
