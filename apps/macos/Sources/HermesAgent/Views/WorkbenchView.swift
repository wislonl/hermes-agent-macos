import SwiftUI

struct WorkbenchView: View {
    @Bindable var state: AppState
    @State private var showInspector = true
    @State private var showModelSetup = false

    var body: some View {
        HStack(spacing: 0) {
            NavigationSplitView {
                SidebarView(state: state)
            } detail: {
                ConversationView(state: state)
            }

            if showInspector {
                Divider()
                InspectorView(state: state)
                    .frame(width: 260)
                    .transition(.move(edge: .trailing))
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                modelIndicator
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showInspector.toggle() }
                } label: {
                    Image(systemName: "sidebar.trailing")
                }
                .help(showInspector ? "Hide Inspector" : "Show Inspector")
            }
        }
        .sheet(item: $state.pendingApproval) { prompt in
            ApprovalSheet(prompt: prompt) { decision in
                state.resolveApproval(optionId: decision)
            }
        }
        .sheet(isPresented: $showModelSetup) {
            ModelSetupView(state: state)
        }
        .onAppear { state.startIfNeeded() }
    }

    @ViewBuilder
    private var modelIndicator: some View {
        Button {
            showModelSetup = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "cpu")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(currentModelName)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("Switch model")
    }

    private var currentModelName: String {
        if state.isRestarting { return "Restarting…" }
        guard let id = state.currentModelId else {
            return state.connectionState == .ready ? "No model" : "Connecting…"
        }
        if let model = state.availableModels.first(where: { $0.id == id }) {
            return model.name
        }
        // Trim long IDs like "anthropic/claude-sonnet-4-6" → "claude-sonnet-4-6"
        return id.components(separatedBy: "/").last ?? id
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
