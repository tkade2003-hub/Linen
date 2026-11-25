import Foundation

// Tax forms integration boundary.
//
// Provider: Abound, the tax compliance API built for platforms and
// marketplaces. It provides the embedded white label W-9 component, real
// time TIN verification, and 1099 NEC generation and filing with federal
// and state authorities, with webhooks for status changes.
//
// The app never collects or stores a full tax ID. The W-9 step opens the
// provider component, the provider holds the form, and Linen receives only
// the status, the TIN match result, and the last 4 digits, which land in
// contractor_tax_profiles through the backend webhook handler.
//
// This stub simulates the provider round trip so the onboarding flow can be
// walked end to end. Swapping in the live client means implementing these
// three calls against the provider API with the account key held server
// side, never in the app.

enum W9Status: String {
    case notStarted = "not_started"
    case invited
    case submitted
    case verified
    case failed
}

struct FormsService {
    static func requestW9(for profileId: UUID) async -> W9Status {
        // Live: create or fetch the payee, then present the embedded W-9.
        return .submitted
    }

    static func refreshW9Status(for profileId: UUID) async -> W9Status {
        // Live: read the payee status, or rely on the webhook mirror.
        return .submitted
    }

    static func filingSummary(taxYear: Int) -> String {
        // A 1099 NEC is filed for each contractor paid at or over the IRS
        // threshold for the year, 600 dollars through 2025 and 2,000
        // dollars for payments made in 2026 and later, due January 31.
        return "1099 NEC forms for \(taxYear) are prepared from payout totals and filed through the forms provider each January."
    }
}
