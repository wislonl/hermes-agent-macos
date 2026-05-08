import SwiftUI

struct WorkspaceFileView: View {
    @Bindable var state: AppState
    @State private var roots: [FileNode] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if roots.isEmpty {
                ContentUnavailableView(
                    "No workspace",
                    systemImage: "folder",
                    description: Text("Open a session to browse files.")
                )
            } else {
                List(roots, children: \.optionalChildren) { node in
                    fileRow(node)
                }
                .listStyle(.sidebar)
            }
        }
        .onAppear { reload() }
        .onChange(of: state.workspacePath) { _, _ in reload() }
    }

    private func reload() {
        guard !state.workspacePath.isEmpty else { return }
        isLoading = true
        let path = state.workspacePath
        Task.detached(priority: .userInitiated) {
            let nodes = FileNode.loadTree(at: path)
            await MainActor.run {
                roots = nodes
                isLoading = false
            }
        }
    }

    @ViewBuilder
    private func fileRow(_ node: FileNode) -> some View {
        HStack(spacing: 6) {
            Image(systemName: node.isDirectory ? "folder" : fileIcon(for: node.name))
                .foregroundStyle(node.isDirectory ? .blue : .secondary)
                .font(.caption)
                .frame(width: 14)
            Text(node.name)
                .font(.callout)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !node.isDirectory {
                state.insertFileReference(node.url.path)
            }
        }
    }

    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "js", "ts", "jsx", "tsx": return "chevron.left.forwardslash.chevron.right"
        case "json", "yaml", "yml", "toml": return "doc.text"
        case "md", "txt": return "doc.plaintext"
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return "photo"
        case "pdf": return "doc.richtext"
        case "sh", "zsh", "bash": return "terminal"
        default: return "doc"
        }
    }
}

private extension FileNode {
    // List(children:) requires Optional<[FileNode]>:
    // - nil means leaf (no disclosure triangle)
    // - empty array shows an empty expandable group
    var optionalChildren: [FileNode]? { children }
}
