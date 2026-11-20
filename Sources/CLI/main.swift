import Foundation

// Herramienta de pruebas: lista un comprimido en la terminal con el mismo código que usa
// la extensión, y opcionalmente guarda el HTML de la vista previa.
//
//   archive-list [--formats formats.json] [--html salida.html] archivo...

var args = Array(CommandLine.arguments.dropFirst())
var formatsPath = "formats.json"
var htmlOut: String?

func take(_ flag: String) -> String? {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    let value = args[i + 1]
    args.removeSubrange(i...(i + 1))
    return value
}
if let p = take("--formats") { formatsPath = p }
htmlOut = take("--html")

guard !args.isEmpty else {
    FileHandle.standardError.write("uso: archive-list [--formats formats.json] [--html out.html] archivo...\n".data(using: .utf8)!)
    exit(2)
}

let catalog: FormatCatalog
do {
    catalog = try FormatCatalog.load(from: URL(fileURLWithPath: formatsPath))
} catch {
    FileHandle.standardError.write("No se pudo leer \(formatsPath): \(error)\n".data(using: .utf8)!)
    exit(2)
}

var failures = 0
for path in args {
    let url = URL(fileURLWithPath: path)
    let format = catalog.format(for: url)
    print("== \(url.lastPathComponent)  [\(format?.name ?? "formato desconocido")]")
    do {
        let listing = try ReaderRegistry.reader(id: format?.reader).list(url: url, limits: ListingLimits())
        print("   detectado: \(listing.detectedFormat ?? "?")  entradas: \(listing.entries.count)"
              + (listing.truncated ? "  (parcial)" : "")
              + (listing.hasEncryptedEntries ? "  (cifrado)" : ""))
        for e in listing.entries.prefix(8) {
            let kind = e.kind == .directory ? "d" : e.kind == .symlink ? "l" : "-"
            print("   \(kind) \(String(e.size ?? -1).padding(toLength: 10, withPad: " ", startingAt: 0)) \(e.path)")
        }
        if listing.entries.count > 8 { print("   …") }
        for w in listing.warnings { print("   aviso: \(w)") }
    } catch {
        failures += 1
        print("   ERROR: \((error as? LocalizedError)?.errorDescription ?? "\(error)")")
    }
}

if let htmlOut, let first = args.first {
    let html = PreviewBuilder.html(for: URL(fileURLWithPath: first), catalog: catalog)
    try html.write(toFile: htmlOut, atomically: true, encoding: .utf8)
    print("HTML guardado en \(htmlOut)")
}
exit(failures == 0 ? 0 : 1)
