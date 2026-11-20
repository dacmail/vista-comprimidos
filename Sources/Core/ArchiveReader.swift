import Foundation

/// Una entrada (archivo, carpeta o enlace) dentro de un comprimido.
struct ArchiveEntry {
    enum Kind { case file, directory, symlink }

    var path: String
    var kind: Kind
    /// Tamaño descomprimido, si el formato lo conoce.
    var size: Int64?
    var modified: Date?
    var isEncrypted: Bool = false
    var linkTarget: String? = nil
}

/// Resultado de listar un comprimido.
struct ArchiveListing {
    var entries: [ArchiveEntry] = []
    /// Descripción técnica del formato detectado (p. ej. "RAR5", "GNU tar + gzip").
    var detectedFormat: String?
    /// true si se cortó el listado por límite de entradas o de tiempo.
    var truncated = false
    /// true si el comprimido tiene entradas cifradas.
    var hasEncryptedEntries = false
    var warnings: [String] = []
}

/// Límites para que la vista previa responda rápido aunque el comprimido sea enorme.
struct ListingLimits {
    var maxEntries = 20_000
    var timeBudget: TimeInterval = 6
    /// Para archivos comprimidos sueltos (.gz, .xz…): cuántos bytes descomprimir como máximo
    /// para calcular su tamaño original.
    var maxRawBytes: Int64 = 2 * 1024 * 1024 * 1024
}

enum ArchiveReaderError: LocalizedError {
    case cannotOpen(String)
    case unrecognized
    case encrypted
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cannotOpen(let msg): return "No se pudo abrir el archivo: \(msg)"
        case .unrecognized: return "Formato no reconocido o archivo dañado."
        case .encrypted: return "El comprimido está cifrado y no se puede listar sin la contraseña."
        case .failed(let msg): return msg
        }
    }
}

/// Un "motor" capaz de listar el contenido de uno o varios formatos.
///
/// Para añadir un motor nuevo:
///  1. Crea un tipo que cumpla este protocolo (mira `LibarchiveReader`).
///  2. Regístralo en `ReaderRegistry.all`.
///  3. Usa su `id` en el campo `reader` de los formatos de `formats.json`.
protocol ArchiveReader {
    static var id: String { get }
    init()
    func list(url: URL, limits: ListingLimits) throws -> ArchiveListing
}

enum ReaderRegistry {
    /// Todos los motores disponibles. El primero es el que se usa por defecto.
    static let all: [ArchiveReader.Type] = [
        LibarchiveReader.self,
    ]

    static func reader(id: String?) -> ArchiveReader {
        let type = all.first { $0.id == id } ?? all[0]
        return type.init()
    }
}
