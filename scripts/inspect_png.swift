import Foundation
import ImageIO
import CoreGraphics

for path in CommandLine.arguments.dropFirst() {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Invalid PNG: \(path)") }
    let width = image.width, height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("Decode failed") }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let transparent = stride(from: 3, to: pixels.count, by: 4).filter { pixels[$0] == 0 }.count
    let opaque = stride(from: 3, to: pixels.count, by: 4).filter { pixels[$0] == 255 }.count
    print("\(URL(fileURLWithPath: path).lastPathComponent): \(width)x\(height), transparent pixels=\(transparent), opaque pixels=\(opaque)")
    if path.contains("ticket") {
        precondition(transparent > 0 && opaque > 0, "Ticket must contain both paper and transparent areas")
        for (name, x, y) in [("outer corner", 0, 0), ("punch hole", 1050, 138), ("paper", 150, 250)] {
            print("  \(name): alpha=\(pixels[(y * width + x) * 4 + 3])")
        }
    } else { precondition(transparent == 0, "Share card must have an opaque background") }
}
