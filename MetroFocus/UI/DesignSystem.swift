import SwiftUI

/// English keys live in Localizable.xcstrings; the Chinese copy is kept alongside for editorial clarity.
func L(_ chinese: String, _ english: String) -> String {
    String(localized: String.LocalizationValue(english))
}

enum MetroTheme {
    static let background = Color(hex: 0x0A0E11)
    static let surface = Color(hex: 0x151B20)
    static let elevated = Color(hex: 0x1E272C)
    static let ink = Color(hex: 0xF1F2EC)
    static let muted = Color(hex: 0xA0ADAE)
    static let dim = Color(hex: 0x627174)
    static let paper = Color(hex: 0xEDE7D5)
    static let paperInk = Color(hex: 0x23362D)
    static let amber = Color(hex: 0xE5BF59)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

extension TransitLine {
    var color: Color {
        switch self {
        case .writing: Color(hex: 0xFF4685)
        case .coding: Color(hex: 0x64D89A)
        case .reading: Color(hex: 0xE8C45F)
        case .life: Color(hex: 0x85C9F1)
        }
    }
    var title: String {
        switch self {
        case .writing: L("写作线", "Writing")
        case .coding: L("代码线", "Coding")
        case .reading: L("阅读线", "Reading")
        case .life: L("生活线", "Life")
        }
    }
    var subtitle: String {
        switch self {
        case .writing: L("让想法抵达纸面", "Bring ideas to life")
        case .coding: L("留白，给深度思考", "Make space for deep work")
        case .reading: L("驶入另一个世界", "Travel into another world")
        case .life: L("小事，也值得一趟旅程", "Small things deserve a journey")
        }
    }
}

extension ServiceKind {
    var title: String {
        switch self {
        case .shuttle: L("微步短驳", "Shuttle")
        case .standard: L("经典通勤", "Standard")
        case .express: L("特快直达", "Express")
        case .custom: L("跨城专线", "Custom")
        }
    }
    var code: String {
        switch self {
        case .shuttle: "LOCAL"
        case .standard: "COMMUTER"
        case .express: "EXPRESS"
        case .custom: "YOUR ROUTE"
        }
    }
}

struct MetroMark: View {
    var color: Color = MetroTheme.ink
    var body: some View {
        Canvas { context, size in
            var track = Path()
            track.move(to: CGPoint(x: 3, y: size.height - 5))
            track.addLine(to: CGPoint(x: 3, y: 6))
            track.addQuadCurve(to: CGPoint(x: 10, y: 6), control: CGPoint(x: 6.5, y: -1))
            track.addLine(to: CGPoint(x: size.width / 2, y: size.height - 8))
            track.addLine(to: CGPoint(x: size.width - 10, y: 6))
            track.addQuadCurve(to: CGPoint(x: size.width - 3, y: 6), control: CGPoint(x: size.width - 6.5, y: -1))
            track.addLine(to: CGPoint(x: size.width - 3, y: size.height - 5))
            context.stroke(track, with: .color(color), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            for x in [CGFloat(3), size.width - 3] {
                context.fill(Path(ellipseIn: CGRect(x: x - 3, y: size.height - 8, width: 6, height: 6)), with: .color(MetroTheme.background))
                context.stroke(Path(ellipseIn: CGRect(x: x - 3, y: size.height - 8, width: 6, height: 6)), with: .color(color), lineWidth: 2)
            }
        }.frame(width: 29, height: 30).accessibilityHidden(true)
    }
}

struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            MetroMark()
            Text("METROFOCUS").font(.system(.subheadline, design: .rounded, weight: .black)).tracking(1.6)
        }.foregroundStyle(MetroTheme.ink)
    }
}

struct LineBadge: View {
    @ScaledMetric(relativeTo: .caption) private var badgeWidth = 25
    @ScaledMetric(relativeTo: .caption) private var badgeHeight = 23
    let line: TransitLine
    var compact = false
    var body: some View {
        HStack(spacing: 7) {
            Text(String(format: "%02d", line.number)).font(.system(.caption, design: .rounded, weight: .black))
                .foregroundStyle(MetroTheme.background).frame(width: badgeWidth, height: badgeHeight).background(line.color, in: RoundedRectangle(cornerRadius: 6))
            if !compact { Text(line.title).font(.subheadline.weight(.semibold)).foregroundStyle(line.color) }
        }
        .accessibilityElement(children: .combine)
    }
}

struct MetroButtonStyle: ButtonStyle {
    var tint: Color = MetroTheme.ink
    var foreground: Color = MetroTheme.background
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(tint, in: RoundedRectangle(cornerRadius: 17))
            .contentShape(RoundedRectangle(cornerRadius: 17))
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SectionLabel: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(MetroTheme.ink)
            Spacer()
            if let trailing { Text(trailing).font(.caption.monospaced()).foregroundStyle(MetroTheme.muted) }
        }
    }
}

struct TransitDivider: View {
    var color: Color = MetroTheme.dim.opacity(0.3)
    var body: some View {
        Rectangle().fill(color).frame(height: 1)
    }
}

func minuteText(_ seconds: TimeInterval) -> String {
    String(Int(max(0, seconds) / 60))
}

func timerText(_ seconds: TimeInterval) -> String {
    let value = max(0, Int(ceil(seconds)))
    if value >= 3600 { return String(format: "%d:%02d:%02d", value / 3600, (value % 3600) / 60, value % 60) }
    return String(format: "%02d:%02d", value / 60, value % 60)
}

struct EmptyStationView: View {
    let title: String
    let message: String
    let symbol: String
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol).font(.system(size: 42, weight: .light)).foregroundStyle(MetroTheme.muted)
            Text(title).font(.title2.weight(.bold)).foregroundStyle(MetroTheme.ink)
            Text(message).font(.body).foregroundStyle(MetroTheme.muted).multilineTextAlignment(.center).frame(maxWidth: 280)
        }.frame(maxWidth: .infinity).padding(.vertical, 50)
    }
}
