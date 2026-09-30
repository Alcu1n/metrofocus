import SwiftUI

@MainActor @Observable
final class JourneyDraft {
    var task = ""
    var line: TransitLine = .writing
    var kind: ServiceKind = .shuttle
    var customFocus = 35
    var customRest = 5
    var customCount = 3
    var milestones = Array(repeating: "", count: 8)

    init() {
        let defaults = UserDefaults.standard
        if let value = defaults.string(forKey: "lastLine"), let line = TransitLine(rawValue: value) { self.line = line }
        if let value = defaults.string(forKey: "lastKind"), let kind = ServiceKind(rawValue: value) { self.kind = kind }
    }
    var focusMinutes: Int {
        switch kind { case .shuttle: 15; case .standard: 25; case .express: 50; case .custom: customFocus }
    }
    var restMinutes: Int {
        switch kind { case .shuttle: 3; case .standard: 5; case .express: 10; case .custom: customRest }
    }
    var segmentCount: Int {
        switch kind { case .shuttle: 1; case .standard: 4; case .express: 2; case .custom: customCount }
    }
    var isValid: Bool { !task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var plan: JourneyPlan {
        JourneyPlan(task: String(task.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24)), line: line, kind: kind, focusMinutes: focusMinutes, restMinutes: restMinutes, segmentCount: segmentCount, milestones: Array(milestones.prefix(segmentCount)), boardingSeconds: 30)
    }
    func remember() {
        UserDefaults.standard.set(line.rawValue, forKey: "lastLine")
        UserDefaults.standard.set(kind.rawValue, forKey: "lastKind")
    }
}

struct StationView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showsEditor = false
    @State private var showsSettings = false
    @FocusState private var destinationFocused: Bool

    var body: some View {
        @Bindable var draft = app.draft
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    adaptiveRow {
                        HStack(spacing: 6) {
                            Circle().fill(draft.line.color).frame(width: 6, height: 6)
                            Text(typeSize.isAccessibilitySize ? L("始发站", "ORIGIN") : L("始发站 · 此刻", "DEPARTURE · NOW")).font(.caption.weight(.semibold)).tracking(1.2).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        if !typeSize.isAccessibilitySize { Spacer() }
                        Text(L("累计", "TOTAL") + "  " + minuteText(app.engine.totalFocusSeconds()) + " min")
                            .font(.caption.monospacedDigit())
                    }.foregroundStyle(MetroTheme.muted)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(L("下一站，心无旁骛。", "Next stop. A clearer mind."))
                            .font(.system(.title, design: .default, weight: .bold)).tracking(-0.7)
                            .lineLimit(typeSize.isAccessibilitySize ? nil : 1).minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(draft.line.subtitle).font(.subheadline).foregroundStyle(MetroTheme.muted)
                    }

                    VStack(spacing: 0) {
                        adaptiveRow {
                            LineBadge(line: draft.line)
                            if !typeSize.isAccessibilitySize { Spacer() }
                            HStack(spacing: 0) {
                                ForEach(TransitLine.allCases) { line in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.25)) { draft.line = line }
                                        app.sensory.feedback(.selection)
                                    } label: {
                                        Text(String(line.number)).font(.caption.monospaced().weight(.bold))
                                            .foregroundStyle(draft.line == line ? MetroTheme.background : line.color)
                                            .frame(width: 26, height: 26)
                                            .background(draft.line == line ? line.color : line.color.opacity(0.09), in: Circle())
                                            .frame(width: 44, height: 44)
                                    }.buttonStyle(.plain).accessibilityLabel(line.title)
                                        .accessibilityIdentifier("line_\(line.rawValue)")
                                        .accessibilityAddTraits(draft.line == line ? .isSelected : [])
                                }
                            }
                        }
                        RailArtwork(color: draft.line.color, progress: 0.22, stationCount: max(2, draft.segmentCount + 1))
                            .frame(height: 75).padding(.top, 0)
                        HStack(alignment: .firstTextBaseline) {
                            Text(L("此刻", "Here & now")).font(.caption).foregroundStyle(MetroTheme.muted)
                            Spacer()
                            Text(L("你的下一站", "Your next stop")).font(.caption).foregroundStyle(draft.line.color)
                        }.padding(.top, -6).padding(.bottom, 12)
                        TransitDivider()
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.and.ellipse").font(.title3).foregroundStyle(draft.line.color)
                            TextField(L("想专注完成什么？", "What are you working on?"), text: $draft.task,
                                      prompt: Text(L("想专注完成什么？", "What are you working on?")).foregroundStyle(MetroTheme.muted))
                                .font(.headline).focused($destinationFocused).submitLabel(.done)
                                .onSubmit { destinationFocused = false }
                                .accessibilityIdentifier("destinationField")
                                .onChange(of: draft.task) { _, value in if value.count > 24 { draft.task = String(value.prefix(24)) } }
                            if !draft.task.isEmpty {
                                Button { draft.task = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(MetroTheme.muted).frame(width: 44, height: 44) }
                                    .accessibilityLabel(L("清空任务名称", "Clear task name"))
                            }
                        }.frame(minHeight: 52)
                    }.padding(.horizontal, 18).padding(.top, 12)
                        .background(MetroTheme.surface, in: RoundedRectangle(cornerRadius: 22))

                    VStack(alignment: .leading, spacing: 13) {
                        adaptiveRow {
                            SectionLabel(title: L("选择班次", "Choose your service"))
                            Button { destinationFocused = false; showsEditor = true } label: {
                                HStack(spacing: 5) { Image(systemName: "slider.horizontal.3"); Text(L("编排", "Edit route")) }.font(.subheadline)
                                    .frame(minHeight: 44)
                            }.foregroundStyle(MetroTheme.muted).accessibilityIdentifier("editRoute")
                        }
                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                serviceCard(.shuttle, minutes: 15, segments: 1)
                                serviceCard(.standard, minutes: 25, segments: 4)
                                serviceCard(.express, minutes: 50, segments: 2)
                                if draft.kind == .custom { serviceCard(.custom, minutes: draft.customFocus, segments: draft.customCount) }
                            }.padding(.horizontal, 24)
                        }.contentMargins(.trailing, 0).scrollIndicators(.hidden).padding(.horizontal, -24)
                    }
                    if let state = app.engine.state, state.isActive {
                        Label(L("你已有一趟进行中的旅程", "Your train is already on its way"), systemImage: "tram.fill")
                            .font(.subheadline).foregroundStyle(state.plan.line.color)
                    }
                }.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(MetroTheme.background)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { BrandHeader().fixedSize(horizontal: true, vertical: false) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { destinationFocused = false; showsSettings = true } label: {
                        Image(systemName: "slider.horizontal.3").font(.body).foregroundStyle(MetroTheme.ink)
                    }.accessibilityLabel(L("设置", "Settings")).accessibilityIdentifier("settingsButton")
                }
            }
            .toolbarBackground(MetroTheme.background, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 9) {
                    Button {
                        destinationFocused = false
                        if app.engine.state?.isActive == true { app.showsJourney = true }
                        else if draft.isValid { draft.remember(); app.startJourney(draft.plan) }
                        else { destinationFocused = true }
                    } label: {
                        if typeSize.isAccessibilitySize {
                            Text(app.engine.state?.isActive == true ? L("返回运行舱", "Back on board") : L("检票发车", "All aboard"))
                                .multilineTextAlignment(.center).padding(.horizontal, 12).padding(.vertical, 10)
                        } else { HStack {
                            Image(systemName: "ticket.fill")
                            Spacer()
                            Text(app.engine.state?.isActive == true ? L("返回运行舱", "Back on board") : L("检票发车", "All aboard"))
                            Spacer()
                            Image(systemName: "arrow.right")
                        }.padding(.horizontal, 21) }
                    }.buttonStyle(MetroButtonStyle(tint: draft.line.color)).accessibilityIdentifier("departButton")
                    Text(journeySummary)
                        .font(.caption).foregroundStyle(MetroTheme.muted)
                }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 12)
                    .background(MetroTheme.background)
            }
            .sheet(isPresented: $showsEditor) { RouteEditor(draft: draft) }
            .sheet(isPresented: $showsSettings) { SettingsView() }
        }
    }

    private var adaptiveRow: AnyLayout {
        typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
    }

    private var journeySummary: String {
        let draft = app.draft
        let format: String
        if typeSize.isAccessibilitySize {
            format = draft.segmentCount == 1 ? L("%d 段 · %d 分钟", "%d stop · %d min") : L("%d 段 · %d 分钟", "%d stops · %d min")
        } else {
            format = draft.segmentCount == 1 ? L("%d 段旅程 · %d 分钟专注", "%d stop · %d minutes of focus") : L("%d 段旅程 · %d 分钟专注", "%d stops · %d minutes of focus")
        }
        return String(format: format, draft.segmentCount, draft.focusMinutes * draft.segmentCount)
    }

    private func serviceCard(_ kind: ServiceKind, minutes: Int, segments: Int) -> some View {
        let selected = app.draft.kind == kind
        return Button {
            withAnimation(.snappy(duration: 0.25)) { app.draft.kind = kind }
            app.sensory.feedback(.selection)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(kind.code).font(.system(.caption2, design: .monospaced, weight: .medium)).tracking(0.5)
                    Spacer(minLength: 2)
                    if selected { Image(systemName: "checkmark.circle.fill").font(.caption) }
                }
                Text(String(minutes)).font(.system(size: typeSize.isAccessibilitySize ? 62 : 51, weight: .bold, design: .rounded)).monospacedDigit().tracking(-2)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(L("分钟", "min")).font(.caption)
                    Spacer(minLength: 0)
                    Text("×\(segments)").font(.caption.monospaced().weight(.semibold))
                }
                Text(kind.title).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
            }.foregroundStyle(selected ? MetroTheme.background : MetroTheme.ink)
                .padding(15).frame(width: typeSize.isAccessibilitySize ? 290 : 132, alignment: .leading)
                .background(selected ? app.draft.line.color : MetroTheme.surface, in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 23, bottomTrailingRadius: 23, topTrailingRadius: 18))
                .contentShape(RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).accessibilityIdentifier("service_\(kind.rawValue)")
            .accessibilityLabel("\(kind.title), \(minutes) " + L("分钟", "minutes") + ", \(segments) " + L("段", "stops"))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var lineSelector: some View {
        HStack(spacing: 0) {
            ForEach(TransitLine.allCases) { line in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { app.draft.line = line }
                    app.sensory.feedback(.selection)
                } label: {
                    VStack(spacing: 7) {
                        Text(String(format: "%02d", line.number))
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .foregroundStyle(app.draft.line == line ? MetroTheme.background : line.color)
                            .frame(width: 37, height: 30)
                            .background(app.draft.line == line ? line.color : line.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        Text(line.title).font(.caption).foregroundStyle(app.draft.line == line ? MetroTheme.ink : MetroTheme.muted)
                    }.frame(maxWidth: .infinity, minHeight: 58)
                }.buttonStyle(.plain).accessibilityIdentifier("line_\(line.rawValue)")
                    .accessibilityAddTraits(app.draft.line == line ? .isSelected : [])
            }
        }
    }
}

struct RouteEditor: View {
    @Bindable var draft: JourneyDraft
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L("任务名称", "Task name"), text: $draft.task)
                        .onChange(of: draft.task) { _, value in draft.task = String(value.prefix(24)) }
                    Picker(L("线路", "Line"), selection: $draft.line) {
                        ForEach(TransitLine.allCases) { Text($0.title).tag($0) }
                    }
                } header: { Text(L("目的地", "Destination")) }
                Section {
                    Picker(L("班次", "Service"), selection: $draft.kind) {
                        Text(ServiceKind.shuttle.title).tag(ServiceKind.shuttle)
                        Text(ServiceKind.standard.title).tag(ServiceKind.standard)
                        Text(ServiceKind.express.title).tag(ServiceKind.express)
                        Text(ServiceKind.custom.title).tag(ServiceKind.custom)
                    }.accessibilityIdentifier("servicePicker")
                    if draft.kind == .custom {
                        Stepper(value: $draft.customFocus, in: 5...120, step: 1) { Text(String(format: L("专注 %d 分钟", "Focus for %d minutes"), draft.customFocus)) }
                        Stepper(value: $draft.customRest, in: 1...30) { Text(String(format: L("休息 %d 分钟", "Rest for %d minutes"), draft.customRest)) }
                        Stepper(value: $draft.customCount, in: 1...8) { Text(String(format: L("共 %d 段", "%d stops"), draft.customCount)) }
                    }
                } header: { Text(L("运行方案", "Service plan")) } footer: { Text(L("每段专注后自动进入休息。休息结束，等你确认再发车。", "Each focus interval is followed by a break. The next train leaves only when you are ready.")) }
                Section {
                    ForEach(0..<draft.segmentCount, id: \.self) { index in
                        HStack {
                            Text(String(format: "%02d", index + 1)).font(.caption.monospaced()).foregroundStyle(draft.line.color)
                            TextField(String(format: L("区间 %d", "Stop %d"), index + 1), text: $draft.milestones[index])
                                .onChange(of: draft.milestones[index]) { _, value in draft.milestones[index] = String(value.prefix(24)) }
                        }
                    }
                } header: { Text(L("途经站 · 可选", "Milestones · optional")) }
            }
            .scrollContentBackground(.hidden).background(MetroTheme.background)
            .navigationTitle(L("编排旅程", "Plan your route")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("完成", "Done")) { draft.remember(); dismiss() }.accessibilityIdentifier("routeEditorDone") } }
        }.tint(draft.line.color).preferredColorScheme(.dark)
    }
}
