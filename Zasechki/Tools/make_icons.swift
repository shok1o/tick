import AppKit

// Иконка «Штрих»: вертикальная черта и оранжевая точка на тёплом фоне.
// iOS-версия — квадрат во весь кадр (система скругляет сама),
// macOS-версия — скруглённый квадрат 824/1024 по сетке Apple.

let out = CommandLine.arguments[1]
let cream = NSColor(red: 0xF5/255, green: 0xF1/255, blue: 0xE8/255, alpha: 1)
let ink = NSColor(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255, alpha: 1)
let orange = NSColor(red: 0xE8/255, green: 0x59/255, blue: 0x0C/255, alpha: 1)

func render(px: Int, mac: Bool) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    // Рабочая область: весь кадр для iOS, 824/1024 для macOS.
    let inset = mac ? s * 100 / 1024 : 0
    let box = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let u = box.width / 100   // единица из макета 100×100

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: s, height: s).fill()
    cream.setFill()
    if mac {
        NSBezierPath(roundedRect: box, xRadius: 22.5 * u, yRadius: 22.5 * u).fill()
    } else {
        box.fill()
    }

    // Черта: от y=28 до y=72 в макете (ось y в AppKit идёт вверх).
    let line = NSBezierPath()
    line.move(to: NSPoint(x: box.minX + 50 * u, y: box.maxY - 28 * u))
    line.line(to: NSPoint(x: box.minX + 50 * u, y: box.maxY - 72 * u))
    line.lineWidth = 10 * u
    line.lineCapStyle = .round
    ink.setStroke()
    line.stroke()

    orange.setFill()
    let r = 5 * u
    NSBezierPath(ovalIn: NSRect(x: box.minX + 72 * u - r, y: box.maxY - 30 * u - r,
                                width: 2 * r, height: 2 * r)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try! render(px: 1024, mac: false).write(to: URL(fileURLWithPath: "\(out)/icon-ios-1024.png"))
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = size * scale
        try! render(px: px, mac: true).write(to: URL(fileURLWithPath: "\(out)/icon-mac-\(size)@\(scale)x.png"))
    }
}
