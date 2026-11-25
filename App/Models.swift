import Foundation

enum Workspace: String, CaseIterable {
    case homeowner = "Homeowner"
    case pro = "Specialist Pro"
}

enum ProStatus: String {
    case none, pending, verified
}

struct Session: Equatable {
    var profileId: UUID
    var name: String
    var email: String
}

struct ServiceTier: Identifiable {
    var id = UUID()
    var name: String
    var priceCents: Int
    var minutes: Int
    var blurb: String
    var tag: String?
}

struct Specialist: Identifiable {
    var id = UUID()
    var name: String
    var rating: Double
    var cleans: Int
    var specialty: String
    var backgroundChecked: Bool
}

enum Pricing {
    static let bedroomCents = 2200
    static let bathroomCents = 2800
    static let recurringSavingPct = 15
    static let surgePct = 15

    static let tiers: [ServiceTier] = [
        ServiceTier(name: "Standard Tidy", priceCents: 11800, minutes: 120,
                    blurb: "Surface dusting, vacuuming, mopping, and kitchen and bath refresh.", tag: nil),
        ServiceTier(name: "Signature Clean", priceCents: 14800, minutes: 150,
                    blurb: "Full home clean with crisp linen bed making, mirrors, and baseboards.", tag: "Most booked"),
        ServiceTier(name: "Deep Seasonal Reset", priceCents: 21500, minutes: 240,
                    blurb: "Inside cabinets, tile grout detailing, window sills, and fixture descaling.", tag: nil)
    ]

    static let addOns: [(name: String, priceCents: Int)] = [
        ("Inside fridge", 2500),
        ("Interior oven", 3000),
        ("Laundry and fold", 2000)
    ]

    static func money(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return dollars.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "$%.0f", dollars)
            : String(format: "$%.2f", dollars)
    }

    static func duration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if m == 0 { return "\(h) hrs" }
        return "\(h).\(m == 30 ? "5" : "\(m)") hrs"
    }
}
