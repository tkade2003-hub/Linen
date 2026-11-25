import SwiftUI
import MapKit

// Live tracking for an en route booking.
// When the store carries a live booking, the specialist coordinate comes
// from the job_locations table (migration 005) over Supabase Realtime,
// written by the pro app every few seconds while the booking is en
// route, and the status ladder follows the bookings stream (migration
// 006). In the demo flow the coordinate advances along the route on a
// timer so the screen can be walked end to end.

final class LiveLocationModel: ObservableObject {
    @Published var coordinate: CLLocationCoordinate2D? = nil
    @Published var lastUpdate: Date? = nil
    private var realtime: RealtimeClient?

    func start(bookingId: UUID, client: SupabaseClient, token: String?) {
        Task {
            if let row = try? await client.latestLocation(bookingId: bookingId) {
                await MainActor.run { self.apply(row) }
            }
        }
        let rt = RealtimeClient(table: "job_locations", bookingId: bookingId, token: token)
        rt.onRecord = { [weak self] record in
            if let row = decodeRow(record, as: JobLocationRow.self) { self?.apply(row) }
        }
        rt.connect()
        realtime = rt
    }

    func apply(_ row: JobLocationRow) {
        coordinate = CLLocationCoordinate2D(latitude: row.latitude, longitude: row.longitude)
        lastUpdate = Date()
    }

    func stop() {
        realtime?.disconnect()
        realtime = nil
    }
}

final class LocationSimulator: ObservableObject {
    let home = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    let route: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 37.7650, longitude: -122.4320),
        CLLocationCoordinate2D(latitude: 37.7690, longitude: -122.4280),
        CLLocationCoordinate2D(latitude: 37.7720, longitude: -122.4230),
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    ]
    @Published var progress: Double = 0.25

    var coordinate: CLLocationCoordinate2D {
        let total = Double(route.count - 1)
        let scaled = progress * total
        let index = min(Int(scaled), route.count - 2)
        let frac = scaled - Double(index)
        let a = route[index]
        let b = route[index + 1]
        return CLLocationCoordinate2D(
            latitude: a.latitude + (b.latitude - a.latitude) * frac,
            longitude: a.longitude + (b.longitude - a.longitude) * frac
        )
    }

    var etaMinutes: Int { max(2, Int((1.0 - progress) * 16)) }
    var arrived: Bool { progress >= 0.98 }

    func advance() {
        if progress < 0.98 { progress += 0.01 }
    }
}

struct LiveTrackingView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var sim = LocationSimulator()
    @StateObject private var live = LiveLocationModel()
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.7705, longitude: -122.4255),
                           span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025))
    )
    private let timer = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()

    private var elenaCoordinate: CLLocationCoordinate2D {
        if store.isLive, let coordinate = live.coordinate { return coordinate }
        return sim.coordinate
    }

    private var routeCoordinates: [CLLocationCoordinate2D] {
        store.isLive ? [sim.home, elenaCoordinate] : sim.route
    }

    // Ladder rows are 0 Confirmed, 1 En route, 2 Arrived,
    // 3 Clean in progress, 4 Completed. In live mode the row states
    // come straight from the booking status the pro app sets.
    private func ladderState(_ index: Int) -> StatusRow.State {
        if store.isLive {
            switch (store.liveBookingStatus ?? "").lowercased().replacingOccurrences(of: " ", with: "_") {
            case "searching":
                return index == 0 ? .active : .upcoming
            case "confirmed":
                if index == 0 { return .done }
                return index == 1 ? .active : .upcoming
            case "en_route":
                if index == 0 { return .done }
                return index == 1 ? .active : .upcoming
            case "arrived":
                if index < 2 { return .done }
                return index == 2 ? .active : .upcoming
            case "in_progress":
                if index < 3 { return .done }
                return index == 3 ? .active : .upcoming
            case "completed":
                return .done
            default:
                return index == 0 ? .done : .upcoming
            }
        }
        switch index {
        case 0: return .done
        case 1: return sim.arrived ? .done : .active
        case 2: return sim.arrived ? .active : .upcoming
        default: return .upcoming
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Map(position: $camera) {
                    Marker("Your home", coordinate: sim.home)
                    Marker("Elena", coordinate: elenaCoordinate)
                    MapPolyline(coordinates: routeCoordinates)
                        .stroke(.blue, lineWidth: 3)
                }
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(sim.arrived ? "Elena has arrived" : "Elena is on the way")
                        .font(.title3.bold())
                    if store.isLive {
                        Text("Signature Clean · 2.5 hrs · Live location")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Signature Clean · 2.5 hrs · ETA \(sim.etaMinutes) min")
                            .foregroundStyle(.secondary)
                    }
                    Text("742 Evergreen Terrace, Apt 4B")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    StatusRow(label: "Confirmed", state: ladderState(0))
                    StatusRow(label: "En route", state: ladderState(1))
                    StatusRow(label: "Arrived", state: ladderState(2))
                    StatusRow(label: "Clean in progress", state: ladderState(3))
                    StatusRow(label: "Completed", state: ladderState(4))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Elena Rostova").bold()
                        Spacer()
                        Text("4.98 ★ · 340 cleans").foregroundStyle(.secondary)
                    }
                    Text("Verified and Insured Pro · Background checked")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack {
                        NavigationLink {
                            MessagesView(contactName: "Elena Rostova")
                        } label: {
                            Label("Message", systemImage: "message")
                        }
                        .buttonStyle(.borderedProminent)
                        Button {
                        } label: {
                            Label("Call", systemImage: "phone")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding()
        }
        .navigationTitle("Live tracking")
        .onReceive(timer) { _ in if !store.isLive { sim.advance() } }
        .task {
            if store.isLive, let bookingId = store.liveBookingId {
                live.start(bookingId: bookingId, client: store.backend, token: store.authToken)
            }
        }
        .onDisappear { live.stop() }
    }
}

private struct StatusRow: View {
    enum State { case done, active, upcoming }
    let label: String
    let state: State

    var body: some View {
        HStack {
            Image(systemName: state == .done ? "checkmark.circle.fill" : state == .active ? "circle.dotted" : "circle")
                .foregroundStyle(state == .upcoming ? .secondary : .green)
            Text(label)
                .foregroundStyle(state == .upcoming ? .secondary : .primary)
                .bold(state == .active)
        }
    }
}
