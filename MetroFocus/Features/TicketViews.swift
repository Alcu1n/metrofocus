import SwiftUI
import UIKit

struct TicketSilhouette: Shape {
    var punched: Bool
    var tearY: CGFloat? = nil
    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: 13)
        for x in [rect.minX, rect.maxX] {
            path.addEllipse(in: CGRect(x: x - 12, y: (tearY ?? rect.height * 0.5) - 12, width: 24, height: 24))
        }
        if punched { path.addEllipse(in: CGRect(x: rect.maxX - 37, y: 19, width: 14, height: 14)) }
        return path
    }
}

struct TicketTearPreference: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) { value = nextValue() ?? value }
}

struct TicketFace: View {
    let ticket: Ticket
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                MetroMark(color: MetroTheme.paperInk).scaleEffect(0.85).frame(width: 25, height: 27)
                VStack(alignment: .leading, spacing: 2) {
                    Text("METROFOCUS").font(.system(.caption, design: .rounded, weight: .black)).tracking(1.5)
                    Text("PERSONAL TRANSIT AUTHORITY").font(.system(size: 7.5, weight: .medium, design: .monospaced)).tracking(0.7)
                }
                Spacer(minLength: 20)
            }.padding(.bottom, 22)
            HStack {
                Text(String(format: "%02d", ticket.line.number)).font(.system(.caption, design: .rounded, weight: .black))
                    .padding(.horizontal, 8).padding(.vertical, 4).background(ticket.line.color, in: RoundedRectangle(cornerRadius: 4)).foregroundStyle(MetroTheme.paperInk)
                Text(ticket.line.title).font(.caption.weight(.bold))
                Spacer()
                Text(ticket.kind.code).font(.system(.caption2, design: .monospaced, weight: .medium))
            }.padding(.bottom, 12)
            Text(ticket.task).font(.system(.title2, design: .default, weight: .bold)).lineLimit(2).fixedSize(horizontal: false, vertical: true).padding(.bottom, 19)
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L("出发", "DEPARTURE")).font(.system(.caption2, design: .monospaced)).opacity(0.65)
                    Text(ticket.startedAt, format: .dateTime.hour().minute()).font(.title3.weight(.semibold).monospacedDigit())
                }
                Spacer()
                Image(systemName: "arrow.right").font(.title3).opacity(0.5)
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text(L("抵达", "ARRIVAL")).font(.system(.caption2, design: .monospaced)).opacity(0.65)
                    Text(ticket.completedAt, format: .dateTime.hour().minute()).font(.title3.weight(.semibold).monospacedDigit())
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(minuteText(ticket.focusSeconds)).font(.system(size: 57, weight: .bold, design: .rounded)).tracking(-2).monospacedDigit()
                Text(L("分钟专注", "MIN OF FOCUS")).font(.system(.caption2, design: .monospaced, weight: .medium))
                Spacer()
            }.padding(.top, 17).padding(.bottom, 15)
            DashedRule().stroke(MetroTheme.paperInk.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [3, 4])).frame(height: 1)
                .padding(.horizontal, -10)
                .anchorPreference(key: TicketTearPreference.self, value: .bounds) { $0 }
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ticket.completedAt, format: .dateTime.year().month(.twoDigits).day(.twoDigits))
                        .font(.system(.caption, design: .monospaced, weight: .medium))
                    Text(String(format: ticket.segmentCount == 1 ? L("%d 站 · 单程通行", "%d STOP · ONE WAY") : L("%d 站 · 单程通行", "%d STOPS · ONE WAY"), ticket.segmentCount))
                        .font(.system(.caption2, design: .monospaced)).opacity(0.7)
                    Text(ticket.punchedAt == nil ? L("长按打孔，收藏这一程", "PUNCH TO KEEP THIS JOURNEY") : L("你的每一分钟，都算数。", "EVERY MINUTE MATTERS."))
                        .font(.system(size: 9, weight: .medium, design: .monospaced)).padding(.top, 2)
                }
                Spacer(minLength: 8)
                VStack(spacing: 3) {
                    Text(verbatim: ticket.punchedAt == nil ? "ARRIVED" : "VALIDATED").font(.system(size: 11, weight: .black, design: .monospaced)).tracking(0.7)
                    Text(ticket.punchedAt == nil ? L("已到站", "COMPLETE") : L("已验票", "PUNCHED")).font(.system(.caption2, design: .monospaced, weight: .bold))
                }.foregroundStyle(Color(hex: 0x306B51)).padding(.horizontal, 9).padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: 0x306B51).opacity(0.8), lineWidth: 2))
                    .rotationEffect(.degrees(-9))
                    .accessibilityIdentifier(ticket.punchedAt == nil ? "arrivalStamp" : "punchedStamp")
            }.padding(.vertical, 22)
            BarcodeArtwork(seed: ticket.id.uuidString).frame(height: 29)
            HStack {
                Text("MF-" + ticket.id.uuidString.prefix(8)).font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1.7)
                Spacer()
                Text("KEEP GOING.").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1)
            }.padding(.top, 5)
        }
        .padding(25)
        .foregroundStyle(MetroTheme.paperInk)
        .backgroundPreferenceValue(TicketTearPreference.self) { tearAnchor in
            GeometryReader { geometry in
            ZStack {
                MetroTheme.paper
                Canvas { context, size in
                    for i in 0..<1600 {
                        let x = CGFloat((i * 79 + 13) % 997) / 997 * size.width
                        let y = CGFloat((i * 137 + 71) % 991) / 991 * size.height
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: i % 3 == 0 ? 1.1 : 0.6, height: 0.7)), with: .color(MetroTheme.paperInk.opacity(0.11)))
                    }
                }
                VStack { Rectangle().fill(.white.opacity(0.4)).frame(height: 1); Spacer(); Rectangle().fill(.black.opacity(0.1)).frame(height: 2) }
            }
            .mask(TicketSilhouette(punched: ticket.punchedAt != nil, tearY: tearAnchor.map { geometry[$0].midY }).fill(style: FillStyle(eoFill: true)))
            }
        }
        .accessibilityElement(children: .contain)
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
                            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 14)
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
                    }.buttonStyle(MetroButtonStyle(tint: ticket.line.color)).accessibilityIdentifier("ticketPunch")
                    Text(L("也可以长按车票打孔", "Or press and hold your ticket")).font(.caption).foregroundStyle(MetroTheme.muted)
                } else {
                    Button { finish() } label: {
                        HStack(spacing: 12) { Image(systemName: "checkmark"); Text(L("收入票夹", "Keep in ticket wallet")) }
                    }
                        .buttonStyle(MetroButtonStyle(tint: ticket.line.color)).accessibilityIdentifier("ticketDone")
                }
                if isArrival {
                    Button { showsRelaxation = true } label: { Text(L("再休息一会儿", "Take a little break")).font(.subheadline).frame(minHeight: 42) }.foregroundStyle(MetroTheme.muted)
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
