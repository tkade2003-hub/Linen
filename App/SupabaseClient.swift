import Foundation

// Row shapes for the live tables added in migrations 005 and 006.
struct JobLocationRow: Codable {
    var id: UUID?
    var booking_id: UUID
    var specialist_id: String
    var latitude: Double
    var longitude: Double
    var heading: Double?
    var speed_mps: Double?
    var recorded_at: String?
}

struct MessageRow: Codable {
    var id: UUID?
    var booking_id: UUID
    var sender_id: String
    var body: String
    var created_at: String?
    var read_at: String?
}

// Thin REST client for the Linen Supabase project.
// Requests carry the anon key plus the signed in user's session token when
// the app has one (the Rork session supplies it through AppStore.authToken).
// Row level security on the server decides what each request may touch, so
// this client holds no privileges of its own.
final class SupabaseClient {
    private let token: String?

    init(token: String?) {
        self.token = token
    }

    private var bearer: String { token ?? SupabaseConfig.anonKey }

    private func request(path: String, method: String, body: Data? = nil) -> URLRequest {
        var req = URLRequest(url: SupabaseConfig.restBase.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        if body != nil {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        }
        return req
    }

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem]) async throws -> [T] {
        var components = URLComponents(url: SupabaseConfig.restBase.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query
        var req = URLRequest(url: components.url!)
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([T].self, from: data)
    }

    private func post<T: Encodable>(_ path: String, row: T) async throws {
        let body = try JSONEncoder().encode(row)
        var req = request(path: path, method: "POST", body: body)
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // GPS tracking (migration 005)

    func latestLocation(bookingId: UUID) async throws -> JobLocationRow? {
        let rows: [JobLocationRow] = try await get("job_locations", query: [
            URLQueryItem(name: "booking_id", value: "eq.\(bookingId.uuidString)"),
            URLQueryItem(name: "order", value: "recorded_at.desc"),
            URLQueryItem(name: "limit", value: "1")
        ])
        return rows.first
    }

    func publishLocation(_ row: JobLocationRow) async throws {
        try await post("job_locations", row: row)
    }

    // Messaging (migration 005)

    func fetchMessages(bookingId: UUID) async throws -> [MessageRow] {
        try await get("messages", query: [
            URLQueryItem(name: "booking_id", value: "eq.\(bookingId.uuidString)"),
            URLQueryItem(name: "order", value: "created_at.asc")
        ])
    }

    func sendMessage(_ row: MessageRow) async throws {
        try await post("messages", row: row)
    }
}
