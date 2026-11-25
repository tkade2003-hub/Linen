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
                    Text("Linen specialists are independent contractors. Finish these six steps once and your application goes to review. Your full tax ID is collected by the payment provider only. Linen keeps the last 4 digits.")
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
    @State private var tin = ""
    @State private var signature = ""
    @State private var agree = false
    @State private var exemptBackupWithholding = false

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
                    Section("Form W-9") {
                        TextField("Name, as shown on your income tax return", text: $legalName)
                        Picker("Federal tax classification", selection: $classification) {
                            Text("Individual or sole proprietor").tag("individual")
                            Text("LLC").tag("llc")
                            Text("Corporation").tag("corporation")
                            Text("Partnership").tag("partnership")
                        }
                        SecureField("Taxpayer Identification Number", text: $tin)
                        Text("Your number goes to the payment provider over a secure connection. Linen stores only the last 4 digits.")
                            .font(.caption).foregroundStyle(.secondary)
                        Toggle("I am exempt from backup withholding", isOn: $exemptBackupWithholding)
                    }
                    Section("Certification and signature") {
                        Text("Under penalties of perjury, I certify that the number shown is my correct Taxpayer Identification Number and I am not subject to backup withholding.")
                            .font(.subheadline)
                        TextField("Type your full legal name to sign", text: $signature)
                        Toggle("I certify the above and sign this W-9", isOn: $agree)
                    }
                case .agreement:
                    Section {
                        Text("Independent Contractor Agreement, version 1.0. You are engaged as an independent contractor, not an employee. Pay is per completed job at the rate shown before you accept, plus 100 percent of client tips. Either side may end this relationship at any time. You agree to arrive on time, follow the in app job checklist, and keep client home details private.")
                    }
                    Toggle("I have read and accept the agreement", isOn: $agree)
                case .payout:
                    Section {
                        Text("Payouts run through the contractor payment integration. It collects your bank details and your tax ID securely and issues your 1099 NEC each January. Linen never sees or stores your full account number or tax ID.")
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
                        if step == .w9 {
                            store.tinLast4 = String(tin.suffix(4))
                        }
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
