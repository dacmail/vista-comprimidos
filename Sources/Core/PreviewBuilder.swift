import Foundation

/// Punto de entrada común para la extensión de Vista Rápida y la herramienta de terminal:
/// dado un archivo, elige formato y motor, lo lista y devuelve el HTML.
enum PreviewBuilder {
    static func html(for url: URL, catalog: FormatCatalog?, contentType: String? = nil,
                     limits: ListingLimits = ListingLimits()) -> String {
        let format = catalog?.format(for: url, contentType: contentType)
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
        let renderer = HTMLRenderer(fileName: url.lastPathComponent, formatName: format?.name, archiveSize: size)
        do {
            let listing = try ReaderRegistry.reader(id: format?.reader).list(url: url, limits: limits)
            return renderer.render(listing: listing)
        } catch {
            return renderer.render(error: error)
        }
    }
}
