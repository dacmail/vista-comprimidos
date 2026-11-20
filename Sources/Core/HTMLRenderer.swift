import Foundation

/// Genera la página HTML que muestra Vista Rápida. Sin JavaScript: las carpetas se
/// pliegan/despliegan con <details>, que funciona en la vista previa de macOS.
struct HTMLRenderer {
    var fileName: String
    var formatName: String?
    var archiveSize: Int64?

    // MARK: - Páginas

    func render(listing: ArchiveListing) -> String {
        let tree = ListingTree(entries: listing.entries)
        let total = tree.root.totalSize

        var stats: [String] = []
        stats.append(plural(tree.fileCount, "archivo", "archivos"))
        if tree.directoryCount > 0 { stats.append(plural(tree.directoryCount, "carpeta", "carpetas")) }
        if total.bytes > 0 || !total.unknown {
            stats.append("\(bytes(total.bytes))\(total.unknown ? "+" : "") descomprimido")
        }
        if let archiveSize {
            var s = "\(bytes(archiveSize)) en disco"
            if total.bytes > 0, !total.unknown, archiveSize < total.bytes {
                let pct = Int((Double(archiveSize) / Double(total.bytes) * 100).rounded())
                s += " (\(pct) %)"
            }
            stats.append(s)
        }

        var notes: [String] = []
        if listing.hasEncryptedEntries { notes.append("🔒 Contiene archivos cifrados.") }
        if listing.truncated { notes.append("Listado parcial: se muestran las primeras \(listing.entries.count) entradas.") }
        if tree.hiddenCount > 0 { notes.append("Ocultas \(tree.hiddenCount) entradas de __MACOSX (metadatos del Finder).") }
        notes += uniqued(listing.warnings).prefix(5).map { "⚠️ \($0)" }

        let openAll = tree.root.descendantCount <= 300
        var rows = ""
        if tree.root.children.isEmpty {
            rows = #"<div class="empty">El comprimido está vacío.</div>"#
        } else {
            for child in tree.root.sortedChildren { renderNode(child, depth: 0, openAll: openAll, into: &rows) }
        }

        let body = """
        <header>
          <div class="title">\(icon(forFile: fileName, directory: false, archive: true)) \(esc(fileName))</div>
          <div class="sub">\(subtitle(detected: listing.detectedFormat))</div>
          <div class="stats">\(stats.map { "<span>\(esc($0))</span>" }.joined())</div>
          \(notes.isEmpty ? "" : "<ul class=\"notes\">" + notes.map { "<li>\(esc($0))</li>" }.joined() + "</ul>")
        </header>
        <div class="list">
          <div class="row head"><span class="name">Nombre</span><span class="size">Tamaño</span><span class="date">Modificado</span></div>
          \(rows)
        </div>
        """
        return page(body)
    }

    func render(error: Error) -> String {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        var sub = formatName.map(esc) ?? ""
        if let archiveSize { sub += (sub.isEmpty ? "" : " · ") + bytes(archiveSize) }
        return page("""
        <header>
          <div class="title">\(icon(forFile: fileName, directory: false, archive: true)) \(esc(fileName))</div>
          <div class="sub">\(sub)</div>
        </header>
        <div class="error">\(esc(message))</div>
        """)
    }

    // MARK: - Filas

    private func renderNode(_ node: TreeNode, depth: Int, openAll: Bool, into out: inout String) {
        let indent = "style=\"--d:\(depth)\""
        if node.isDirectory {
            let size = node.totalSize
            let sizeText = node.children.isEmpty ? "—" : bytes(size.bytes) + (size.unknown ? "+" : "")
            let open = openAll || node.descendantCount <= 25
            out += "<details\(open ? " open" : "")><summary class=\"row dir\" \(indent)>"
            out += "<span class=\"name\"><span class=\"tw\"></span>📁 \(esc(node.name))"
            out += "<span class=\"count\">\(node.descendantCount)</span></span>"
            out += "<span class=\"size\">\(sizeText)</span><span class=\"date\">\(date(node.entry?.modified))</span>"
            out += "</summary>"
            for child in node.sortedChildren { renderNode(child, depth: depth + 1, openAll: openAll, into: &out) }
            out += "</details>"
        } else {
            let e = node.entry
            var name = esc(node.name)
            if e?.kind == .symlink {
                name += " <span class=\"link\">→ \(esc(e?.linkTarget ?? "?"))</span>"
            }
            let lock = e?.isEncrypted == true ? " 🔒" : ""
            let symbol = e?.kind == .symlink ? "🔗" : icon(forFile: node.name, directory: false, archive: false)
            out += "<div class=\"row\" \(indent)><span class=\"name\"><span class=\"tw\"></span>\(symbol) \(name)\(lock)</span>"
            out += "<span class=\"size\">\(e?.size.map(bytes) ?? "—")</span>"
            out += "<span class=\"date\">\(date(e?.modified))</span></div>"
        }
    }

    // MARK: - Utilidades

    private func subtitle(detected: String?) -> String {
        var parts: [String] = []
        if let formatName { parts.append(esc(formatName)) }
        if let detected, detected.caseInsensitiveCompare(formatName ?? "") != .orderedSame {
            parts.append("<span class=\"muted\">\(esc(detected))</span>")
        }
        return parts.joined(separator: " · ")
    }

    private func icon(forFile name: String, directory: Bool, archive: Bool) -> String {
        if archive { return "🗜️" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "heic", "webp", "tif", "tiff", "bmp", "svg", "ico", "psd", "raw", "dng":
            return "🖼️"
        case "mp3", "m4a", "wav", "aiff", "aif", "flac", "ogg", "opus", "aac":
            return "🎵"
        case "mp4", "mov", "m4v", "mkv", "avi", "webm", "wmv":
            return "🎬"
        case "pdf":
            return "📕"
        case "doc", "docx", "odt", "rtf", "pages", "txt", "md", "markdown":
            return "📝"
        case "xls", "xlsx", "ods", "csv", "tsv", "numbers":
            return "📊"
        case "ppt", "pptx", "odp", "key":
            return "📽️"
        case "zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "zst", "lz4", "cab", "iso", "dmg", "pkg", "jar", "apk":
            return "🗜️"
        case "swift", "c", "h", "m", "cpp", "hpp", "js", "ts", "jsx", "tsx", "py", "rb", "php", "java", "kt",
             "go", "rs", "sh", "zsh", "css", "scss", "html", "htm", "json", "xml", "yml", "yaml", "toml", "sql":
            return "📜"
        case "ttf", "otf", "woff", "woff2":
            return "🔤"
        case "app", "exe", "dll", "so", "dylib", "bin":
            return "⚙️"
        default:
            return "📄"
        }
    }

    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f
    }()

    private func bytes(_ n: Int64) -> String { Self.byteFormatter.string(fromByteCount: n) }

    private func date(_ d: Date?) -> String {
        // Fechas imposibles (0 o muy antiguas) son habituales en ISO/cpio: no las mostramos.
        guard let d, d.timeIntervalSince1970 > 86_400 else { return "" }
        return Self.dateFormatter.string(from: d)
    }

    private func plural(_ n: Int, _ one: String, _ many: String) -> String {
        "\(n.formatted()) \(n == 1 ? one : many)"
    }

    private func uniqued(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }
    }

    private func esc(_ s: String) -> String {
        var r = ""
        r.reserveCapacity(s.count)
        for c in s {
            switch c {
            case "&": r += "&amp;"
            case "<": r += "&lt;"
            case ">": r += "&gt;"
            case "\"": r += "&quot;"
            default: r.append(c)
            }
        }
        return r
    }

    private func page(_ body: String) -> String {
        """
        <!doctype html>
        <html lang="es"><head><meta charset="utf-8">
        <meta name="color-scheme" content="light dark">
        <style>\(Self.css)</style></head>
        <body>\(body)</body></html>
        """
    }

    private static let css = """
    :root {
      --bg: #ffffff; --fg: #1d1d1f; --muted: #6e6e73; --line: #e5e5ea;
      --head: #f5f5f7; --hover: #f0f4ff; --accent: #0a64d8; --warn-bg: #fff8e6; --err: #c4302b;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #1e1e1e; --fg: #f2f2f7; --muted: #98989d; --line: #333336;
        --head: #2a2a2c; --hover: #23324a; --accent: #4f9cff; --warn-bg: #3a3220; --err: #ff6b63;
      }
    }
    * { box-sizing: border-box; }
    html, body { margin: 0; background: var(--bg); color: var(--fg);
      font: 13px/1.4 -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; }
    header { padding: 16px 18px 12px; border-bottom: 1px solid var(--line); }
    .title { font-size: 17px; font-weight: 600; word-break: break-all; }
    .sub { color: var(--muted); margin-top: 2px; }
    .muted { color: var(--muted); }
    .stats { margin-top: 8px; display: flex; flex-wrap: wrap; gap: 6px; }
    .stats span { background: var(--head); border: 1px solid var(--line); border-radius: 6px; padding: 2px 8px;
      font-variant-numeric: tabular-nums; }
    .notes { margin: 10px 0 0; padding: 6px 10px 6px 26px; background: var(--warn-bg); border-radius: 6px; }
    .notes li { margin: 2px 0; }
    .list { padding-bottom: 12px; }
    .row { display: grid; grid-template-columns: minmax(0, 1fr) 90px 128px; gap: 12px;
      padding: 3px 18px 3px calc(18px + var(--d, 0) * 18px); border-bottom: 1px solid var(--line); }
    .row:hover { background: var(--hover); }
    .row.head { position: sticky; top: 0; background: var(--head); color: var(--muted); font-weight: 600;
      font-size: 11px; text-transform: uppercase; letter-spacing: .03em; padding-left: 18px; z-index: 1; }
    .name { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .size, .date { text-align: right; color: var(--muted); font-variant-numeric: tabular-nums; white-space: nowrap; }
    .count { color: var(--muted); font-size: 11px; margin-left: 6px; }
    .count::before { content: "("; } .count::after { content: ")"; }
    .link { color: var(--muted); }
    .tw { display: inline-block; width: 14px; }
    summary { list-style: none; cursor: default; }
    summary::-webkit-details-marker { display: none; }
    summary.dir .tw::before { content: "▸"; color: var(--muted); }
    details[open] > summary.dir .tw::before { content: "▾"; }
    .dir .name { font-weight: 500; }
    @media (max-width: 520px) {
      .row { grid-template-columns: minmax(0, 1fr) 80px; padding-left: calc(10px + var(--d, 0) * 12px); padding-right: 10px; }
      .row .date { display: none; }
      header { padding: 12px 10px; }
    }
    .empty, .error { padding: 24px 18px; color: var(--muted); }
    .error { color: var(--err); font-weight: 500; }
    """
}
