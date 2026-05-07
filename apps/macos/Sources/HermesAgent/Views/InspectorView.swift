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
                                Label("Approval required", systemImage: "lock")
                                    .foregroundStyle(.orange)
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
}
