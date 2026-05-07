import SwiftUI

struct ConversationView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(state.messages) { message in
                        Text(message.text)
                            .frame(maxWidth: .infinity, alignment: message.author == .user ? .trailing : .leading)
                            .padding(10)
                            .background(message.author == .user ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
            }

            HStack {
                TextField("Ask Hermes", text: $state.draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { state.submitDraft() }
                Button("Send") { state.submitDraft() }
                    .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle("Conversation")
    }
}
