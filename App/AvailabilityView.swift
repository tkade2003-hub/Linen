import SwiftUI

// Weekly availability editing for specialists, backed by the availability
// table from migration 001 and mirrored in AppStore so the schedule tab
// reflects edits immediately. Auto accept for repeat clients during open
// hours comes from the supplied pro settings screen.
struct AvailabilityView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                Text("Clients can book you only inside your open hours. Same day urgent requests inside open hours carry the 15 percent surge.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach($store.availability) { $day in
                Section {
                    Toggle(day.label, isOn: $day.isOpen)
                        .bold()
                    if day.isOpen {
                        DatePicker("Opens", selection: $day.start, displayedComponents: .hourAndMinute)
                        DatePicker("Closes", selection: $day.end, displayedComponents: .hourAndMinute)
                    } else {
                        Text("Closed").foregroundStyle(.secondary)
                    }
                }
            }
            Section("Booking rules") {
                Toggle("Auto accept repeat clients during open hours", isOn: $store.autoAcceptRepeats)
                Text("Service radius: within 6 miles of Midtown")
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Done") { dismiss() }
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Weekly availability")
    }
}
