import SwiftUI

struct ChatMessage: Identifiable {
    var id = UUID()
    var fromMe: Bool
    var text: String
    var timeLabel: String
}

// One thread per booking, backed by the messages table in migration
// 005. Quick actions come from the supplied messaging screen. In live
// mode the thread loads from the table, sending inserts a row, and the
// other side receives it over Realtime. In the demo flow the sample
// thread below stands in and sending appends locally.
struct MessagesView: View {
    var contactName: String
    var bookingId: UUID? = nil
    @EnvironmentObject var store: AppStore
    @State private var realtime: RealtimeClient? = nil
    @State private var draft = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(fromMe: false, text: "Good morning, I am on my way and should arrive around 10:18. The doorman can let me in.", timeLabel: "9:58 AM"),
        ChatMessage(fromMe: true, text: "Perfect, thank you. The spare key is with the doorman under my name.", timeLabel: "10:01 AM"),
        ChatMessage(fromMe: false, text: "Got it. I will start with the kitchen and bathrooms, then the bedrooms.", timeLabel: "10:03 AM")
    ]

    private let quickActions = ["Share address", "Running 10 min late", "Please start with the kitchen"]

    private var liveBookingId: UUID? {
        guard store.isLive else { return nil }
        return bookingId ?? store.liveBookingId
    }

    private func timeLabel(for row: MessageRow) -> String {
        guard let raw = row.created_at else { return "Now" }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return "Now" }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func loadLive(bookingId: UUID) {
        let client = store.backend
        let myId = store.currentUserId
        Task {
            if let rows = try? await client.fetchMessages(bookingId: bookingId) {
                await MainActor.run {
                    messages = rows.map {
                        ChatMessage(fromMe: $0.sender_id == myId, text: $0.body, timeLabel: timeLabel(for: $0))
                    }
                }
            }
        }
        let rt = RealtimeClient(table: "messages", bookingId: bookingId, token: store.authToken)
        rt.onRecord = { record in
            guard let row = decodeRow(record, as: MessageRow.self), row.sender_id != myId else { return }
            messages.append(ChatMessage(fromMe: false, text: row.body, timeLabel: timeLabel(for: row)))
        }
        rt.connect()
        realtime = rt
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(messages) { message in
                        HStack {
                            if message.fromMe { Spacer(minLength: 48) }
                            VStack(alignment: message.fromMe ? .trailing : .leading, spacing: 2) {
                                Text(message.text)
                                    .padding(10)
                                    .background(message.fromMe ? Color.accentColor : Color(.secondarySystemBackground))
                                    .foregroundStyle(message.fromMe ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                Text(message.timeLabel)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if !message.fromMe { Spacer(minLength: 48) }
                        }
                    }
                }
                .padding()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(quickActions, id: \.self) { action in
                        Button(action) { send(action) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 6)

            HStack {
                TextField("Message", text: $draft)
                    .textFieldStyle(.roundedBorder)
                Button("Send") { send(draft) }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .navigationTitle(contactName)
        .task {
            if let bookingId = liveBookingId { loadLive(bookingId: bookingId) }
        }
        .onDisappear {
            realtime?.disconnect()
            realtime = nil
        }
    }

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(fromMe: true, text: trimmed, timeLabel: "Now"))
        draft = ""
        if let bookingId = liveBookingId, let senderId = store.currentUserId {
            let row = MessageRow(booking_id: bookingId, sender_id: senderId, body: trimmed)
            let client = store.backend
            Task { try? await client.sendMessage(row) }
        }
    }
}
