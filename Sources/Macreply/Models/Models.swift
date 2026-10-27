import Foundation

public struct SubUser: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: String { username }
    public var followed: Bool
    public var follows: Bool
    public var username: String
    public var email: String
    public var fullName: String
    public var firstName: String
    public var lastName: String
    public var createdAt: Double
    public var seenAt: Double
    public var donated: Double
    public var timestamp: String
    public var emoji: String
    public var birthday: String
    public var location: String
    public var link: String
    public var description: String
    public var phone: [String: String]
    public var social: [String: String]

    enum CodingKeys: String, CodingKey {
        case followed
        case follows
        case username
        case email
        case fullName = "full_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case createdAt = "created_at"
        case seenAt = "seen_at"
        case donated
        case timestamp
        case emoji
        case birthday
        case location
        case link
        case description
        case phone
        case social
    }

    public init(
        followed: Bool = false,
        follows: Bool = false,
        username: String,
        email: String = "",
        fullName: String,
        firstName: String,
        lastName: String = "",
        createdAt: Double = 0,
        seenAt: Double = 0,
        donated: Double = 0,
        timestamp: String = "",
        emoji: String = "",
        birthday: String = "",
        location: String = "",
        link: String = "",
        description: String = "",
        phone: [String: String] = [:],
        social: [String: String] = [:]
    ) {
        self.followed = followed
        self.follows = follows
        self.username = username
        self.email = email
        self.fullName = fullName
        self.firstName = firstName
        self.lastName = lastName
        self.createdAt = createdAt
        self.seenAt = seenAt
        self.donated = donated
        self.timestamp = timestamp
        self.emoji = emoji
        self.birthday = birthday
        self.location = location
        self.link = link
        self.description = description
        self.phone = phone
        self.social = social
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.followed = try container.decodeIfPresent(Bool.self, forKey: .followed) ?? false
        self.follows = try container.decodeIfPresent(Bool.self, forKey: .follows) ?? false
        self.username = try container.decode(String.self, forKey: .username)
        self.email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        self.fullName = try container.decodeIfPresent(String.self, forKey: .fullName) ?? username
        self.firstName = try container.decodeIfPresent(String.self, forKey: .firstName) ?? ""
        self.lastName = try container.decodeIfPresent(String.self, forKey: .lastName) ?? ""
        self.createdAt = try container.decodeIfPresent(Double.self, forKey: .createdAt) ?? 0
        self.seenAt = try container.decodeIfPresent(Double.self, forKey: .seenAt) ?? 0
        self.donated = try container.decodeIfPresent(Double.self, forKey: .donated) ?? 0
        self.timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp) ?? ""
        self.emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? ""
        self.birthday = try container.decodeIfPresent(String.self, forKey: .birthday) ?? ""
        self.location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        self.link = try container.decodeIfPresent(String.self, forKey: .link) ?? ""
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.phone = try container.decodeIfPresent([String: String].self, forKey: .phone) ?? [:]
        self.social = try container.decodeIfPresent([String: String].self, forKey: .social) ?? [:]
    }

    public var allLinks: [(name: String, url: URL)] {
        var combined = social
        if let code = phone["code"], let number = phone["number"], !code.isEmpty, !number.isEmpty {
            combined["telephone"] = code + number
        }
        let templates: [String: (String, String)] = [
            "dribbble": ("Dribbble", "https://dribbble.com/%@"),
            "github": ("GitHub", "https://github.com/%@"),
            "instagram": ("Instagram", "https://instagram.com/%@"),
            "linkedin": ("LinkedIn", "https://linkedin.com/in/%@"),
            "patreon": ("Patreon", "https://patreon.com/%@"),
            "paypal": ("PayPal", "https://paypal.me/%@"),
            "pinboard": ("Pinboard", "https://pinboard.in/u:%@/"),
            "reddit": ("Reddit", "https://reddit.com/u/%@"),
            "soundcloud": ("SoundCloud", "https://soundcloud.com/%@"),
            "spotify": ("Spotify", "https://open.spotify.com/user/%@"),
            "telegram": ("Telegram", "https://t.me/%@"),
            "telephone": ("Telephone", "tel:%@"),
            "twitter": ("Twitter", "https://twitter.com/%@"),
            "x": ("X", "https://x.com/%@"),
            "youtube": ("YouTube", "https://youtube.com/@%@")
        ]
        return combined.keys.sorted().compactMap { key in
            guard let handle = combined[key], !handle.isEmpty,
                  let (label, format) = templates[key],
                  let url = URL(string: String(format: format, handle)) else {
                return nil
            }
            return (name: label, url: url)
        }
    }

    public var cityLabel: String {
        guard !location.isEmpty else { return "" }
        if let commaIndex = location.firstIndex(of: ",") {
            return String(location[..<commaIndex]).trimmingCharacters(in: .whitespaces)
        }
        return location
    }
}

public final class SubEntryBox: Codable, Equatable, Hashable, Sendable {
    public let value: SubEntry

    public init(_ value: SubEntry) {
        self.value = value
    }

    public static func == (lhs: SubEntryBox, rhs: SubEntryBox) -> Bool {
        lhs.value == rhs.value
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(SubEntry.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

public struct SubEntry: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: Int
    public var content: String
    public var createdBy: SubUser
    public var saved: Bool
    public var edited: Bool
    public var replies: Int?
    public var timestamp: String
    private var parentBox: SubEntryBox?
    public var hasExplicitNullParent: Bool
    public var kids: [SubEntry]?

    public var parent: SubEntry? {
        get { parentBox?.value }
        set { parentBox = newValue.map(SubEntryBox.init) }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case createdBy = "created_by"
        case saved
        case edited
        case replies
        case timestamp
        case parent
        case kids
    }

    public init(
        id: Int,
        content: String,
        createdBy: SubUser,
        saved: Bool = false,
        edited: Bool = false,
        replies: Int? = nil,
        timestamp: String = "now",
        parent: SubEntry? = nil,
        hasExplicitNullParent: Bool = false,
        kids: [SubEntry]? = nil
    ) {
        self.id = id
        self.content = content
        self.createdBy = createdBy
        self.saved = saved
        self.edited = edited
        self.replies = replies
        self.timestamp = timestamp
        self.parentBox = parent.map(SubEntryBox.init)
        self.hasExplicitNullParent = hasExplicitNullParent
        self.kids = kids
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.content = try container.decode(String.self, forKey: .content)
        self.createdBy = try container.decode(SubUser.self, forKey: .createdBy)
        self.saved = try container.decodeIfPresent(Bool.self, forKey: .saved) ?? false
        self.edited = try container.decodeIfPresent(Bool.self, forKey: .edited) ?? false
        self.replies = try container.decodeIfPresent(Int.self, forKey: .replies)
        self.timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp) ?? ""
        if container.contains(.parent) {
            if try container.decodeNil(forKey: .parent) {
                self.parentBox = nil
                self.hasExplicitNullParent = true
            } else {
                let decodedParent = try container.decode(SubEntry.self, forKey: .parent)
                self.parentBox = SubEntryBox(decodedParent)
                self.hasExplicitNullParent = false
            }
        } else {
            self.parentBox = nil
            self.hasExplicitNullParent = false
        }
        self.kids = try container.decodeIfPresent([SubEntry].self, forKey: .kids)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(createdBy, forKey: .createdBy)
        try container.encode(saved, forKey: .saved)
        try container.encode(edited, forKey: .edited)
        try container.encodeIfPresent(replies, forKey: .replies)
        try container.encode(timestamp, forKey: .timestamp)
        if let parent = parentBox?.value {
            try container.encode(parent, forKey: .parent)
        } else if hasExplicitNullParent {
            try container.encodeNil(forKey: .parent)
        }
        try container.encodeIfPresent(kids, forKey: .kids)
    }

    public var replyCount: Int {
        max(replies ?? 0, kids?.count ?? 0)
    }

    public var replyLabel: String {
        let count = replyCount
        if count == 0 {
            return "reply"
        } else if count == 1 {
            return "1 reply"
        } else {
            return "\(count) replies"
        }
    }

    /// Chronological 5-most-recent replies as displayed in Subreply's `stream.html` (`entry.kids.all()[:5] | reverse`)
    public var streamKids: [SubEntry] {
        guard let kids, !kids.isEmpty else { return [] }
        return Array(kids.prefix(5).reversed())
    }
}

public struct SubChat: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: Int
    public var content: String
    public var createdBy: SubUser
    public var toUser: SubUser
    public var seen: Bool
    public var timestamp: String

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case createdBy = "created_by"
        case toUser = "to_user"
        case seen
        case timestamp
    }

    public init(
        id: Int,
        content: String,
        createdBy: SubUser,
        toUser: SubUser,
        seen: Bool = false,
        timestamp: String
    ) {
        self.id = id
        self.content = content
        self.createdBy = createdBy
        self.toUser = toUser
        self.seen = seen
        self.timestamp = timestamp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.content = try container.decode(String.self, forKey: .content)
        self.createdBy = try container.decode(SubUser.self, forKey: .createdBy)
        self.toUser = try container.decode(SubUser.self, forKey: .toUser)
        self.seen = try container.decodeIfPresent(Bool.self, forKey: .seen) ?? false
        self.timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp) ?? ""
    }
}

public struct SubNotifications: Codable, Equatable, Sendable {
    public var followers: Int
    public var mentions: Int
    public var replies: Int
    public var messages: Int

    public init(followers: Int = 0, mentions: Int = 0, replies: Int = 0, messages: Int = 0) {
        self.followers = followers
        self.mentions = mentions
        self.replies = replies
        self.messages = messages
    }

    public var total: Int {
        followers + mentions + replies + messages
    }

    public static func capBadge(_ value: Int) -> String {
        guard value > 0 else { return "" }
        return value > 99 ? "99+" : "\(value)"
    }
}

// MARK: - API Responses

public struct PaginatedEntriesResponse: Codable, Sendable {
    public let page: Int
    public let entries: [SubEntry]
}

public struct PaginatedUsersResponse: Codable, Sendable {
    public let page: Int
    public let entries: [SubUser]
}

public struct PaginatedChatsResponse: Codable, Sendable {
    public let page: Int
    public let blocked: Bool?
    public let entries: [SubChat]
}

public struct MemberResponse: Codable, Sendable {
    public let member: SubUser
}

public struct MemberFeedResponse: Codable, Sendable {
    public let page: Int
    public let member: SubUser
    public let entries: [SubEntry]
}

public struct ReplyDetailResponse: Codable, Sendable {
    public let entry: SubEntry
    public let ancestors: [SubEntry]
    public let kids: [SubEntry]
    public let duplicate: Bool?
}

public struct AuthResponse: Codable, Sendable {
    public let token: String?
    public let user: SubUser?
    public let errors: [String: String]?
}

public struct UserUpdateResponse: Codable, Sendable {
    public let user: SubUser?
    public let errors: [String: String]?
}

public struct ActionStatusResponse: Codable, Sendable {
    public let status: String?
    public let errors: [String: String]?
}
