import SwiftUI

@main
struct HermesAgentApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            WorkbenchView(state: state)
                .frame(minWidth: 1080, minHeight: 720)
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
