import Foundation
import Observation

@Observable
final class FileNode: Identifiable {
    let id: String
    let name: String
    let url: URL
    let isDirectory: Bool
    private(set) var children: [FileNode] = []
    private(set) var isLoaded: Bool

    init(url: URL, isDirectory: Bool) {
        self.id = url.path
        self.name = url.lastPathComponent
        self.url = url
        self.isDirectory = isDirectory
        self.isLoaded = !isDirectory
    }

    func loadChildrenIfNeeded() {
        guard isDirectory, !isLoaded else { return }
        isLoaded = true
        children = Self.directChildren(of: url)
    }

    /// Non-blocking: reads children on a background thread, then updates on MainActor.
    func loadChildrenIfNeededAsync() {
        guard isDirectory, !isLoaded else { return }
        isLoaded = true
        let url = self.url
        Task.detached(priority: .userInitiated) { [weak self] in
            let loaded = FileNode.directChildren(of: url)
            await MainActor.run { self?.children = loaded }
        }
    }

    static func loadRoots(at path: String) -> [FileNode] {
        directChildren(of: URL(fileURLWithPath: path))
    }

    static func directChildren(of url: URL) -> [FileNode] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        let nodes = entries
            .filter { !skipNames.contains($0.lastPathComponent) }
            .compactMap { childURL -> FileNode? in
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: childURL.path, isDirectory: &isDir)
                return FileNode(url: childURL, isDirectory: isDir.boolValue)
            }

        return nodes.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private static let skipNames: Set<String> = [
        ".git", ".build", ".swiftpm", "node_modules", "__pycache__",
        ".DS_Store", "DerivedData", ".idea", ".vscode",
        "venv", ".venv", ".tox", "dist", "build",
    ]
}
