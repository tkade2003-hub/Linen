import SwiftUI

struct HomeownerShellView: View {
    @State private var showMenu = false

    var body: some View {
        TabView {
            QuickBookView(showMenu: $showMenu)
                .tabItem { Label("Home", systemImage: "house") }
            ConfigureCleanView()
                .tabItem { Label("Book", systemImage: "plus.circle") }
            BookingsView()
                .tabItem { Label("Bookings", systemImage: "calendar") }
            AccountView()
                .tabItem { Label("Account", systemImage: "person") }
        }
        .sheet(isPresented: $showMenu) { WorkspaceMenuView() }
    }
}

struct QuickBookView: View {
    @Binding var showMenu: Bool
    private let specialists = [
        Specialist(name: "Elena R.", rating: 4.98, cleans: 340, specialty: "Linen care and eco home specialist", backgroundChecked: true),
        Specialist(name: "Marcus V.", rating: 4.95, cleans: 218, specialty: "Deep reset and kitchen detailing", backgroundChecked: true)
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Pinned header: stays at the top of the screen while
                // the rest of the home screen scrolls under it.
                VStack(alignment: .leading, spacing: 4) {
                    Text("Freshness, on your schedule.")
                        .font(.title2.bold())
                    Text("Vetted home specialists available as soon as today at 2:00 PM.")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                Divider()

                ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Next visit").font(.headline)
                        Text("Elena is on the way").bold()
                        Text("Signature Clean · 2.5 hrs · ETA 10:18 AM (12 min)")
                            .foregroundStyle(.secondary)
                        NavigationLink {
                            LiveTrackingView()
                        } label: {
                            Label("Track live", systemImage: "location")
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 2)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Text("Choose a service").font(.headline)
                    ForEach(Pricing.tiers) { tier in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(tier.name).bold()
                                if let tag = tier.tag {
                                    Text(tag)
                                        .font(.caption.bold())
                                        .foregroundStyle(LinenTheme.mintDeep)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(LinenTheme.mintSoft)
                                        .clipShape(Capsule())
                                }
                                Spacer()
                                Text(Pricing.money(tier.priceCents)).bold()
                            }
                            Text("\(Pricing.duration(tier.minutes)) · \(tier.blurb)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Text("Specialists near you").font(.headline)
                    ForEach(specialists) { pro in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(pro.name).bold()
                                Text(String(format: "%.2f ★ (%d) · %@", pro.rating, pro.cleans, pro.specialty))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
                }
            }
            .navigationTitle("Linen")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showMenu = true } label: { Image(systemName: "line.3.horizontal") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "bell")
                }
            }
        }
    }
}

struct ConfigureCleanView: View {
    @State private var beds = 2
    @State private var baths = 2
    @State private var tierIndex = 1

    private var totalCents: Int {
        Pricing.tiers[tierIndex].priceCents
            + beds * Pricing.bedroomCents
            + baths * Pricing.bathroomCents
            - 2 * Pricing.bedroomCents
            - 2 * Pricing.bathroomCents
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Home size") {
                    Stepper("Bedrooms, \(Pricing.money(Pricing.bedroomCents)) each: \(beds)", value: $beds, in: 0...8)
                    Stepper("Bathrooms, \(Pricing.money(Pricing.bathroomCents)) each: \(baths)", value: $baths, in: 0...8)
                }
                Section("Service tier") {
                    Picker("Tier", selection: $tierIndex) {
                        ForEach(Pricing.tiers.indices, id: \.self) { i in
                            Text("\(Pricing.tiers[i].name) · \(Pricing.money(Pricing.tiers[i].priceCents))").tag(i)
                        }
                    }
                    .pickerStyle(.inline)
                }
                Section {
                    Button("Confirm booking · \(Pricing.money(totalCents))") {}
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Configure your clean")
        }
    }
}

struct BookingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Upcoming") {
                    NavigationLink {
                        LiveTrackingView()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("En route · ETA 10:18 AM").bold()
                            Text("Signature Clean · Today · 10:00 AM · 2.5 hrs · $148")
                            Text("Elena Rostova · 742 Evergreen Terrace")
                                .foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recurring, every two weeks").bold()
                        Text("Standard Tidy · Tue, Dec 8 · 10:00 AM · 2 hrs · $118")
                        Text("Marcus Vance · 742 Evergreen Terrace")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Past") {
                    Text("Signature Clean · Nov 10 · Elena Rostova · 5.0 ★ · $148 · Completed")
                    Text("Deep Seasonal Reset · Oct 24 · Marcus Vance · 5.0 ★ · $215 · Completed")
                }
            }
            .navigationTitle("Bookings")
        }
    }
}

struct AccountView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(store.session?.name ?? "")
                        .font(.headline)
                    Text(store.session?.email ?? "")
                        .foregroundStyle(.secondary)
                }
                Section("Saved homes") {
                    Text("Primary Residence · Default")
                    Text("742 Evergreen Terrace, Apt 4B · 2 Bed, 2 Bath")
                        .foregroundStyle(.secondary)
                    Text("Entry: Doorman has spare key")
                        .foregroundStyle(.secondary)
                }
                Section("Care preferences") {
                    Text("Pet friendly products")
                    Text("Plant based, unscented formulas")
                    Text("Preferred specialist: Elena Rostova when available")
                }
                Section {
                    Text("Payment and support")
                    Text("Settings and privacy")
                    Button("Sign out", role: .destructive) { store.signOut() }
                }
            }
            .navigationTitle("Account")
        }
    }
}
