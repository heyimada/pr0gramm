// Renders the placeholder app icon layers. Run: swift scripts/make-icons.swift <outdir>
import AppKit
import ImageIO
import UniformTypeIdentifiers

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
let side = 1024
let orange = CGColor(srgbRed: 0.933, green: 0.302, blue: 0.180, alpha: 1)
let background = CGColor(srgbRed: 0.086, green: 0.086, blue: 0.094, alpha: 1)

func render(_ name: String, opaque: Bool, draw: (CGContext) -> Void) {
    // App Store icons must not carry an alpha channel; the visionOS front layer needs one.
    let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: alpha.rawValue)!
    if opaque { ctx.setFillColor(background); ctx.fill(CGRect(x: 0, y: 0, width: side, height: side)) }
    draw(ctx)
    let dest = CGImageDestinationCreateWithURL(out.appendingPathComponent(name) as CFURL,
                                               UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}

func drawMark(_ ctx: CGContext) {
    let text = NSAttributedString(string: "pr0", attributes: [
        .font: NSFont.systemFont(ofSize: 430, weight: .black),
        .foregroundColor: CGColor(gray: 1, alpha: 1),
    ])
    let line = CTLineCreateWithAttributedString(text)
    let bounds = CTLineGetImageBounds(line, ctx)
    ctx.textPosition = CGPoint(x: (CGFloat(side) - bounds.width) / 2 - bounds.minX,
                               y: (CGFloat(side) - bounds.height) / 2 - bounds.minY + 40)
    CTLineDraw(line, ctx)
    ctx.setFillColor(orange)
    ctx.fill(CGRect(x: 262, y: 250, width: 500, height: 40))
}

render("icon.png", opaque: true, draw: drawMark)
render("back.png", opaque: true) { _ in }
render("front.png", opaque: false, draw: drawMark)
