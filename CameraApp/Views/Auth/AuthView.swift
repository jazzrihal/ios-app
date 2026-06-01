import SwiftUI

/// Minimal sign-in / sign-up screen for Supabase email+password auth.
struct AuthView: View {
    @Environment(AuthManager.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isSignUp = false

    private var authDisabled: Bool {
        let validationError = isSignUp
            ? AuthManager.signUpValidationError(email: email, password: password, username: username)
            : AuthManager.signInValidationError(email: email, password: password)
        return validationError != nil || auth.isLoading
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppStyle.Spacing.medium) {
                Spacer()

                Image("AppLogo")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(height: AppStyle.IconSize.avatarLarge * 2.4)
                    .accessibilityLabel("Pinstoria logo")

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, AppStyle.Spacing.large)
            .safeAreaInset(edge: .bottom) {
                bottomAuthSection
                    .padding(.horizontal, AppStyle.Spacing.large)
                    .padding(.bottom, AppStyle.Spacing.medium)
            }
        }
    }

    private var bottomAuthSection: some View {
        VStack(spacing: AppStyle.Spacing.medium) {
            // Keep the field stack height stable so branding does not shift when toggling modes.
            TextField("Username", text: $username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.control))
                .opacity(isSignUp ? 1 : 0)
                .allowsHitTesting(isSignUp)
                .accessibilityHidden(!isSignUp)

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

            if let error = auth.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }

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

            Button {
                var noAnimationTransaction = Transaction(animation: nil)
                noAnimationTransaction.disablesAnimations = true
                withTransaction(noAnimationTransaction) {
                    isSignUp.toggle()
                    username = ""
                    auth.errorMessage = nil
                }
            } label: {
                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }
}
