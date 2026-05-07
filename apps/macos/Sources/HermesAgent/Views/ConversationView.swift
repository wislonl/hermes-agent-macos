import SwiftUI

struct ConversationView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(state.messages) { message in
                        VStack(alignment: message.author == .user ? .trailing : .leading, spacing: 4) {
                            Text(message.author.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(message.text)
                                .padding(10)
                                .background(message.author == .user ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .frame(maxWidth: .infinity, alignment: message.author == .user ? .trailing : .leading)
                    }
                }
                .padding()
            }

            HStack {
                TextField("Ask Hermes", text: $state.draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await state.submitDraft() } }
                Button("Send") { Task { await state.submitDraft() } }
                    .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle("Conversation")
    }
}

private extension ChatMessage.Author {
    var displayName: String {
        switch self {
        case .user:
            "You"
        case .assistant:
            "Hermes"
        case .system:
            "System"
        }
    }
}
