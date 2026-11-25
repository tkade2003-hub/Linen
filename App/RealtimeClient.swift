import Foundation

// Minimal Supabase Realtime client over a websocket, speaking the Phoenix
// channel protocol the Realtime server expects. It subscribes to INSERT
// events on one table filtered to one booking, which is all live tracking
// and messaging need. The access token is the signed in user's session
// token when the app has one, and the anon key otherwise; row level
// security still governs which rows the server will stream.
final class RealtimeClient {
    private var task: URLSessionWebSocketTask?
    private var heartbeat: Timer?
    private var refCounter = 0
    private let table: String
    private let bookingId: UUID
    private let token: String
    var onRecord: (([String: Any]) -> Void)?

    init(table: String, bookingId: UUID, token: String?) {
        self.table = table
        self.bookingId = bookingId
        self.token = token ?? SupabaseConfig.anonKey
    }

    func connect() {
        let session = URLSession(configuration: .default)
        task = session.webSocketTask(with: SupabaseConfig.realtimeURL)
        task?.resume()
        join()
        receive()
        heartbeat = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            self?.send(topic: "phoenix", event: "heartbeat", payload: [:])
        }
    }

    func disconnect() {
        heartbeat?.invalidate()
        heartbeat = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func nextRef() -> String {
        refCounter += 1
        return String(refCounter)
    }

    private func join() {
        let change: [String: Any] = [
            "event": "INSERT",
            "schema": "public",
            "table": table,
            "filter": "booking_id=eq.\(bookingId.uuidString)"
        ]
        let config: [String: Any] = [
            "broadcast": ["ack": false, "self": false],
            "presence": ["key": ""],
            "postgres_changes": [change]
        ]
        send(topic: "realtime:public:\(table)", event: "phx_join",
             payload: ["config": config, "access_token": token])
    }

    private func send(topic: String, event: String, payload: [String: Any]) {
        let message: [String: Any] = [
            "topic": topic,
            "event": event,
            "payload": payload,
            "ref": nextRef()
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { _ in }
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message,
                   let data = text.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   (json["event"] as? String) == "postgres_changes",
                   let payload = json["payload"] as? [String: Any],
                   let payloadData = payload["data"] as? [String: Any],
                   let record = payloadData["record"] as? [String: Any] {
                    DispatchQueue.main.async { self.onRecord?(record) }
                }
                self.receive()
            case .failure:
                self.disconnect()
            }
        }
    }
}

// Converts a realtime record dictionary back into a Codable row.
func decodeRow<T: Decodable>(_ record: [String: Any], as type: T.Type) -> T? {
    guard let data = try? JSONSerialization.data(withJSONObject: record) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
}
