import SwiftUI

/// Minimal sign-in / sign-up screen for Supabase email+password auth.
struct AuthView: View {
    @Environment(AuthManager.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isSignUp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: AppStyle.Spacing.large) {
                Spacer()

                // App branding
                Image(systemName: "camera.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.primary)
                Text("CameraApp")
                    .font(.largeTitle.bold())

                Spacer()

                // Form fields
                VStack(spacing: AppStyle.Spacing.medium) {
                    if isSignUp {
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.control))
                    }

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.control))

                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.control))
                }

                // Error
                if let error = auth.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                }

                // Primary action
                let authDisabled = email.isEmpty || password.isEmpty || (isSignUp && username.isEmpty) || auth.isLoading

                Button {
                    Task {
                        if isSignUp {
                            await auth.signUp(email: email, password: password, username: username)
                        } else {
                            await auth.signIn(email: email, password: password)
                        }
                    }
                } label: {
                    if auth.isLoading {
                        ProgressView()
                            .tint(Color(.systemGray))
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                    }
                }
                .buttonStyle(.appPrimary)
                .disabled(authDisabled)
                .accessibilityIdentifier("AuthActionButton")

                // Toggle mode
                Button {
                    isSignUp.toggle()
                    username = ""
                    auth.errorMessage = nil
                } label: {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, AppStyle.Spacing.large)
        }
    }
}
