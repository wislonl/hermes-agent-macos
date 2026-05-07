import SwiftUI

private extension String {
    // Strip <think>...</think> blocks (including multiline) and trim whitespace.
    func strippingThinkTags() -> String {
        var result = self
        while let open = result.range(of: "<think>", options: .caseInsensitive),
              let close = result.range(of: "</think>", options: .caseInsensitive),
              open.lowerBound <= close.lowerBound {
            result.removeSubrange(open.lowerBound..<close.upperBound)
        }
        // Also strip unclosed <think> block that reaches end of string
        if let open = result.range(of: "<think>", options: .caseInsensitive) {
            result.removeSubrange(open.lowerBound...)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct SidebarView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Sessions").font(.headline)
                Spacer()
                Button {
                    Task { await state.startNewSession() }
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.borderless)
                .help("New session")
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if state.sessions.isEmpty {
                ContentUnavailableView(
                    "No prior sessions",
                    systemImage: "tray",
                    description: Text("Start chatting to create one.")
                )
                .padding(.top, 24)
                Spacer()
            } else {
                List(selection: Binding(
                    get: { state.currentSessionId },
                    set: { newValue in
                        guard let id = newValue,
                              let session = state.sessions.first(where: { $0.id == id })
                        else { return }
                        Task { await state.switchToSession(id, cwd: session.cwd) }
                    }
                )) {
                    ForEach(state.sessions) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.displayTitle)
                                .font(.headline)
                                .lineLimit(1)
                            Text(session.displayCwd)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .tag(session.id)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .navigationTitle("Hermes")
    }
}
