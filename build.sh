#!/bin/bash
# Compila la app + extensión de Vista Rápida sin Xcode (solo Command Line Tools).
#
#   ./build.sh            compila en build/
#   ./build.sh install    compila, copia a ~/Applications, la registra y reinicia Vista Rápida
#   ./build.sh test       compila la herramienta de terminal y prueba los comprimidos de Tests/
#   ./build.sh release    compila (universal: Apple Silicon + Intel) y crea el .zip para publicar
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Vista de Comprimidos"
BUNDLE_ID="local.archivepreview"
VERSION="1.0.2"
MIN_MACOS="13.0"
ARCHS=(arm64 x86_64)
INSTALL_DIR="$HOME/Applications"

BUILD="build"
APP="$BUILD/$APP_NAME.app"
APPEX="$APP/Contents/PlugIns/ArchivePreviewExtension.appex"
SWIFT_FLAGS=(-swift-version 5 -O -I Sources/CArchive)
CORE=(Sources/Core/*.swift)

# Compila un ejecutable universal: uno por arquitectura y luego los une con lipo.
#   swiftc_universal <salida> <argumentos de swiftc…>
swiftc_universal() {
    local out="$1"; shift
    local parts=()
    for arch in "${ARCHS[@]}"; do
        swiftc -target "$arch-apple-macos$MIN_MACOS" "${SWIFT_FLAGS[@]}" "$@" \
            -module-cache-path "$BUILD/cache-$arch" -o "$out.$arch"
        parts+=("$out.$arch")
    done
    lipo -create "${parts[@]}" -output "$out"
    rm -f "${parts[@]}"
}

build_cli() {
    mkdir -p "$BUILD"
    swiftc -target "$(uname -m)-apple-macos$MIN_MACOS" "${SWIFT_FLAGS[@]}" \
        -module-name archive_list "${CORE[@]}" Sources/CLI/main.swift -o "$BUILD/archive-list"
}

build_app() {
    rm -rf "$APP"
    mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APPEX/Contents/MacOS" "$APPEX/Contents/Resources" "$BUILD/plists"

    python3 Scripts/gen-plists.py formats.json "$BUILD/plists" "$BUNDLE_ID" "$VERSION"
    cp "$BUILD/plists/App-Info.plist" "$APP/Contents/Info.plist"
    cp "$BUILD/plists/Extension-Info.plist" "$APPEX/Contents/Info.plist"
    cp formats.json "$APPEX/Contents/Resources/formats.json"
    cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"   # se regenera con Scripts/make-icon.swift

    echo "Compilando extensión…"
    swiftc_universal "$APPEX/Contents/MacOS/ArchivePreviewExtension" \
        -application-extension -parse-as-library -module-name ArchivePreviewExtension \
        "${CORE[@]}" Sources/Extension/*.swift \
        -Xlinker -e -Xlinker _NSExtensionMain

    echo "Compilando app…"
    swiftc_universal "$APP/Contents/MacOS/ArchivePreview" \
        -module-name ArchivePreview "${CORE[@]}" Sources/App/main.swift

    echo "Firmando (firma local, sin certificado)…"
    codesign --force --sign - --entitlements Support/Extension.entitlements "$APPEX"
    codesign --force --sign - --entitlements Support/App.entitlements "$APP"
    codesign --verify --deep --strict "$APP"
    echo "Listo: $APP"
}

case "${1:-build}" in
    build)
        build_app
        ;;
    install)
        build_app
        mkdir -p "$INSTALL_DIR"
        rm -rf "$INSTALL_DIR/$APP_NAME.app"
        cp -R "$APP" "$INSTALL_DIR/"
        LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
        "$LSREG" -f -R "$INSTALL_DIR/$APP_NAME.app"
        pluginkit -a "$INSTALL_DIR/$APP_NAME.app/Contents/PlugIns/ArchivePreviewExtension.appex" || true
        qlmanage -r >/dev/null 2>&1 || true
        qlmanage -r cache >/dev/null 2>&1 || true
        echo "Instalada en $INSTALL_DIR/$APP_NAME.app"
        pluginkit -m -v -i "$BUNDLE_ID.extension" || true
        ;;
    release)
        build_app
        ZIP="$BUILD/release/Vista-de-Comprimidos.zip"   # nombre fijo: el enlace releases/latest/download/… siempre funciona
        rm -rf "$BUILD/release" && mkdir -p "$BUILD/release"
        # ditto conserva firma y atributos del bundle (zip -r puede romperlos).
        ditto -c -k --keepParent "$APP" "$ZIP"
        echo "Release: $ZIP ($(du -h "$ZIP" | cut -f1))"
        lipo -archs "$APP/Contents/MacOS/ArchivePreview"
        ;;
    test)
        build_cli
        Tests/make-fixtures.sh
        "$BUILD/archive-list" --formats formats.json Tests/fixtures/*
        ;;
    *)
        echo "uso: $0 [build|install|test|release]" >&2
        exit 2
        ;;
esac
