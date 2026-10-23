import Testing
import Foundation
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
                    "timestamp": "10m",
                    "parent": null,
                    "kids": [
                        {"id": 106, "content": "Kid 6", "created_by": {"username": "u6", "full_name": "U6"}, "saved": false, "timestamp": "1m"},
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
        #expect(entry.hasExplicitNullParent == true)
        #expect(entry.parent == nil)
        #expect(entry.replyCount == 6)
        #expect(entry.replyLabel == "6 replies")
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

        let guestSections = SidebarSection.visibleSections(isAuthenticated: false)
        #expect(guestSections == [.about, .login, .register, .people, .trending, .discover])
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
}
