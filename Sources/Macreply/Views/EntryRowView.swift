import SwiftUI
import AppKit

public struct RichContentView: View {
    @EnvironmentObject private var appState: AppState
    public let author: SubUser?
    public let content: String
    public var fontSize: CGFloat = 14
    public var singleLine: Bool = false

    @State private var viewWidth: CGFloat = SubTheme.contentWidth
    @State private var isHoveringLink: Bool = false

    public init(
        author: SubUser? = nil,
        content: String,
        fontSize: CGFloat = 14,
        singleLine: Bool = false
    ) {
        self.author = author
        self.content = content
        self.fontSize = fontSize
        self.singleLine = singleLine
    }

    public var body: some View {
        let attributed = buildAttributedString()
        Text(attributed)
            .font(.system(size: fontSize))
            .lineSpacing(3)
            .lineLimit(singleLine ? 1 : nil)
            .truncationMode(.tail)
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
                    let overLink = isLocationOverLink(location, in: attributed, width: viewWidth)
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
            .modifier(ConditionalLinkPointerModifier(isLink: isHoveringLink))
            .environment(\.openURL, OpenURLAction { url in
                handleURL(url)
            })
    }

    private func buildAttributedString() -> AttributedString {
        var attributed = AttributedString()

        if let author {
            var authorAttr = AttributedString(author.fullName + " ")
            authorAttr.font = .system(size: fontSize, weight: .bold)
            authorAttr.foregroundColor = .primary
            if let url = URL(string: "macreply://member/\(author.username)") {
                authorAttr.link = url
            }
            attributed.append(authorAttr)
        }

        let tokens = ContentParser.tokenize(content)
        for token in tokens {
            switch token {
            case .text(let str):
                var part = AttributedString(str)
                part.foregroundColor = .primary
                attributed.append(part)

            case .mention(let prefix, let username, let suffix):
                if !prefix.isEmpty {
                    attributed.append(AttributedString(prefix))
                }
                var handle = AttributedString("@\(username)")
                handle.foregroundColor = SubTheme.accent
                if let url = URL(string: "macreply://member/\(username)") {
                    handle.link = url
                }
                attributed.append(handle)
                if !suffix.isEmpty {
                    attributed.append(AttributedString(suffix))
                }

            case .replyRef(let prefix, let id, let suffix):
                if !prefix.isEmpty {
                    attributed.append(AttributedString(prefix))
                }
                var ref = AttributedString("#\(id)")
                ref.foregroundColor = SubTheme.accent
                if let url = URL(string: "macreply://reply/\(id)") {
                    ref.link = url
                }
                attributed.append(ref)
                if !suffix.isEmpty {
                    attributed.append(AttributedString(suffix))
                }

            case .hashtag(let prefix, let tag, let suffix):
                if !prefix.isEmpty {
                    attributed.append(AttributedString(prefix))
                }
                var hash = AttributedString("#\(tag)")
                hash.foregroundColor = SubTheme.accent
                if let encoded = tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                   let url = URL(string: "macreply://hashtag/\(encoded)") {
                    hash.link = url
                }
                attributed.append(hash)
                if !suffix.isEmpty {
                    attributed.append(AttributedString(suffix))
                }

            case .link(let prefix, let rawURL, let display, let suffix):
                if !prefix.isEmpty {
                    attributed.append(AttributedString(prefix))
                }
                var linkPart = AttributedString(display)
                linkPart.foregroundColor = SubTheme.accent
                if let url = URL(string: rawURL) {
                    linkPart.link = url
                }
                attributed.append(linkPart)
                if !suffix.isEmpty {
                    attributed.append(AttributedString(suffix))
                }
            }
        }

        return attributed
    }

    private func isLocationOverLink(_ point: CGPoint, in attributed: AttributedString, width: CGFloat) -> Bool {
        guard width > 0 else { return false }
        let nsAttributed = NSMutableAttributedString(attributed)
        let fullRange = NSRange(location: 0, length: nsAttributed.length)
        guard fullRange.length > 0 else { return false }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3
        nsAttributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        nsAttributed.addAttribute(.font, value: NSFont.systemFont(ofSize: fontSize), range: fullRange)
        if let author {
            let authorLength = (author.fullName + " ").utf16.count
            if authorLength <= nsAttributed.length {
                nsAttributed.addAttribute(
                    .font,
                    value: NSFont.boldSystemFont(ofSize: fontSize),
                    range: NSRange(location: 0, length: authorLength)
                )
            }
        }

        let textStorage = NSTextStorage(attributedString: nsAttributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        if singleLine {
            textContainer.maximumNumberOfLines = 1
            textContainer.lineBreakMode = .byTruncatingTail
        }
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

    private func handleURL(_ url: URL) -> OpenURLAction.Result {
        guard url.scheme == "macreply" else {
            return .systemAction
        }
        let host = url.host ?? ""
        let pathComponent = url.lastPathComponent
        switch host {
        case "member":
            if !pathComponent.isEmpty {
                appState.openMember(pathComponent)
            }
        case "reply":
            if let id = Int(pathComponent) {
                appState.openReply(id)
            }
        case "hashtag":
            if !pathComponent.isEmpty {
                appState.openHashtag(pathComponent)
            }
        default:
            break
        }
        return .handled
    }
}

private struct ConditionalLinkPointerModifier: ViewModifier {
    let isLink: Bool

    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.pointerStyle(isLink ? .link : .default)
        } else {
            content
        }
    }
}

public struct InlineParentRowView: View {
    @EnvironmentObject private var appState: AppState
    public let entry: SubEntry

    public init(entry: SubEntry) {
        self.entry = entry
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Button {
                appState.openMember(entry.createdBy.username)
            } label: {
                Text(entry.createdBy.fullName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.subLink)

            Button {
                appState.openReply(entry.id)
            } label: {
                Text(entry.content)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .buttonStyle(.subLink)

            Spacer(minLength: 0)
        }
        .opacity(0.5)
        .padding(.vertical, 6)
    }
}

public struct EntryItemView: View {
    @EnvironmentObject private var appState: AppState
    @Binding public var entry: SubEntry
    public var isSummary: Bool = false
    public var isRootOverride: Bool? = nil
    public var canDeleteAsRecipient: Bool = false
    public var onDeleted: (() -> Void)? = nil

    @State private var isConfirmingDelete = false
    @State private var isDeleted = false
    @State private var deleteError = false

    public init(
        entry: Binding<SubEntry>,
        isSummary: Bool = false,
        isRootOverride: Bool? = nil,
        canDeleteAsRecipient: Bool = false,
        onDeleted: (() -> Void)? = nil
    ) {
        self._entry = entry
        self.isSummary = isSummary
        self.isRootOverride = isRootOverride
        self.canDeleteAsRecipient = canDeleteAsRecipient
        self.onDeleted = onDeleted
    }

    private var isOwnEntry: Bool {
        guard let current = appState.currentUser?.username.lowercased() else { return false }
        return entry.createdBy.username.lowercased() == current
    }

    private var isRootThread: Bool {
        if let isRootOverride {
            return isRootOverride
        }
        if entry.parent != nil {
            return false
        }
        return entry.hasExplicitNullParent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RichContentView(
                author: entry.createdBy,
                content: entry.content,
                fontSize: isSummary ? 16 : 14
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Button {
                    appState.openReply(entry.id)
                } label: {
                    HStack(spacing: 3) {
                        Text(entry.replyLabel)
                        if isRootThread {
                            Text("¬")
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(SubTheme.gray)
                }
                .buttonStyle(.subLink)

                if appState.isAuthenticated {
                    if isOwnEntry {
                        if entry.replyCount == 0 && !isDeleted {
                            Button("edit") {
                                appState.openEdit(entry)
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                            .buttonStyle(.subLink)
                        }
                    } else {
                        Button(entry.saved ? "unsave" : "save") {
                            toggleSave()
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.gray)
                        .buttonStyle(.subLink)
                    }

                    if (isOwnEntry || canDeleteAsRecipient) && entry.replyCount == 0 {
                        if isDeleted {
                            Text("deleted")
                                .font(.system(size: 13))
                                .foregroundStyle(SubTheme.silver)
                        } else if isConfirmingDelete {
                            Button("undo") {
                                isConfirmingDelete = false
                                deleteError = false
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                            .buttonStyle(.subLink)

                            Button(deleteError ? "error" : "yes") {
                                performDelete()
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(deleteError ? SubTheme.alert : SubTheme.gray)
                            .buttonStyle(.subLink)
                        } else {
                            Button("delete") {
                                isConfirmingDelete = true
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                            .buttonStyle(.subLink)
                        }
                    }
                }

                Spacer(minLength: 0)

                Button {
                    appState.openReply(entry.id)
                } label: {
                    Text(entry.timestamp)
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.silver)
                }
                .buttonStyle(.subLink)
            }
        }
        .padding(.vertical, 6)
    }

    private func toggleSave() {
        let targetState = !entry.saved
        let entryID = entry.id
        entry.saved = targetState
        Task {
            do {
                let confirmed = try await appState.apiClient.setSaved(id: entryID, save: targetState)
                entry.saved = confirmed
            } catch {
                entry.saved = !targetState
            }
        }
    }

    private func performDelete() {
        let entryID = entry.id
        Task {
            do {
                let ok = try await appState.apiClient.deleteEntry(id: entryID)
                if ok {
                    isDeleted = true
                    isConfirmingDelete = false
                    onDeleted?()
                }
            } catch {
                deleteError = true
            }
        }
    }
}

/// Mirrors `templates/common/stream.html`
public struct StreamEntryView: View {
    @Binding public var entry: SubEntry
    public var previousParentID: Int?
    public var isFirstInList: Bool

    public init(
        entry: Binding<SubEntry>,
        previousParentID: Int? = nil,
        isFirstInList: Bool = false
    ) {
        self._entry = entry
        self.previousParentID = previousParentID
        self.isFirstInList = isFirstInList
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let parent = entry.parent {
                if previousParentID != parent.id {
                    if !isFirstInList {
                        Divider().overlay(SubTheme.whitesmoke)
                    }
                    InlineParentRowView(entry: parent)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Divider().overlay(SubTheme.whitesmoke)
                    EntryItemView(
                        entry: $entry,
                        isRootOverride: false
                    )
                }
                .padding(.leading, SubTheme.indent)
            } else {
                if !isFirstInList {
                    Divider().overlay(SubTheme.whitesmoke)
                }
                EntryItemView(
                    entry: $entry,
                    isRootOverride: true
                )

                let recentKids = entry.streamKids
                if !recentKids.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(recentKids.indices, id: \.self) { index in
                            Divider().overlay(SubTheme.whitesmoke)
                            KidEntryBindingRow(
                                parentEntry: $entry,
                                kidID: recentKids[index].id,
                                canDeleteAsRecipient: true
                            )
                        }
                    }
                    .padding(.leading, SubTheme.indent)
                }
            }
        }
    }
}

public struct KidEntryBindingRow: View {
    @EnvironmentObject private var appState: AppState
    @Binding public var parentEntry: SubEntry
    public let kidID: Int
    public var canDeleteAsRecipient: Bool = false

    public var body: some View {
        if let idx = parentEntry.kids?.firstIndex(where: { $0.id == kidID }) {
            let binding = Binding<SubEntry>(
                get: { parentEntry.kids?[idx] ?? parentEntry },
                set: { newValue in
                    parentEntry.kids?[idx] = newValue
                }
            )
            let isParentAuthor = appState.currentUser?.username.lowercased() == parentEntry.createdBy.username.lowercased()
            EntryItemView(
                entry: binding,
                isRootOverride: false,
                canDeleteAsRecipient: canDeleteAsRecipient && isParentAuthor
            )
        }
    }
}
