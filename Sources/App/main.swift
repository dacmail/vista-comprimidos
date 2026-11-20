import AppKit

// App contenedora mínima: su única función es llevar dentro la extensión y declarar
// los tipos de archivo nuevos. Basta con abrirla una vez para que macOS la registre.

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let formats = loadFormatNames()
        let text = """
        La extensión de Vista Rápida para comprimidos está instalada.

        Selecciona un comprimido en el Finder y pulsa la barra espaciadora para ver su contenido.

        Formatos: \(formats)

        Si no funciona, revisa que esté activada en Ajustes del Sistema → General → \
        Ítems de inicio y extensiones → Vista Rápida.
        """

        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 13)
        label.isSelectable = true

        let settings = NSButton(title: "Abrir ajustes de extensiones", target: self, action: #selector(openSettings))
        let close = NSButton(title: "Cerrar", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        close.keyEquivalent = "\r"

        let buttons = NSStackView(views: [settings, close])
        buttons.orientation = .horizontal

        let stack = NSStackView(views: [label, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 460).isActive = true

        window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Vista de Comprimidos"
        window.contentView = stack
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    @objc func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
            NSWorkspace.shared.open(url)
        }
    }

    private func loadFormatNames() -> String {
        guard let plugins = Bundle.main.builtInPlugInsURL,
              let appex = Bundle(url: plugins.appendingPathComponent("ArchivePreviewExtension.appex")),
              let catalog = FormatCatalog.bundled(appex) else { return "—" }
        return catalog.formats.map(\.name).joined(separator: ", ")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
