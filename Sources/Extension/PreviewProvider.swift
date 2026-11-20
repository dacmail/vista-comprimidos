import Foundation
import QuickLookUI
import UniformTypeIdentifiers

/// Extensión de Vista Rápida "basada en datos": devolvemos HTML y macOS lo muestra.
/// El nombre ObjC fijo coincide con NSExtensionPrincipalClass del Info.plist.
@objc(PreviewProvider)
final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    private static let catalog = FormatCatalog.bundled()

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let url = request.fileURL
        let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.identifier
        let html = PreviewBuilder.html(for: url, catalog: Self.catalog, contentType: type)

        let reply = QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 820, height: 620)) { reply in
            reply.stringEncoding = .utf8
            return Data(html.utf8)
        }
        reply.title = url.lastPathComponent
        return reply
    }
}
