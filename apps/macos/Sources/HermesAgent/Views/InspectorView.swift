import SwiftUI

struct InspectorView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Run Inspector").font(.title3).bold()

            if state.toolCalls.isEmpty {
                ContentUnavailableView("No tool calls yet", systemImage: "wrench.and.screwdriver")
            } else {
                List(state.toolCalls) { call in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: call.requiresApproval ? "exclamationmark.triangle.fill" : "terminal")
                            .foregroundStyle(call.requiresApproval ? .orange : .secondary)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(call.title).font(.headline)
                            Text(call.detail).font(.caption).foregroundStyle(.secondary)
                            if call.requiresApproval {
                                let approval = state.approvals.first { $0.id == call.approvalId }
                                let decision = approval?.decision

                                Label(statusText(for: decision), systemImage: "lock")
                                    .foregroundStyle(statusColor(for: decision))

                                if decision == nil {
                                    HStack(spacing: 8) {
                                        Button("Approve") {
                                            resolve(call, as: .approved)
                                        }
                                        Button("Deny", role: .destructive) {
                                            resolve(call, as: .denied)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .frame(minWidth: 280)
    }

    private func resolve(_ call: ToolCall, as decision: ApprovalDecision) {
        guard let approvalId = call.approvalId else { return }
        state.resolveApproval(id: approvalId, decision: decision)
    }

    private func statusText(for decision: ApprovalDecision?) -> String {
        switch decision {
        case .approved:
            "Approved"
        case .denied:
            "Denied"
        case nil:
            "Pending"
        }
    }

    private func statusColor(for decision: ApprovalDecision?) -> Color {
        switch decision {
        case .approved:
            .green
        case .denied:
            .red
        case nil:
            .orange
        }
    }
}
