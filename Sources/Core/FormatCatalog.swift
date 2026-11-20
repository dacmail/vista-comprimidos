import Foundation

/// Un formato definido en `formats.json`.
struct ArchiveFormat: Decodable {
    struct Declaration: Decodable {
        var identifier: String
        var description: String
        var conformsTo: [String]
    }

    var id: String
    var name: String
    var reader: String
    var extensions: [String]
    var types: [String]
    var declare: Declaration?

    /// Todos los UTIs que identifican este formato (los del sistema + el declarado).
    var allTypes: [String] { types + (declare.map { [$0.identifier] } ?? []) }
}

/// Catálogo de formatos cargado desde `formats.json`.
struct FormatCatalog: Decodable {
    var formats: [ArchiveFormat]

    static func load(from url: URL) throws -> FormatCatalog {
        try JSONDecoder().decode(FormatCatalog.self, from: Data(contentsOf: url))
    }

    /// El catálogo copiado dentro del bundle (extensión o app).
    static func bundled(_ bundle: Bundle = .main) -> FormatCatalog? {
        guard let url = bundle.url(forResource: "formats", withExtension: "json") else { return nil }
        return try? load(from: url)
    }

    /// Busca el formato de un archivo: primero por extensión (la más larga gana, para que
    /// "x.tar.gz" sea tar+gzip y no gzip) y si no, por su UTI.
    func format(for url: URL, contentType: String? = nil) -> ArchiveFormat? {
        let name = url.lastPathComponent.lowercased()
        var best: (ArchiveFormat, Int)?
        for format in formats {
            for ext in format.extensions where name.hasSuffix("." + ext.lowercased()) {
                if best == nil || ext.count > best!.1 { best = (format, ext.count) }
            }
        }
        if let best { return best.0 }
        if let contentType {
            return formats.first { $0.allTypes.contains(contentType) }
        }
        return nil
    }
}
