import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation
let dimension = 1024
let context = CGContext(data: nil, width: dimension, height: dimension, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 10/255, green: 14/255, blue: 17/255, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: dimension, height: dimension))
let track = CGMutablePath()
track.move(to: CGPoint(x: 240, y: 245))
track.addLine(to: CGPoint(x: 240, y: 711))
track.addCurve(to: CGPoint(x: 356, y: 744), control1: CGPoint(x: 240, y: 814), control2: CGPoint(x: 315, y: 832))
track.addLine(to: CGPoint(x: 512, y: 403))
track.addLine(to: CGPoint(x: 668, y: 744))
track.addCurve(to: CGPoint(x: 784, y: 711), control1: CGPoint(x: 709, y: 832), control2: CGPoint(x: 784, y: 814))
track.addLine(to: CGPoint(x: 784, y: 245))
context.addPath(track)
context.setStrokeColor(CGColor(red: 1, green: 70/255, blue: 133/255, alpha: 1))
context.setLineWidth(91); context.setLineCap(.round); context.setLineJoin(.round); context.strokePath()
for x: CGFloat in [240, 784] {
 context.setFillColor(CGColor(red: 0.95, green: 0.95, blue: 0.92, alpha: 1))
 context.fillEllipse(in: CGRect(x: x-61, y: 184, width: 122, height: 122))
 context.setFillColor(CGColor(red: 10/255, green: 14/255, blue: 17/255, alpha: 1))
 context.fillEllipse(in: CGRect(x: x-26, y: 219, width: 52, height: 52))
}
let url = URL(fileURLWithPath: "MetroFocus/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination))
