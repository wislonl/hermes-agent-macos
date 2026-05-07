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
    }
}
