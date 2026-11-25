import Foundation
import SwiftUI

final class AppStore: ObservableObject {
    @Published var session: Session? = nil
    @Published var workspace: Workspace = .homeowner
    @Published var proStatus: ProStatus = .none
    @Published var signInPath: Workspace = .homeowner
    @Published var isOnline: Bool = true
    @Published var completedSteps: Set<OnboardingStep> = []
    @Published var tinLast4: String? = nil
    @Published var availability: [DayAvailability] = DayAvailability.defaults
    @Published var autoAcceptRepeats: Bool = true

    // Live backend context. The app session fills these in at sign in:
    // authToken is the session JWT the database checks on every request,
    // currentUserId is the profile id the tables store as text, and
    // liveBookingId is the booking the tracking and messaging screens
    // stream for. All stay nil in the demo flow, where the screens run
    // on the sample data they shipped with.
    @Published var authToken: String? = nil
    @Published var currentUserId: String? = nil
    @Published var liveBookingId: UUID? = nil
    @Published var liveBookingStatus: String? = nil
    @Published var liveSpecialistId: String? = nil
    let locationPublisher = LocationPublisher()

    var backend: SupabaseClient { SupabaseClient(token: authToken) }
    var isLive: Bool { liveBookingId != nil && authToken != nil }

    var onboardingComplete: Bool {
        completedSteps.count == OnboardingStep.allCases.count
    }

    func completeStep(_ step: OnboardingStep) {
        completedSteps.insert(step)
    }

    func submitForReview() {
        guard onboardingComplete else { return }
        proStatus = .pending
    }

    // Stage demo only: simulates the review clearing. Remove before launch.
    func simulateApproval() {
        proStatus = .verified
        workspace = .pro
    }

    func signIn(email: String, path: Workspace) {
        session = Session(profileId: UUID(), name: "Sarah Jenkins", email: email)
        signInPath = path
        if path == .pro {
            // Pro sign in lands on the onboarding gate until verification clears.
            workspace = .pro
        } else {
            workspace = .homeowner
        }
    }

    func applyForPro() {
        proStatus = .pending
    }

    func switchWorkspace(to next: Workspace) {
        workspace = next
    }

    func signOut() {
        session = nil
        workspace = .homeowner
    }
}
