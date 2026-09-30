import ActivityKit
import SwiftUI
import WidgetKit

@main
struct MetroFocusWidgetBundle: WidgetBundle {
    var body: some Widget { MetroFocusLiveActivity() }
}

struct MetroFocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TransitActivityAttributes.self) { context in
            TransitLockScreen(context: context)
                .activityBackgroundTint(Color(red: 10.0/255, green: 14.0/255, blue: 17.0/255))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "metrofocus://journey/\(context.attributes.journeyID.uuidString)"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("MetroFocus", systemImage: "tram.fill")
                        .font(.caption.bold()).foregroundStyle(lineTint(context.attributes.line))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.segmentIndex + 1) / \(context.state.segmentCount)")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(context.attributes.task).font(.headline).lineLimit(1)
                            Spacer(minLength: 8)
                            TransitCountdown(context: context).font(.title2.bold().monospacedDigit())
                        }
                        TransitTrack(color: lineTint(context.attributes.line), segments: context.state.segmentCount, index: context.state.segmentIndex)
                            .frame(height: 15)
                        Text(context.isStale ? String(localized: "请打开查看行程") : phaseLabel(context.state.phase))
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "tram.fill").foregroundStyle(lineTint(context.attributes.line))
            } compactTrailing: {
                TransitCountdown(context: context).font(.caption2.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.8).frame(width: 54)
            } minimal: {
                Image(systemName: "tram.fill").foregroundStyle(lineTint(context.attributes.line))
            }
            .keylineTint(lineTint(context.attributes.line))
            .widgetURL(URL(string: "metrofocus://journey/\(context.attributes.journeyID.uuidString)"))
        }
    }
}

private struct TransitLockScreen: View {
    let context: ActivityViewContext<TransitActivityAttributes>
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("MetroFocus", systemImage: "tram.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(lineTint(context.attributes.line))
                    Text(context.attributes.task).font(.headline).foregroundStyle(.white).lineLimit(1)
                }
                Spacer(minLength: 16)
                TransitCountdown(context: context)
                    .font(.largeTitle.weight(.bold).monospacedDigit()).foregroundStyle(.white)
                    .frame(maxWidth: 135, alignment: .trailing)
            }
            TransitTrack(color: lineTint(context.attributes.line), segments: context.state.segmentCount, index: context.state.segmentIndex).frame(height: 16)
            HStack {
                Text(context.isStale ? String(localized: "请打开查看行程") : phaseLabel(context.state.phase))
                Spacer()
                Text(context.state.station).lineLimit(1)
            }.font(.caption).foregroundStyle(.white.opacity(0.7))
        }.padding(18)
        .accessibilityElement(children: .combine)
    }
}

private struct TransitCountdown: View {
    let context: ActivityViewContext<TransitActivityAttributes>
    var body: some View {
        if context.isStale {
            Image(systemName: "arrow.up.forward.app")
                .accessibilityLabel(String(localized: "请打开查看行程"))
        } else if let deadline = context.state.deadline,
                  ["focusing", "resting", "boarding"].contains(context.state.phase) {
            Text(timerInterval: (context.state.startedAt ?? Date())...max(deadline, context.state.startedAt ?? Date()), countsDown: true)
                .multilineTextAlignment(.trailing)
                .contentTransition(.numericText(countsDown: true))
        } else {
            Image(systemName: context.state.phase == "paused" ? "pause.fill" : "tram.fill")
                .accessibilityLabel(phaseLabel(context.state.phase))
        }
    }
}

private struct TransitTrack: View {
    let color: Color
    let segments: Int
    let index: Int
    var body: some View {
        GeometryReader { proxy in
            let total = max(2, min(9, segments + 1))
            let step = max(0, proxy.size.width - 16) / CGFloat(total - 1)
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.22)).frame(height: 6)
                Capsule().fill(color).frame(width: max(12, step * CGFloat(min(index + 1, total - 1))), height: 6)
                ForEach(0..<total, id: \.self) { point in
                    Circle().fill(point <= index ? color : Color.white)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 3))
                        .offset(x: step * CGFloat(point))
                }
            }.frame(height: proxy.size.height)
        }.accessibilityHidden(true)
    }
}

private func lineTint(_ line: String) -> Color {
    switch line {
    case "coding": return Color(red: 100.0/255, green: 216.0/255, blue: 154.0/255)
    case "reading": return Color(red: 232.0/255, green: 196.0/255, blue: 95.0/255)
    case "life": return Color(red: 133.0/255, green: 201.0/255, blue: 241.0/255)
    default: return Color(red: 1, green: 70.0/255, blue: 133.0/255)
    }
}
private func phaseLabel(_ phase: String) -> String {
    switch phase {
    case "boarding": return String(localized: "候车准备")
    case "resting": return String(localized: "站台休息")
    case "paused": return String(localized: "行程已暂停")
    case "awaitingDeparture": return String(localized: "等待确认发车")
    default: return String(localized: "驶向下一站")
    }
}
