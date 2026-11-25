import SwiftUI
import MapKit

// Live tracking for an en route booking.
// The specialist coordinate advances along the route on a timer so the
// screen can be walked end to end. In production the coordinate comes from
// the job_locations stream in migration 004 over Supabase Realtime, written
// by the pro app every few seconds while the booking is en route.

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
    @StateObject private var sim = LocationSimulator()
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.7705, longitude: -122.4255),
                           span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025))
    )
    private let timer = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Map(position: $camera) {
                    Marker("Your home", coordinate: sim.home)
                    Marker("Elena", coordinate: sim.coordinate)
                    MapPolyline(coordinates: sim.route)
                        .stroke(.blue, lineWidth: 3)
                }
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(sim.arrived ? "Elena has arrived" : "Elena is on the way")
                        .font(.title3.bold())
                    Text("Signature Clean · 2.5 hrs · ETA \(sim.etaMinutes) min")
                        .foregroundStyle(.secondary)
                    Text("742 Evergreen Terrace, Apt 4B")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    StatusRow(label: "Confirmed", state: .done)
                    StatusRow(label: "En route", state: sim.arrived ? .done : .active)
                    StatusRow(label: "Arrived", state: sim.arrived ? .active : .upcoming)
                    StatusRow(label: "Clean in progress", state: .upcoming)
                    StatusRow(label: "Completed", state: .upcoming)
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
        .onReceive(timer) { _ in sim.advance() }
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
