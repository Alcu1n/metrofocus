import SwiftUI
import UIKit

struct TicketSilhouette: Shape {
    var punched: Bool
    var tearY: CGFloat? = nil
    var notchRadius: CGFloat = 9.5
    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: 13)
        for x in [rect.minX, rect.maxX] {
            path.addEllipse(in: CGRect(x: x - notchRadius, y: (tearY ?? rect.height * 0.5) - notchRadius, width: notchRadius * 2, height: notchRadius * 2))
        }
        if punched { path.addEllipse(in: CGRect(x: rect.maxX - 37, y: 19, width: 14, height: 14)) }
        return path
    }
}

/// A thin card-stock edge follows the same tear notches and punched hole as the face.
struct TicketPaper: View {
    var punched = false
    var tearY: CGFloat?
    var notchRadius: CGFloat = 9.5

    var body: some View {
        let shape = TicketSilhouette(punched: punched, tearY: tearY, notchRadius: notchRadius)
        ZStack {
            shape.fill(Color(hex: 0xA99F82), style: FillStyle(eoFill: true))
                .clipped().offset(y: 2)
            shape.fill(Color(hex: 0xC9BFA3), style: FillStyle(eoFill: true))
                .clipped().offset(y: 1)
            MetroTheme.paper
                .overlay {
                    // Fixed, very fine fibers: no animated noise or image assets.
                    Canvas { context, size in
                        for index in 0..<Int(size.width * size.height / 95) {
                            let x = CGFloat((index * 73 + 19) % 1009) / 1009 * size.width
                            let y = CGFloat((index * 137 + 47) % 1013) / 1013 * size.height
                            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 0.8, height: 0.35)),
                                         with: .color(MetroTheme.paperInk.opacity(0.055)))
                        }
                    }
                }
                .mask(shape.fill(style: FillStyle(eoFill: true)))
            shape.stroke(LinearGradient(colors: [.white.opacity(0.7), Color(hex: 0x9F9476).opacity(0.55)],
                                        startPoint: .top, endPoint: .bottom), lineWidth: 1)
                .mask(shape.fill(style: FillStyle(eoFill: true)))
                .clipped()
        }
        .compositingGroup()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// Dark upper recess and a lower paper lip suggest ink pressed into stock.
private struct TicketImprint: ViewModifier {
    var ink: Color
    var depth: CGFloat
    func body(content: Content) -> some View {
        content
            .foregroundStyle(ink.shadow(.inner(color: .black.opacity(0.6), radius: depth * 0.5, x: 0, y: depth * 0.7)))
            .shadow(color: .white.opacity(0.8), radius: 0.15, x: 0, y: depth)
    }
}

extension View {
    func ticketImprint(ink: Color = MetroTheme.paperInk, depth: CGFloat = 0.9) -> some View {
        modifier(TicketImprint(ink: ink, depth: depth))
    }
}

struct TicketPerforation: View {
    var body: some View {
        ZStack {
            DashedRule().stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [3, 3]))
                .offset(y: 0.85)
            DashedRule().stroke(Color(hex: 0x756F59).opacity(0.8), style: StrokeStyle(lineWidth: 1.1, lineCap: .round, dash: [3, 3]))
        }.frame(height: 1).accessibilityHidden(true).allowsHitTesting(false)
    }
}

struct TicketTearPreference: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) { value = nextValue() ?? value }
}

struct TicketFace: View {
    let ticket: Ticket
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title2) private var taskSize = 24
    @ScaledMetric(relativeTo: .title3) private var timeSize = 23
    @ScaledMetric(relativeTo: .largeTitle) private var focusSize = 48
    private var tailLayout: AnyLayout {
        typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack { Text(verbatim: "METROFOCUS"); Spacer(minLength: 12); reference.fixedSize() }
                VStack(alignment: .leading, spacing: 6) { Text(verbatim: "METROFOCUS"); reference }
            }
            .font(.caption2.monospaced()).ticketImprint(ink: MetroTheme.paperSecondary, depth: 0.5)
            .padding(.trailing, ticket.punchedAt == nil ? 0 : 22)
            .padding(.bottom, 13)
            TransitDivider(color: MetroTheme.paperRule).accessibilityHidden(true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { lineLabel.fixedSize(); Spacer(minLength: 8); serviceCode.fixedSize() }
                VStack(alignment: .leading, spacing: 6) { lineLabel; serviceCode }
            }.padding(.top, 16)
            Text(ticket.task).font(.system(size: taskSize, weight: .semibold)).tracking(-0.3).ticketImprint()
                .fixedSize(horizontal: false, vertical: true).padding(.top, 13).padding(.bottom, 23)
            ViewThatFits(in: .horizontal) {
                HStack {
                    timeColumn(L("出发", "DEPARTURE"), date: ticket.startedAt, alignment: .leading).fixedSize()
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right").ticketImprint(ink: MetroTheme.paperSecondary, depth: 0.5).accessibilityHidden(true)
                    Spacer(minLength: 8)
                    timeColumn(L("抵达", "ARRIVAL"), date: ticket.completedAt, alignment: .trailing).fixedSize()
                }
                VStack(alignment: .leading, spacing: 16) {
                    timeColumn(L("出发", "DEPARTURE"), date: ticket.startedAt, alignment: .leading)
                    timeColumn(L("抵达", "ARRIVAL"), date: ticket.completedAt, alignment: .leading)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 7) { focusNumber.fixedSize(); focusCaption.fixedSize(); Spacer(minLength: 0) }
                VStack(alignment: .leading, spacing: 7) { focusNumber; focusCaption }
            }.padding(.top, 24).padding(.bottom, 16)
            TicketPerforation()
                .frame(height: 1).anchorPreference(key: TicketTearPreference.self, value: .bounds) { $0 }
                .accessibilityHidden(true)
            tailLayout {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ticket.completedAt, format: .dateTime.year().month(.twoDigits).day(.twoDigits))
                        .font(.caption.monospaced().weight(.semibold)).ticketImprint(depth: 0.6)
                    Text(String(format: ticket.segmentCount == 1 ? L("%d 站 · 单程通行", "%d STOP · ONE WAY") : L("%d 站 · 单程通行", "%d STOPS · ONE WAY"), ticket.segmentCount))
                        .font(.caption2.monospaced()).ticketImprint(ink: MetroTheme.paperSecondary, depth: 0.5)
                    Text(ticket.punchedAt == nil ? L("长按打孔，收藏这一程", "PUNCH TO KEEP THIS JOURNEY") : L("你的每一分钟，都算数。", "EVERY MINUTE MATTERS."))
                        .font(.caption2).ticketImprint(ink: MetroTheme.paperSecondary, depth: 0.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                stamp.fixedSize()
            }.padding(.top, 15).padding(.bottom, 18)
            BarcodeArtwork(seed: ticket.id.uuidString).frame(height: 25)
            HStack {
                Text(verbatim: "MF-" + ticket.id.uuidString.prefix(8))
                Spacer(minLength: 8)
                Text(verbatim: "KEEP GOING.")
            }.font(.caption2.monospaced()).ticketImprint(ink: MetroTheme.paperSecondary, depth: 0.5)
                .padding(.top, 6).accessibilityHidden(true)
        }
        .padding(21)
        .foregroundStyle(MetroTheme.paperInk)
        .backgroundPreferenceValue(TicketTearPreference.self) { tearAnchor in
            GeometryReader { geometry in
                TicketPaper(punched: ticket.punchedAt != nil, tearY: tearAnchor.map { geometry[$0].midY })
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var reference: some View { Text(verbatim: "MF / " + ticket.id.uuidString.prefix(8)) }
    private var lineLabel: some View {
        HStack(spacing: 7) {
            Text(String(format: "%02d", ticket.line.number)).font(.caption2.monospaced().weight(.semibold))
                .ticketImprint(ink: MetroTheme.background, depth: 0.45).padding(.horizontal, 5).padding(.vertical, 4)
                .background(ticket.line.color, in: RoundedRectangle(cornerRadius: 4))
            Text(ticket.line.title).font(.caption.weight(.semibold)).ticketImprint(depth: 0.55)
        }
    }
    private var serviceCode: some View { Text(verbatim: ticket.kind.code).font(.caption2.monospaced()).ticketImprint(ink: MetroTheme.paperSecondary, depth: 0.5) }
    private var focusNumber: some View {
        Text(minuteText(ticket.focusSeconds)).font(.system(size: focusSize, weight: .medium)).monospacedDigit().tracking(-1.2).ticketImprint()
    }
    private var focusCaption: some View { Text(L("分钟专注", "MIN OF FOCUS")).font(.caption2).ticketImprint(ink: MetroTheme.paperSecondary, depth: 0.5) }
    private func timeColumn(_ title: String, date: Date, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title).font(.caption2).ticketImprint(ink: MetroTheme.paperSecondary, depth: 0.5)
            Text(date, format: .dateTime.hour().minute()).font(.system(size: timeSize, weight: .medium)).monospacedDigit().ticketImprint()
        }
    }
    private var stamp: some View {
        VStack(spacing: 3) {
            Text(verbatim: ticket.punchedAt == nil ? "ARRIVED" : "VALIDATED").font(.caption2.monospaced().weight(.semibold))
            Text(ticket.punchedAt == nil ? L("已到站", "COMPLETE") : L("已验票", "PUNCHED")).font(.caption2.weight(.semibold))
        }.ticketImprint(ink: MetroTheme.stampInk, depth: 0.5).padding(.horizontal, 7).padding(.vertical, 5)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(MetroTheme.stampInk, lineWidth: 1))
            .rotationEffect(.degrees(-7))
            .accessibilityIdentifier(ticket.punchedAt == nil ? "arrivalStamp" : "punchedStamp")
    }
}

struct DashedRule: Shape {
    func path(in rect: CGRect) -> Path { var path = Path(); path.move(to: .zero); path.addLine(to: CGPoint(x: rect.width, y: 0)); return path }
}

struct BarcodeArtwork: View {
    let seed: String
    var body: some View {
        Canvas { context, size in
            let bytes = Array(seed.utf8)
            var x: CGFloat = 0
            var index = 0
            while x < size.width {
                let width = CGFloat(bytes[index % bytes.count] % 3 + 1)
                if index % 2 == 0 { context.fill(Path(CGRect(x: x, y: 0, width: min(width, size.width - x), height: size.height)), with: .color(MetroTheme.paperInk)) }
                x += width + 0.6
                index += 1
            }
        }.accessibilityHidden(true)
    }
}

struct TicketDetailView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let ticket: Ticket
    var isArrival = false
    var onDone: (() -> Void)?
    @State private var motion = TicketMotion()
    @State private var showsExportOptions = false
    @State private var share: ShareFile?
    @State private var exportError = false
    @State private var showsRelaxation = false
    @State private var inserted = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { finish() } label: {
                    Image(systemName: isArrival ? "xmark" : "chevron.left").font(.headline).frame(width: 44, height: 44)
                }.accessibilityLabel(L("关闭车票", "Close ticket"))
                Spacer()
                Text(L("个人通行凭证", "YOUR PASSAGE")).font(.system(.caption2, design: .monospaced, weight: .medium)).tracking(1.6).foregroundStyle(MetroTheme.muted)
                Spacer()
                Button { showsExportOptions = true } label: {
                    Image(systemName: "square.and.arrow.up").font(.headline).frame(width: 44, height: 44)
                }.accessibilityLabel(L("分享车票", "Share ticket")).accessibilityIdentifier("shareTicket")
            }.padding(.horizontal, 15)
            ScrollView {
                VStack(spacing: 25) {
                    if isArrival {
                        VStack(spacing: 9) {
                            Text(L("这一程，值得珍藏。", "A journey worth keeping."))
                                .font(.title2.weight(.bold)).multilineTextAlignment(.center)
                            Text(L("专注已到站。带走属于你的时间。", "You made it. Take your time with you."))
                                .font(.subheadline).foregroundStyle(MetroTheme.muted).multilineTextAlignment(.center)
                        }.padding(.top, 12)
                    }
                    VStack(spacing: 0) {
                        if isArrival {
                            Capsule().fill(.black).frame(height: 7).padding(.horizontal, -9).overlay(alignment: .top) { Capsule().fill(MetroTheme.dim.opacity(0.4)).frame(height: 1).padding(.horizontal, -9) }.opacity(inserted ? 0 : 1)
                        }
                        TicketFace(ticket: ticket)
                            .compositingGroup()
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 6)
                            .rotation3DEffect(.degrees(reduceMotion ? 0 : motion.pitch * 6), axis: (x: 1, y: 0, z: 0))
                            .rotation3DEffect(.degrees(reduceMotion ? 0 : motion.roll * 6), axis: (x: 0, y: 1, z: 0))
                            .overlay(alignment: .topLeading) {
                                // A small foil strip, confined to its physical security patch.
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(LinearGradient(colors: [.white.opacity(0.15), ticket.line.color.opacity(0.45), .white.opacity(0.55)], startPoint: .init(x: 0.1 + motion.roll * 0.3, y: 0), endPoint: .bottomTrailing))
                                    .frame(width: 48, height: 5).padding(.top, 9).padding(.leading, 25)
                                    .allowsHitTesting(false)
                            }
                            .offset(y: isArrival && !inserted && !reduceMotion ? -35 : 0)
                            .opacity(inserted || !isArrival ? 1 : 0.4)
                            .onLongPressGesture(minimumDuration: 0.6) { punch() }
                    }.padding(.horizontal, 31).padding(.top, 3)
                    if !ticket.milestones.filter({ !$0.isEmpty }).isEmpty {
                        VStack(alignment: .leading, spacing: 11) {
                            Text(L("沿途完成", "ALONG THE WAY")).font(.caption.monospaced()).foregroundStyle(MetroTheme.muted)
                            ForEach(Array(ticket.milestones.enumerated()), id: \.offset) { index, name in
                                if !name.isEmpty { Label(name, systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(MetroTheme.ink) }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 34)
                    }
                }.padding(.bottom, 25)
            }.scrollIndicators(.hidden)
            VStack(spacing: 8) {
                if ticket.punchedAt == nil {
                    Button { punch() } label: {
                        Label(L("打孔，收藏这一程", "Punch & keep this journey"), systemImage: "circle.dotted.circle.fill")
                    }.buttonStyle(MetroButtonStyle(tint: MetroTheme.paper, foreground: MetroTheme.paperInk, cornerRadius: 10)).accessibilityIdentifier("ticketPunch")
                    Text(L("也可以长按车票打孔", "Or press and hold your ticket")).font(.caption).foregroundStyle(MetroTheme.muted)
                } else {
                    Button { finish() } label: {
                        HStack(spacing: 12) { Image(systemName: "checkmark"); Text(L("收入票夹", "Keep in ticket wallet")) }
                    }
                        .buttonStyle(MetroButtonStyle(tint: MetroTheme.paper, foreground: MetroTheme.paperInk, cornerRadius: 10)).accessibilityIdentifier("ticketDone")
                }
                if isArrival {
                    Button { showsRelaxation = true } label: { Text(L("再休息一会儿", "Take a little break")).font(.subheadline).frame(minHeight: 44) }.foregroundStyle(MetroTheme.muted)
                }
            }.padding(.horizontal, 26).padding(.top, 12).padding(.bottom, 12)
            if let error = app.engine.errorMessage {
                Text(error).font(.caption).foregroundStyle(MetroTheme.amber).padding(.horizontal)
                Button(L("重试保存", "Retry saving")) { app.engine.retrySave() }
            }
        }.foregroundStyle(MetroTheme.ink).background(MetroTheme.background)
            .navigationBarBackButtonHidden().toolbar(.hidden, for: .navigationBar)
            .task {
                motion.start(reduceMotion: reduceMotion)
                withAnimation(reduceMotion ? .linear(duration: 0) : .spring(response: 0.8, dampingFraction: 0.82)) { inserted = true }
            }
            .onChange(of: reduceMotion) { _, value in motion.start(reduceMotion: value) }
            .onDisappear { motion.stop() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { motion.start(reduceMotion: reduceMotion) } else { motion.stop() }
            }
            .confirmationDialog(L("导出车票", "Export ticket"), isPresented: $showsExportOptions, titleVisibility: .visible) {
                Button(L("透明背景 PNG", "Transparent PNG")) { export(transparent: true) }.accessibilityIdentifier("exportTransparent")
                Button(L("分享卡片", "Share card")) { export(transparent: false) }.accessibilityIdentifier("exportCard")
                Button(L("取消", "Cancel"), role: .cancel) {}
            }
            .sheet(item: $share) { file in ShareSheet(url: file.url) }
            .sheet(isPresented: $showsRelaxation) { RelaxationView(minutes: relaxationMinutes) }
            .alert(L("暂时无法导出", "Couldn't export the ticket"), isPresented: $exportError) { Button(L("好", "OK"), role: .cancel) {} } message: { Text(L("车票已保留，请稍后重试。", "Your ticket is saved. Please try again.")) }
    }
    private var relaxationMinutes: Int {
        if let session = app.engine.sessions.first(where: { $0.id == ticket.journeyID }),
           let state = try? session.decodedState() { return state.plan.finalRelaxationMinutes }
        return switch ticket.kind { case .shuttle: 3; case .standard: 15; case .express: 10; case .custom: 5 }
    }
    private func punch() {
        guard ticket.punchedAt == nil else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) { app.punch(ticket) }
    }
    private func finish() {
        if let onDone { onDone() } else { dismiss() }
    }
    @MainActor private func export(transparent: Bool) {
        let face = TicketFace(ticket: ticket).frame(width: 360).environment(\.colorScheme, .light)
        let renderer: ImageRenderer<AnyView>
        if transparent {
            renderer = ImageRenderer(content: AnyView(face.padding(20)))
        } else {
            renderer = ImageRenderer(content: AnyView(VStack(spacing: 25) {
                HStack { BrandHeader(); Spacer() }
                face.rotationEffect(.degrees(-3)).padding(.vertical, 12)
                Text(L("把时间，开往热爱。", "Give your time a destination.")).font(.headline).foregroundStyle(MetroTheme.ink)
            }.padding(35).frame(width: 450).background(MetroTheme.background)))
        }
        renderer.scale = 3
        renderer.isOpaque = !transparent
        guard let data = renderer.uiImage?.pngData() else { exportError = true; return }
        let url = URL.temporaryDirectory.appendingPathComponent("MetroFocus-\(ticket.id.uuidString.prefix(8))-\(transparent ? "ticket" : "card").png")
        do { try data.write(to: url, options: .atomic); share = ShareFile(url: url) }
        catch { exportError = true }
    }
}

struct ShareFile: Identifiable { let id = UUID(); let url: URL }
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct RelaxationView: View {
    let minutes: Int
    @Environment(\.dismiss) private var dismiss
    @State private var deadline: Date?
    var body: some View {
        VStack(spacing: 22) {
            Capsule().fill(MetroTheme.dim).frame(width: 35, height: 4).padding(.top, 16)
            Spacer()
            Image(systemName: "cup.and.saucer").font(.system(size: 44, weight: .light)).foregroundStyle(MetroTheme.amber)
            Text(L("终点站，慢慢来。", "End of the line. Take it slow.")).font(.title2.bold()).multilineTextAlignment(.center)
            if let deadline {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    Text(timerText(max(0, deadline.timeIntervalSince(timeline.date)))).font(.system(size: 60, weight: .semibold, design: .rounded)).monospacedDigit()
                }
            }
            Text(L("这段休息不计入专注时间。", "This break is yours. It doesn't add focus time.")).font(.subheadline).foregroundStyle(MetroTheme.muted)
            Spacer()
            Button(L("休息好了", "I'm refreshed")) { dismiss() }.buttonStyle(MetroButtonStyle(tint: MetroTheme.amber)).padding(.bottom, 25)
        }.padding(.horizontal, 26).background(MetroTheme.background).presentationDetents([.medium, .large])
            .onAppear { if deadline == nil { deadline = Date().addingTimeInterval(Double(minutes * 60)) } }
    }
}
