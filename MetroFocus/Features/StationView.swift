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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsEditor = false
    @State private var showsSettings = false
    @State private var showsTaskError = false
    @FocusState private var destinationFocused: Bool
    @ScaledMetric(relativeTo: .title2) private var taskSize = 25
    @ScaledMetric(relativeTo: .title) private var serviceSize = 32

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L("下一站，心无旁骛。", "Next stop. A clearer mind."))
                            .font(.title.bold()).tracking(-0.7).fixedSize(horizontal: false, vertical: true)
                        Text(app.draft.line.subtitle).font(.subheadline).foregroundStyle(MetroTheme.muted)
                    }
                    lineSelector
                    ticketForm
                    adaptiveRow {
                        Text(L("始发站 · 此刻", "DEPARTURE · NOW"))
                        if !typeSize.isAccessibilitySize { Spacer() }
                        Text(L("累计", "TOTAL") + " " + minuteText(app.engine.totalFocusSeconds()) + " min").monospacedDigit()
                    }.font(.caption).foregroundStyle(MetroTheme.muted)
                    if let state = app.engine.state, state.isActive {
                        Label(L("你已有一趟进行中的旅程", "Your train is already on its way"), systemImage: "tram.fill")
                            .font(.subheadline).foregroundStyle(state.plan.line.color)
                    }
                }.padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 16)
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
            .safeAreaInset(edge: .bottom, spacing: 0) { departure }
            .sheet(isPresented: $showsEditor) { RouteEditor(draft: app.draft) }
            .sheet(isPresented: $showsSettings) { SettingsView() }
        }
    }

    private var adaptiveRow: AnyLayout {
        typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
    }

    private var ticketForm: some View {
        @Bindable var draft = app.draft
        return VStack(alignment: .leading, spacing: 0) {
            Text(L("个人通行凭证", "PERSONAL TRANSIT PASS"))
                .font(.caption.monospaced()).foregroundStyle(MetroTheme.paperSecondary)
                .padding(.bottom, 13)
            TransitDivider(color: MetroTheme.paperRule).padding(.bottom, 17)
            adaptiveRow {
                HStack(spacing: 7) {
                    LineBadge(line: draft.line, compact: true)
                    Text(draft.line.title).font(.caption.weight(.semibold))
                }
                HStack(spacing: 8) {
                    Text("·").accessibilityHidden(true)
                    Text(L("此刻", "Here & now"))
                    Image(systemName: "arrow.right").accessibilityHidden(true)
                }.font(.caption).foregroundStyle(MetroTheme.paperSecondary)
            }.padding(.bottom, 13)
            Text(L("这一程，想完成什么？", "WHAT WILL YOU FINISH?"))
                .font(.caption).foregroundStyle(MetroTheme.paperSecondary)
            HStack(spacing: 4) {
                TextField(L("想专注完成什么？", "What are you working on?"), text: $draft.task,
                          prompt: Text(L("想专注完成什么？", "What are you working on?")).foregroundStyle(MetroTheme.paperSecondary))
                    .font(.system(size: taskSize, weight: .semibold)).tint(draft.line.color)
                    .focused($destinationFocused).submitLabel(.done).frame(minHeight: 44)
                    .onSubmit { destinationFocused = false }
                    .accessibilityIdentifier("destinationField")
                    .onChange(of: draft.task) { _, value in
                        if value.count > 24 { draft.task = String(value.prefix(24)) }
                        if draft.isValid { showsTaskError = false }
                    }
                Button {
                    if draft.task.isEmpty { destinationFocused = true }
                    else { draft.task = ""; destinationFocused = true }
                } label: {
                    Image(systemName: draft.task.isEmpty ? "pencil" : "xmark.circle")
                        .font(.body).foregroundStyle(MetroTheme.paperSecondary).frame(width: 44, height: 44)
                }.accessibilityLabel(draft.task.isEmpty ? L("编辑任务名称", "Edit task name") : L("清空任务名称", "Clear task name"))
            }.padding(.top, 3).padding(.bottom, 13)
            if showsTaskError {
                Text(L("先写下这次想完成的事。", "Add something you want to finish first."))
                    .font(.caption).foregroundStyle(MetroTheme.paperError).padding(.bottom, 12)
                    .accessibilityIdentifier("destinationError")
            }
            TransitDivider(color: MetroTheme.paperRule)
            adaptiveRow {
                Text(L("选择班次", "Choose your service")).font(.caption.weight(.semibold))
                if !typeSize.isAccessibilitySize { Spacer() }
                Button { destinationFocused = false; showsEditor = true } label: {
                    Label(L("编排", "Edit route"), systemImage: "slider.horizontal.3")
                        .font(.caption).frame(minHeight: 44)
                }.foregroundStyle(MetroTheme.paperSecondary).accessibilityIdentifier("editRoute")
            }.foregroundStyle(MetroTheme.paperSecondary).padding(.top, 8).padding(.bottom, 6)
            LazyVGrid(columns: serviceColumns, spacing: 7) {
                serviceCard(.shuttle, minutes: 15, segments: 1)
                serviceCard(.standard, minutes: 25, segments: 4)
                serviceCard(.express, minutes: 50, segments: 2)
                if draft.kind == .custom { serviceCard(.custom, minutes: draft.customFocus, segments: draft.customCount) }
            }
            TicketPerforation()
                .frame(height: 1).padding(.top, 22)
                .anchorPreference(key: TicketTearPreference.self, value: .bounds) { $0 }
            adaptiveRow {
                VStack(alignment: .leading, spacing: 5) {
                    Text(draft.kind.title).font(.subheadline.weight(.semibold))
                    Text(String(format: draft.segmentCount == 1 ? L("%d 分钟 × %d 段", "%d min × %d stop") : L("%d 分钟 × %d 段", "%d min × %d stops"), draft.focusMinutes, draft.segmentCount))
                        .font(.caption).foregroundStyle(MetroTheme.paperSecondary)
                    if typeSize.isAccessibilitySize {
                        Text(journeySummary).font(.caption.weight(.semibold))
                            .accessibilityIdentifier("accessibleJourneySummary")
                        Text(L("30 秒候车准备", "30-second boarding"))
                            .font(.caption).foregroundStyle(MetroTheme.paperSecondary)
                    }
                }
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                VStack(spacing: 3) {
                    Text(L("尚未发车", "NOT YET BOARDED"))
                    Text("READY WHEN YOU ARE")
                }.font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(MetroTheme.stampInk).multilineTextAlignment(.center)
                    .padding(.horizontal, 7).padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(MetroTheme.stampInk, lineWidth: 1))
                    .rotationEffect(.degrees(-6))
            }.padding(.top, 17).padding(.bottom, 21)
        }
        .padding(.horizontal, 21).padding(.top, 21).foregroundStyle(MetroTheme.paperInk)
        .backgroundPreferenceValue(TicketTearPreference.self) { anchor in
            GeometryReader { geometry in
                TicketPaper(tearY: anchor.map { geometry[$0].maxY })
            }
        }
    }

    private var serviceColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: typeSize.isAccessibilitySize ? 1 : (app.draft.kind == .custom ? 2 : 3))
    }

    private var departure: some View {
        VStack(spacing: 10) {
            if !typeSize.isAccessibilitySize {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text(journeySummary).font(.caption.weight(.semibold))
                        Spacer(minLength: 6)
                        Text(L("30 秒候车准备", "30-second boarding")).font(.caption2).foregroundStyle(MetroTheme.muted)
                    }
                    Text(journeySummary).font(.caption.weight(.semibold))
                }
            }
            Button {
                destinationFocused = false
                if app.engine.state?.isActive == true { app.showsJourney = true }
                else if app.draft.isValid { app.draft.remember(); app.startJourney(app.draft.plan) }
                else { showsTaskError = true; destinationFocused = true }
            } label: {
                if typeSize.isAccessibilitySize {
                    Text(app.engine.state?.isActive == true ? L("返回运行舱", "Back on board") : L("检票发车", "All aboard"))
                        .multilineTextAlignment(.center).padding(.horizontal, 12).padding(.vertical, 10)
                } else {
                    HStack {
                        Image(systemName: "ticket")
                        Spacer()
                        Text(app.engine.state?.isActive == true ? L("返回运行舱", "Back on board") : L("检票发车", "All aboard"))
                        Spacer()
                        Image(systemName: "arrow.right")
                    }.padding(.horizontal, 18)
                }
            }.buttonStyle(MetroButtonStyle(tint: MetroTheme.paper, foreground: MetroTheme.paperInk, cornerRadius: 10))
                .accessibilityIdentifier("departButton")
        }.padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 10).background(MetroTheme.background)
    }

    private var journeySummary: String {
        let draft = app.draft
        let format = draft.segmentCount == 1 ? L("%d 段旅程 · %d 分钟专注", "%d stop · %d minutes of focus") : L("%d 段旅程 · %d 分钟专注", "%d stops · %d minutes of focus")
        return String(format: format, draft.segmentCount, draft.focusMinutes * draft.segmentCount)
    }

    private func serviceCard(_ kind: ServiceKind, minutes: Int, segments: Int) -> some View {
        let selected = app.draft.kind == kind
        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { app.draft.kind = kind }
            app.sensory.feedback(.selection)
        } label: {
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(minutes)).font(.system(size: serviceSize, weight: .semibold)).monospacedDigit().tracking(-1)
                    Text(L("分钟", "min")).font(.caption2)
                }
                Text(kind.title + " ×\(segments)").font(.caption2.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity, minHeight: 74).padding(.horizontal, 3).padding(.vertical, 8)
                .foregroundStyle(selected ? MetroTheme.paper : MetroTheme.paperInk)
                .background(selected ? MetroTheme.paperInk : .clear, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(selected ? MetroTheme.paperInk : MetroTheme.paperRule, lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain).accessibilityIdentifier("service_\(kind.rawValue)")
            .accessibilityLabel("\(kind.title), \(minutes) " + L("分钟", "minutes") + ", \(segments) " + L("段", "stops"))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var lineSelector: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: typeSize.isAccessibilitySize ? 2 : 4), spacing: 5) {
            ForEach(TransitLine.allCases) { line in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { app.draft.line = line }
                    app.sensory.feedback(.selection)
                } label: {
                    HStack(spacing: 5) {
                        Circle().fill(line.color).frame(width: 7, height: 7)
                        Text(line.title).font(.caption.weight(app.draft.line == line ? .semibold : .regular)).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, minHeight: 44).padding(.horizontal, 2)
                        .foregroundStyle(app.draft.line == line ? MetroTheme.ink : MetroTheme.muted)
                        .background(app.draft.line == line ? line.color.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
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
