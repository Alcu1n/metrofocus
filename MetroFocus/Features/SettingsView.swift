import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var notificationResult: Bool?
    @State private var requestingNotifications = false
    var body: some View {
        @Bindable var settings = app.settings
        NavigationStack {
            Form {
                Section {
                    Toggle(L("车厢声景", "Carriage soundscape"), isOn: $settings.soundEnabled).accessibilityIdentifier("soundToggle")
                    if app.sensory.hasInterruptedPlayback {
                        Button(L("恢复声音", "Resume audio")) { app.sensory.play(userInitiated: true) }
                    }
                    ForEach(Soundscape.allCases) { sound in
                        HStack {
                            Button {
                                settings.soundscape = sound
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: sound.symbol).frame(width: 25).foregroundStyle(MetroTheme.muted)
                                    Text(sound.title).foregroundStyle(MetroTheme.ink)
                                    Spacer()
                                    if settings.soundscape == sound { Image(systemName: "checkmark").foregroundStyle(MetroTheme.ink) }
                                }.frame(minHeight: 44)
                            }.buttonStyle(.plain)
                            Button {
                                if app.sensory.isPreviewing { app.sensory.stop() }
                                else { app.sensory.preview(sound) }
                            } label: {
                                Image(systemName: app.sensory.isPreviewing ? "stop.circle" : "play.circle").font(.title2).frame(width: 44, height: 44)
                            }.buttonStyle(.borderless).accessibilityLabel(L("试听", "Preview") + " " + sound.title)
                                .accessibilityValue(app.sensory.isPreviewing ? L("播放中", "Playing") : L("未播放", "Stopped"))
                        }
                    }
                } header: { Text(L("你的车厢", "Your carriage")) } footer: { Text(L("声景仅在专注时播放。试听持续 8 秒。", "Soundscapes play during focus. Previews last 8 seconds.")) }
                Section {
                    Toggle(L("进站报站", "Station announcements"), isOn: $settings.announcementsEnabled)
                    Toggle(L("机械操作音", "Mechanical sound effects"), isOn: $settings.effectsEnabled)
                    Toggle(L("触觉反馈", "Haptic feedback"), isOn: $settings.hapticsEnabled)
                } header: { Text(L("声音与触感", "Sound & touch")) }
                Section {
                    Button {
                        requestingNotifications = true
                        Task {
                            notificationResult = await app.notifications.requestAuthorization()
                            requestingNotifications = false
                            app.synchronize(allowEffects: false)
                        }
                    } label: {
                        HStack {
                            Label(L("启用到站提醒", "Enable arrival alerts"), systemImage: "bell")
                            Spacer()
                            if requestingNotifications { ProgressView() }
                        }
                    }.disabled(requestingNotifications)
                    if let result = notificationResult {
                        Text(result ? L("到站提醒已启用。", "Arrival alerts are enabled.") : L("通知未开启。可在系统设置中更改，计时仍会继续。", "Notifications are off. You can change this in Settings; your timer will still run."))
                            .font(.footnote).foregroundStyle(MetroTheme.muted)
                    }
                    Button(L("打开系统设置", "Open system settings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                } header: { Text(L("系统联动", "System integration")) } footer: { Text(L("锁屏或切换应用不会中止旅程。休息结束后，由你确认继续。", "Locking your phone or switching apps never ends a journey. Continue after each break when you are ready.")) }
                if let error = app.sensory.errorMessage {
                    Section { Text(error).foregroundStyle(MetroTheme.amber) }
                }
                Section {
                    LabeledContent(L("版本", "Version"), value: "1.0")
                    Text(L("属于你的时间，只保存在这台设备。", "Your time belongs to you. Journeys stay on this device."))
                        .font(.footnote).foregroundStyle(MetroTheme.muted)
                } header: { Text("METROFOCUS") }
            }.scrollContentBackground(.hidden).background(MetroTheme.background)
                .navigationTitle(L("乘车偏好", "On-board preferences")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("完成", "Done")) { dismiss() } } }
        }.preferredColorScheme(.dark).tint(MetroTheme.ink)
            .onChange(of: settings.soundEnabled) { _, enabled in
                if enabled, app.engine.state?.phase == .focusing { app.sensory.play(userInitiated: true) }
                else { settingsChanged() }
            }
            .onChange(of: settings.soundscape) { _, _ in settingsChanged() }
            .onChange(of: settings.announcementsEnabled) { _, _ in settingsChanged() }
            .onChange(of: settings.effectsEnabled) { _, _ in settingsChanged() }
            .onDisappear {
                if app.sensory.isPreviewing { app.sensory.stop() }
                if app.engine.state?.phase == .focusing { app.sensory.play() }
            }
    }
    private func settingsChanged() {
        app.sensory.applySettings()
        if app.engine.state?.phase == .focusing { app.sensory.play() }
    }
}
