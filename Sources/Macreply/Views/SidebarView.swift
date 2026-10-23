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
    public static let minContentWidth: CGFloat = 320
    public static let contentWidth: CGFloat = 640
    public static let horizontalPadding: CGFloat = 24

    public static func sidebarWidth(isCompact: Bool) -> CGFloat {
        isCompact ? 78 : 155
    }

    public static func minWindowWidth(isCompact: Bool) -> CGFloat {
        sidebarWidth(isCompact: isCompact) + 1 + (horizontalPadding * 2) + minContentWidth
    }

    public static func maxWindowWidth(isCompact: Bool) -> CGFloat {
        sidebarWidth(isCompact: isCompact) + 1 + (horizontalPadding * 2) + contentWidth
    }

    public static let sidebarTopHeaderHeight: CGFloat = 61.5
    public static let sidebarBottomPadding: CGFloat = 14.5
    public static let sidebarRowHeight: CGFloat = 32
    public static let sidebarRowSpacing: CGFloat = 2

    public static func minWindowHeight(isAuthenticated: Bool) -> CGFloat {
        let count = CGFloat(SidebarSection.visibleSections(isAuthenticated: isAuthenticated).count)
        let rowsHeight = (count * sidebarRowHeight) + (max(0, count - 1) * sidebarRowSpacing)
        return sidebarTopHeaderHeight + rowsHeight + sidebarBottomPadding
    }
}

public extension View {
    func subFeedContainer() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(
                minWidth: SubTheme.minContentWidth,
                maxWidth: SubTheme.contentWidth,
                alignment: .leading
            )
            .padding(.horizontal, SubTheme.horizontalPadding)
            .padding(.top, 14)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
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

/// Configures the hosting `NSWindow` to hide the native titlebar/toolbar, constrain the feed area
/// width between 320px and 640px (excluding padding and sidebar), and vertically align
/// the standard macOS traffic light controls (center Y = 22.5pt from top) with the top compose field.
public struct FakeTitleBarWindowConfigurator: NSViewRepresentable {
    public let isCompactSidebar: Bool
    public let minWindowHeight: CGFloat

    public init(isCompactSidebar: Bool = false, minWindowHeight: CGFloat = SubTheme.minWindowHeight(isAuthenticated: true)) {
        self.isCompactSidebar = isCompactSidebar
        self.minWindowHeight = minWindowHeight
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(isCompactSidebar: isCompactSidebar, minWindowHeight: minWindowHeight)
    }

    public func makeNSView(context: Context) -> NSView {
        let view = WindowObserverView()
        view.onWindowAttached = { window in
            context.coordinator.attach(to: window)
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.updateConfiguration(
            isCompact: isCompactSidebar,
            minWindowHeight: minWindowHeight
        )
        if let window = nsView.window {
            context.coordinator.attach(to: window)
        }
    }

    private final class WindowObserverView: NSView {
        var onWindowAttached: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            onWindowAttached?(window)
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window else { return }
                self.onWindowAttached?(window)
            }
        }
    }

    @MainActor
    public final class Coordinator: NSObject {
        private weak var observedWindow: NSWindow?
        private weak var observedContainer: NSView?
        private var isCompactSidebar: Bool
        private var minWindowHeight: CGFloat
        private var isAdjusting = false
        private nonisolated(unsafe) var observers: [NSObjectProtocol] = []

        public init(isCompactSidebar: Bool, minWindowHeight: CGFloat) {
            self.isCompactSidebar = isCompactSidebar
            self.minWindowHeight = minWindowHeight
        }

        public func updateConfiguration(isCompact: Bool, minWindowHeight: CGFloat) {
            let compactChanged = isCompactSidebar != isCompact
            let heightChanged = abs(self.minWindowHeight - minWindowHeight) > 0.5
            guard compactChanged || heightChanged else { return }

            let previousSidebarWidth = SubTheme.sidebarWidth(isCompact: isCompactSidebar)
            let newSidebarWidth = SubTheme.sidebarWidth(isCompact: isCompact)
            self.isCompactSidebar = isCompact
            self.minWindowHeight = minWindowHeight

            guard let window = observedWindow else { return }
            updateWindowSizeLimits(window)

            if compactChanged && !window.styleMask.contains(.fullScreen) {
                var frame = window.frame
                let delta = newSidebarWidth - previousSidebarWidth
                let minW = SubTheme.minWindowWidth(isCompact: isCompact)
                let maxW = SubTheme.maxWindowWidth(isCompact: isCompact)
                frame.size.width = min(max(frame.size.width + delta, minW), maxW)
                window.setFrame(frame, display: true)
            }
        }

        public func attach(to window: NSWindow) {
            configureWindow(window)
            updateWindowSizeLimits(window)
            repositionTrafficLights(in: window)

            guard observedWindow !== window else { return }
            removeObservers()
            observedWindow = window

            let center = NotificationCenter.default
            let windowNotifications: [Notification.Name] = [
                NSWindow.didResizeNotification,
                NSWindow.didEndLiveResizeNotification,
                NSWindow.didBecomeKeyNotification,
                NSWindow.didResignKeyNotification,
                NSWindow.didDeminiaturizeNotification,
                NSWindow.didExitFullScreenNotification
            ]

            for name in windowNotifications {
                let token = center.addObserver(forName: name, object: window, queue: .main) { [weak self, weak window] _ in
                    MainActor.assumeIsolated {
                        guard let self, let window else { return }
                        self.configureWindow(window)
                        self.updateWindowSizeLimits(window)
                        self.repositionTrafficLights(in: window)
                    }
                }
                observers.append(token)
            }

            if let container = window.standardWindowButton(.closeButton)?.superview?.superview {
                observedContainer = container
                container.postsFrameChangedNotifications = true
                let token = center.addObserver(
                    forName: NSView.frameDidChangeNotification,
                    object: container,
                    queue: .main
                ) { [weak self, weak window] _ in
                    MainActor.assumeIsolated {
                        guard let self, let window else { return }
                        self.repositionTrafficLights(in: window)
                    }
                }
                observers.append(token)
            }
        }

        private func configureWindow(_ window: NSWindow) {
            if window.toolbar != nil {
                window.toolbar = nil
            }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
        }

        private func updateWindowSizeLimits(_ window: NSWindow) {
            let minW = SubTheme.minWindowWidth(isCompact: isCompactSidebar)
            let maxW = SubTheme.maxWindowWidth(isCompact: isCompactSidebar)
            let minH = minWindowHeight

            if window.contentMinSize.width != minW || window.contentMinSize.height != minH {
                window.contentMinSize = NSSize(width: minW, height: minH)
            }
            if window.contentMaxSize.width != maxW {
                window.contentMaxSize = NSSize(width: maxW, height: .greatestFiniteMagnitude)
            }

            if !window.styleMask.contains(.fullScreen) {
                var frame = window.frame
                let clampedWidth = min(max(frame.size.width, minW), maxW)
                let clampedHeight = max(frame.size.height, minH)
                if abs(frame.size.width - clampedWidth) > 0.5 || abs(frame.size.height - clampedHeight) > 0.5 {
                    let heightDelta = clampedHeight - frame.size.height
                    frame.origin.y -= heightDelta
                    frame.size.width = clampedWidth
                    frame.size.height = clampedHeight
                    window.setFrame(frame, display: true)
                }
            }
        }

        private func repositionTrafficLights(in window: NSWindow) {
            guard !isAdjusting,
                  !window.styleMask.contains(.fullScreen),
                  let close = window.standardWindowButton(.closeButton),
                  let mini = window.standardWindowButton(.miniaturizeButton),
                  let zoom = window.standardWindowButton(.zoomButton),
                  let titlebar = close.superview,
                  let container = titlebar.superview else {
                return
            }

            isAdjusting = true
            defer { isAdjusting = false }

            // Shift the 32pt titlebar container down by 18.5pt so traffic lights center at Y = 34.5pt from top,
            // matching the 29pt compose field at 20pt top padding (20 + 14.5 = 34.5pt).
            let targetContainerY = window.frame.height - container.frame.height - 18.5
            if abs(container.frame.origin.y - targetContainerY) > 0.25 || abs(container.frame.origin.x) > 0.25 {
                container.setFrameOrigin(NSPoint(x: 0, y: targetContainerY))
            }

            let buttonY = (titlebar.bounds.height - close.frame.height) / 2.0
            close.setFrameOrigin(NSPoint(x: 12, y: buttonY))
            mini.setFrameOrigin(NSPoint(x: 32, y: buttonY))
            zoom.setFrameOrigin(NSPoint(x: 52, y: buttonY))
        }

        private nonisolated func removeObservers() {
            for token in observers {
                NotificationCenter.default.removeObserver(token)
            }
            observers.removeAll()
        }

        deinit {
            removeObservers()
        }
    }
}

/// Draggable fake titlebar region so the user can drag the window from the top area.
public struct FakeTitleBarDragRegion: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        DraggableTitleBarNSView()
    }

    public func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DraggableTitleBarNSView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}
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
        .ignoresSafeArea(.container, edges: .top)
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

public struct SidebarVisualEffectView: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .sidebar
        nsView.blendingMode = .behindWindow
        nsView.state = .followsWindowActiveState
    }
}

public struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Fake titlebar area holding the macOS window controls (aligned with the compose field)
            FakeTitleBarDragRegion()
                .frame(height: SubTheme.sidebarTopHeaderHeight)
                .frame(maxWidth: .infinity)

            VStack(alignment: appState.isCompactSidebar ? .center : .trailing, spacing: SubTheme.sidebarRowSpacing) {
                ForEach(SidebarSection.visibleSections(isAuthenticated: appState.isAuthenticated)) { section in
                    SidebarRowButton(
                        section: section,
                        isSelected: appState.selectedSection == section && appState.navigationPath.isEmpty,
                        isCompact: appState.isCompactSidebar,
                        badgeCount: appState.badgeCount(for: section)
                    ) {
                        appState.selectSection(section)
                    }
                }
            }
            .padding(.horizontal, appState.isCompactSidebar ? 8 : 10)
            .padding(.bottom, SubTheme.sidebarBottomPadding)
            .fixedSize(horizontal: false, vertical: true)

            FakeTitleBarDragRegion()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
            width: SubTheme.sidebarWidth(isCompact: appState.isCompactSidebar)
        )
        .frame(
            minHeight: SubTheme.minWindowHeight(isAuthenticated: appState.isAuthenticated)
        )
        .ignoresSafeArea(.container, edges: .top)
        .background(
            SidebarVisualEffectView()
                .ignoresSafeArea()
        )
    }
}

private struct SidebarRowButton: View {
    let section: SidebarSection
    let isSelected: Bool
    let isCompact: Bool
    let badgeCount: Int
    let action: () -> Void

    @State private var isHovered = false

    private var hasUnread: Bool {
        badgeCount > 0 && !isSelected
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: isCompact ? 0 : 10) {
                if !isCompact {
                    Spacer(minLength: 0)

                    Text(section.title)
                        .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .lineLimit(1)
                }

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
            .padding(.horizontal, isCompact ? 7 : 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: isCompact ? .center : .trailing)
            .background(
                RoundedRectangle(cornerRadius: SubTheme.radius)
                    .fill(rowBackground)
            )
            .contentShape(RoundedRectangle(cornerRadius: SubTheme.radius))
        }
        .buttonStyle(.subLink)
        .help(isCompact ? section.title : "")
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return SubTheme.alert
        } else if isHovered {
            return Color.primary.opacity(0.08)
        } else {
            return .clear
        }
    }
}
