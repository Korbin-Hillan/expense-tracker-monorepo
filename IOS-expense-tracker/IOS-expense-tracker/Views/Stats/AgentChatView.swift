//
//  AgentChatView.swift
//  IOS-expense-tracker
//

import SwiftUI

struct AgentChatView: View {
    struct ChatMessage: Identifiable {
        let id = UUID()
        let role: Role
        let text: String
        enum Role { case user, assistant }
    }

    @State private var messages: [ChatMessage] = [
        .init(role: .assistant, text: "Hi! Ask me about your spending — for example: ‘How much did I spend on groceries last month?’ or ‘Top categories this month’. ")
    ]
    @State private var input: String = ""
    @State private var sending = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { msg in
                                HStack(alignment: .top) {
                                    if msg.role == .assistant { Image(systemName: "sparkles").foregroundColor(.purple) }
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(msg.text)
                                            .foregroundColor(.primary)
                                    }
                                    .padding(12)
                                    .background(msg.role == .assistant ? Color.purple.opacity(0.08) : Color.blue.opacity(0.08))
                                    .cornerRadius(12)
                                    if msg.role == .user { Image(systemName: "person.circle.fill").foregroundColor(.blue) }
                                }
                                .id(msg.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }

                HStack(spacing: 8) {
                    TextField("Ask about your expenses…", text: $input, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                    Button(action: send) {
                        if sending { ProgressView().scaleEffect(0.8) } else { Image(systemName: "paperplane.fill") }
                    }
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Ask AI")
        }
    }

    private func send() {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        input = ""
        messages.append(.init(role: .user, text: question))
        sending = true
        Task {
            defer { sending = false }
            do {
                let reply = try await AIClient().ask(question)
                await MainActor.run { messages.append(.init(role: .assistant, text: reply)) }
            } catch {
                await MainActor.run { messages.append(.init(role: .assistant, text: "Sorry, I couldn't process that right now.")) }
            }
        }
    }
}

