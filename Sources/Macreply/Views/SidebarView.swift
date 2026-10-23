import SwiftUI

public enum SubTheme {
    public static let accent = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(red: 0x60 / 255.0, green: 0x80 / 255.0, blue: 0xE0 / 255.0, alpha: 1.0)
            : NSColor(red: 0x40 / 255.0, green: 0x60 / 255.0, blue: 0xE0 / 255.0, alpha: 1.0)
    }))

    public static let alert = Color(red: 1.0, green: 0x40 / 255.0, blue: 0.0)

    public static let background = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? .black : .white
    }))

    public static let whitesmoke = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(white: 0x18 / 255.0, alpha: 1.0)
            : NSColor(white: 0xF0 / 255.0, alpha: 1.0)
    }))

    public static let redsmoke = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(red: 0x28 / 255.0, green: 0x18 / 255.0, blue: 0x18 / 255.0, alpha: 1.0)
            : NSColor(red: 1.0, green: 0xF0 / 255.0, blue: 0xF0 / 255.0, alpha: 1.0)
    }))

    public static let gainsboro = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(white: 0x28 / 255.0, alpha: 1.0)
            : NSColor(white: 0xE0 / 255.0, alpha: 1.0)
    }))

    public static let silver = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(white: 0x40 / 255.0, alpha: 1.0)
            : NSColor(white: 0xC0 / 255.0, alpha: 1.0)
    }))

    public static let gray = Color(white: 0x80 / 255.0)
    public static let indent: CGFloat = 30
    public static let radius: CGFloat = 6
    public static let contentWidth: CGFloat = 560
}

public struct SubLinkButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .linkCursor()
    }
}

public extension ButtonStyle where Self == SubLinkButtonStyle {
    static var subLink: SubLinkButtonStyle { SubLinkButtonStyle() }
}

private struct LinkCursorModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        Group {
            if #available(macOS 15.0, *) {
                content.pointerStyle(.link)
            } else {
                content
            }
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

public extension View {
    func linkCursor() -> some View {
        modifier(LinkCursorModifier())
    }
}

/// Observes trackpad/mouse scroll-wheel gestures on the enclosing `NSScrollView` without altering its layout or insets.
private struct MacScrollViewBridge: NSViewRepresentable {
    let onPullGesture: (_ pullDistance: CGFloat, _ phase: NSEvent.Phase) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPullGesture: onPullGesture)
    }

    func makeNSView(context: Context) -> NSView {
        let view = ScrollObserverNSView()
        view.onScrollViewAttached = { scrollView in
            context.coordinator.attach(to: scrollView)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onPullGesture = onPullGesture
        if let scrollView = nsView.enclosingScrollView {
            context.coordinator.attach(to: scrollView)
        }
    }

    private final class ScrollObserverNSView: NSView {
        var onScrollViewAttached: ((NSScrollView) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self, let sv = self.enclosingScrollView else { return }
                self.onScrollViewAttached?(sv)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var onPullGesture: (_ pullDistance: CGFloat, _ phase: NSEvent.Phase) -> Void
        private weak var observedScrollView: NSScrollView?
        private nonisolated(unsafe) var scrollMonitor: Any?
        private var restingTopOriginY: CGFloat?
        private var accumulatedPull: CGFloat = 0
        private var isTrackingTopPull = false

        init(onPullGesture: @escaping (_ pullDistance: CGFloat, _ phase: NSEvent.Phase) -> Void) {
            self.onPullGesture = onPullGesture
        }

        func attach(to scrollView: NSScrollView) {
            scrollView.verticalScrollElasticity = .allowed
            if observedScrollView !== scrollView {
                observedScrollView = scrollView
                restingTopOriginY = scrollView.contentView.bounds.origin.y
            }

            if scrollMonitor == nil {
                scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                    self?.handleScrollWheel(event)
                    return event
                }
            }
        }

        private func handleScrollWheel(_ event: NSEvent) {
            guard let scrollView = observedScrollView,
                  let window = scrollView.window,
                  event.window === window else {
                return
            }

            // Ignore momentum events after fingers have lifted
            if !event.momentumPhase.isEmpty {
                return
            }

            let locationInScroll = scrollView.convert(event.locationInWindow, from: nil)
            guard scrollView.bounds.contains(locationInScroll) else { return }

            let currentOriginY = scrollView.contentView.bounds.origin.y
            let baselineY = min(restingTopOriginY ?? 0, 0)
            if restingTopOriginY == nil || (event.phase == .began && currentOriginY < (restingTopOriginY ?? 0) && currentOriginY <= 0) {
                restingTopOriginY = currentOriginY
            }

            let isAtTop = currentOriginY <= baselineY + 1.0

            if event.phase == .began {
                isTrackingTopPull = isAtTop
                accumulatedPull = 0
            } else if event.phase.isEmpty {
                // Mouse wheel without trackpad phase
                isTrackingTopPull = isAtTop
            }

            if isTrackingTopPull {
                if event.scrollingDeltaY > 0 && isAtTop {
                    let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY * 0.55 : event.scrollingDeltaY * 5.0
                    accumulatedPull = min(90, accumulatedPull + delta)
                } else if event.scrollingDeltaY < 0 {
                    let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY * 0.8 : event.scrollingDeltaY * 5.0
                    accumulatedPull = max(0, accumulatedPull + delta)
                }

                let effectivePhase: NSEvent.Phase = event.phase.isEmpty ? .ended : event.phase
                onPullGesture(accumulatedPull, effectivePhase)

                if effectivePhase == .ended || effectivePhase == .cancelled {
                    isTrackingTopPull = false
                    accumulatedPull = 0
                }
            }
        }

        deinit {
            if let monitor = scrollMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

/// Native macOS pull-to-refresh ScrollView.
/// Keeps `ScrollView` as the root view and renders the indicator in an `.overlay(alignment: .top)`
/// so safe-area insets and scroll position are never shifted or trapped in a refresh loop.
public struct RefreshableScrollView<Content: View>: View {
    private let onRefresh: () async -> Void
    private let content: () -> Content

    @State private var isRefreshing = false
    @State private var pullOffset: CGFloat = 0

    private let triggerThreshold: CGFloat = 44

    public init(
        onRefresh: @escaping () async -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onRefresh = onRefresh
        self.content = content
    }

    private var showIndicator: Bool {
        isRefreshing || pullOffset > 6
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                MacScrollViewBridge { distance, phase in
                    handlePullGesture(distance: distance, phase: phase)
                }
                .frame(width: 0, height: 0)

                content()
            }
        }
        .overlay(alignment: .top) {
            if showIndicator {
                HStack(spacing: 7) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: pullOffset >= triggerThreshold ? "arrow.up" : "arrow.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(SubTheme.gray)
                    }
                    Text(statusLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SubTheme.gray)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(SubTheme.whitesmoke)
                        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                )
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.16), value: showIndicator)
        .animation(.easeInOut(duration: 0.16), value: isRefreshing)
    }

    private var statusLabel: String {
        if isRefreshing {
            return "Refreshing..."
        } else if pullOffset >= triggerThreshold {
            return "Release to refresh"
        } else {
            return "Pull to refresh"
        }
    }

    private func handlePullGesture(distance: CGFloat, phase: NSEvent.Phase) {
        guard !isRefreshing else { return }

        switch phase {
        case .began, .changed, .stationary:
            pullOffset = distance
        case .ended:
            let shouldRefresh = distance >= triggerThreshold || pullOffset >= triggerThreshold
            pullOffset = 0
            if shouldRefresh {
                Task {
                    await performRefreshWithMinimumDuration()
                }
            }
        default:
            pullOffset = 0
        }
    }

    private func performRefreshWithMinimumDuration() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        let start = ContinuousClock.now
        await onRefresh()
        let elapsed = ContinuousClock.now - start
        if elapsed < .milliseconds(450) {
            try? await Task.sleep(for: .milliseconds(450) - elapsed)
        }
        pullOffset = 0
        isRefreshing = false
    }
}

public struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 2) {
                ForEach(SidebarSection.visibleSections(isAuthenticated: appState.isAuthenticated)) { section in
                    SidebarRowButton(
                        section: section,
                        isSelected: appState.selectedSection == section && appState.navigationPath.isEmpty,
                        badgeCount: appState.badgeCount(for: section)
                    ) {
                        appState.selectSection(section)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .background(SubTheme.background)
    }
}

private struct SidebarRowButton: View {
    let section: SidebarSection
    let isSelected: Bool
    let badgeCount: Int
    let action: () -> Void

    @State private var isHovered = false

    private var hasUnread: Bool {
        badgeCount > 0 && !isSelected
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Spacer(minLength: 0)

                Text(section.title)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)

                ZStack(alignment: .topTrailing) {
                    Image(systemName: section.systemImage)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 22, height: 20)
                        .foregroundStyle(
                            isSelected ? Color.white : (hasUnread ? SubTheme.alert : Color.primary)
                        )

                    if badgeCount > 0 {
                        Text(SubNotifications.capBadge(badgeCount))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(isSelected ? Color.white : SubTheme.alert)
                            .offset(x: 7, y: -5)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: SubTheme.radius)
                    .fill(rowBackground)
            )
            .contentShape(RoundedRectangle(cornerRadius: SubTheme.radius))
        }
        .buttonStyle(.subLink)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return SubTheme.alert
        } else if isHovered {
            return SubTheme.whitesmoke
        } else {
            return .clear
        }
    }
}
