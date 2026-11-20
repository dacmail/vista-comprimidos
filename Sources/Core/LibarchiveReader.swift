import Foundation
import CArchive

/// Motor basado en libarchive (incluida en macOS).
///
/// Lee: ZIP, 7z, RAR (v4 y v5), tar (y tar.gz/bz2/xz/zst/lz4…), cpio, xar, ISO 9660,
/// CAB, LHA, ar/deb, RPM y archivos comprimidos sueltos (.gz, .bz2, .xz, .zst…).
struct LibarchiveReader: ArchiveReader {
    static let id = "libarchive"

    func list(url: URL, limits: ListingLimits) throws -> ArchiveListing {
        do {
            return try read(url: url, raw: false, limits: limits)
        } catch ArchiveReaderError.unrecognized {
            // No es un contenedor: puede ser un archivo comprimido suelto (p. ej. notas.txt.gz).
            return try read(url: url, raw: true, limits: limits)
        }
    }

    private func read(url: URL, raw: Bool, limits: ListingLimits) throws -> ArchiveListing {
        guard let a = archive_read_new() else { throw ArchiveReaderError.failed("libarchive no disponible") }
        defer { archive_read_free(a) }

        archive_read_support_filter_all(a)
        if raw {
            archive_read_support_format_raw(a)
        } else {
            archive_read_support_format_all(a)
        }

        // libarchive detecta el formato ya al abrir, así que aquí también puede salir "no reconocido".
        guard archive_read_open_filename(a, url.path, 64 * 1024) == ARCHIVE_OK else {
            if archive_errno(a) == EFTYPE {
                throw raw ? ArchiveReaderError.failed("Formato no reconocido o archivo dañado.")
                          : ArchiveReaderError.unrecognized
            }
            throw ArchiveReaderError.cannotOpen(errorString(a))
        }

        // En modo "raw" cualquier archivo "vale"; solo tiene sentido si hay compresión real.
        if raw, !(0..<archive_filter_count(a)).contains(where: { string(archive_filter_name(a, $0)) != "none" }) {
            throw ArchiveReaderError.failed("Formato no reconocido o archivo dañado.")
        }

        var listing = ArchiveListing()
        let deadline = Date().addingTimeInterval(limits.timeBudget)
        var entry: OpaquePointer?

        while true {
            let status = archive_read_next_header(a, &entry)
            if status == ARCHIVE_EOF { break }
            if status == ARCHIVE_WARN {
                listing.warnings.append(errorString(a))
            } else if status != ARCHIVE_OK {
                if listing.entries.isEmpty {
                    if archive_errno(a) == EFTYPE, !raw { throw ArchiveReaderError.unrecognized }
                    if looksEncrypted(a) { throw ArchiveReaderError.encrypted }
                    throw ArchiveReaderError.failed(errorString(a))
                }
                listing.warnings.append("Listado incompleto: \(errorString(a))")
                listing.truncated = true
                break
            }
            guard let entry else { break }

            if listing.detectedFormat == nil { listing.detectedFormat = formatDescription(a, raw: raw) }

            var item = makeEntry(entry)
            if raw {
                // En modo "raw" libarchive llama a la entrada "data": usamos el nombre del archivo
                // sin la extensión de compresión, y descomprimimos para saber el tamaño real.
                item.path = url.deletingPathExtension().lastPathComponent
                item.size = countRawBytes(a, limits: limits, deadline: deadline, listing: &listing)
            }
            if item.isEncrypted { listing.hasEncryptedEntries = true }
            listing.entries.append(item)

            if listing.entries.count >= limits.maxEntries || Date() > deadline {
                listing.truncated = true
                break
            }
        }

        if archive_read_has_encrypted_entries(a) > 0 { listing.hasEncryptedEntries = true }
        if listing.detectedFormat == nil { listing.detectedFormat = formatDescription(a, raw: raw) }
        return listing
    }

    private func makeEntry(_ e: OpaquePointer) -> ArchiveEntry {
        let path = string(archive_entry_pathname_utf8(e)) ?? string(archive_entry_pathname(e)) ?? "?"
        let kind: ArchiveEntry.Kind
        switch archive_entry_filetype(e) {
        case AE_IFDIR: kind = .directory
        case AE_IFLNK: kind = .symlink
        default: kind = path.hasSuffix("/") ? .directory : .file
        }
        return ArchiveEntry(
            path: path,
            kind: kind,
            size: archive_entry_size_is_set(e) != 0 ? archive_entry_size(e) : nil,
            modified: archive_entry_mtime_is_set(e) != 0
                ? Date(timeIntervalSince1970: TimeInterval(archive_entry_mtime(e))) : nil,
            isEncrypted: archive_entry_is_encrypted(e) != 0,
            linkTarget: kind == .symlink ? string(archive_entry_symlink_utf8(e)) : nil
        )
    }

    private func countRawBytes(_ a: OpaquePointer, limits: ListingLimits, deadline: Date,
                               listing: inout ArchiveListing) -> Int64? {
        var total: Int64 = 0
        let bufferSize = 256 * 1024
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: 16)
        defer { buffer.deallocate() }
        while true {
            let n = archive_read_data(a, buffer, bufferSize)
            if n == 0 { return total }
            if n < 0 { listing.warnings.append(errorString(a)); return nil }
            total += Int64(n)
            if total > limits.maxRawBytes || Date() > deadline {
                listing.warnings.append("Tamaño original no calculado del todo (archivo muy grande).")
                return nil
            }
        }
    }

    private func formatDescription(_ a: OpaquePointer, raw: Bool) -> String? {
        var parts: [String] = []
        if !raw, var f = string(archive_format_name(a)) {
            // "ZIP 2.0 (deflation)" describe solo la primera entrada: nos quedamos con "ZIP".
            if f.hasPrefix("ZIP") { f = "ZIP" }
            parts.append(f)
        }
        // Filtros de compresión (el índice 0 es el más externo; "none" no aporta nada).
        let count = archive_filter_count(a)
        for i in 0..<count {
            if let name = string(archive_filter_name(a, i)), name != "none" { parts.append(name) }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " + ")
    }

    private func looksEncrypted(_ a: OpaquePointer) -> Bool {
        if archive_read_has_encrypted_entries(a) > 0 { return true }
        let msg = errorString(a).lowercased()
        return msg.contains("encrypt") || msg.contains("passphrase") || msg.contains("password")
    }

    private func errorString(_ a: OpaquePointer) -> String {
        string(archive_error_string(a)) ?? "error desconocido"
    }

    private func string(_ p: UnsafePointer<CChar>?) -> String? {
        p.map { String(cString: $0) }
    }
}
