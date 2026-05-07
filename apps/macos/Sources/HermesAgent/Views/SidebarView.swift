import SwiftUI

struct SidebarView: View {
    @Bindable var state: AppState
    @State private var renaming: SessionSummary? = nil
    @State private var renameText: String = ""

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
                        sessionRow(session)
                            .tag(session.id)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .navigationTitle("Hermes")
        .sheet(item: $renaming) { session in
            RenameSheet(
                initialTitle: session.displayTitle,
                onConfirm: { newTitle in
                    state.renameSession(session.id, title: newTitle)
                    renaming = nil
                },
                onCancel: { renaming = nil }
            )
        }
    }

    @ViewBuilder
    private func sessionRow(_ session: SessionSummary) -> some View {
        HStack(alignment: .center, spacing: 6) {
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

            Spacer()

            Menu {
                Button {
                    renameText = session.displayTitle
                    renaming = session
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive) {
                    state.deleteSession(session.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}

private struct RenameSheet: View {
    let initialTitle: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String
    @FocusState private var focused: Bool

    init(initialTitle: String, onConfirm: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.initialTitle = initialTitle
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _text = State(initialValue: initialTitle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename Session").font(.headline)
            TextField("Session title", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { commit() }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Rename", action: commit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
        .onAppear { focused = true }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onConfirm(trimmed)
    }
}
