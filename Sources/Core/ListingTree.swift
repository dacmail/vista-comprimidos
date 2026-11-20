import Foundation

/// Árbol de carpetas construido a partir de la lista plana de entradas.
/// Crea las carpetas intermedias que algunos formatos (ZIP sobre todo) no incluyen.
final class TreeNode {
    let name: String
    var isDirectory: Bool
    var entry: ArchiveEntry?
    var children: [String: TreeNode] = [:]

    init(name: String, isDirectory: Bool) {
        self.name = name
        self.isDirectory = isDirectory
    }

    /// Hijos ordenados: carpetas primero, luego por nombre (orden natural, sin mayúsculas).
    var sortedChildren: [TreeNode] {
        children.values.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// Tamaño total (suma de archivos) y si algún tamaño es desconocido.
    lazy var totalSize: (bytes: Int64, unknown: Bool) = {
        if !isDirectory { return (entry?.size ?? 0, entry?.size == nil) }
        var bytes: Int64 = 0, unknown = false
        for child in children.values {
            let s = child.totalSize
            bytes += s.bytes
            unknown = unknown || s.unknown
        }
        return (bytes, unknown)
    }()

    lazy var descendantCount: Int = children.values.reduce(0) { $0 + 1 + $1.descendantCount }
}

struct ListingTree {
    let root = TreeNode(name: "", isDirectory: true)
    private(set) var fileCount = 0
    private(set) var directoryCount = 0
    /// Entradas ocultas por ser "ruido" (p. ej. la carpeta __MACOSX que añade el Finder).
    private(set) var hiddenCount = 0

    static let hiddenRoots: Set<String> = ["__MACOSX"]

    init(entries: [ArchiveEntry]) {
        for entry in entries { insert(entry) }
    }

    private mutating func insert(_ entry: ArchiveEntry) {
        let parts = entry.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { $0 != "." }
        guard !parts.isEmpty else { return }
        if Self.hiddenRoots.contains(parts[0]) { hiddenCount += 1; return }

        var node = root
        for (i, part) in parts.enumerated() {
            let isLast = i == parts.count - 1
            let isDir = isLast ? entry.kind == .directory : true
            if let existing = node.children[part] {
                node = existing
                if isLast && isDir && !existing.isDirectory { existing.isDirectory = true }
            } else {
                let child = TreeNode(name: part, isDirectory: isDir)
                node.children[part] = child
                if isDir { directoryCount += 1 } else { fileCount += 1 }
                node = child
            }
            if isLast { node.entry = entry }
        }
    }
}
