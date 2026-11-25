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
