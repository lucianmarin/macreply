import SwiftUI

/// Mirrors `templates/pages/profile.html` and `templates/pages/account.html`
public struct OptionsView: View {
    @EnvironmentObject private var appState: AppState

    public enum Tab: String, CaseIterable {
        case profile = "Profile"
        case account = "Account"
    }

    @State private var selectedTab: Tab = .profile

    // Profile fields
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var emoji: String = ""
    @State private var birthday: String = ""
    @State private var location: String = ""
    @State private var link: String = ""
    @State private var descriptionText: String = ""
    @State private var profileErrors: [String: String] = [:]
    @State private var profileStatus: String?
    @State private var isSavingProfile = false

    // Account / Server config
    @State private var serverURL: String = ""
    @State private var serverSavedNotice: Bool = false
    @State private var pollingMinutesText: String = "5"
    @State private var pollingSavedNotice: Bool = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                menuHeader

                switch selectedTab {
                case .profile:
                    profileForm
                case .account:
                    accountSection
                }
            }
            .subFeedContainer()
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(SubTheme.background)
        .onAppear {
            populateFromCurrentUser()
        }
        .onChange(of: appState.feedRefreshTrigger) { _, _ in
            populateFromCurrentUser()
        }
    }

    private var menuHeader: some View {
        HStack(spacing: 10) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                    profileStatus = nil
                    serverSavedNotice = false
                    pollingSavedNotice = false
                    appState.refreshNotificationsOnViewChange()
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(selectedTab == tab ? Color.primary : SubTheme.silver)
                        Rectangle()
                            .fill(selectedTab == tab ? SubTheme.accent : Color.clear)
                            .frame(width: 10, height: 2)
                    }
                }
                .buttonStyle(.subLink)
            }
            Spacer()
        }
        .padding(.vertical, 6.5)
    }

    private var profileForm: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 7) {
                SubFormField(label: "Username", required: true, text: $username)
                SubFormField(label: "Email address", required: true, text: $email)
            }
            errorRows(for: ["username", "email"], in: profileErrors)

            HStack(alignment: .top, spacing: 7) {
                SubFormField(label: "First name", required: true, text: $firstName)
                SubFormField(label: "Last name", required: false, text: $lastName)
            }
            errorRows(for: ["first_name", "last_name", "full_name"], in: profileErrors)

            HStack(alignment: .top, spacing: 7) {
                SubFormField(label: "Emoji", required: false, placeholder: ":)", text: $emoji)
                    .frame(width: 64)
                SubFormField(label: "Birthday", required: false, placeholder: "Y-M-D", text: $birthday)
                    .frame(width: 108)
                SubFormField(label: "Location", required: false, placeholder: "City, Country", text: $location)
            }
            errorRows(for: ["emoji", "birthday", "location"], in: profileErrors)

            SubFormField(label: "Link", required: false, placeholder: "https://", text: $link)
            errorRows(for: ["link"], in: profileErrors)

            VStack(alignment: .leading, spacing: 7) {
                Text("Description")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                TextField("Bio or short description", text: $descriptionText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(2...5)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6.5)
                    .background(
                        RoundedRectangle(cornerRadius: SubTheme.radius)
                            .fill(descriptionText.count > 640 ? SubTheme.redsmoke : SubTheme.whitesmoke)
                    )
            }
            errorRows(for: ["description", "general"], in: profileErrors)

            HStack {
                if let profileStatus {
                    Text(profileStatus)
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.gray)
                }
                Spacer()
                SubSubmitButton(title: isSavingProfile ? "Updating..." : "Update") {
                    Task { await saveProfile() }
                }
                .disabled(isSavingProfile)
            }
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            SubFormField(
                label: "API Base URL",
                required: false,
                placeholder: "https://subreply.com/api",
                text: $serverURL
            )

            HStack {
                if serverSavedNotice {
                    Text("Saved API endpoint.")
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.gray)
                }
                Spacer()
                SubSubmitButton(title: "Save Endpoint") {
                    appState.updateAPIBaseURL(serverURL)
                    serverURL = appState.apiBaseURL
                    serverSavedNotice = true
                }
            }

            SubFormField(
                label: "Notifications polling (minutes)",
                required: false,
                placeholder: "5",
                text: $pollingMinutesText
            ) {
                saveNotificationPolling()
            }

            HStack {
                if pollingSavedNotice {
                    Text("Saved polling interval.")
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.gray)
                }
                Spacer()
                SubSubmitButton(title: "Save Interval") {
                    saveNotificationPolling()
                }
            }

            if appState.isAuthenticated {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Signed in as @\(appState.currentUser?.username ?? "")")
                            .font(.system(size: 14, weight: .medium))
                        Text("Sign out from this Mac and clear stored Bearer token.")
                            .font(.system(size: 13))
                            .foregroundStyle(SubTheme.gray)
                    }
                    Spacer()
                    SubSubmitButton(title: "Logout") {
                        appState.logout()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func errorRows(for keys: [String], in dict: [String: String]) -> some View {
        ForEach(keys, id: \.self) { key in
            if let message = dict[key] {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(SubTheme.alert)
            }
        }
    }

    private func populateFromCurrentUser() {
        serverURL = appState.apiBaseURL
        pollingMinutesText = String(appState.notificationPollingMinutes)
        email = appState.currentUser?.email.isEmpty == false ? (appState.currentUser?.email ?? "") : appState.currentEmail
        guard let user = appState.currentUser else { return }
        username = user.username
        firstName = user.firstName
        lastName = user.lastName
        emoji = user.emoji
        birthday = user.birthday
        location = user.location
        link = user.link
        descriptionText = user.description
    }

    private func saveNotificationPolling() {
        let trimmed = pollingMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = Int(trimmed) ?? 5
        appState.updateNotificationPollingMinutes(parsed)
        pollingMinutesText = String(appState.notificationPollingMinutes)
        pollingSavedNotice = true
    }

    private func saveProfile() async {
        isSavingProfile = true
        profileErrors.removeAll()
        profileStatus = nil

        let payload: [String: String] = [
            "username": username,
            "email": email,
            "first_name": firstName,
            "last_name": lastName,
            "emoji": emoji,
            "birthday": birthday,
            "location": location,
            "link": link,
            "description": descriptionText
        ]

        do {
            let updatedUser = try await appState.apiClient.updateProfile(payload: payload)
            appState.updateCurrentUser(updatedUser, email: email)
            profileStatus = "Profile updated."
        } catch let apiError as APIError {
            if !apiError.fieldErrors.isEmpty {
                profileErrors = apiError.fieldErrors
            } else {
                profileErrors["general"] = apiError.localizedDescription
            }
        } catch {
            profileErrors["general"] = error.localizedDescription
        }
        isSavingProfile = false
    }
}

public struct SubFormField: View {
    public let label: String
    public var required: Bool = false
    public var placeholder: String = ""
    public var isSecure: Bool = false
    @Binding public var text: String
    public var onSubmit: (() -> Void)? = nil

    public init(
        label: String,
        required: Bool = false,
        placeholder: String = "",
        isSecure: Bool = false,
        text: Binding<String>,
        onSubmit: (() -> Void)? = nil
    ) {
        self.label = label
        self.required = required
        self.placeholder = placeholder
        self.isSecure = isSecure
        self._text = text
        self.onSubmit = onSubmit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 1) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                if required {
                    Text("*")
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.gray)
                }
            }

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .onSubmit { onSubmit?() }
                } else {
                    TextField(placeholder, text: $text)
                        .onSubmit { onSubmit?() }
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .padding(.horizontal, 10)
            .padding(.vertical, 6.5)
            .background(
                RoundedRectangle(cornerRadius: SubTheme.radius)
                    .fill(SubTheme.whitesmoke)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct SubSubmitButton: View {
    public let title: String
    public let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(SubTheme.background)
                .padding(.horizontal, 15)
                .padding(.vertical, 6.5)
                .background(
                    RoundedRectangle(cornerRadius: SubTheme.radius)
                        .fill(SubTheme.accent)
                )
        }
        .buttonStyle(.subLink)
    }
}
