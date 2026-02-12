import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        NavigationStack {
            Group {
                if let user = authManager.currentProfile {
                    profileContent(user: user)
                } else {
                    ProgressView("Loading profile…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Profile")
        }
    }

    // MARK: - Content

    private func profileContent(user: User) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                profileHeader(user: user)
                statsSection(user: user)
                bioSection(user: user)
                logOutButton
            }
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Profile Header

    private func profileHeader(user: User) -> some View {
        VStack(spacing: 14) {
            AvatarView(user: user, size: 96)
                .shadow(color: user.gradientColors.first?.opacity(0.3) ?? .clear, radius: 12, y: 4)

            VStack(spacing: 4) {
                Text(user.displayName)
                    .font(.title2.weight(.bold))

                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text("Joined \(user.joinDateFormatted)")
                    .font(.caption)
            }
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Stats

    private func statsSection(user: User) -> some View {
        HStack(spacing: 0) {
            statItem(value: "\(user.postCount)", label: "Posts")
            Divider()
                .frame(height: 36)
            statItem(value: "\(user.friendCount)", label: "Friends")
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bio

    private func bioSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("About", systemImage: "text.quote")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(user.bio.isEmpty ? "No bio yet." : user.bio)
                .font(.subheadline)
                .foregroundStyle(user.bio.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Log Out

    private var logOutButton: some View {
        Button {
            Task { await authManager.signOut() }
        } label: {
            Text("Log Out")
                .font(.footnote)
                .foregroundStyle(.red)
        }
        .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .environment(AuthManager())
}
