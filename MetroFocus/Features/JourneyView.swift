import SwiftUI

struct JourneyView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize = 82
    @State private var confirmsCancellation = false
    @State private var showsSettings = false

    var body: some View {
        Group {
            if let state = app.engine.state, state.phase == .completed,
               let ticket = app.engine.ticket(for: state.id) {
                TicketDetailView(ticket: ticket, isArrival: true) {
                    app.showsJourney = false
                    app.selectedTab = 2
                }
            } else if let state = app.engine.state, state.isActive {
                runningContent(state)
            } else if app.engine.errorMessage != nil {
                VStack(spacing: 20) {
                    Text(L("正在保管你的旅程", "Keeping your journey safe")).font(.title2.bold())
                    Text(app.engine.errorMessage ?? "").foregroundStyle(MetroTheme.muted)
                    Button(L("重试保存", "Retry saving")) { app.engine.retrySave() }.buttonStyle(MetroButtonStyle())
                    Button(L("返回车站", "Back to station")) { app.showsJourney = false }
                }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).background(MetroTheme.background)
            } else {
                VStack(spacing: 24) {
                    Text(L("这一程，已被记住。", "Your time still counts.")).font(.title2.bold())
                    Text(L("已投入的专注会保留在路网里。", "The time you spent is saved in your atlas.")).foregroundStyle(MetroTheme.muted)
                    Button(L("返回车站", "Back to station")) { app.showsJourney = false }.buttonStyle(MetroButtonStyle())
                }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).background(MetroTheme.background)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showsSettings) { SettingsView() }
    }

    private func runningContent(_ state: JourneyState) -> some View {
        let resting = state.phase == .resting || state.phase == .awaitingDeparture || state.pausedPhase == .resting
        let tint = resting ? MetroTheme.amber : state.plan.line.color
        return VStack(spacing: 0) {
            HStack {
                Button { app.showsJourney = false } label: {
                    Image(systemName: "chevron.down").font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44).background(MetroTheme.surface, in: Circle())
                }.accessibilityLabel(L("收起运行舱", "Close journey")).accessibilityIdentifier("journeyClose")
                Spacer()
                Text(state.plan.kind.code).font(.system(.caption, design: .monospaced, weight: .semibold)).tracking(2).foregroundStyle(MetroTheme.muted)
                Spacer()
                Button { showsSettings = true } label: {
                    Image(systemName: app.sensory.isPlaying ? "waveform" : "speaker.slash").font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44).background(MetroTheme.surface, in: Circle())
                }.accessibilityLabel(L("声音设置", "Sound settings"))
            }.padding(.horizontal, 24).padding(.top, 10)
            ScrollView {
                VStack(spacing: 23) {
                    if !dynamicTypeSize.isAccessibilitySize { journeyHeader(state) }
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        VStack(spacing: 6) {
                            HStack(spacing: 7) {
                                Circle().fill(tint).frame(width: 6, height: 6)
                                Text(phaseLabel(state)).font(.subheadline.weight(.medium)).foregroundStyle(tint)
                                    .accessibilityIdentifier("phaseStatus").accessibilityValue(state.phase.rawValue)
                            }
                            if state.phase == .awaitingDeparture {
                                Text(L("准备好了？", "Ready when\nyou are."))
                                    .font(.system(.largeTitle, weight: .bold)).multilineTextAlignment(.center).padding(.vertical, 15)
                                    .accessibilityIdentifier("focusTimer")
                            } else {
                                Text(timerText(state.remaining(at: timeline.date)))
                                    .font(.system(size: timerSize, weight: .semibold, design: .rounded))
                                    .tracking(-3).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                                    .contentTransition(.numericText(countsDown: true))
                                    .accessibilityIdentifier("focusTimer")
                            }
                            Text(phaseMessage(state)).font(.subheadline).foregroundStyle(MetroTheme.muted).multilineTextAlignment(.center)
                            if dynamicTypeSize.isAccessibilitySize {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text(L("下一站", "NEXT STOP")).font(.caption).foregroundStyle(tint)
                                    Text(app.stationName).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 20)
                            } else {
                            ZStack {
                                RailArtwork(color: tint, progress: resting ? 1 : state.progress(at: timeline.date), tall: true, stationCount: 2)
                                    .frame(width: 210, height: 217)
                                VStack {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(L("出发", "FROM")).font(.system(.caption2, design: .monospaced)).foregroundStyle(MetroTheme.muted)
                                            Text(state.segmentIndex == 0 ? L("此刻", "Here & now") : String(format: L("区间 %d", "Stop %d"), state.segmentIndex)).font(.subheadline.weight(.semibold))
                                        }
                                        Spacer()
                                    }
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 5) {
                                            Text(resting ? L("已到站", "ARRIVED") : L("下一站", "NEXT STOP")).font(.system(.caption2, design: .monospaced)).foregroundStyle(tint)
                                            Text(app.stationName).font(.headline).lineLimit(2).frame(maxWidth: 155, alignment: .trailing)
                                        }
                                    }
                                }.padding(.vertical, 19)
                            }.padding(.top, 15)
                            }
                        }
                    }
                    if dynamicTypeSize.isAccessibilitySize { journeyHeader(state) }
                    VStack(spacing: 13) {
                        TransitDivider()
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L("行程进度", "JOURNEY")).font(.system(.caption2, design: .monospaced)).foregroundStyle(MetroTheme.muted)
                                Text(String(format: L("第 %d / %d 段", "Stop %d of %d"), state.segmentIndex + 1, state.plan.segmentCount)).font(.subheadline.weight(.semibold))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                Text(L("已专注", "FOCUSED")).font(.system(.caption2, design: .monospaced)).foregroundStyle(MetroTheme.muted)
                                TimelineView(.periodic(from: .now, by: 1)) { time in
                                    Text(minuteText(state.currentFocusSeconds(at: time.date)) + " / \(state.plan.totalFocusMinutes) min")
                                        .font(.subheadline.monospacedDigit().weight(.semibold)).foregroundStyle(tint)
                                }
                            }
                        }
                    }
                }.padding(.horizontal, 27).padding(.top, 24).padding(.bottom, 20)
            }.scrollIndicators(.hidden)
            VStack(spacing: 10) {
                if state.phase == .boarding {
                    Button { app.engine.skipBoarding() } label: { actionLabel(L("准备好了，立即发车", "Ready. Let's go"), compact: L("发车", "Let's go"), icon: "arrow.right") }
                        .buttonStyle(MetroButtonStyle(tint: tint)).accessibilityIdentifier("skipBoarding")
                } else if state.phase == .resting || state.phase == .awaitingDeparture {
                    Button { app.engine.continueJourney() } label: { actionLabel(state.phase == .resting ? L("提前发车", "Leave early") : L("继续发车", "Continue journey"), compact: L("继续", "Continue"), icon: "arrow.right") }
                        .buttonStyle(MetroButtonStyle(tint: tint)).accessibilityIdentifier("continueJourney")
                } else if state.phase == .paused {
                    Button { app.engine.resume() } label: { actionLabel(L("继续前行", "Resume journey"), compact: L("继续", "Resume"), icon: "play.fill") }
                        .buttonStyle(MetroButtonStyle(tint: tint)).accessibilityIdentifier("resumeJourney")
                } else {
                    Button { app.engine.pause() } label: { actionLabel(L("暂时停靠", "Pause journey"), compact: L("暂停", "Pause"), icon: "pause.fill") }
                        .buttonStyle(MetroButtonStyle(tint: MetroTheme.elevated, foreground: MetroTheme.ink)).foregroundStyle(MetroTheme.ink)
                        .accessibilityIdentifier("pauseJourney")
                }
                Button { confirmsCancellation = true } label: {
                    actionLabel(L("结束本次旅程", "End this journey"), compact: L("结束旅程", "End journey"), icon: "stop.circle")
                        .font(.subheadline).foregroundStyle(MetroTheme.muted).frame(minHeight: 44)
                }.accessibilityIdentifier("cancelJourney")
            }.padding(.horizontal, 27).padding(.top, 10).background(MetroTheme.background)
            if let error = app.engine.errorMessage {
                Text(error).font(.footnote).foregroundStyle(MetroTheme.amber).padding(.horizontal)
                Button(L("重试保存", "Retry saving")) { app.engine.retrySave() }
            }
        }
        .foregroundStyle(MetroTheme.ink).background(MetroTheme.background)
        .confirmationDialog(L("在这里结束旅程？", "End your journey here?"), isPresented: $confirmsCancellation, titleVisibility: .visible) {
            Button(L("结束旅程", "End journey"), role: .destructive) {
                app.engine.cancelJourney()
                if app.engine.errorMessage == nil { app.showsJourney = false }
            }.accessibilityIdentifier("cancelConfirm")
            Button(L("继续专注", "Keep focusing"), role: .cancel) {}
        } message: {
            Text(L("已经投入的时间会保留，但这趟旅程不会生成完整车票。", "Your focus time will be saved, but this journey will not issue a completed ticket."))
        }
    }

    @ViewBuilder
    private func actionLabel(_ title: String, compact: String, icon: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize { Text(compact) }
        else { Label(title, systemImage: icon) }
    }

    private func journeyHeader(_ state: JourneyState) -> some View {
                    let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18)) : AnyLayout(HStackLayout(alignment: .top))
                    return layout {
                        VStack(alignment: .leading, spacing: 8) {
                            LineBadge(line: state.plan.line)
                            Text(state.plan.task).font(.title2.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                        }
                        if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 20) }
                        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 7) {
                            Text(L("预计最早抵达", "ARRIVE FROM")).font(.system(.caption2, design: .monospaced)).foregroundStyle(MetroTheme.muted)
                            if let date = state.earliestArrival(at: .now) {
                                Text(date, format: .dateTime.hour().minute()).font(.title3.weight(.bold).monospacedDigit())
                            }
                        }
                    }
    }

    private func phaseLabel(_ state: JourneyState) -> String {
        switch state.phase {
        case .boarding: L("候车准备", "Boarding soon")
        case .focusing: state.remaining() <= 180 ? L("即将进站", "Approaching your stop") : L("列车正点运行", "Running on time")
        case .paused: L("暂时停靠", "Paused at the platform")
        case .resting: L("站台换乘中", "A moment to recharge")
        case .awaitingDeparture: L("下一站，等你出发", "Your next stop is waiting")
        default: L("已到站", "Arrived")
        }
    }
    private func phaseMessage(_ state: JourneyState) -> String {
        switch state.phase {
        case .boarding: L("整理桌面，把这一程留给自己。", "Clear your desk. This journey is yours.")
        case .focusing: L("世界可以稍等。你只需向前。", "The world can wait. Keep moving forward.")
        case .paused: L("喘口气，列车会在这里等你。", "Take a breath. Your train will wait.")
        case .resting: L("起身走走，让目光驶向窗外。", "Stretch your legs. Let your eyes wander.")
        case .awaitingDeparture: L("准备好了，再开始下一段专注。", "Start the next stretch when you feel ready.")
        default: ""
        }
    }
}
