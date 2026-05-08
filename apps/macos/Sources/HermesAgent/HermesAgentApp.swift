import SwiftUI
import HermesAgentCore

@main
struct HermesAgentApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            WorkbenchView(state: state)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Hermes Session") {
                    Task { await state.startNewSession() }
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }
}
