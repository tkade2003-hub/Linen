import SwiftUI

struct ChatMessage: Identifiable {
    var id = UUID()
    var fromMe: Bool
    var text: String
    var timeLabel: String
}

// One thread per homeowner and specialist pair, backed by the messages
// table in migration 004. Quick actions come from the supplied messaging
// screen. Sending appends locally here; the live client inserts the row
// and the other side receives it over Realtime.
struct MessagesView: View {
    var contactName: String
    @State private var draft = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(fromMe: false, text: "Good morning, I am on my way and should arrive around 10:18. The doorman can let me in.", timeLabel: "9:58 AM"),
        ChatMessage(fromMe: true, text: "Perfect, thank you. The spare key is with the doorman under my name.", timeLabel: "10:01 AM"),
        ChatMessage(fromMe: false, text: "Got it. I will start with the kitchen and bathrooms, then the bedrooms.", timeLabel: "10:03 AM")
    ]

    private let quickActions = ["Share address", "Running 10 min late", "Please start with the kitchen"]

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
    }

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(fromMe: true, text: trimmed, timeLabel: "Now"))
        draft = ""
    }
}
