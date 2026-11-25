import SwiftUI

enum OnboardingStep: String, CaseIterable, Identifiable {
    case contractorStatus
    case taxDetails
    case w9
    case agreement
    case payout
    case backgroundCheck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .contractorStatus: return "Independent contractor status"
        case .taxDetails: return "Legal and tax details"
        case .w9: return "Form W-9"
        case .agreement: return "Contractor agreement"
        case .payout: return "Payout setup"
        case .backgroundCheck: return "Background check consent"
        }
    }

    var detail: String {
        switch self {
        case .contractorStatus: return "Confirm you work as an independent contractor, not an employee."
        case .taxDetails: return "Legal name, tax classification, and mailing address for your 1099."
        case .w9: return "Complete and sign your W-9 so Linen can report your pay."
        case .agreement: return "The terms that govern jobs, pay, and ending the relationship."
        case .payout: return "Connect the bank account your contractor pay goes to."
        case .backgroundCheck: return "Consent to the identity and background check clients rely on."
        }
    }
}

struct ContractorOnboardingView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var activeStep: OnboardingStep? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Linen specialists are independent contractors. Finish these six steps once and your application goes to review. Your W-9 is collected and verified by our tax forms partner, and your 1099 is filed through the same partner each January. Linen keeps only the status and the last 4 digits of your tax ID.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section("Steps") {
                    ForEach(OnboardingStep.allCases) { step in
                        Button { activeStep = step } label: {
                            HStack {
                                Image(systemName: store.completedSteps.contains(step) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(store.completedSteps.contains(step) ? .green : .secondary)
                                VStack(alignment: .leading) {
                                    Text(step.title).foregroundStyle(.primary)
                                    Text(step.detail).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                if store.onboardingComplete && store.proStatus == .none {
                    Section {
                        Button("Submit for review") {
                            store.submitForReview()
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Contractor onboarding")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $activeStep) { step in
                StepFormView(step: step)
            }
        }
    }
}

struct StepFormView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let step: OnboardingStep

    @State private var legalName = ""
    @State private var businessName = ""
    @State private var classification = "individual"
    @State private var address = ""
    @State private var agree = false

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .contractorStatus:
                    Section {
                        Text("You provide cleaning services as an independent business. You choose which jobs to accept, set your own availability, supply your own transport, and are responsible for your own taxes. Linen does not withhold taxes from contractor pay and reports it on Form 1099 NEC each year.")
                    }
                    Toggle("I understand and I work as an independent contractor", isOn: $agree)
                case .taxDetails:
                    Section("Legal details") {
                        TextField("Legal name, as on your tax return", text: $legalName)
                        TextField("Business name, if different (optional)", text: $businessName)
                        Picker("Tax classification", selection: $classification) {
                            Text("Individual").tag("individual")
                            Text("LLC").tag("llc")
                            Text("Corporation").tag("corporation")
                            Text("Partnership").tag("partnership")
                        }
                        TextField("Mailing address for your 1099", text: $address)
                    }
                case .w9:
                    Section("Form W-9, collected by our tax forms partner") {
                        Text("The next screen is the official W-9, presented and held by our tax forms partner. They verify your name and tax ID with the IRS in real time, keep the signed form on file, and use it to file your 1099 NEC each January. Linen never sees your full tax ID.")
                        Text("Use the legal name, classification, and address from the tax details step. They are sent ahead so the form opens partly filled.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Section {
                        Toggle("I completed and signed my W-9 with the forms partner", isOn: $agree)
                    }
                case .agreement:
                    Section {
                        Text("Independent Contractor Agreement, version 1.0. You are engaged as an independent contractor, not an employee. Pay is per completed job at the rate shown before you accept, plus 100 percent of client tips. Either side may end this relationship at any time. You agree to arrive on time, follow the in app job checklist, and keep client home details private.")
                    }
                    Toggle("I have read and accept the agreement", isOn: $agree)
                case .payout:
                    Section {
                        Text("Payouts run through the contractor payment integration, which collects your bank details securely. Your 1099 NEC is filed separately by our tax forms partner from your W-9 and your payout totals. Linen never sees or stores your full account number or tax ID.")
                    }
                    Toggle("I connected my payout account", isOn: $agree)
                case .backgroundCheck:
                    Section {
                        Text("Clients let specialists into their homes, so Linen verifies identity and runs a background check before the Pro workspace opens. The check covers identity, criminal history, and the sex offender registry.")
                    }
                    Toggle("I consent to identity verification and a background check", isOn: $agree)
                }
                Section {
                    Button("Save and mark complete") {
                        store.completeStep(step)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!agree && step != .taxDetails)
                }
            }
            .navigationTitle(step.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
