import Testing
import Foundation
import SwiftUI
import AppKit
@testable import Macreply

@Suite("Macreply Core Tests")
struct MacreplyTests {

    @Test("Tokenizes mentions, reply refs, hashtags, and links matching Subreply parser")
    func testContentParserTokenize() {
        let input = "Hello (@lucian), check #42 and #macOS at https://www.subreply.com/very/long/path/here!"
        let tokens = ContentParser.tokenize(input)

        #expect(tokens.contains(.mention(prefix: "(", username: "lucian", suffix: "),")))
        #expect(tokens.contains(.replyRef(prefix: "", id: 42, suffix: "")))
        #expect(tokens.contains(.hashtag(prefix: "", tag: "macOS", suffix: "")))
        #expect(tokens.contains(.link(
            prefix: "",
            url: "https://www.subreply.com/very/long/path/here",
            display: "subreply.com/very/...",
            suffix: "!"
        )))
    }

    @Test("Decodes SubEntry with explicit null parent vs nested parent and reverses 5 streamKids")
    func testSubEntryDecodingAndStreamKids() throws {
        let json = """
        {
            "page": 1,
            "entries": [
                {
                    "id": 100,
                    "content": "Root thread content",
                    "created_by": {
                        "followed": true,
                        "username": "lm",
                        "full_name": "🦊 Lucian M.",
                        "first_name": "Lucian",
                        "last_name": "M",
                        "created_at": 1700000000.0,
                        "emoji": ":fox:",
                        "birthday": "1988-04-12",
                        "location": "Bucharest, Romania",
                        "link": "https://subreply.com",
                        "description": "Creator of @subreply",
                        "phone": {"code": "+40", "number": "722000000"},
                        "social": {"github": "lucianmarin", "x": "lucianmarin"}
                    },
                    "saved": true,
                    "edited": true,
                    "replies": 8,
                    "timestamp": "10m",
                    "parent": null,
                    "kids": [
                        {"id": 106, "content": "Kid 6", "created_by": {"username": "u6", "full_name": "U6"}, "saved": false, "replies": 2, "timestamp": "1m"},
                        {"id": 105, "content": "Kid 5", "created_by": {"username": "u5", "full_name": "U5"}, "saved": false, "timestamp": "2m"},
                        {"id": 104, "content": "Kid 4", "created_by": {"username": "u4", "full_name": "U4"}, "saved": false, "timestamp": "3m"},
                        {"id": 103, "content": "Kid 3", "created_by": {"username": "u3", "full_name": "U3"}, "saved": false, "timestamp": "4m"},
                        {"id": 102, "content": "Kid 2", "created_by": {"username": "u2", "full_name": "U2"}, "saved": false, "timestamp": "5m"},
                        {"id": 101, "content": "Kid 1", "created_by": {"username": "u1", "full_name": "U1"}, "saved": false, "timestamp": "6m"}
                    ]
                }
            ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PaginatedEntriesResponse.self, from: json)
        #expect(decoded.page == 1)
        #expect(decoded.entries.count == 1)

        let entry = decoded.entries[0]
        #expect(entry.createdBy.followed == true)
        #expect(entry.edited == true)
        #expect(entry.hasExplicitNullParent == true)
        #expect(entry.parent == nil)
        #expect(entry.replyCount == 8)
        #expect(entry.replyLabel == "8 replies")
        #expect(entry.kids?[0].replyCount == 2)
        #expect(entry.kids?[0].replyLabel == "2 replies")
        #expect(entry.streamKids.map(\.id) == [102, 103, 104, 105, 106])
        #expect(entry.createdBy.cityLabel == "Bucharest")
        #expect(entry.createdBy.allLinks.map(\.name) == ["GitHub", "Phone", "X"])
    }

    @MainActor
    @Test("Sidebar sections match Subreply authenticated and guest states")
    func testSidebarSections() {
        let authSections = SidebarSection.visibleSections(isAuthenticated: true)
        #expect(authSections.first == .feed)
        #expect(authSections.contains(.mentions))
        #expect(authSections.contains(.messages))
        #expect(authSections.contains(.options))
        #expect(!authSections.contains(.login))

        #expect(SidebarSection.following.systemImage == "text.insert")
        #expect(SidebarSection.followers.systemImage == "text.append")
        #expect(SidebarSection.messages.systemImage == "bubble.left")

        let suiteName = "macreply.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = AppState(defaults: defaults)
        #expect(state.systemImage(for: .messages) == "bubble.left")
        state.hasMessages = true
        #expect(state.systemImage(for: .messages) == "bubble.left")

        state.openConversation("subreply")
        #expect(state.isSectionSelected(.messages) == true)
        #expect(state.isSectionSelected(.trending) == false)
        #expect(state.systemImage(for: .messages) == "ellipsis.bubble")
        state.hasMessages = true
        #expect(state.systemImage(for: .messages) == "text.bubble")

        state.selectSection(.messages)
        #expect(state.isSectionSelected(.messages) == true)
        #expect(state.systemImage(for: .messages) == "bubble.left")

        let guestSections = SidebarSection.visibleSections(isAuthenticated: false)
        #expect(guestSections == [.about, .login, .register, .people, .trending, .discover])
    }

    @MainActor
    @Test("Dock badge sums all notification counts and clears when zero")
    func testDockNotificationsBadge() {
        let suiteName = "macreply.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = AppState(defaults: defaults)
        #expect(state.notifications.total == 0)
        #expect(state.dockBadgeLabel == nil)
        #expect(state.notificationPollingMinutes == 5)

        state.updateNotificationPollingMinutes(10)
        #expect(state.notificationPollingMinutes == 10)
        #expect(defaults.integer(forKey: "macreply.config.notificationPollingMinutes") == 10)

        state.notifications = SubNotifications(followers: 2, mentions: 3, replies: 4, messages: 1)
        #expect(state.notifications.total == 10)
        #expect(state.dockBadgeLabel == "10")
        #expect(NSApplication.shared.dockTile.badgeLabel == "10")
        #expect(state.deliveredNotificationMessages == [
            "Reply received",
            "Message received",
            "Follower received",
            "Mention received"
        ])

        // Polling with unchanged counts does not emit duplicate native notifications
        state.notifications = SubNotifications(followers: 2, mentions: 3, replies: 4, messages: 1)
        #expect(state.deliveredNotificationMessages.count == 4)

        // Clearing a section count does not emit notifications
        state.clearNotificationCount(for: .mentions)
        #expect(state.notifications.total == 7)
        #expect(state.dockBadgeLabel == "7")
        #expect(NSApplication.shared.dockTile.badgeLabel == "7")
        #expect(state.deliveredNotificationMessages.count == 4)

        // Incrementing only replies emits only "Reply received"
        state.notifications = SubNotifications(followers: 2, mentions: 0, replies: 5, messages: 1)
        #expect(state.deliveredNotificationMessages.last == "Reply received")
        #expect(state.deliveredNotificationMessages.count == 5)

        // Persists notifications across app restarts when authenticated and avoids re-notifying unchanged counts
        let selfUser = SubUser(username: "lucian", fullName: "Lucian Marin", firstName: "Lucian")
        state.applyAuthSession(token: "test-token", user: selfUser)
        state.notifications = SubNotifications(followers: 2, mentions: 0, replies: 5, messages: 1)

        let restartedState = AppState(defaults: defaults)
        #expect(restartedState.notifications == SubNotifications(followers: 2, mentions: 0, replies: 5, messages: 1))
        #expect(restartedState.deliveredNotificationMessages.isEmpty)

        restartedState.notifications = SubNotifications(followers: 2, mentions: 0, replies: 5, messages: 1)
        #expect(restartedState.deliveredNotificationMessages.isEmpty)

        state.logout()
        #expect(state.notifications.total == 0)
        #expect(state.dockBadgeLabel == nil)
        #expect(NSApplication.shared.dockTile.badgeLabel == nil)
        #expect(state.deliveredNotificationMessages.isEmpty)
    }

    @MainActor
    @Test("Changing views triggers notification refresh when authenticated")
    func testViewChangesRefreshNotifications() async throws {
        let suiteName = "macreply.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = AppState(defaults: defaults)
        state.token = "test-token"
        state.currentUser = SubUser(username: "lucian", fullName: "Lucian Marin", firstName: "Lucian")
        let initialCount = state.notificationRefreshCount

        state.selectSection(.mentions)
        try await Task.sleep(for: .milliseconds(20))
        let afterSectionSelect = state.notificationRefreshCount
        #expect(afterSectionSelect > initialCount)

        state.openReply(42)
        try await Task.sleep(for: .milliseconds(20))
        let afterOpenReply = state.notificationRefreshCount
        #expect(afterOpenReply > afterSectionSelect)

        state.openMember("subreply")
        try await Task.sleep(for: .milliseconds(20))
        let afterOpenMember = state.notificationRefreshCount
        #expect(afterOpenMember > afterOpenReply)

        state.navigationPath.removeLast()
        try await Task.sleep(for: .milliseconds(20))
        let afterBack = state.notificationRefreshCount
        #expect(afterBack > afterOpenMember)

        // Clicking the already-active section in the sidebar triggers a content reload and notification refresh
        let previousRefreshTrigger = state.feedRefreshTrigger
        state.selectSection(.mentions)
        #expect(state.feedRefreshTrigger != previousRefreshTrigger)
        try await Task.sleep(for: .milliseconds(20))
        #expect(state.notificationRefreshCount > afterBack)
    }

    @MainActor
    @Test("Member header, profile status row, and user rows match Subreply templates")
    func testSelfMemberHeaderShowsMessageButton() {
        let suiteName = "macreply.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = AppState(defaults: defaults)
        let now = Date().timeIntervalSince1970
        let selfUser = SubUser(
            username: "lucian",
            fullName: "Lucian Marin",
            firstName: "Lucian",
            createdAt: now - 86400 * 14,
            seenAt: now - 300
        )
        state.token = "test-token"
        state.currentUser = selfUser

        let row = UserRowView(member: .constant(selfUser), isMemberHeader: true)
            .environmentObject(state)
            .frame(width: 640)

        let host = NSHostingView(rootView: row)
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize.height > 0)

        let selfStatusRow = MemberStatusRowView(member: .constant(selfUser))
            .environmentObject(state)
            .frame(width: 640)
        let statusHost = NSHostingView(rootView: selfStatusRow)
        statusHost.layoutSubtreeIfNeeded()
        #expect(statusHost.fittingSize.height > 0)

        state.openConversation(selfUser.username)
        #expect(state.navigationPath == [.conversation("lucian")])

        let otherUser = SubUser(
            followed: false,
            follows: true,
            username: "subreply",
            fullName: "Subreply",
            firstName: "Subreply",
            createdAt: now - 86400 * 30,
            seenAt: now - 600
        )
        let otherRow = UserRowView(member: .constant(otherUser), isMemberHeader: false)
        #expect(otherRow.followActionTitle == "Follow")

        let otherStatusRow = MemberStatusRowView(member: .constant(otherUser))
        #expect(otherStatusRow.followActionTitle == "FOLLOW")

        let followedUser = SubUser(followed: true, username: "subreply", fullName: "Subreply", firstName: "Subreply")
        let followedRow = UserRowView(member: .constant(followedUser), isMemberHeader: false)
        #expect(followedRow.followActionTitle == "Unfollow")

        let followedStatusRow = MemberStatusRowView(member: .constant(followedUser))
        #expect(followedStatusRow.followActionTitle == "UNFOLLOW")

        let selfBanner = PlaceholderBannerView(text: "No reply yet", showsReplyIcon: true)
        #expect(selfBanner.showsReplyIcon == true)
    }

    @MainActor
    @Test("ComposerView expands vertically when resized from 640px to 320px width")
    func testComposerViewReflowsOnResize() {
        let longText = "This is a long composer message that fits on two lines at 640px width but requires more lines when the window is resized down to 320px width so nothing gets clipped."
        let composer = ComposerView(placeholder: "Share something...", initialText: longText) { _ in }

        let wideHost = NSHostingView(rootView: composer.frame(width: 640))
        wideHost.layoutSubtreeIfNeeded()
        let wideHeight = wideHost.fittingSize.height

        let narrowHost = NSHostingView(rootView: composer.frame(width: 320))
        narrowHost.layoutSubtreeIfNeeded()
        let narrowHeight = narrowHost.fittingSize.height

        #expect(narrowHeight > wideHeight)
    }

    @MainActor
    @Test("ComposerView limits input to 720 characters maximum while warning at 641+")
    func testComposerViewCharacterLimits() {
        #expect(ComposerView.warningCharacterLimit == 640)
        #expect(ComposerView.maxCharacterLimit == 720)

        let text650 = String(repeating: "a", count: 650)
        #expect(ComposerView.clamp(text650).count == 650)

        let text800 = String(repeating: "b", count: 800)
        let clamped = ComposerView.clamp(text800)
        #expect(clamped.count == 720)

        let composer = ComposerView(placeholder: "Share something...", initialText: text800) { _ in }
        #expect(composer.initialText.count == 720)
    }

    @Test("Timeago formatting matches Subreply filter")
    func testTimeAgo() {
        let now: Double = 1_700_000_000
        #expect(ContentParser.timeAgo(since: now - 45, now: now) == "45s")
        #expect(ContentParser.timeAgo(since: now - 300, now: now) == "5m")
        #expect(ContentParser.timeAgo(since: now - 7200, now: now) == "2h")
        #expect(ContentParser.timeAgo(since: now - 86400 * 3, now: now) == "3d")
        #expect(ContentParser.timeAgo(since: now - 86400 * 14, now: now) == "2w")
    }

    @Test("Feed area resizes from 320px to 640px excluding padding and sidebar")
    func testFeedAreaResizeBounds() {
        #expect(SubTheme.minContentWidth == 320)
        #expect(SubTheme.contentWidth == 640)

        for isCompact in [false, true] {
            let sidebar = SubTheme.sidebarWidth(isCompact: isCompact)
            let padding = SubTheme.horizontalPadding * 2
            let minFeed = SubTheme.minWindowWidth(isCompact: isCompact) - sidebar - 1 - padding
            let maxFeed = SubTheme.maxWindowWidth(isCompact: isCompact) - sidebar - 1 - padding
            #expect(minFeed == 320)
            #expect(maxFeed == 640)
        }

        #expect(SubTheme.minWindowHeight == 482)
        #expect(SubTheme.minWindowHeight(isAuthenticated: true) == 482)
        #expect(SubTheme.minWindowHeight(isAuthenticated: false) == 482)
    }

    @MainActor
    @Test("Member social links for /lucian wrap across multiple lines at 320px width")
    func testMemberLinksMultilineWrapping() {
        let lucian = SubUser(
            username: "lucian",
            fullName: "🍊 Lucian Marin",
            firstName: "Lucian",
            lastName: "Marin",
            createdAt: 1398381247.156,
            emoji: ":tangerine:",
            birthday: "1986-11-26",
            location: "Bucharest, Romania",
            link: "https://lucianmarin.com/",
            description: "Python developer and all things tech.",
            phone: ["code": "+40", "number": "726210589"],
            social: [
                "x": "lucianmarin",
                "github": "lucianmarin",
                "paypal": "lucianmarin",
                "spotify": "lucianmarin",
                "linkedin": "marinlucian",
                "instagram": "lucianmarin"
            ]
        )

        let links = lucian.allLinks
        #expect(links.map(\.name) == ["GitHub", "Instagram", "LinkedIn", "PayPal", "Phone", "Spotify", "X"])

        let view = MemberLinksView(links: links)
        let plainText = String(view.buildAttributedString().characters)
        #expect(plainText == "Also on GitHub, Instagram, LinkedIn, PayPal, Phone, Spotify and X.")

        let donatedView = MemberLinksView(links: links, donated: 25.0)
        let donatedPlainText = String(donatedView.buildAttributedString().characters)
        #expect(donatedPlainText == "Also on GitHub, Instagram, LinkedIn, PayPal, Phone, Spotify and X. Donated $25.")

        let donatedOnlyView = MemberLinksView(links: [], donated: 10.5)
        let donatedOnlyPlainText = String(donatedOnlyView.buildAttributedString().characters)
        #expect(donatedOnlyPlainText == "Donated $11.")

        let wideHost = NSHostingView(rootView: view.frame(width: 640))
        wideHost.layoutSubtreeIfNeeded()
        let wideHeight = wideHost.fittingSize.height

        let narrowHost = NSHostingView(rootView: view.frame(width: 320))
        narrowHost.layoutSubtreeIfNeeded()
        let narrowHeight = narrowHost.fittingSize.height

        #expect(narrowHeight > wideHeight)
        #expect(narrowHeight < 65)
    }

    @Test("AppIcon renders macOS squircle icon from light.svg and dark.svg specifications")
    func testAppIconGeneration() throws {
        let lightPNG = try #require(AppIcon.renderPNGData(pixelSize: 256, mode: .light))
        let darkPNG = try #require(AppIcon.renderPNGData(pixelSize: 256, mode: .dark))
        #expect(!lightPNG.isEmpty)
        #expect(!darkPNG.isEmpty)
        #expect(lightPNG != darkPNG)

        let lightRep = try #require(NSBitmapImageRep(data: lightPNG))
        let darkRep = try #require(NSBitmapImageRep(data: darkPNG))

        func pixelRGB(_ rep: NSBitmapImageRep, x: Int, y: Int) -> (Int, Int, Int) {
            var px = [0, 0, 0, 0]
            rep.getPixel(&px, atX: x, y: y)
            return (px[0], px[1], px[2])
        }

        // Background inside squircle at (50, 50): light is teal (#2EB8B8), dark is navy (#1F4D7A)
        #expect(pixelRGB(lightRep, x: 50, y: 50) == (0x2E, 0xB8, 0xB8))
        #expect(pixelRGB(darkRep, x: 50, y: 50) == (0x1F, 0x4D, 0x7A))

        // Upper tile at (148, 107): light is navy (#1F4D7A), dark is white (#FFFFFF)
        #expect(pixelRGB(lightRep, x: 148, y: 107) == (0x1F, 0x4D, 0x7A))
        #expect(pixelRGB(darkRep, x: 148, y: 107) == (0xFF, 0xFF, 0xFF))

        // Lower tile at (107, 148): light is white (#FFFFFF), dark is teal (#2EB8B8)
        #expect(pixelRGB(lightRep, x: 107, y: 148) == (0xFF, 0xFF, 0xFF))
        #expect(pixelRGB(darkRep, x: 107, y: 148) == (0x2E, 0xB8, 0xB8))

        #expect(AppIcon.mode(for: NSAppearance(named: .aqua)) == .light)
        #expect(AppIcon.mode(for: NSAppearance(named: .darkAqua)) == .dark)

        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("macreply-icon-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        try AppIcon.writeIconComposerBundle(to: tmpDir)
        let iconJSONURL = tmpDir.appendingPathComponent("icon.json")
        let iconJSONText = try String(contentsOf: iconJSONURL, encoding: .utf8)
        #expect(iconJSONText.contains("light.svg"))
        #expect(iconJSONText.contains("dark.svg"))
        #expect(FileManager.default.fileExists(atPath: tmpDir.appendingPathComponent("Assets/light.svg").path))
        #expect(FileManager.default.fileExists(atPath: tmpDir.appendingPathComponent("Assets/dark.svg").path))

        let image = AppIcon.loadOrRenderImage()
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
        #expect(!AppIcon.upperTileCGPath().isEmpty)
        #expect(!AppIcon.lowerTileCGPath().isEmpty)
    }

    @Test("SubTheme accent and alert colors match Subreply classic branding")
    func testSubThemeBrandingColors() throws {
        let accentSRGB = try #require(NSColor(SubTheme.accent).usingColorSpace(.sRGB))
        #expect(abs(accentSRGB.redComponent - (0x2E / 255.0)) < 0.01)
        #expect(abs(accentSRGB.greenComponent - (0xB8 / 255.0)) < 0.01)
        #expect(abs(accentSRGB.blueComponent - (0xB8 / 255.0)) < 0.01)

        let alertSRGB = try #require(NSColor(SubTheme.alert).usingColorSpace(.sRGB))
        #expect(abs(alertSRGB.redComponent - 1.0) < 0.01)
        #expect(abs(alertSRGB.greenComponent - (0x45 / 255.0)) < 0.01)
        #expect(abs(alertSRGB.blueComponent - 0.0) < 0.01)

        let bgNSColor = NSColor(SubTheme.background)
        if let lightAppearance = NSAppearance(named: .aqua) {
            lightAppearance.performAsCurrentDrawingAppearance {
                let srgb = bgNSColor.usingColorSpace(.sRGB)
                #expect(srgb?.redComponent == 1.0)
                #expect(srgb?.greenComponent == 1.0)
                #expect(srgb?.blueComponent == 1.0)
            }
        }
        if let darkAppearance = NSAppearance(named: .darkAqua) {
            darkAppearance.performAsCurrentDrawingAppearance {
                let srgb = bgNSColor.usingColorSpace(.sRGB)
                #expect(srgb?.redComponent == 0.0)
                #expect(srgb?.greenComponent == 0.0)
                #expect(srgb?.blueComponent == 0.0)
            }
        }
    }

    @Test("Decodes MemberResponse with optional email when member is req.user")
    func testMemberResponseDecodingWithEmail() throws {
        let selfJson = """
        {
            "member": {
                "followed": true,
                "username": "lucian",
                "email": "lucian@subreply.com",
                "full_name": "🍊 Lucian Marin",
                "first_name": "Lucian",
                "last_name": "Marin"
            }
        }
        """.data(using: .utf8)!

        let decodedSelf = try JSONDecoder().decode(MemberResponse.self, from: selfJson)
        #expect(decodedSelf.member.username == "lucian")
        #expect(decodedSelf.member.email == "lucian@subreply.com")

        let otherJson = """
        {
            "member": {
                "followed": false,
                "username": "subreply",
                "full_name": "Subreply",
                "first_name": "Subreply"
            }
        }
        """.data(using: .utf8)!

        let decodedOther = try JSONDecoder().decode(MemberResponse.self, from: otherJson)
        #expect(decodedOther.member.username == "subreply")
        #expect(decodedOther.member.email == "")
    }

    @MainActor
    @Test("Double-clicking and dragging top sidebar region around traffic lights respects macOS AppleActionOnDoubleClick and exclusive drag")
    func testTopSidebarTrafficLightRegionDoubleClickRespectsMacOSAction() throws {
        final class TestWindow: NSWindow {
            var miniaturizeCount = 0
            var zoomCount = 0
            var fillCount = 0
            var dragCount = 0

            override func performMiniaturize(_ sender: Any?) {
                miniaturizeCount += 1
            }

            override func performZoom(_ sender: Any?) {
                zoomCount += 1
            }

            override func performDrag(with event: NSEvent) {
                dragCount += 1
            }

            @objc func _zoomFill(_ sender: Any?) {
                fillCount += 1
            }
        }

        let suiteName = "macreply.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = AppState(defaults: defaults)
        let sidebar = SidebarView()
            .environmentObject(state)
            .frame(height: 640)

        let window = TestWindow(
            contentRect: NSRect(x: 0, y: 0, width: 764, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false

        let host = NSHostingView(rootView: sidebar)
        host.frame = NSRect(x: 0, y: 0, width: 120, height: 640)
        window.contentView = host
        host.layoutSubtreeIfNeeded()

        func findDragViews(in view: NSView) -> [FakeTitleBarDragRegion.DraggableTitleBarNSView] {
            var result: [FakeTitleBarDragRegion.DraggableTitleBarNSView] = []
            if let dragView = view as? FakeTitleBarDragRegion.DraggableTitleBarNSView {
                result.append(dragView)
            }
            for sub in view.subviews {
                result.append(contentsOf: findDragViews(in: sub))
            }
            return result
        }

        let dragViews = findDragViews(in: host)
        #expect(dragViews.count == 1)
        let topRegion = try #require(dragViews.first(where: { $0.handlesDoubleClick }))
        topRegion.userDefaults = defaults

        let singleClick = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 90, y: 605.5),
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1.0
        ))
        let dragEvent = try #require(NSEvent.mouseEvent(
            with: .leftMouseDragged,
            location: NSPoint(x: 95, y: 605.5),
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime + 0.05,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1.0
        ))
        let doubleClick = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 90, y: 605.5),
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime + 0.1,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 2,
            clickCount: 2,
            pressure: 1.0
        ))

        // Dragging top region moves window
        topRegion.mouseDragged(with: dragEvent)
        #expect(window.dragCount == 1)

        // 1. Maximize / Zoom
        defaults.set("Maximize", forKey: "AppleActionOnDoubleClick")
        topRegion.mouseDown(with: singleClick)
        #expect(window.zoomCount == 0)
        topRegion.mouseDown(with: doubleClick)
        #expect(window.zoomCount == 1)

        // 2. Minimize
        defaults.set("Minimize", forKey: "AppleActionOnDoubleClick")
        topRegion.mouseDown(with: doubleClick)
        #expect(window.miniaturizeCount == 1)

        // 3. Fill
        defaults.set("Fill", forKey: "AppleActionOnDoubleClick")
        topRegion.mouseDown(with: doubleClick)
        #expect(window.fillCount == 1)

        // 4. None (Do Nothing)
        defaults.set("None", forKey: "AppleActionOnDoubleClick")
        topRegion.mouseDown(with: doubleClick)
        #expect(window.zoomCount == 1)
        #expect(window.miniaturizeCount == 1)
        #expect(window.fillCount == 1)
    }

    @Test("clearConversation posts to /api/{username}/clear and verifies status == cleared")
    func testClearConversationEndpoint() async throws {
        final class MockURLProtocol: URLProtocol, @unchecked Sendable {
            nonisolated(unsafe) static var lastRequest: URLRequest?
            nonisolated(unsafe) static var responseStatus: String = "cleared"

            override class func canInit(with request: URLRequest) -> Bool { true }
            override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

            override func startLoading() {
                Self.lastRequest = request
                let url = request.url!
                let http = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let data = "{\"status\": \"\(Self.responseStatus)\"}".data(using: .utf8)!
                client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            }

            override func stopLoading() {}
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = APIClient(baseURLString: "https://subreply.com/api", token: "tok", session: session)

        MockURLProtocol.responseStatus = "cleared"
        let cleared = try await client.clearConversation(username: "Subreply")
        #expect(cleared == true)
        #expect(MockURLProtocol.lastRequest?.httpMethod == "POST")
        #expect(MockURLProtocol.lastRequest?.url?.absoluteString == "https://subreply.com/api/subreply/clear")

        MockURLProtocol.responseStatus = "not found"
        await #expect(throws: APIError.serverStatus("not found")) {
            _ = try await client.clearConversation(username: "unknown")
        }
    }

    @Test("EndpointCache only caches first page without q or p>1 parameters and treats ?p=1 as plain endpoint")
    func testEndpointCacheKeyAndFiltering() async throws {
        let suiteName = "macreply.cache.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        final class MockCacheProtocol: URLProtocol, @unchecked Sendable {
            nonisolated(unsafe) static var handler: ((URLRequest) -> Data)?
            nonisolated(unsafe) static var requestedURLs: [String] = []

            override class func canInit(with request: URLRequest) -> Bool { true }
            override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

            override func startLoading() {
                let url = request.url!
                Self.requestedURLs.append(url.absoluteString)
                let data = Self.handler?(request) ?? Data("{}".utf8)
                let http = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            }

            override func stopLoading() {}
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockCacheProtocol.self]
        let session = URLSession(configuration: config)
        let cache = EndpointCache(defaults: defaults)
        let client = APIClient(baseURLString: "https://subreply.com/api", token: "tok", session: session, cache: cache)

        let author = SubUser(username: "lucian", fullName: "Lucian", firstName: "Lucian")
        let page1Entry = SubEntry(id: 10, content: "Page 1 content", createdBy: author)
        let page2Entry = SubEntry(id: 20, content: "Page 2 content", createdBy: author)
        let searchEntry = SubEntry(id: 30, content: "Search content", createdBy: author)

        MockCacheProtocol.requestedURLs = []
        MockCacheProtocol.handler = { req in
            let urlStr = req.url?.absoluteString ?? ""
            if urlStr.contains("p=2") {
                return try! JSONEncoder().encode(PaginatedEntriesResponse(page: 2, entries: [page2Entry]))
            }
            if urlStr.contains("q=swift") {
                return try! JSONEncoder().encode(PaginatedEntriesResponse(page: 1, entries: [searchEntry]))
            }
            return try! JSONEncoder().encode(PaginatedEntriesResponse(page: 1, entries: [page1Entry]))
        }

        // 1. Plain endpoint call (?p=1 equivalent) caches under /discover
        let fetched1 = try await client.fetchEntries(path: "/discover?p=1", page: 1, query: nil)
        #expect(fetched1.entries.first?.content == "Page 1 content")
        #expect(MockCacheProtocol.requestedURLs.last == "https://subreply.com/api/discover")
        #expect(client.cachedEntries(path: "/discover")?.entries.first?.id == 10)
        #expect(client.cachedEntries(path: "/discover?p=1")?.entries.first?.id == 10)

        // 2. Page 2 (?p=2) is NOT cached and does not overwrite page 1 cache
        let fetched2 = try await client.fetchEntries(path: "/discover", page: 2, query: nil)
        #expect(fetched2.entries.first?.id == 20)
        #expect(client.cachedEntries(path: "/discover", page: 2) == nil)
        #expect(client.cachedEntries(path: "/discover?p=2") == nil)
        #expect(client.cachedEntries(path: "/discover")?.entries.first?.id == 10)

        // 3. Search query (?q=swift) is NOT cached and does not overwrite page 1 cache
        let fetchedSearch = try await client.fetchEntries(path: "/discover", page: 1, query: "swift")
        #expect(fetchedSearch.entries.first?.id == 30)
        #expect(client.cachedEntries(path: "/discover", page: 1, query: "swift") == nil)
        #expect(client.cachedEntries(path: "/discover?q=swift") == nil)
        #expect(client.cachedEntries(path: "/discover")?.entries.first?.id == 10)
    }

    @Test("Views draw cached content on first paint and replace in place when live endpoint responds, and logout clears caches")
    @MainActor
    func testFirstPaintCacheAndInPlaceReplacementAndLogout() async throws {
        let suiteName = "macreply.firstpaint.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        final class MockLiveProtocol: URLProtocol, @unchecked Sendable {
            nonisolated(unsafe) static var feedContent: String = "Live feed post"

            override class func canInit(with request: URLRequest) -> Bool { true }
            override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

            override func startLoading() {
                let url = request.url!
                let author = SubUser(username: "lucian", fullName: "Lucian", firstName: "Lucian")
                let liveEntry = SubEntry(id: 101, content: Self.feedContent, createdBy: author)
                let response = PaginatedEntriesResponse(page: 1, entries: [liveEntry])
                let data = (try? JSONEncoder().encode(response)) ?? Data("{}".utf8)
                let http = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            }

            override func stopLoading() {}
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockLiveProtocol.self]
        let session = URLSession(configuration: config)
        let cache = EndpointCache(defaults: defaults)
        let apiClient = APIClient(baseURLString: "https://subreply.com/api", token: "tok", session: session, cache: cache)

        let author = SubUser(username: "lucian", fullName: "Lucian", firstName: "Lucian")
        let cachedEntry = SubEntry(id: 100, content: "Cached first paint post", createdBy: author)
        cache.store(PaginatedEntriesResponse(page: 1, entries: [cachedEntry]), forPath: "/trending")
        cache.store(PaginatedUsersResponse(page: 1, entries: [author]), forPath: "/people")
        cache.store(MemberResponse(member: author), forPath: "/lucian")
        cache.store(PaginatedEntriesResponse(page: 1, entries: [cachedEntry]), forPath: "/lucian/posts")
        cache.store(ReplyDetailResponse(entry: cachedEntry, ancestors: [], kids: [], duplicate: false), forPath: "/reply/100")
        cache.store(PaginatedChatsResponse(page: 1, entries: []), forPath: "/messages")

        let state = AppState(defaults: defaults, apiClient: apiClient)
        let feedView = FeedView(section: .trending).environmentObject(state)
        let host = NSHostingView(rootView: feedView)
        host.frame = NSRect(x: 0, y: 0, width: 600, height: 600)

        // First paint before async network task completes still has cached data available synchronously
        #expect(state.apiClient.cachedEntries(path: "/trending")?.entries.first?.content == "Cached first paint post")
        host.layoutSubtreeIfNeeded()

        // Once live endpoint finishes, cache is updated in place with live data
        let liveFetched = try await state.apiClient.fetchEntries(path: "/trending", page: 1)
        #expect(liveFetched.entries.first?.content == "Live feed post")
        #expect(state.apiClient.cachedEntries(path: "/trending")?.entries.first?.content == "Live feed post")

        // Logging out clears all endpoint caches in memory and UserDefaults
        state.logout()
        #expect(state.apiClient.cachedEntries(path: "/trending") == nil)
        #expect(state.apiClient.cachedUsers(path: "/people") == nil)
        #expect(state.apiClient.cachedMemberDetail(username: "lucian") == nil)
        #expect(state.apiClient.cachedMemberPosts(username: "lucian") == nil)
        #expect(state.apiClient.cachedReplyDetail(id: 100) == nil)
        #expect(state.apiClient.cachedMessages() == nil)
        let remainingCacheKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(EndpointCache.keyPrefix) }
        #expect(remainingCacheKeys.isEmpty)
    }
}
