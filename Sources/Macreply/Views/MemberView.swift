import SwiftUI
import AppKit

/// Mirrors `templates/common/user.html`
public struct UserRowView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    @Binding public var member: SubUser
    public var isMemberHeader: Bool = false

    public init(member: Binding<SubUser>, isMemberHeader: Bool = false) {
        self._member = member
        self.isMemberHeader = isMemberHeader
    }

    private var isSelf: Bool {
        guard let current = appState.currentUser?.username.lowercased() else { return false }
        return current == member.username.lowercased()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    appState.openMember(member.username)
                } label: {
                    (
                        Text(member.fullName)
                            .foregroundStyle(.primary)
                        + Text(" @\(member.username)")
                            .foregroundStyle(SubTheme.gray)
                    )
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                }
                .buttonStyle(.subLink)

                if appState.isAuthenticated {
                    HStack(spacing: 6) {
                        Text("•")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(SubTheme.gray)

                        if isSelf {
                            Button("logout") {
                                appState.logout()
                            }
                            .font(.system(size: 14))
                            .foregroundStyle(SubTheme.gray)
                            .buttonStyle(.subLink)
                        } else {
                            Button(member.followed ? "unfollow" : "follow") {
                                toggleFollow()
                            }
                            .font(.system(size: 14, weight: member.followed ? .regular : .medium))
                            .foregroundStyle(member.followed ? SubTheme.gray : SubTheme.accent)
                            .buttonStyle(.subLink)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
                }

                Spacer(minLength: 0)

                if isMemberHeader {
                    if appState.isAuthenticated && !isSelf {
                        Button {
                            appState.openConversation(member.username)
                        } label: {
                            Text("MESSAGE")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(SubTheme.silver)
                        }
                        .buttonStyle(.subLink)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(1)
                    }
                } else if member.createdAt > 0 {
                    Button {
                        appState.openMember(member.username)
                    } label: {
                        Text(ContentParser.timeAgo(since: member.createdAt))
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.silver)
                    }
                    .buttonStyle(.subLink)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
                }
            }

            if !member.description.isEmpty {
                RichContentView(content: member.description)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !member.link.isEmpty || !member.birthday.isEmpty || !member.location.isEmpty {
                HStack(spacing: 5) {
                    if !member.link.isEmpty, let url = URL(string: member.link) {
                        Button {
                            openURL(url)
                        } label: {
                            Text(ContentParser.hostname(from: member.link))
                                .font(.system(size: 13))
                                .foregroundStyle(SubTheme.gray)
                        }
                        .buttonStyle(.subLink)
                    }

                    if let age = ContentParser.age(from: member.birthday) {
                        Text("~ \(age)y old")
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                    }

                    if !member.cityLabel.isEmpty {
                        HStack(spacing: 3) {
                            Text("from")
                                .font(.system(size: 13))
                                .foregroundStyle(SubTheme.gray)
                            Button {
                                appState.openLocationSearch(member.cityLabel)
                            } label: {
                                Text(member.cityLabel)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(SubTheme.gray)
                            }
                            .buttonStyle(.subLink)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func toggleFollow() {
        let target = !member.followed
        let username = member.username
        member.followed = target
        Task {
            do {
                let confirmed = try await appState.apiClient.setFollowing(
                    username: username,
                    follow: target
                )
                member.followed = confirmed
            } catch {
                member.followed = !target
            }
        }
    }
}

/// Mirrors `templates/pages/regular.html` (`view == 'member'`) and `templates/common/status.html`
public struct MemberView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    public let username: String

    @State private var member: SubUser?
    @State private var entries: [SubEntry] = []
    @State private var currentPage: Int = 1
    @State private var canLoadMore: Bool = false
    @State private var isLoading: Bool = true
    @State private var isLoadingMore: Bool = false
    @State private var errorMessage: String?

    private let pageSize = 16

    public init(username: String) {
        self.username = username
    }

    public var body: some View {
        RefreshableScrollView {
            await loadMember(reset: true)
            await appState.refreshNotifications()
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                if isLoading && member == nil {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading @\(username)...")
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                    }
                    .padding(.vertical, 16)
                } else if let errorMessage, member == nil {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.alert)
                        .padding(.vertical, 12)
                } else if let member {
                    UserRowView(
                        member: Binding(
                            get: { self.member ?? member },
                            set: { self.member = $0 }
                        ),
                        isMemberHeader: true
                    )

                    let links = member.allLinks
                    if !links.isEmpty {
                        Divider().overlay(SubTheme.whitesmoke)
                        MemberLinksView(links: links)
                    }

                    if member.createdAt > 0 {
                        Divider().overlay(SubTheme.whitesmoke)
                        Text("Joined \(ContentParser.timeAgo(since: member.createdAt)) ago.")
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                            .padding(.vertical, 6)
                    }

                    if entries.isEmpty && !isLoading {
                        Divider().overlay(SubTheme.whitesmoke)
                        Text("Uh, nothing here yet.")
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .padding(.vertical, 10)
                    } else {
                        ForEach(entries.indices, id: \.self) { index in
                            let prevParentID: Int? = index > 0 ? entries[index - 1].parent?.id : nil
                            StreamEntryView(
                                entry: $entries[index],
                                previousParentID: prevParentID,
                                isFirstInList: false
                            )
                        }

                        if canLoadMore {
                            Divider().overlay(SubTheme.whitesmoke)
                            HStack {
                                Spacer()
                                Button {
                                    Task { await loadMember(reset: false) }
                                } label: {
                                    Text(isLoadingMore ? "Loading..." : "Load more")
                                        .font(.system(size: 14))
                                        .foregroundStyle(SubTheme.gray)
                                }
                                .buttonStyle(.subLink)
                                .disabled(isLoadingMore)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                        }
                    }
                }
            }
            .subFeedContainer()
        }
        .background(SubTheme.background)
        .task(id: "\(username.lowercased())-\(appState.feedRefreshTrigger.uuidString)") {
            await loadMember(reset: true)
        }
    }

    private func loadMember(reset: Bool) async {
        guard !username.isEmpty else { return }
        if reset {
            isLoading = true
            errorMessage = nil
        } else {
            isLoadingMore = true
        }

        let targetPage = reset ? 1 : currentPage + 1
        do {
            let response = try await appState.apiClient.fetchMember(
                username: username,
                page: targetPage
            )
            member = response.member
            if reset {
                entries = response.entries
            } else {
                entries.append(contentsOf: response.entries)
            }
            currentPage = response.page
            canLoadMore = response.entries.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        isLoadingMore = false
    }
}

public struct MemberLinksView: View {
    public let links: [(name: String, url: URL)]

    @State private var viewWidth: CGFloat = SubTheme.contentWidth
    @State private var isHoveringLink: Bool = false

    public init(links: [(name: String, url: URL)]) {
        self.links = links
    }

    public var body: some View {
        let attributed = buildAttributedString()
        Text(attributed)
            .font(.system(size: 13))
            .lineSpacing(3)
            .lineLimit(nil)
            .tint(SubTheme.gray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { viewWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, newWidth in
                            viewWidth = newWidth
                        }
                }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let overLink = isLocationOverLink(location, width: viewWidth)
                    if overLink != isHoveringLink {
                        isHoveringLink = overLink
                    }
                    if overLink {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                case .ended:
                    if isHoveringLink {
                        isHoveringLink = false
                        NSCursor.arrow.set()
                    }
                }
            }
            .modifier(MemberLinkPointerModifier(isLink: isHoveringLink))
            .padding(.vertical, 6)
    }

    public func buildAttributedString() -> AttributedString {
        var attributed = AttributedString("Also on ")
        attributed.font = .system(size: 13)
        attributed.foregroundColor = SubTheme.gray

        for idx in links.indices {
            if idx > 0 {
                var separator = AttributedString(idx == links.count - 1 ? " and " : ", ")
                separator.font = .system(size: 13)
                separator.foregroundColor = SubTheme.gray
                attributed.append(separator)
            }

            var linkPart = AttributedString(links[idx].name)
            linkPart.font = .system(size: 13, weight: .medium)
            linkPart.foregroundColor = SubTheme.gray
            linkPart.link = links[idx].url
            attributed.append(linkPart)
        }

        var dot = AttributedString(".")
        dot.font = .system(size: 13)
        dot.foregroundColor = SubTheme.gray
        attributed.append(dot)

        return attributed
    }

    public func isLocationOverLink(_ point: CGPoint, width: CGFloat) -> Bool {
        guard width > 0, !links.isEmpty else { return false }
        let nsAttributed = buildNSAttributedString()
        guard nsAttributed.length > 0 else { return false }

        let textStorage = NSTextStorage(attributedString: nsAttributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)

        var fraction: CGFloat = 0
        let glyphIndex = layoutManager.glyphIndex(
            for: point,
            in: textContainer,
            fractionOfDistanceThroughGlyph: &fraction
        )
        guard glyphIndex < layoutManager.numberOfGlyphs else { return false }
        let glyphRect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            in: textContainer
        )
        guard glyphRect.insetBy(dx: -2, dy: -2).contains(point) else { return false }
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        guard charIndex < textStorage.length else { return false }
        return textStorage.attribute(.link, at: charIndex, effectiveRange: nil) != nil
    }

    private func buildNSAttributedString() -> NSMutableAttributedString {
        let regularAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .regular)
        ]
        let linkAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium)
        ]

        let result = NSMutableAttributedString(string: "Also on ", attributes: regularAttrs)
        for idx in links.indices {
            if idx > 0 {
                let sep = idx == links.count - 1 ? " and " : ", "
                result.append(NSAttributedString(string: sep, attributes: regularAttrs))
            }
            var attrs = linkAttrs
            attrs[.link] = links[idx].url
            result.append(NSAttributedString(string: links[idx].name, attributes: attrs))
        }
        result.append(NSAttributedString(string: ".", attributes: regularAttrs))

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3
        result.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: result.length)
        )
        return result
    }
}

private struct MemberLinkPointerModifier: ViewModifier {
    let isLink: Bool

    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.pointerStyle(isLink ? .link : .default)
        } else {
            content
        }
    }
}
