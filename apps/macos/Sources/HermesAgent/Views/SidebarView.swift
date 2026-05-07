import SwiftUI

struct SidebarView: View {
    @Bindable var state: AppState

    var body: some View {
        List(selection: $state.selectedAgentId) {
            Section("Agents") {
                ForEach(state.agents) { agent in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(agent.name).font(.headline)
                        Text(agent.role).font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(agent.id)
                }
            }
        }
        .navigationTitle("Hermes")
    }
}
