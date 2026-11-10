import SwiftUI

/// Mirrors `templates/pages/login.html` (`POST /api/login`)
public struct LoginView: View {
    @EnvironmentObject private var appState: AppState

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var errors: [String: String] = [:]
    @State private var isSubmitting: Bool = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Login")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                    Rectangle()
                        .fill(SubTheme.accent)
                        .frame(width: 10, height: 2)
                }
                .padding(.top, 5)

                HStack(alignment: .top, spacing: 7) {
                    SubFormField(
                        label: "Username or email",
                        required: true,
                        text: $username
                    ) {
                        Task { await submitLogin() }
                    }

                    SubFormField(
                        label: "Password",
                        required: true,
                        isSecure: true,
                        text: $password
                    ) {
                        Task { await submitLogin() }
                    }
                }

                ForEach(["username", "password", "general"], id: \.self) { key in
                    if let message = errors[key] {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.alert)
                    }
                }

                HStack {
                    Spacer()
                    SubSubmitButton(title: isSubmitting ? "Signing in..." : "Login") {
                        Task { await submitLogin() }
                    }
                    .disabled(isSubmitting)
                }
            }
            .subFeedContainer()
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(SubTheme.background)
    }

    private func submitLogin() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errors.removeAll()

        do {
            let (token, user) = try await appState.apiClient.login(
                username: username,
                password: password
            )
            let inferredEmail = username.contains("@") ? username.trimmingCharacters(in: .whitespaces).lowercased() : nil
            appState.applyAuthSession(token: token, user: user, email: inferredEmail)
        } catch let apiError as APIError {
            if !apiError.fieldErrors.isEmpty {
                errors = apiError.fieldErrors
            } else {
                errors["general"] = apiError.localizedDescription
            }
        } catch {
            errors["general"] = error.localizedDescription
        }
        isSubmitting = false
    }
}

/// Mirrors `templates/pages/register.html` (`POST /api/register`)
public struct RegisterView: View {
    @EnvironmentObject private var appState: AppState

    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password1: String = ""
    @State private var password2: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var emoji: String = ""
    @State private var birthday: String = ""
    @State private var location: String = ""
    @State private var errors: [String: String] = [:]
    @State private var isSubmitting: Bool = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Register")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                    Rectangle()
                        .fill(SubTheme.accent)
                        .frame(width: 10, height: 2)
                }
                .padding(.top, 5)

                HStack(alignment: .top, spacing: 7) {
                    SubFormField(label: "Username", required: true, text: $username)
                    SubFormField(label: "Email address", required: true, text: $email)
                }
                errorView(keys: ["username", "email"])

                HStack(alignment: .top, spacing: 7) {
                    SubFormField(label: "Password", required: true, isSecure: true, text: $password1)
                    SubFormField(label: "Password confirmation", required: true, isSecure: true, text: $password2)
                }
                errorView(keys: ["password"])

                HStack(alignment: .top, spacing: 7) {
                    SubFormField(label: "First name", required: true, text: $firstName)
                    SubFormField(label: "Last name", required: false, text: $lastName)
                }
                errorView(keys: ["first_name", "last_name", "full_name"])

                HStack(alignment: .top, spacing: 7) {
                    SubFormField(label: "Emoji", required: false, placeholder: ":)", text: $emoji)
                        .frame(width: 64)
                    SubFormField(label: "Birthday", required: false, placeholder: "Y-M-D", text: $birthday)
                        .frame(width: 108)
                    SubFormField(label: "Location", required: false, placeholder: "City, Country", text: $location)
                }
                errorView(keys: ["emoji", "birthday", "location", "general"])

                HStack {
                    Text("You agree with Privacy, Safety and Terms.")
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.gray)
                    Spacer()
                    SubSubmitButton(title: isSubmitting ? "Registering..." : "Register") {
                        Task { await submitRegistration() }
                    }
                    .disabled(isSubmitting)
                }
            }
            .subFeedContainer()
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(SubTheme.background)
    }

    @ViewBuilder
    private func errorView(keys: [String]) -> some View {
        ForEach(keys, id: \.self) { key in
            if let message = errors[key] {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(SubTheme.alert)
            }
        }
    }

    private func submitRegistration() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errors.removeAll()

        let payload: [String: String] = [
            "username": username,
            "email": email,
            "password1": password1,
            "password2": password2,
            "first_name": firstName,
            "last_name": lastName,
            "emoji": emoji,
            "birthday": birthday,
            "location": location
        ]

        do {
            let (token, user) = try await appState.apiClient.register(payload: payload)
            appState.applyAuthSession(token: token, user: user, email: email)
        } catch let apiError as APIError {
            if !apiError.fieldErrors.isEmpty {
                errors = apiError.fieldErrors
            } else {
                errors["general"] = apiError.localizedDescription
            }
        } catch {
            errors["general"] = error.localizedDescription
        }
        isSubmitting = false
    }
}

/// Mirrors `templates/pages/about.html` & `templates/pages/api.html`
public struct AboutView: View {
    @EnvironmentObject private var appState: AppState
    @State private var serverURL: String = ""
    @State private var savedNotice = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("About")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                    Rectangle()
                        .fill(SubTheme.accent)
                        .frame(width: 10, height: 2)
                }
                .padding(.top, 5)

                Text("Welcome to Macreply, the native macOS client for Subreply. It eliminates distractions and clutter, allowing you to focus on meaningful conversations and content sharing directly from a native sidebar and native feeds.")
                    .font(.system(size: 14))
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: 7) {
                    Text("Features and limitations")
                        .font(.system(size: 14, weight: .bold))
                    aboutRule(1, "Reverse-chronological order for all feeds")
                    Divider().overlay(SubTheme.whitesmoke)
                    aboutRule(2, "Unique name handles with emoji avatars")
                    Divider().overlay(SubTheme.whitesmoke)
                    aboutRule(3, "Unique conversation view similar to a chat interface")
                    Divider().overlay(SubTheme.whitesmoke)
                    aboutRule(4, "Light and dark themes based on macOS preference")
                    Divider().overlay(SubTheme.whitesmoke)
                    aboutRule(5, "Supports links, @mentions, #id hashrefs and #hashtags")
                    Divider().overlay(SubTheme.whitesmoke)
                    aboutRule(6, "Limited to ASCII characters and emojis")
                    Divider().overlay(SubTheme.whitesmoke)
                    aboutRule(7, "Limited to 640 characters per reply")
                    Divider().overlay(SubTheme.whitesmoke)
                    aboutRule(8, "Limited to one link, mention, hashref or hashtag per reply")
                    Divider().overlay(SubTheme.whitesmoke)
                    aboutRule(9, "No support for paragraphs, keeps conversation tidy")
                    Divider().overlay(SubTheme.whitesmoke)
                    aboutRule(10, "No popularity counters or instant gratification")
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Keeping things private")
                        .font(.system(size: 14, weight: .bold))
                    aboutRule(1, "Edit or delete your replies before they are replied to")
                    Divider().overlay(SubTheme.whitesmoke)
                    aboutRule(2, "Delete received replies before they are replied to")
                    Divider().overlay(SubTheme.whitesmoke)
                    aboutRule(3, "No redistribution of any data, private or public based on GDPR")
                }

                // Divider().overlay(SubTheme.whitesmoke)

                VStack(alignment: .leading, spacing: 7) {
                    SubFormField(
                        label: "API Server URL",
                        placeholder: "https://subreply.com/api",
                        text: $serverURL
                    )
                    HStack {
                        if savedNotice {
                            Text("Updated API Server URL.")
                                .font(.system(size: 13))
                                .foregroundStyle(SubTheme.gray)
                        }
                        Spacer()
                        SubSubmitButton(title: "Save Server") {
                            appState.updateAPIBaseURL(serverURL)
                            serverURL = appState.apiBaseURL
                            savedNotice = true
                        }
                    }
                }
            }
            .subFeedContainer()
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(SubTheme.background)
        .onAppear {
            serverURL = appState.apiBaseURL
        }
    }

    private func aboutRule(_ number: Int, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(number).")
                    .font(.system(size: 13))
                    .foregroundStyle(SubTheme.gray)
                    .frame(width: 22, alignment: .trailing)
                Text(text)
                    .font(.system(size: 14))
            }
        }
    }
}
