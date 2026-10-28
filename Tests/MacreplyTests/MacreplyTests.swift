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
        #expect(entry.createdBy.allLinks.map(\.name) == ["GitHub", "Telephone", "X"])
    }

    @Test("Sidebar sections match Subreply authenticated and guest states")
    func testSidebarSections() {
        let authSections = SidebarSection.visibleSections(isAuthenticated: true)
        #expect(authSections.first == .feed)
        #expect(authSections.contains(.mentions))
        #expect(authSections.contains(.messages))
        #expect(authSections.contains(.options))
        #expect(!authSections.contains(.login))

        #expect(SidebarSection.following.systemImage == "arrow.turn.left.up")
        #expect(SidebarSection.followers.systemImage == "arrow.turn.right.down")

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
        #expect(state.notificationPollingMinutes == 2)

        state.updateNotificationPollingMinutes(5)
        #expect(state.notificationPollingMinutes == 5)
        #expect(defaults.integer(forKey: "macreply.config.notificationPollingMinutes") == 5)

        state.notifications = SubNotifications(followers: 2, mentions: 3, replies: 4, messages: 1)
        #expect(state.notifications.total == 10)
        #expect(state.dockBadgeLabel == "10")
        #expect(NSApplication.shared.dockTile.badgeLabel == "10")

        state.clearNotificationCount(for: .mentions)
        #expect(state.notifications.total == 7)
        #expect(state.dockBadgeLabel == "7")
        #expect(NSApplication.shared.dockTile.badgeLabel == "7")

        state.logout()
        #expect(state.notifications.total == 0)
        #expect(state.dockBadgeLabel == nil)
        #expect(NSApplication.shared.dockTile.badgeLabel == nil)
    }

    @MainActor
    @Test("Member header shows MESSAGE action for logged-in user's own profile")
    func testSelfMemberHeaderShowsMessageButton() {
        let suiteName = "macreply.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = AppState(defaults: defaults)
        let selfUser = SubUser(username: "lucian", fullName: "Lucian Marin", firstName: "Lucian")
        state.token = "test-token"
        state.currentUser = selfUser

        let row = UserRowView(member: .constant(selfUser), isMemberHeader: true)
            .environmentObject(state)
            .frame(width: 640)

        let host = NSHostingView(rootView: row)
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize.height > 0)

        state.openConversation(selfUser.username)
        #expect(state.navigationPath == [.conversation("lucian")])
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
        #expect(links.map(\.name) == ["GitHub", "Instagram", "LinkedIn", "PayPal", "Spotify", "Telephone", "X"])

        let view = MemberLinksView(links: links)
        let plainText = String(view.buildAttributedString().characters)
        #expect(plainText == "Also on GitHub, Instagram, LinkedIn, PayPal, Spotify, Telephone and X.")

        let wideHost = NSHostingView(rootView: view.frame(width: 640))
        wideHost.layoutSubtreeIfNeeded()
        let wideHeight = wideHost.fittingSize.height

        let narrowHost = NSHostingView(rootView: view.frame(width: 320))
        narrowHost.layoutSubtreeIfNeeded()
        let narrowHeight = narrowHost.fittingSize.height

        #expect(narrowHeight > wideHeight)
        #expect(narrowHeight < 65)
    }

    @Test("AppIcon renders macOS squircle icon from icon.svg specifications")
    func testAppIconGeneration() throws {
        let pngData = try #require(AppIcon.renderPNGData(pixelSize: 256))
        #expect(!pngData.isEmpty)
        let image = AppIcon.loadOrRenderImage()
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
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
}
