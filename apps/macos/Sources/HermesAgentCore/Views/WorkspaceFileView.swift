import SwiftUI

struct WorkspaceFileView: View {
    @Bindable var state: AppState
    @State private var roots: [FileNode] = []
    @State private var isLoading = false
    @State private var lastInserted: String? = nil
    @State private var reloadTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Path header + refresh
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(workspaceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(state.workspacePath)
                Spacer()
                Button { reload() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

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
                List {
                    ForEach(roots) { node in
                        FileRowView(node: node, lastInserted: $lastInserted) { selected in
                            state.insertFileReference(selected.url.path)
                            lastInserted = selected.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                if lastInserted == selected.id { lastInserted = nil }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .onAppear { reload() }
        .onChange(of: state.workspacePath) { _, _ in reload() }
    }

    private var workspaceName: String {
        URL(fileURLWithPath: state.workspacePath).lastPathComponent
    }

    private func reload() {
        reloadTask?.cancel()
        guard !state.workspacePath.isEmpty else { return }
        isLoading = true
        let path = state.workspacePath
        reloadTask = Task {
            let nodes = await Task.detached(priority: .userInitiated) {
                FileNode.loadRoots(at: path)
            }.value
            guard !Task.isCancelled else { return }
            roots = nodes
            isLoading = false
        }
    }
}

private struct FileRowView: View {
    let node: FileNode
    @Binding var lastInserted: String?
    let onSelect: (FileNode) -> Void

    @State private var isExpanded = false

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(node.children) { child in
                    FileRowView(node: child, lastInserted: $lastInserted, onSelect: onSelect)
                }
            } label: {
                rowLabel
            }
            .onChange(of: isExpanded) { _, expanded in
                if expanded { node.loadChildrenIfNeededAsync() }
            }
        } else {
            rowLabel
                .contentShape(Rectangle())
                .onTapGesture { onSelect(node) }
        }
    }

    @ViewBuilder
    private var rowLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: node.isDirectory ? "folder" : fileIcon(for: node.name))
                .foregroundStyle(node.isDirectory ? Color.accentColor : .secondary)
                .font(.caption)
                .frame(width: 14)
            Text(node.name)
                .font(.callout)
                .lineLimit(1)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
        .background(
            lastInserted == node.id
                ? Color.accentColor.opacity(0.2)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .animation(.easeOut(duration: 0.5), value: lastInserted)
    }

    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift":                          return "swift"
        case "py":                             return "chevron.left.forwardslash.chevron.right"
        case "js", "ts", "jsx", "tsx":        return "chevron.left.forwardslash.chevron.right"
        case "json", "yaml", "yml", "toml":   return "doc.text"
        case "md", "txt":                      return "doc.plaintext"
        case "png", "jpg", "jpeg", "gif",
             "svg", "webp":                    return "photo"
        case "pdf":                            return "doc.richtext"
        case "sh", "zsh", "bash":             return "terminal"
        default:                               return "doc"
        }
    }
}
