import SwiftUI

struct ProShellView: View {
    @State private var showMenu = false

    var body: some View {
        TabView {
            JobsDashboardView(showMenu: $showMenu)
                .tabItem { Label("Jobs", systemImage: "briefcase") }
            ProScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }
            ProEarningsView()
                .tabItem { Label("Earnings", systemImage: "creditcard") }
            ProProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
        }
        .sheet(isPresented: $showMenu) { WorkspaceMenuView() }
    }
}

struct JobsDashboardView: View {
    @EnvironmentObject var store: AppStore
    @Binding var showMenu: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Pinned header: the online switch and today's pay stay
                // at the top of the screen while jobs scroll under it.
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Online", isOn: $store.isOnline)
                        .bold()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today projected pay").foregroundStyle(.secondary)
                        Text("$266.00").font(.title.bold())
                        Text("2 visits · 4.5 hrs booked").foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                Divider()

                ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Up next · 10:00 AM").font(.headline)
                        Text("En route · 0.8 mi away").bold()
                        Text("Signature Clean · 2.5 hrs · Sarah Jenkins")
                        Text("742 Evergreen Terrace, Apt 4B · $130")
                        Text("2 Bed · 2 Bath · Inside fridge · Doorman key")
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Navigate") {}.buttonStyle(.bordered)
                            NavigationLink {
                                MessagesView(contactName: "Sarah Jenkins")
                            } label: {
                                Text("Message")
                            }
                            .buttonStyle(.bordered)
                            Button("Start visit") { store.locationPublisher.stop() }
                                .buttonStyle(.borderedProminent)
                        }
                        if store.isLive, let bookingId = store.liveBookingId {
                            if store.locationPublisher.isSharing {
                                HStack {
                                    Label("Sharing location live", systemImage: "location.fill")
                                        .foregroundStyle(.green)
                                    Spacer()
                                    Button("Stop") { store.locationPublisher.stop() }
                                }
                            } else {
                                Button("Start route and share location") {
                                    store.locationPublisher.start(
                                        bookingId: bookingId,
                                        specialistId: store.liveSpecialistId ?? store.currentUserId ?? "",
                                        client: store.backend
                                    )
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Text("New requests · 2 nearby").font(.headline)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Deep Seasonal Reset").bold()
                        Text("Thu, Nov 26 · 1:30 PM · 4 hrs · 1.4 mi · $164")
                        HStack {
                            Button("Decline") {}.buttonStyle(.bordered)
                            Button("Accept job") {}.buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Standard Tidy").bold()
                        Text("Fri, Nov 27 · 9:00 AM · 2 hrs · 2.1 mi · $88")
                        HStack {
                            Button("Decline") {}.buttonStyle(.bordered)
                            Button("Accept job") {}.buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding()
                }
            }
            .navigationTitle("Linen Pro")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showMenu = true } label: { Image(systemName: "line.3.horizontal") }
                }
            }
        }
    }
}

struct ProScheduleView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationStack {
            List {
                Section("Tue, Nov 24 · 2 visits · $266") {
                    Text("10:00 AM to 12:30 PM · Signature Clean · $130 · Sarah Jenkins")
                    Text("Break and transit · 1.5 hrs").foregroundStyle(.secondary)
                    Text("2:00 PM to 4:00 PM · Standard Tidy · $136 · David Chen")
                }
                Section("Weekly availability") {
                    ForEach(store.availability) { day in
                        HStack {
                            Text(day.label)
                            Spacer()
                            Text(day.summary).foregroundStyle(.secondary)
                        }
                    }
                    Text(store.autoAcceptRepeats
                         ? "Auto accept repeat clients during open hours is on"
                         : "Auto accept repeat clients is off")
                        .foregroundStyle(.secondary)
                    NavigationLink {
                        AvailabilityView()
                    } label: {
                        Label("Edit weekly availability", systemImage: "calendar.badge.clock")
                    }
                }
            }
            .navigationTitle("Schedule")
        }
    }
}

struct ProEarningsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Available balance") {
                    Text("$842.50").font(.title2.bold())
                    Text("7 completed cleans · Auto payout Fri, Nov 27")
                        .foregroundStyle(.secondary)
                    Text("Base pay $714.00 · Client tips $128.50")
                    Button("Cash out $842.50") {}.buttonStyle(.borderedProminent)
                }
                Section("Completed visits") {
                    Text("Deep Seasonal Reset · Mon, Nov 23 · $192.00 · Includes $28 tip")
                    Text("Signature Clean · Mon, Nov 23 · $132.00 · Includes $20 tip")
                    Text("Standard Tidy · Sun, Nov 22 · $103.00 · Includes $15 tip")
                }
                Section("November total") {
                    Text("$3,410.00 · 29 completed cleans · 4.98 ★ average rating")
                }
            }
            .navigationTitle("Earnings")
        }
    }
}

struct ProProfileView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Online", isOn: $store.isOnline)
                    Text("Elena Rostova").font(.headline)
                    Text("Verified and Insured Pro")
                    Text("4.98 ★ Rating · 340 Cleans · 99% On time")
                        .foregroundStyle(.secondary)
                }
                Section("Work area and payout") {
                    Text("Settings and service radius · Within 6 miles of Midtown")
                    Text("Payout account · Chase Checking ending 8814")
                    Text("Eco kit supplies · Restock scheduled for Dec 1")
                }
                Section("Recent review") {
                    Text("Sarah Jenkins · 5.0 ★")
                    Text("Elena is always punctual and leaves our linens and kitchen spotless.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Profile")
        }
    }
}
