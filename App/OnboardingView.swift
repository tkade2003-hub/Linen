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
    @State private var showOnboarding = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Verified and Insured Pro", systemImage: "checkmark.shield")
                        .font(.headline)
                    Text(store.proStatus == .pending
                         ? "Your application is in review. We check identity, background, and payout details before the Pro workspace opens."
                         : "Finish contractor onboarding to open the Pro workspace. Specialists are 1099 independent contractors.")
                        .foregroundStyle(.secondary)
                }
                Section("Contractor onboarding") {
                    ForEach(OnboardingStep.allCases) { step in
                        HStack {
                            Image(systemName: store.completedSteps.contains(step) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(store.completedSteps.contains(step) ? .green : .secondary)
                            Text(step.title)
                        }
                    }
                    if store.proStatus == .none {
                        Button(store.completedSteps.isEmpty ? "Start contractor onboarding" : "Continue contractor onboarding") {
                            showOnboarding = true
                        }
                    }
                    if store.onboardingComplete && store.proStatus == .none {
                        Button("Submit for review") { store.submitForReview() }
                            .bold()
                    }
                    if let last4 = store.tinLast4 {
                        Text("W-9 on file, tax ID ending \(last4)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if store.proStatus == .pending {
                    Section("Stage demo") {
                        Button("Simulate approval") { store.simulateApproval() }
                    }
                }
                Section {
                    Button("Use the homeowner side instead") { store.switchWorkspace(to: .homeowner) }
                    Button("Sign out", role: .destructive) { store.signOut() }
                }
            }
            .navigationTitle("Pro verification")
            .sheet(isPresented: $showOnboarding) { ContractorOnboardingView() }
        }
    }
}
