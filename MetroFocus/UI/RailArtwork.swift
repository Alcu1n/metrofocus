import SwiftUI

/// An original transit schematic. Points are shared by the rail and moving train.
struct RailArtwork: View {
    var color: Color
    var progress: Double = 0
    var tall = false
    var active = true
    var stationCount = 3
    var showTrain = true

    private func point(_ t: Double, in size: CGSize) -> CGPoint {
        if tall {
            let curve = sin(t * .pi * 2 - .pi / 2)
            return CGPoint(x: size.width * (0.5 + 0.25 * curve), y: size.height * (0.10 + 0.80 * t))
        }
        let eased = t * t * (3 - 2 * t)
        return CGPoint(x: size.width * (0.08 + 0.84 * t), y: size.height * (0.78 - 0.56 * eased))
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                Canvas { context, dimensions in
                    // Faint neighboring routes give the main line a geographic context.
                    var neighbor = Path()
                    if tall {
                        neighbor.move(to: CGPoint(x: dimensions.width * 0.9, y: 0))
                        neighbor.addLine(to: CGPoint(x: dimensions.width * 0.9, y: dimensions.height * 0.35))
                        neighbor.addQuadCurve(to: CGPoint(x: dimensions.width * 0.7, y: dimensions.height * 0.5), control: CGPoint(x: dimensions.width * 0.9, y: dimensions.height * 0.5))
                        neighbor.addLine(to: CGPoint(x: dimensions.width * 0.12, y: dimensions.height * 0.8))
                    } else {
                        neighbor.move(to: CGPoint(x: 0, y: dimensions.height * 0.28))
                        neighbor.addLine(to: CGPoint(x: dimensions.width * 0.42, y: dimensions.height * 0.28))
                        neighbor.addQuadCurve(to: CGPoint(x: dimensions.width * 0.64, y: dimensions.height * 0.75), control: CGPoint(x: dimensions.width * 0.57, y: dimensions.height * 0.28))
                        neighbor.addLine(to: CGPoint(x: dimensions.width, y: dimensions.height * 0.75))
                    }
                    if !tall { context.stroke(neighbor, with: .color(MetroTheme.elevated), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)) }
                    var rail = Path()
                    rail.addLines((0...100).map { point(Double($0) / 100, in: dimensions) })
                    context.stroke(rail, with: .color(color.opacity(active ? 0.24 : 0.13)), style: StrokeStyle(lineWidth: tall ? 12 : 10, lineCap: .round))
                    context.stroke(rail.trimmedPath(from: 0, to: max(0.025, min(1, progress))), with: .color(color), style: StrokeStyle(lineWidth: tall ? 12 : 10, lineCap: .round))
                    for index in 0..<max(2, stationCount) {
                        let t = Double(index) / Double(max(1, stationCount - 1))
                        let p = point(t, in: dimensions)
                        let radius: CGFloat = index == 0 || index == stationCount - 1 ? 8 : 5
                        let ring = Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
                        context.fill(ring, with: .color(t <= progress ? color : MetroTheme.background))
                        context.stroke(ring, with: .color(t <= progress ? MetroTheme.ink : color.opacity(0.9)), lineWidth: 3)
                    }
                }
                if showTrain {
                    TrainGlyph(color: color)
                        .position(point(min(0.96, max(0.04, progress)), in: size))
                }
            }
        }.accessibilityHidden(true)
    }
}

struct TrainGlyph: View {
    var color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13).fill(MetroTheme.background).frame(width: 42, height: 48)
            RoundedRectangle(cornerRadius: 10).fill(MetroTheme.ink).frame(width: 32, height: 39)
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 19, height: 4)
                RoundedRectangle(cornerRadius: 4).fill(MetroTheme.background).frame(width: 23, height: 13)
                HStack { Circle().fill(MetroTheme.background).frame(width: 4); Spacer(); Circle().fill(MetroTheme.background).frame(width: 4) }.frame(width: 20, height: 4)
            }
        }.shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 4)
    }
}
