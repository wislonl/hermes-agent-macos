import SwiftUI

struct WorkbenchView: View {
    @Bindable var state: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView(state: state)
        } content: {
            ConversationView(state: state)
        } detail: {
            InspectorView(state: state)
        }
        .toolbar {
            ToolbarItem(placement: .status) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(connectionColor(for: state.connectionState))
                        .frame(width: 7, height: 7)
                    Text(toolbarLabel(for: state.connectionState))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(item: $state.pendingApproval) { prompt in
            ApprovalSheet(prompt: prompt) { decision in
                state.resolveApproval(optionId: decision)
            }
        }
        .onAppear { state.startIfNeeded() }
    }
}

private func connectionColor(for state: AppState.ConnectionState) -> Color {
    switch state {
    case .ready: return .green
    case .starting: return .yellow
    case .failed, .disconnected: return .red
    }
}

private func toolbarLabel(for state: AppState.ConnectionState) -> String {
    switch state {
    case .ready: return "Connected"
    case .starting: return "Connecting…"
    case .failed: return "Disconnected"
    case .disconnected: return "Disconnected"
    }
}

private struct ApprovalSheet: View {
    let prompt: ApprovalPrompt
    let onResolve: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Hermes is requesting permission", systemImage: "exclamationmark.shield")
                .font(.headline)
            Text(prompt.summary)
                .font(.body)
                .textSelection(.enabled)

            Divider()

            HStack(spacing: 8) {
                ForEach(prompt.options) { option in
                    optionButton(option)
                }
                Spacer()
                Button("Dismiss") { onResolve(nil) }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 420)
    }

    @ViewBuilder
    private func optionButton(_ option: ApprovalPrompt.Option) -> some View {
        if option.kind.contains("reject") {
            Button(option.name) { onResolve(option.id) }
                .buttonStyle(.bordered)
        } else {
            Button(option.name) { onResolve(option.id) }
                .buttonStyle(.borderedProminent)
        }
    }
}
