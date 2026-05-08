import Foundation

struct FileNode: Identifiable {
    let id: String        // absolute path
    let name: String
    let url: URL
    let isDirectory: Bool
    var children: [FileNode]?  // nil = file (leaf), [...] = directory

    // Directories and files that should never appear in the tree
    private static let skipNames: Set<String> = [
        ".git", ".build", ".swiftpm", "node_modules", "__pycache__",
        ".DS_Store", "DerivedData", ".idea", ".vscode",
        "venv", ".venv", ".tox", "dist", "build",
    ]

    static func loadTree(at workspacePath: String, depth: Int = 4) -> [FileNode] {
        loadChildren(of: URL(fileURLWithPath: workspacePath), depth: depth)
    }

    static func loadChildren(of url: URL, depth: Int) -> [FileNode] {
        guard depth > 0,
              let entries = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
              )
        else { return [] }

        let nodes: [FileNode] = entries
            .filter { !skipNames.contains($0.lastPathComponent) }
            .compactMap { childURL in
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: childURL.path, isDirectory: &isDir)
                let dir = isDir.boolValue
                return FileNode(
                    id: childURL.path,
                    name: childURL.lastPathComponent,
                    url: childURL,
                    isDirectory: dir,
                    children: dir ? loadChildren(of: childURL, depth: depth - 1) : nil
                )
            }

        return nodes.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}
