import Foundation

// Connection details for Vashon's own Supabase project (the Linen backend
// transferred out of Rork on 2026-11-24, ref vftlwlnbfqqqxfdscato).
// The anon key is a public client key by design: it ships inside the app
// and every table is protected by row level security, so a request only
// ever sees rows the signed in user is a party to. The service role key
// must never appear in app code.
enum SupabaseConfig {
    static let projectURL = URL(string: "https://vftlwlnbfqqqxfdscato.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmdGx3bG5iZnFxcXhmZHNjYXRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTU1NzYyNDgsImV4cCI6MjExMTE1MjI0OH0.YfNnJEAE1QO9MG3ZKpJ5QY47_XiqWqXrWCUdgjnh4Ro"

    static var restBase: URL { projectURL.appendingPathComponent("rest/v1") }
    static var realtimeURL: URL {
        var components = URLComponents()
        components.scheme = "wss"
        components.host = projectURL.host
        components.path = "/realtime/v1/websocket"
        components.queryItems = [
            URLQueryItem(name: "apikey", value: anonKey),
            URLQueryItem(name: "vsn", value: "1.0.0")
        ]
        return components.url!
    }
}
