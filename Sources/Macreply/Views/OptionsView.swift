import SwiftUI

/// Mirrors `templates/pages/profile.html`, `templates/pages/details.html`, and `templates/pages/account.html`
public struct OptionsView: View {
    @EnvironmentObject private var appState: AppState

    public enum Tab: String, CaseIterable {
        case profile = "Profile"
        case details = "Details"
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

    // Details fields
    @State private var github: String = ""
    @State private var instagram: String = ""
    @State private var linkedin: String = ""
    @State private var reddit: String = ""
    @State private var phoneCode: String = ""
    @State private var phoneNumber: String = ""
    @State private var paypal: String = ""
    @State private var spotify: String = ""
    @State private var xHandle: String = ""
    @State private var detailsErrors: [String: String] = [:]
    @State private var detailsStatus: String?
    @State private var isSavingDetails = false

    // Account / Server config
    @State private var serverURL: String = ""
    @State private var serverSavedNotice: Bool = false
    @State private var pollingMinutesText: String = "2"
    @State private var pollingSavedNotice: Bool = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                menuHeader

                switch selectedTab {
                case .profile:
                    profileForm
                case .details:
                    detailsForm
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
        HStack(spacing: 12) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                    profileStatus = nil
                    detailsStatus = nil
                    serverSavedNotice = false
                    pollingSavedNotice = false
                    appState.refreshNotificationsOnViewChange()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(selectedTab == tab ? Color.primary : SubTheme.silver)
                        Rectangle()
                            .fill(selectedTab == tab ? SubTheme.alert : Color.clear)
                            .frame(width: 10, height: 2)
                    }
                }
                .buttonStyle(.subLink)
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    private var profileForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                SubFormField(label: "Username", required: true, text: $username)
                SubFormField(label: "Email address", required: true, text: $email)
            }
            errorRows(for: ["username", "email"], in: profileErrors)

            HStack(alignment: .top, spacing: 8) {
                SubFormField(label: "First name", required: true, text: $firstName)
                SubFormField(label: "Last name", required: false, text: $lastName)
            }
            errorRows(for: ["first_name", "last_name", "full_name"], in: profileErrors)

            HStack(alignment: .top, spacing: 8) {
                SubFormField(label: "Emoji", required: false, placeholder: ":)", text: $emoji)
                    .frame(width: 64)
                SubFormField(label: "Birthday", required: false, placeholder: "Y-M-D", text: $birthday)
                    .frame(width: 108)
                SubFormField(label: "Location", required: false, placeholder: "City, Country", text: $location)
            }
            errorRows(for: ["emoji", "birthday", "location"], in: profileErrors)

            SubFormField(label: "Link", required: false, placeholder: "https://", text: $link)
            errorRows(for: ["link"], in: profileErrors)

            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                TextField("Bio or short description", text: $descriptionText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(2...5)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
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

    private var detailsForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                SubFormField(label: "GitHub", required: false, text: $github)
                SubFormField(label: "Instagram", required: false, text: $instagram)
            }
            errorRows(for: ["github", "instagram"], in: detailsErrors)

            HStack(alignment: .top, spacing: 8) {
                SubFormField(label: "LinkedIn", required: false, text: $linkedin)
                SubFormField(label: "Reddit", required: false, text: $reddit)
            }
            errorRows(for: ["linkedin", "reddit"], in: detailsErrors)

            HStack(alignment: .top, spacing: 8) {
                SubFormField(label: "Code", required: false, placeholder: "+1", text: $phoneCode)
                    .frame(width: 64)
                SubFormField(label: "Phone number", required: false, text: $phoneNumber)
                SubFormField(label: "PayPal", required: false, text: $paypal)
            }
            errorRows(for: ["phone", "paypal"], in: detailsErrors)

            HStack(alignment: .top, spacing: 8) {
                SubFormField(label: "Spotify", required: false, text: $spotify)
                SubFormField(label: "X", required: false, text: $xHandle)
            }
            errorRows(for: ["spotify", "x", "general"], in: detailsErrors)

            HStack {
                if let detailsStatus {
                    Text(detailsStatus)
                        .font(.system(size: 13))
                        .foregroundStyle(SubTheme.gray)
                }
                Spacer()
                SubSubmitButton(title: isSavingDetails ? "Updating..." : "Update") {
                    Task { await saveDetails() }
                }
                .disabled(isSavingDetails)
            }
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            Divider().overlay(SubTheme.whitesmoke)

            SubFormField(
                label: "Notifications polling (minutes)",
                required: false,
                placeholder: "2",
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

            Divider().overlay(SubTheme.whitesmoke)

            if appState.isAuthenticated {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
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

        github = user.social["github"] ?? ""
        instagram = user.social["instagram"] ?? ""
        linkedin = user.social["linkedin"] ?? ""
        reddit = user.social["reddit"] ?? ""
        paypal = user.social["paypal"] ?? ""
        spotify = user.social["spotify"] ?? ""
        xHandle = user.social["x"] ?? ""
        phoneCode = user.phone["code"] ?? ""
        phoneNumber = user.phone["number"] ?? ""
    }

    private func saveNotificationPolling() {
        let trimmed = pollingMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = Int(trimmed) ?? 2
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

    private func saveDetails() async {
        isSavingDetails = true
        detailsErrors.removeAll()
        detailsStatus = nil

        let payload: [String: String] = [
            "github": github,
            "instagram": instagram,
            "linkedin": linkedin,
            "reddit": reddit,
            "code": phoneCode,
            "number": phoneNumber,
            "paypal": paypal,
            "spotify": spotify,
            "x": xHandle
        ]

        do {
            let updatedUser = try await appState.apiClient.updateDetails(payload: payload)
            appState.updateCurrentUser(updatedUser)
            detailsStatus = "Details updated."
        } catch let apiError as APIError {
            if !apiError.fieldErrors.isEmpty {
                detailsErrors = apiError.fieldErrors
            } else {
                detailsErrors["general"] = apiError.localizedDescription
            }
        } catch {
            detailsErrors["general"] = error.localizedDescription
        }
        isSavingDetails = false
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
        VStack(alignment: .leading, spacing: 4) {
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
            .padding(.vertical, 6)
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

    @State private var isHovered = false

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .padding(.horizontal, 15)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: SubTheme.radius)
                        .fill(isHovered ? SubTheme.gainsboro : SubTheme.whitesmoke)
                )
        }
        .buttonStyle(.subLink)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
