import SwiftUI

struct TicketLibraryView: View {
    @Environment(AppModel.self) private var app
    private var days: [Date] {
        Array(Set(app.engine.tickets.map { Calendar.current.startOfDay(for: $0.completedAt) })).sorted(by: >)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(L("时间的存根。", "Time, well kept."))
                            .font(.largeTitle.weight(.bold)).tracking(-1)
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        Text(String(format: "%02d", app.engine.tickets.count)).font(.title2.monospacedDigit().weight(.bold))
                        Text(L("张车票 · 每一张，都是抵达", "tickets · every one, an arrival")).font(.subheadline).foregroundStyle(MetroTheme.muted)
                    }
                    TransitDivider()
                    if app.engine.tickets.isEmpty {
                        VStack(spacing: 0) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10).stroke(MetroTheme.dim.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                                    .frame(width: 220, height: 120).rotationEffect(.degrees(-7))
                                Image(systemName: "ticket").font(.system(size: 38, weight: .light)).foregroundStyle(MetroTheme.muted)
                            }.frame(height: 160)
                            EmptyStationView(title: L("第一张，留给下一程。", "Your first ticket is waiting."), message: L("完成一趟专注旅程，\n把认真度过的时间收藏在这里。", "Finish a focus journey and keep a little piece of time here."), symbol: "")
                                .padding(.top, -42)
                            Button(L("去车站发车", "Head to the station")) { app.selectedTab = 0 }.buttonStyle(MetroButtonStyle()).padding(.horizontal, 15)
                        }
                    } else {
                        ForEach(days, id: \.self) { day in
                            VStack(alignment: .leading, spacing: 14) {
                                Text(day, format: .dateTime.month(.wide).day().weekday()).font(.caption.weight(.semibold)).foregroundStyle(MetroTheme.muted)
                                ForEach(app.engine.tickets.filter { Calendar.current.isDate($0.completedAt, inSameDayAs: day) }) { ticket in
                                    NavigationLink { TicketDetailView(ticket: ticket) } label: { TicketRow(ticket: ticket) }
                                        .buttonStyle(.plain).accessibilityIdentifier("ticketRow_\(ticket.id.uuidString)")
                                }
                            }
                        }
                    }
                }.padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 35)
            }.background(MetroTheme.background)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Text(L("票夹", "Ticket wallet")).font(.headline).fixedSize(horizontal: true, vertical: false) }
                    ToolbarItem(placement: .topBarTrailing) { Image(systemName: "ticket").foregroundStyle(MetroTheme.muted) }
                }
                .toolbarBackground(MetroTheme.background, for: .navigationBar)
        }
    }
}

struct TicketRow: View {
    let ticket: Ticket
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 5) {
                Text(minuteText(ticket.focusSeconds)).font(.system(.largeTitle, design: .rounded, weight: .bold)).monospacedDigit()
                Text("MIN").font(.system(.caption2, design: .monospaced)).tracking(1)
            }.frame(width: 82).foregroundStyle(MetroTheme.paperInk)
            Rectangle().fill(MetroTheme.paperInk.opacity(0.15)).frame(width: 1).padding(.vertical, 15)
            VStack(alignment: .leading, spacing: 10) {
                Text(ticket.task).font(.headline).lineLimit(2)
                HStack(spacing: 5) {
                    Circle().fill(ticket.line.color).frame(width: 7, height: 7)
                    Text(ticket.line.title).font(.caption)
                    Spacer()
                    Image(systemName: ticket.punchedAt == nil ? "circle.dotted" : "checkmark.seal.fill").foregroundStyle(Color(hex: 0x306B51))
                }
            }.padding(17).foregroundStyle(MetroTheme.paperInk)
        }.frame(minHeight: 105).background(MetroTheme.paper)
            .mask(TicketSilhouette(punched: false).fill(style: FillStyle(eoFill: true)))
            .accessibilityElement(children: .combine)
    }
}

struct AtlasView: View {
    @Environment(AppModel.self) private var app
    @State private var selectedLine: TransitLine = .writing
    @State private var zoom: CGFloat = 1
    @GestureState private var gestureZoom: CGFloat = 1
    @State private var mapWindow = 0
    private var totals: [TransitLine: Double] {
        Dictionary(uniqueKeysWithValues: TransitLine.allCases.map { ($0, app.engine.totalFocusSeconds(line: $0)) })
    }
    private var maxWindow: Int {
        max(0, (Int((totals.values.max() ?? 0) / 3600) + 1) / AtlasMap.stationsPerWindow)
    }
    private var mapScale: CGFloat { max(0.7, min(1.8, zoom * gestureZoom)) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(L("一座城，慢慢长大。", "A city, built by you."))
                            .font(.largeTitle.weight(.bold)).tracking(-1).fixedSize(horizontal: false, vertical: true)
                        Text(L("你走过的每一分钟，都有迹可循。", "Every minute you give leaves a mark."))
                            .font(.subheadline).foregroundStyle(MetroTheme.muted)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%.1f", app.engine.totalFocusSeconds() / 360))
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold)).monospacedDigit()
                        Text("km").font(.headline).foregroundStyle(MetroTheme.muted)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 5) {
                            Text(L("累计铺轨", "TRACK LAID")).font(.caption.monospaced()).foregroundStyle(MetroTheme.muted)
                            Text(String(format: L("%d 座新站", "%d new stations"), totalStations)).font(.subheadline.weight(.semibold))
                        }
                    }
                    ZStack(alignment: .bottomTrailing) {
                        ScrollView([.horizontal, .vertical]) {
                            let map = AtlasMap(totals: totals, selected: selectedLine, window: mapWindow)
                            map.frame(width: map.canvasSize.width, height: map.canvasSize.height)
                                .scaleEffect(mapScale, anchor: .center)
                                .frame(width: map.canvasSize.width * mapScale, height: map.canvasSize.height * mapScale)
                        }.defaultScrollAnchor(.center).scrollIndicators(.hidden)
                            .simultaneousGesture(MagnifyGesture().updating($gestureZoom) { value, state, _ in state = value.magnification }.onEnded { value in zoom = max(0.7, min(1.8, zoom * value.magnification)) })
                        Button { withAnimation(.smooth) { zoom = zoom == 1 ? 0.7 : 1 } } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 44, height: 44).background(MetroTheme.elevated, in: Circle())
                        }.padding(12).accessibilityLabel(L("调整地图缩放", "Adjust map zoom"))
                    }.frame(height: 295).background(Color(hex: 0x10181B), in: RoundedRectangle(cornerRadius: 22)).clipShape(RoundedRectangle(cornerRadius: 22))
                    if maxWindow > 0 {
                        HStack(spacing: 12) {
                            Button { mapWindow = max(0, mapWindow - 1) } label: {
                                Image(systemName: "chevron.left").frame(width: 44, height: 44)
                            }.disabled(mapWindow == 0).accessibilityLabel(L("上一段路网", "Previous map section"))
                            VStack(spacing: 4) {
                                Text(String(format: L("第 %d–%d 站", "Stations %d–%d"), mapWindow * AtlasMap.stationsPerWindow + 1, (mapWindow + 1) * AtlasMap.stationsPerWindow))
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                Text(L("分段浏览 · 统计包含全部线路", "Browse sections · totals include every station"))
                                    .font(.caption2).foregroundStyle(MetroTheme.muted)
                            }.frame(maxWidth: .infinity)
                            Button { mapWindow = min(maxWindow, mapWindow + 1) } label: {
                                Image(systemName: "chevron.right").frame(width: 44, height: 44)
                            }.disabled(mapWindow == maxWindow).accessibilityLabel(L("下一段路网", "Next map section"))
                        }.foregroundStyle(MetroTheme.ink)
                    }
                    SectionLabel(title: L("你的线路", "Your lines"), trailing: L("1 小时 = 10 km", "1 HOUR = 10 km"))
                    VStack(spacing: 0) {
                        ForEach(TransitLine.allCases) { line in
                            Button { selectedLine = line } label: { lineRow(line) }.buttonStyle(.plain)
                            if line != .life { TransitDivider().padding(.leading, 44) }
                        }
                    }
                    if app.engine.totalFocusSeconds() == 0 {
                        Text(L("从第一次发车开始，点亮属于你的城市。", "Your city begins with your first departure."))
                            .font(.subheadline).foregroundStyle(MetroTheme.muted).frame(maxWidth: .infinity).multilineTextAlignment(.center)
                    }
                    if !app.engine.sessions.isEmpty {
                        SectionLabel(title: L("运行记录", "Journey log"))
                        ForEach(app.engine.sessions.prefix(5)) { session in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.task).font(.subheadline.weight(.semibold))
                                    Text(session.startedAt, format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(MetroTheme.muted)
                                }
                                Spacer()
                                Text(session.phase == .completed ? L("已抵达", "Arrived") : session.phase == .cancelled ? L("中途停靠", "Ended early") : L("运行中", "In progress"))
                                    .font(.caption).foregroundStyle(session.line.color)
                            }
                        }
                    }
                }.padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 35)
            }.background(MetroTheme.background)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Text(L("城市路网", "Your metro atlas")).font(.headline).fixedSize(horizontal: true, vertical: false) }
                    ToolbarItem(placement: .topBarTrailing) { Image(systemName: "point.topleft.down.to.point.bottomright.curvepath").foregroundStyle(MetroTheme.muted) }
                }
                .toolbarBackground(MetroTheme.background, for: .navigationBar)
        }
    }
    private var totalStations: Int { TransitLine.allCases.reduce(0) { $0 + Int(app.engine.totalFocusSeconds(line: $1) / 3600) } }
    private func lineRow(_ line: TransitLine) -> some View {
        let seconds = app.engine.totalFocusSeconds(line: line)
        return HStack(spacing: 12) {
            LineBadge(line: line, compact: true)
            VStack(alignment: .leading, spacing: 5) {
                Text(line.title).font(.headline).foregroundStyle(selectedLine == line ? MetroTheme.ink : MetroTheme.muted)
                Text(seconds > 0 ? String(format: L("距下一站还需 %d 分钟", "%d min to the next station"), max(1, 60 - Int(seconds / 60) % 60)) : L("等待第一次发车", "Waiting for your first departure"))
                    .font(.caption).foregroundStyle(MetroTheme.muted)
            }
            Spacer(minLength: 8)
            Text(String(format: "%.1f km", seconds / 360)).font(.subheadline.monospacedDigit().weight(.semibold)).foregroundStyle(line.color)
        }.padding(.vertical, 14).frame(minHeight: 65)
    }
}

struct AtlasMap: View {
    static let stationsPerWindow = 24
    let totals: [TransitLine: Double]
    let selected: TransitLine
    var window: Int = 0
    private var windowStart: Int { max(0, window) * Self.stationsPerWindow }
    private var background: Color { Color(hex: 0x10181B) }

    /// Nodes depend only on ordinal, never on total time or the number of other lines.
    /// Fixed 24-station windows bound rendering while keeping every station reachable.
    private func relativeNode(_ ordinal: Int, line: TransitLine) -> CGPoint {
        let steps: [CGPoint]
        switch line {
        case .writing: steps = [.init(x: 62, y: -62), .init(x: 88, y: 0), .init(x: 62, y: -62), .init(x: 0, y: -88)]
        case .coding: steps = [.init(x: 62, y: 62), .init(x: 0, y: 88), .init(x: 62, y: 62), .init(x: 88, y: 0)]
        case .reading: steps = [.init(x: -88, y: 0), .init(x: -62, y: 62), .init(x: 0, y: 88), .init(x: -62, y: 62)]
        case .life: steps = [.init(x: 0, y: -88), .init(x: -62, y: -62), .init(x: -88, y: 0), .init(x: -62, y: -62)]
        }
        return (0..<max(0, ordinal)).reduce(CGPoint.zero) { point, index in
            let step = steps[index % steps.count]
            return CGPoint(x: point.x + step.x, y: point.y + step.y)
        }
    }
    private func hours(_ line: TransitLine) -> Double { max(0, totals[line, default: 0]) / 3600 }
    private func visibleCount(_ line: TransitLine) -> Int {
        // Only two future stops; earlier pages stay intact as the line grows.
        min(Self.stationsPerWindow, max(0, Int(hours(line)) + 2 - windowStart))
    }
    var canvasSize: CGSize {
        var extentX: CGFloat = 0
        var extentY: CGFloat = 0
        for line in TransitLine.allCases where visibleCount(line) > 0 {
            let end = relativeNode(visibleCount(line) + (window > 0 ? 1 : 0), line: line)
            extentX = max(extentX, abs(end.x))
            extentY = max(extentY, abs(end.y))
        }
        // Grow symmetrically around the hub, without moving any node relative to it.
        return CGSize(width: max(610, extentX * 2 + 180), height: max(470, extentY * 2 + 160))
    }
    private var hub: CGPoint { CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2) }
    private func point(_ ordinal: Int, line: TransitLine) -> CGPoint {
        let relative = relativeNode(ordinal, line: line)
        return CGPoint(x: hub.x + relative.x, y: hub.y + relative.y)
    }
    private func labelPoint(_ line: TransitLine) -> CGPoint {
        let p = point(1, line: line)
        switch line {
        case .writing: return CGPoint(x: p.x + 38, y: p.y - 27)
        case .coding: return CGPoint(x: p.x + 52, y: p.y + 3)
        case .reading: return CGPoint(x: p.x - 23, y: p.y + 27)
        case .life: return CGPoint(x: p.x - 58, y: p.y - 3)
        }
    }
    var body: some View {
        ZStack {
            Canvas { context, _ in
                for line in TransitLine.allCases where visibleCount(line) > 0 {
                    let count = visibleCount(line)
                    let offset = window > 0 ? 1 : 0
                    let earned = hours(line)
                    let opacity = line == selected ? 1.0 : 0.65
                    if window > 0 {
                        // Explicitly compress preceding stations, never mislabel them as one stop.
                        var continuation = Path()
                        continuation.move(to: hub)
                        continuation.addLine(to: point(1, line: line))
                        context.stroke(continuation, with: .color(line.color.opacity(0.45)), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [3, 6]))
                    }
                    for localIndex in 1...count {
                        let station = windowStart + localIndex
                        let previous = point(localIndex - 1 + offset, line: line)
                        let next = point(localIndex + offset, line: line)
                        var segment = Path()
                        segment.move(to: previous)
                        segment.addLine(to: next)
                        context.stroke(segment, with: .color(line.color.opacity(line == selected ? 0.21 : 0.10)), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [3, 7]))
                        let progress = min(1, max(0, earned - Double(station - 1)))
                        if progress > 0 {
                            context.stroke(segment.trimmedPath(from: 0, to: progress), with: .color(line.color.opacity(opacity)), style: StrokeStyle(lineWidth: line == selected ? 9 : 7, lineCap: .round))
                        }
                        let reached = Double(station) <= earned
                        let ring = Path(ellipseIn: CGRect(x: next.x - 5, y: next.y - 5, width: 10, height: 10))
                        context.fill(ring, with: .color(reached ? line.color.opacity(opacity) : background))
                        context.stroke(ring, with: .color(line.color.opacity(reached ? opacity : 0.25)), lineWidth: 2)
                        if line == selected && reached {
                            let label = Text(String(format: "%02d", station)).font(.system(.caption2, design: .monospaced)).foregroundStyle(MetroTheme.muted)
                            context.draw(label, at: CGPoint(x: next.x + (next.x < hub.x ? -20 : 20), y: next.y))
                        }
                    }
                }
                let origin = Path(ellipseIn: CGRect(x: hub.x - 10, y: hub.y - 10, width: 20, height: 20))
                context.fill(origin, with: .color(background))
                context.stroke(origin, with: .color(MetroTheme.ink), lineWidth: 4)
            }
            Text(L("此刻", "HERE & NOW")).font(.caption.weight(.bold)).foregroundStyle(MetroTheme.ink)
                .padding(.horizontal, 7).padding(.vertical, 4).background(background, in: RoundedRectangle(cornerRadius: 4))
                .position(x: hub.x + 32, y: hub.y + 29)
            ForEach(TransitLine.allCases) { line in
                if visibleCount(line) > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Text(String(format: "%02d", line.number)).font(.caption.monospaced().weight(.bold))
                            Text(line.title).font(.caption.weight(.semibold))
                        }
                        if window > 0 {
                            Text(String(format: L("接第 %d 站", "After stop %d"), windowStart)).font(.caption2)
                        }
                    }.foregroundStyle(line.color.opacity(line == selected ? 1 : 0.6)).position(labelPoint(line))
                }
            }
            Text("METROFOCUS · PERSONAL TRANSIT NETWORK")
                .font(.system(.caption2, design: .monospaced)).tracking(1).foregroundStyle(MetroTheme.dim)
                .position(x: hub.x, y: canvasSize.height - 25)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("个人地铁线路示意图，可拖动和缩放", "Your personal transit map. Drag and pinch to explore."))
        .accessibilityValue(String(format: L("当前第 %d–%d 站区间，统计包含全部旅程", "Showing stations %d–%d. Totals include all journeys."), windowStart + 1, windowStart + Self.stationsPerWindow))
    }
}
