import SwiftUI
import AppKit

/// Single-paragraph auto-expanding composer matching Subreply's `.reply` input rules:
/// - Disallows newlines (pressing Return submits)
/// - Caps input at 720 characters maximum
/// - Highlights background in `--redsmoke` when length exceeds 640 characters
/// - Displays server validation errors in `--alert` (`#ff4500`)
public struct ComposerView: View {
    public static let warningCharacterLimit = 640
    public static let maxCharacterLimit = 720

    public let placeholder: String
    public var initialText: String = ""
    public var focusTrigger: UUID = UUID()
    public let onSubmit: (String) async throws -> Void

    @State private var text: String = ""
    @State private var isSubmitting = false
    @State private var errorMessages: [String] = []
    @State private var composerHeight: CGFloat = 0
    @State private var scrollAnchorView: NSView?
    @FocusState private var isFocused: Bool

    public init(
        placeholder: String,
        initialText: String = "",
        focusTrigger: UUID = UUID(),
        onSubmit: @escaping (String) async throws -> Void
    ) {
        self.placeholder = placeholder
        let clampedInitial = Self.clamp(initialText)
        self.initialText = clampedInitial
        self.focusTrigger = focusTrigger
        self.onSubmit = onSubmit
        self._text = State(initialValue: clampedInitial)
    }

    public static func clamp(_ input: String) -> String {
        guard input.count > maxCharacterLimit else { return input }
        return String(input.prefix(maxCharacterLimit))
    }

    private var isOverLimit: Bool {
        text.count > Self.warningCharacterLimit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                // Hidden sizing text ensures SwiftUI recalculates multiline height immediately
                // when the window width changes (macOS TextField(axis: .vertical) caches intrinsic width).
                Text(text.isEmpty ? placeholder : (text + " "))
                    .font(.system(size: 14))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .hidden()
                    .accessibilityHidden(true)

                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(1...24)
                    .focused($isFocused)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .disabled(isSubmitting)
                    .onChange(of: text) { _, newValue in
                        if newValue.contains("\n") {
                            let sanitized = Self.clamp(newValue.replacingOccurrences(of: "\n", with: " "))
                            text = sanitized
                            submitIfReady()
                            return
                        }
                        if newValue.count > Self.maxCharacterLimit {
                            text = Self.clamp(newValue)
                            return
                        }
                        if isFocused {
                            reflowAndHideInternalTextScrollbars()
                            scrollComposerIntoView()
                        }
                    }
                    .onSubmit {
                        submitIfReady()
                    }

                if !text.isEmpty {
                    Text("\(text.count)")
                        .font(.system(size: 11, weight: isOverLimit ? .bold : .regular))
                        .foregroundStyle(isOverLimit ? SubTheme.alert : SubTheme.gray)
                        .padding(.trailing, 8)
                        .padding(.bottom, 6)
                        .allowsHitTesting(false)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: SubTheme.radius)
                    .fill(isOverLimit ? SubTheme.redsmoke : SubTheme.whitesmoke)
            )

            ForEach(errorMessages, id: \.self) { err in
                Text(err)
                    .font(.system(size: 13))
                    .foregroundStyle(SubTheme.alert)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 8)
        .onAppear {
            requestFocus()
        }
        .onChange(of: placeholder) { _, _ in
            requestFocus()
        }
        .onChange(of: focusTrigger) { _, _ in
            requestFocus()
        }
        .background(
            GeometryReader { geo in
                ComposerScrollAnchorBridge { nsView in
                    if scrollAnchorView !== nsView {
                        scrollAnchorView = nsView
                    }
                    reflowAndHideInternalTextScrollbars()
                }
                .onAppear {
                    composerHeight = geo.size.height
                    reflowAndHideInternalTextScrollbars()
                }
                .onChange(of: geo.size.width) { _, _ in
                    reflowAndHideInternalTextScrollbars()
                    if isFocused {
                        scrollComposerIntoView()
                    }
                }
                .onChange(of: geo.size.height) { oldHeight, newHeight in
                    composerHeight = newHeight
                    reflowAndHideInternalTextScrollbars()
                    if isFocused && newHeight > oldHeight {
                        scrollComposerIntoView()
                    }
                }
            }
        )
    }

    private func reflowAndHideInternalTextScrollbars() {
        guard let anchor = scrollAnchorView, let root = anchor.superview?.superview else { return }
        func configureViews(in view: NSView) {
            if let sv = view as? NSScrollView {
                sv.hasVerticalScroller = false
                sv.hasHorizontalScroller = false
                sv.verticalScroller?.alphaValue = 0
                sv.horizontalScroller?.alphaValue = 0
            }
            if let tf = view as? NSTextField {
                tf.preferredMaxLayoutWidth = max(1, tf.bounds.width)
                tf.invalidateIntrinsicContentSize()
                if let editor = tf.currentEditor() as? NSTextView {
                    editor.textContainer?.widthTracksTextView = true
                    if let tc = editor.textContainer {
                        editor.layoutManager?.ensureLayout(for: tc)
                    }
                }
            }
            if let tv = view as? NSTextView {
                tv.textContainer?.widthTracksTextView = true
                if let tc = tv.textContainer {
                    tv.layoutManager?.ensureLayout(for: tc)
                }
                tv.needsLayout = true
            }
            for sub in view.subviews {
                configureViews(in: sub)
            }
        }
        configureViews(in: root)
    }

    private func scrollComposerIntoView() {
        DispatchQueue.main.async {
            guard let anchor = scrollAnchorView,
                  let scrollView = anchor.enclosingScrollView,
                  let documentView = scrollView.documentView else {
                return
            }

            documentView.layoutSubtreeIfNeeded()
            let rectInDoc = anchor.convert(anchor.bounds, to: documentView).insetBy(dx: 0, dy: -14)
            let visibleRect = scrollView.contentView.documentVisibleRect

            if rectInDoc.maxY > visibleRect.maxY {
                var targetOrigin = visibleRect.origin
                targetOrigin.y += (rectInDoc.maxY - visibleRect.maxY)
                let maxOffsetY = max(0, documentView.bounds.height - visibleRect.height)
                targetOrigin.y = min(max(0, targetOrigin.y), maxOffsetY)

                let previousScrollerState = scrollView.hasVerticalScroller
                scrollView.hasVerticalScroller = false
                scrollView.verticalScroller?.alphaValue = 0
                scrollView.contentView.scroll(to: targetOrigin)
                scrollView.reflectScrolledClipView(scrollView.contentView)
                DispatchQueue.main.async {
                    scrollView.hasVerticalScroller = previousScrollerState
                    scrollView.verticalScroller?.alphaValue = 1
                }
            }
        }
    }

    private func submitIfReady() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSubmitting else { return }
        isSubmitting = true
        errorMessages.removeAll()

        Task {
            do {
                try await onSubmit(trimmed)
                text = ""
                errorMessages.removeAll()
            } catch let apiError as APIError {
                let errs = apiError.fieldErrors
                if !errs.isEmpty {
                    errorMessages = Array(errs.values)
                } else if let desc = apiError.errorDescription {
                    errorMessages = [desc]
                }
            } catch {
                errorMessages = [error.localizedDescription]
            }
            isSubmitting = false
            requestFocus()
        }
    }

    private func requestFocus() {
        isFocused = true
        DispatchQueue.main.async {
            isFocused = true
        }
    }
}

private struct ComposerScrollAnchorBridge: NSViewRepresentable {
    let onUpdate: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onUpdate(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onUpdate(nsView)
        }
    }
}

public struct PlaceholderBannerView: View {
    public let text: String
    public var actionLabel: String? = nil
    public var onAction: (() -> Void)? = nil
    public var secondaryActionLabel: String? = nil
    public var onSecondaryAction: (() -> Void)? = nil

    public init(
        text: String,
        actionLabel: String? = nil,
        onAction: (() -> Void)? = nil,
        secondaryActionLabel: String? = nil,
        onSecondaryAction: (() -> Void)? = nil
    ) {
        self.text = text
        self.actionLabel = actionLabel
        self.onAction = onAction
        self.secondaryActionLabel = secondaryActionLabel
        self.onSecondaryAction = onSecondaryAction
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let actionLabel, let onAction {
                Button(actionLabel, action: onAction)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .buttonStyle(.subLink)
            }
            if let secondaryActionLabel, let onSecondaryAction {
                Text("or")
                    .font(.system(size: 14))
                    .foregroundStyle(SubTheme.gray)
                Button(secondaryActionLabel, action: onSecondaryAction)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .buttonStyle(.subLink)
            }
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(SubTheme.gray)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [SubTheme.whitesmoke, SubTheme.background],
                startPoint: .leading,
                endPoint: .trailing
            )
            .clipShape(RoundedRectangle(cornerRadius: SubTheme.radius))
        )
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}

/// Mirrors `templates/input/query.html` for `/people` and `/discover`
public struct SearchQueryBar: View {
    public let placeholder: String
    @Binding public var query: String
    public var focusTrigger: UUID = UUID()
    public let onSearch: () -> Void

    @FocusState private var isFocused: Bool

    public init(
        placeholder: String,
        query: Binding<String>,
        focusTrigger: UUID = UUID(),
        onSearch: @escaping () -> Void
    ) {
        self.placeholder = placeholder
        self._query = query
        self.focusTrigger = focusTrigger
        self.onSearch = onSearch
    }

    public var body: some View {
        HStack(spacing: 0) {
            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($isFocused)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .onSubmit {
                    onSearch()
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    onSearch()
                    requestFocus()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.gray)
                }
                .buttonStyle(.subLink)
                .padding(.trailing, 6)
            }

            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 29)
            }
            .buttonStyle(.subLink)
            .padding(.trailing, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: SubTheme.radius)
                .fill(SubTheme.whitesmoke)
        )
        .padding(.top, 6)
        .padding(.bottom, 8)
        .onAppear {
            requestFocus()
        }
        .onChange(of: placeholder) { _, _ in
            requestFocus()
        }
        .onChange(of: focusTrigger) { _, _ in
            requestFocus()
        }
    }

    private func requestFocus() {
        isFocused = true
        DispatchQueue.main.async {
            isFocused = true
        }
    }
}
