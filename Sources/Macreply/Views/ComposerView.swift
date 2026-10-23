import SwiftUI

/// Single-paragraph auto-expanding composer matching Subreply's `.reply` input rules:
/// - Disallows newlines (pressing Return submits)
/// - Highlights background in `--redsmoke` when length exceeds 640 characters
/// - Displays server validation errors in `--alert` (`#ff4000`)
public struct ComposerView: View {
    public let placeholder: String
    public var initialText: String = ""
    public let onSubmit: (String) async throws -> Void

    @State private var text: String = ""
    @State private var isSubmitting = false
    @State private var errorMessages: [String] = []

    public init(
        placeholder: String,
        initialText: String = "",
        onSubmit: @escaping (String) async throws -> Void
    ) {
        self.placeholder = placeholder
        self.initialText = initialText
        self.onSubmit = onSubmit
        self._text = State(initialValue: initialText)
    }

    private var isOverLimit: Bool {
        text.count > 640
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(1...8)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .padding(.trailing, text.isEmpty ? 0 : 44)
                    .background(
                        RoundedRectangle(cornerRadius: SubTheme.radius)
                            .fill(isOverLimit ? SubTheme.redsmoke : SubTheme.whitesmoke)
                    )
                    .disabled(isSubmitting)
                    .onChange(of: text) { _, newValue in
                        if newValue.contains("\n") {
                            let sanitized = newValue.replacingOccurrences(of: "\n", with: " ")
                            text = sanitized
                            submitIfReady()
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
                }
            }

            ForEach(errorMessages, id: \.self) { err in
                Text(err)
                    .font(.system(size: 13))
                    .foregroundStyle(SubTheme.alert)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 8)
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
        }
    }
}

public struct PlaceholderBannerView: View {
    public let text: String
    public var actionLabel: String? = nil
    public var onAction: (() -> Void)? = nil

    public init(text: String, actionLabel: String? = nil, onAction: (() -> Void)? = nil) {
        self.text = text
        self.actionLabel = actionLabel
        self.onAction = onAction
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let actionLabel, let onAction {
                Button(actionLabel, action: onAction)
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
    public let onSearch: () -> Void

    public init(placeholder: String, query: Binding<String>, onSearch: @escaping () -> Void) {
        self.placeholder = placeholder
        self._query = query
        self.onSearch = onSearch
    }

    public var body: some View {
        HStack(spacing: 0) {
            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .onSubmit {
                    onSearch()
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    onSearch()
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
    }
}
