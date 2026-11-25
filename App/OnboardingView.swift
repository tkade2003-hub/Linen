import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    @State private var path: Workspace = .homeowner
    @State private var email: String = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Linen")
                .font(.largeTitle.bold())
            Text("Calm, trusted care for your home. Book background checked specialists in minutes, or join as a home care pro.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Picker("I am a", selection: $path) {
                ForEach(Workspace.allCases, id: \.self) { ws in
                    Text(ws.rawValue).tag(ws)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            TextField("Email address", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

            Button {
                store.signIn(email: email, path: path)
            } label: {
                Text("Continue as \(path.rawValue)")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .disabled(email.isEmpty)

            Text("By continuing, you agree to Linen Terms and Privacy Policy.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

struct ProGateView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 44))
            Text("Pro verification")
                .font(.title2.bold())
            Text(store.proStatus == .pending
                 ? "Your application is in review. We check identity, background, and payout details before the Pro workspace opens."
                 : "The Pro workspace opens after identity, background check, and payout setup are complete.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            if store.proStatus == .none {
                Button("Start pro application") { store.applyForPro() }
                    .buttonStyle(.borderedProminent)
            }
            Button("Use the homeowner side instead") { store.switchWorkspace(to: .homeowner) }
                .buttonStyle(.bordered)
            Button("Sign out", role: .destructive) { store.signOut() }
        }
        .padding()
    }
}
