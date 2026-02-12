import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                Button(role: .destructive) {
                    Task { await authManager.signOut() }
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("Profile")
        }
    }
}
