#!/usr/bin/env python3
"""Genera los Info.plist de la app y de la extensión a partir de formats.json.

uso: gen-plists.py formats.json <dir-salida> <bundle-id> <versión>
"""
import json
import plistlib
import sys
from pathlib import Path

formats_path, out_dir, bundle_id, version = sys.argv[1:5]
formats = json.loads(Path(formats_path).read_text())["formats"]
out = Path(out_dir)
out.mkdir(parents=True, exist_ok=True)

ids = [f["id"] for f in formats]
dupes = {i for i in ids if ids.count(i) > 1}
if dupes:
    sys.exit(f"formats.json: ids repetidos: {', '.join(sorted(dupes))}")

supported, imported = [], []
for f in formats:
    for uti in f.get("types", []):
        if uti not in supported:
            supported.append(uti)
    decl = f.get("declare")
    if decl:
        supported.append(decl["identifier"])
        imported.append({
            "UTTypeIdentifier": decl["identifier"],
            "UTTypeDescription": decl["description"],
            "UTTypeConformsTo": decl["conformsTo"],
            "UTTypeTagSpecification": {
                # Solo extensiones simples: macOS no entiende "tar.zst" como extensión.
                "public.filename-extension": [e for e in f["extensions"] if "." not in e],
            },
        })

common = {
    "CFBundleDevelopmentRegion": "es",
    "CFBundleInfoDictionaryVersion": "6.0",
    "CFBundleShortVersionString": version,
    "CFBundleVersion": version,
    "CFBundleSupportedPlatforms": ["MacOSX"],
    "LSMinimumSystemVersion": "13.0",
}

app = {
    **common,
    "CFBundleIdentifier": bundle_id,
    "CFBundleName": "Vista de Comprimidos",
    "CFBundleDisplayName": "Vista de Comprimidos",
    "CFBundleExecutable": "ArchivePreview",
    "CFBundlePackageType": "APPL",
    "LSApplicationCategoryType": "public.app-category.utilities",
    "NSPrincipalClass": "NSApplication",
    "UTImportedTypeDeclarations": imported,
}

ext = {
    **common,
    "CFBundleIdentifier": bundle_id + ".extension",
    "CFBundleName": "ArchivePreviewExtension",
    "CFBundleDisplayName": "Vista de Comprimidos",
    "CFBundleExecutable": "ArchivePreviewExtension",
    "CFBundlePackageType": "XPC!",
    "NSExtension": {
        "NSExtensionPointIdentifier": "com.apple.quicklook.preview",
        "NSExtensionPrincipalClass": "PreviewProvider",
        "NSExtensionAttributes": {
            "QLIsDataBasedPreview": True,
            "QLSupportsSearchableItems": False,
            "QLSupportedContentTypes": supported,
        },
    },
}

(out / "App-Info.plist").write_bytes(plistlib.dumps(app))
(out / "Extension-Info.plist").write_bytes(plistlib.dumps(ext))
print(f"{len(formats)} formatos, {len(supported)} UTIs, {len(imported)} declarados")
