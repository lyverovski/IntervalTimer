// Draws the app icon: a stopwatch whose face shows warm-up, work and rest wedges in the
// running screen's phase colors, on a dark background.
//
// Run from the repo root:  swift scripts/generate_icon.swift [outDir] [--face light|dark]
// Writes icon.png, icon-dark.png and icon-tinted.png (1024×1024) into outDir,
// defaulting to the AppIcon asset folder.

import AppKit
import CoreGraphics

let args = CommandLine.arguments
let outDir = args.count > 1 && !args[1].hasPrefix("--")
	? args[1]
	: "IntervalTimer/Assets.xcassets/AppIcon.appiconset"
let darkFace = args.contains("dark")

let size: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
	CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
		blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

let orange = color(0xFF9500)
let red = color(0xFF3B30)
let teal = color(0x30C8C8)
let white = color(0xFFFFFF)
let ink = color(0x1C1C1E)
let faceDark = color(0x1E2029)

enum Variant {
	case standard
	/// Background left transparent so iOS can supply its own dark backdrop.
	case dark
	/// Grayscale on black; iOS applies the user's tint color.
	case tinted
}

func render(_ variant: Variant) -> CGImage {
	let alpha: CGImageAlphaInfo = variant == .dark ? .premultipliedLast : .noneSkipLast
	let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
		space: space, bitmapInfo: alpha.rawValue)!

	switch variant {
	case .standard:
		let g = CGGradient(colorsSpace: space, colors: [color(0x0E0F14), color(0x2A2D3A)] as CFArray, locations: [0, 1])!
		ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size), options: [])
	case .dark:
		break
	case .tinted:
		ctx.setFillColor(color(0x000000))
		ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
	}

	let center = CGPoint(x: size / 2, y: size / 2 - 40)
	let r: CGFloat = 320

	// Case: crown on top, side button at 1:30, body circle.
	ctx.setFillColor(white)
	ctx.addPath(CGPath(roundedRect: CGRect(x: center.x - 55, y: center.y + r - 20, width: 110, height: 90),
		cornerWidth: 20, cornerHeight: 20, transform: nil))
	ctx.addPath(CGPath(roundedRect: CGRect(x: center.x - 95, y: center.y + r + 55, width: 190, height: 55),
		cornerWidth: 22, cornerHeight: 22, transform: nil))
	ctx.fillPath()
	ctx.saveGState()
	ctx.translateBy(x: center.x, y: center.y)
	ctx.rotate(by: -.pi / 4)
	ctx.addPath(CGPath(roundedRect: CGRect(x: -40, y: r - 30, width: 80, height: 85),
		cornerWidth: 18, cornerHeight: 18, transform: nil))
	ctx.fillPath()
	ctx.restoreGState()
	ctx.fillEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))

	// Face.
	let inner = r - 46
	if darkFace {
		ctx.setFillColor(faceDark)
		ctx.fillEllipse(in: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2))
	}

	// Wedges clockwise from 12 o'clock, as fractions of a full turn.
	func wedge(from: CGFloat, to: CGFloat, _ c: CGColor) {
		ctx.setFillColor(c)
		ctx.move(to: center)
		ctx.addArc(center: center, radius: inner, startAngle: .pi / 2 - from * 2 * .pi,
			endAngle: .pi / 2 - to * 2 * .pi, clockwise: true)
		ctx.closePath()
		ctx.fillPath()
	}
	wedge(from: 0, to: 0.14, orange)
	wedge(from: 0.14, to: 0.48, red)
	wedge(from: 0.48, to: 0.66, teal)

	// Hand and hub.
	let handColor = darkFace ? white : ink
	let angle = CGFloat.pi / 2 - 0.66 * 2 * .pi
	ctx.setStrokeColor(handColor)
	ctx.setLineWidth(26)
	ctx.setLineCap(.round)
	ctx.move(to: center)
	ctx.addLine(to: CGPoint(x: center.x + cos(angle) * (inner - 30), y: center.y + sin(angle) * (inner - 30)))
	ctx.strokePath()
	ctx.setFillColor(handColor)
	ctx.fillEllipse(in: CGRect(x: center.x - 34, y: center.y - 34, width: 68, height: 68))

	let image = ctx.makeImage()!
	guard variant == .tinted else { return image }
	// Convert to grayscale so the system tint applies evenly.
	let gray = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
		space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
	gray.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
	return gray.makeImage()!
}

func write(_ image: CGImage, _ name: String) {
	let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
	guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
		fatalError("Failed to encode \(name)")
	}
	do {
		try data.write(to: url)
		print("wrote \(url.path)")
	} catch {
		fatalError("Failed to write \(url.path): \(error)")
	}
}

write(render(.standard), "icon.png")
write(render(.dark), "icon-dark.png")
write(render(.tinted), "icon-tinted.png")
