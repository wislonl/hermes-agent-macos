import SwiftUI

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
                            Text(session.title).font(.headline).lineLimit(1)
                            Text(session.cwd)
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
