// Dibuja el icono de la app y genera Support/AppIcon.icns.
//
//   swift Scripts/make-icon.swift            (desde la raíz del proyecto)
//
// Motivo: un documento con cremallera (comprimido) y una lupa (vista previa),
// sobre un fondo azul con la forma y márgenes estándar de los iconos de macOS.

import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func linearGradient(_ ctx: CGContext, _ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [])
}

func draw(_ ctx: CGContext) {
    // Coordenadas de CoreGraphics: origen abajo a la izquierda.

    // 1. Fondo: rectángulo redondeado de 824 pt centrado (rejilla estándar de macOS).
    let base = CGRect(x: 100, y: 100, width: 824, height: 824)
    let basePath = CGPath(roundedRect: base, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.30))
    ctx.addPath(basePath); ctx.setFillColor(color(0x2B7BF0)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(basePath); ctx.clip()
    linearGradient(ctx, [color(0x5DB4FF), color(0x2F7BEF), color(0x1B4FC4)],
                   from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))
    // Brillo suave arriba.
    linearGradient(ctx, [color(0xFFFFFF, 0.18), color(0xFFFFFF, 0)],
                   from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 620))
    ctx.restoreGState()

    // 2. Documento blanco con la esquina doblada.
    let doc = CGRect(x: 268, y: 196, width: 420, height: 560)
    let fold: CGFloat = 110
    let r: CGFloat = 36
    let docPath = CGMutablePath()
    docPath.move(to: CGPoint(x: doc.minX + r, y: doc.minY))
    docPath.addLine(to: CGPoint(x: doc.maxX - r, y: doc.minY))
    docPath.addQuadCurve(to: CGPoint(x: doc.maxX, y: doc.minY + r), control: CGPoint(x: doc.maxX, y: doc.minY))
    docPath.addLine(to: CGPoint(x: doc.maxX, y: doc.maxY - fold))
    docPath.addLine(to: CGPoint(x: doc.maxX - fold, y: doc.maxY))
    docPath.addLine(to: CGPoint(x: doc.minX + r, y: doc.maxY))
    docPath.addQuadCurve(to: CGPoint(x: doc.minX, y: doc.maxY - r), control: CGPoint(x: doc.minX, y: doc.maxY))
    docPath.addLine(to: CGPoint(x: doc.minX, y: doc.minY + r))
    docPath.addQuadCurve(to: CGPoint(x: doc.minX + r, y: doc.minY), control: CGPoint(x: doc.minX, y: doc.minY))
    docPath.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x0A2A6B, 0.35))
    ctx.addPath(docPath); ctx.setFillColor(color(0xFFFFFF)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(docPath); ctx.clip()
    linearGradient(ctx, [color(0xFFFFFF), color(0xE9F0FB)], from: CGPoint(x: 0, y: doc.maxY), to: CGPoint(x: 0, y: doc.minY))
    ctx.restoreGState()

    // Pestaña doblada.
    let flap = CGMutablePath()
    flap.move(to: CGPoint(x: doc.maxX - fold, y: doc.maxY))
    flap.addLine(to: CGPoint(x: doc.maxX - fold, y: doc.maxY - fold + 18))
    flap.addQuadCurve(to: CGPoint(x: doc.maxX - fold + 18, y: doc.maxY - fold),
                      control: CGPoint(x: doc.maxX - fold, y: doc.maxY - fold))
    flap.addLine(to: CGPoint(x: doc.maxX, y: doc.maxY - fold))
    flap.closeSubpath()
    ctx.addPath(flap); ctx.setFillColor(color(0xC9D8F0)); ctx.fillPath()

    // 3. Cremallera vertical en el centro del documento.
    let zx: CGFloat = doc.midX - 40
    let tooth = CGSize(width: 34, height: 22)
    var y = doc.maxY - 30
    var left = true
    ctx.setFillColor(color(0x1E3A6E))
    while y > doc.minY + 250 {
        let x = left ? zx - tooth.width + 4 : zx - 4
        ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: y - tooth.height, width: tooth.width, height: tooth.height),
                           cornerWidth: 6, cornerHeight: 6, transform: nil))
        ctx.fillPath()
        y -= tooth.height + 6
        left.toggle()
    }
    // Tirador.
    let pull = CGRect(x: zx - 34, y: doc.minY + 140, width: 68, height: 110)
    ctx.addPath(CGPath(roundedRect: pull, cornerWidth: 24, cornerHeight: 24, transform: nil))
    ctx.setFillColor(color(0x1E3A6E)); ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: pull.insetBy(dx: 18, dy: 22), cornerWidth: 10, cornerHeight: 10, transform: nil))
    ctx.setFillColor(color(0xE9F0FB)); ctx.fillPath()

    // 4. Lupa abajo a la derecha.
    let c = CGPoint(x: 646, y: 368)
    let lensR: CGFloat = 128
    // Mango.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: color(0x0A2A6B, 0.35))
    ctx.setLineCap(.round)
    ctx.setLineWidth(64)
    ctx.setStrokeColor(color(0x13284F))
    ctx.move(to: CGPoint(x: c.x + lensR * 0.68, y: c.y - lensR * 0.68))
    ctx.addLine(to: CGPoint(x: c.x + lensR * 1.55, y: c.y - lensR * 1.55))
    ctx.strokePath()
    // Aro.
    ctx.setLineWidth(44)
    ctx.setStrokeColor(color(0x13284F))
    ctx.addEllipse(in: CGRect(x: c.x - lensR, y: c.y - lensR, width: lensR * 2, height: lensR * 2))
    ctx.strokePath()
    ctx.restoreGState()
    // Cristal.
    let lens = CGRect(x: c.x - lensR + 20, y: c.y - lensR + 20, width: (lensR - 20) * 2, height: (lensR - 20) * 2)
    ctx.saveGState()
    ctx.addEllipse(in: lens); ctx.clip()
    linearGradient(ctx, [color(0xBFE3FF, 0.92), color(0x7CC0FF, 0.92)],
                   from: CGPoint(x: lens.minX, y: lens.maxY), to: CGPoint(x: lens.maxX, y: lens.minY))
    // Reflejo.
    ctx.setFillColor(color(0xFFFFFF, 0.55))
    ctx.addEllipse(in: CGRect(x: lens.minX + 34, y: lens.maxY - 96, width: 92, height: 52))
    ctx.fillPath()
    ctx.restoreGState()
}

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)
    draw(ctx)
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: "build/AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try render(size: 1024).write(to: URL(fileURLWithPath: "build/AppIcon-preview.png"))

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "Support/AppIcon.icns"]
try p.run(); p.waitUntilExit()
print(p.terminationStatus == 0 ? "Support/AppIcon.icns generado" : "iconutil falló")
