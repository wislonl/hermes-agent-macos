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

        .sheet(item: $state.pendingApproval) { prompt in
            ApprovalSheet(prompt: prompt) { decision in
                state.resolveApproval(optionId: decision)
            }
        }
        .onAppear { state.startIfNeeded() }
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
