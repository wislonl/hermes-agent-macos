import SwiftUI

struct ConversationView: View {
    @Bindable var state: AppState
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(state.messages) { message in
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: state.messages.last?.id) { _, newValue in
                    guard let id = newValue else { return }
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }

            Divider()

            HStack(alignment: .center, spacing: 8) {
                TextField("Ask Hermes", text: $state.draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...6)
                    .focused($inputFocused)
                    .onSubmit { state.submitDraft() }
                    .disabled(state.connectionState != .ready)

                if state.isAwaitingResponse {
                    Button {
                        Task { await state.cancelCurrentRun() }
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                    }
                } else {
                    Button {
                        state.submitDraft()
                    } label: {
                        Label("Send", systemImage: "paperplane.fill")
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(state.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || state.connectionState != .ready)
                }
            }
            .padding(12)
            .background(.bar)
        }
        .navigationTitle("Conversation")
        .onAppear { inputFocused = true }
    }

    @ViewBuilder
    private func messageRow(_ message: ChatMessage) -> some View {
        let isUser = message.author == .user
        VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            Text(message.author.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(message.text.isEmpty && message.author == .agent ? "…" : message.text)
                .textSelection(.enabled)
                .padding(10)
                .background(background(for: message.author))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private func background(for author: ChatMessage.Author) -> Color {
        switch author {
        case .user: return Color.accentColor.opacity(0.12)
        case .agent: return Color.secondary.opacity(0.10)
        case .system: return Color.orange.opacity(0.10)
        }
    }
}

private extension ChatMessage.Author {
    var displayName: String {
        switch self {
        case .user: "You"
        case .agent: "Hermes"
        case .system: "System"
        }
    }
}
