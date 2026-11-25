import Foundation
import CoreLocation

// Publishes the pro's position to job_locations while a booking is en
// route or in progress, throttled to one row every few seconds or every
// 25 meters of movement. The homeowner app reads the same table, so the
// tracking map follows the real phone rather than a simulation.
//
// Permission scope for this stage is When In Use, which covers sharing
// while the pro has the app open on the way to a job. Sharing with the
// app fully closed needs the Always permission and the location
// background mode in the project settings; see LOCATION-PERMISSIONS.md.
final class LocationPublisher: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isSharing = false
    private let manager = CLLocationManager()
    private var bookingId: UUID?
    private var specialistId: String?
    private var client: SupabaseClient?
    private var lastSentAt: Date?
    private var lastSentCoordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .automotiveNavigation
    }

    func start(bookingId: UUID, specialistId: String, client: SupabaseClient) {
        self.bookingId = bookingId
        self.specialistId = specialistId
        self.client = client
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
        isSharing = true
    }

    func stop() {
        manager.stopUpdatingLocation()
        bookingId = nil
        specialistId = nil
        client = nil
        lastSentAt = nil
        lastSentCoordinate = nil
        isSharing = false
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              let bookingId, let specialistId, let client else { return }
        let now = Date()
        if let lastSentAt, now.timeIntervalSince(lastSentAt) < 5 { return }
        if let last = lastSentCoordinate {
            let moved = CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: location)
            if moved < 25, let lastSentAt, now.timeIntervalSince(lastSentAt) < 30 { return }
        }
        lastSentAt = now
        lastSentCoordinate = location.coordinate
        let row = JobLocationRow(
            booking_id: bookingId,
            specialist_id: specialistId,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            heading: location.course >= 0 ? location.course : nil,
            speed_mps: location.speed >= 0 ? location.speed : nil
        )
        Task { try? await client.publishLocation(row) }
    }
}
