import AVFoundation
import CoreHaptics
import Observation
import UIKit

enum TransitEffect: String { case departure, arrival, punch }
enum TransitFeedback { case departure, arrival, punch, selection, pulse }

@MainActor @Observable
final class SensoryService {
    let settings: SensorySettings
    private(set) var isPlaying = false
    private(set) var isPreviewing = false
    private(set) var hasInterruptedPlayback = false
    private(set) var errorMessage: String?
    @ObservationIgnored private var ambient: AVAudioPlayer?
    @ObservationIgnored private var effectPlayer: AVAudioPlayer?
    @ObservationIgnored private var hapticEngine: CHHapticEngine?
    @ObservationIgnored private let speech = AVSpeechSynthesizer()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var stopTask: Task<Void, Never>?
    @ObservationIgnored private var previewTask: Task<Void, Never>?
    @ObservationIgnored private var currentSound: Soundscape?

    init(settings: SensorySettings) {
        self.settings = settings
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor [weak self] in self?.interruptPlayback() }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            guard raw == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            Task { @MainActor [weak self] in self?.interruptPlayback() }
        })
    }

    /// Apply toggle changes without starting ambient sound in an idle journey.
    func applySettings() {
        if !settings.soundEnabled { stop() }
        else if isPlaying && !isPreviewing && currentSound != settings.soundscape { play() }
        if !settings.announcementsEnabled { speech.stopSpeaking(at: .immediate) }
        if !settings.effectsEnabled { effectPlayer?.stop() }
    }

    func play(userInitiated: Bool = false) {
        guard settings.soundEnabled else { stop(); return }
        guard !hasInterruptedPlayback || userInitiated else { return }
        if start(settings.soundscape, preview: false) { hasInterruptedPlayback = false }
    }
    func preview(_ soundscape: Soundscape) {
        // Explicit preview is an intentional request to resume audio.
        guard start(soundscape, preview: true) else { return }
        hasInterruptedPlayback = false
        previewTask?.cancel()
        previewTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(8)) } catch { return }
            self?.stop()
        }
    }
    func stop() {
        previewTask?.cancel()
        stopTask?.cancel()
        guard let retiring = ambient else { isPlaying = false; isPreviewing = false; return }
        ambient = nil
        currentSound = nil
        isPlaying = false
        isPreviewing = false
        retiring.setVolume(0, fadeDuration: 0.45)
        stopTask = Task {
            // Even cancellation must stop the retired player to avoid an orphaned loop.
            try? await Task.sleep(for: .milliseconds(480))
            retiring.stop()
        }
    }
    private func start(_ soundscape: Soundscape, preview: Bool) -> Bool {
        if isPlaying, currentSound == soundscape, isPreviewing == preview { return true }
        stopImmediately()
        do {
            guard let url = resource(soundscape.rawValue) else { throw CocoaError(.fileNoSuchFile) }
            try activateSession()
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0
            player.prepareToPlay()
            guard player.play() else { throw CocoaError(.fileReadUnknown) }
            player.setVolume(0.55, fadeDuration: 1.2)
            ambient = player
            currentSound = soundscape
            isPlaying = true
            isPreviewing = preview
            errorMessage = nil
            return true
        } catch {
            errorMessage = String(localized: "声音暂时无法播放，请重试。")
            return false
        }
    }
    private func interruptPlayback() {
        // Preserve the suppression across foreground refresh, settings dismissal,
        // focus transitions and interruptions ending. Only explicit playback clears it.
        if isPlaying || effectPlayer?.isPlaying == true || speech.isSpeaking {
            hasInterruptedPlayback = true
        }
        stopImmediately()
    }
    private func stopImmediately() {
        previewTask?.cancel()
        stopTask?.cancel()
        ambient?.stop()
        ambient = nil
        currentSound = nil
        effectPlayer?.stop()
        speech.stopSpeaking(at: .immediate)
        isPlaying = false
        isPreviewing = false
    }
    func effect(_ effect: TransitEffect) {
        guard !hasInterruptedPlayback, settings.effectsEnabled, let url = resource(effect.rawValue) else { return }
        do {
            try activateSession()
            effectPlayer = try AVAudioPlayer(contentsOf: url)
            effectPlayer?.volume = 0.45
            effectPlayer?.play()
        } catch { errorMessage = String(localized: "声音暂时无法播放，请重试。") }
    }
    func announce(station: String, locale: String = Locale.current.identifier) {
        guard !hasInterruptedPlayback, settings.announcementsEnabled else { return }
        let chinese = locale.hasPrefix("zh")
        let utterance = AVSpeechUtterance(string: chinese ? "下一站，\(station)" : "Next station, \(station)")
        utterance.voice = AVSpeechSynthesisVoice(language: chinese ? "zh-CN" : "en-US")
        utterance.rate = 0.43
        utterance.volume = 0.55
        do { try activateSession(); speech.speak(utterance) }
        catch { errorMessage = String(localized: "声音暂时无法播放，请重试。") }
    }
    func feedback(_ feedback: TransitFeedback) {
        guard settings.hapticsEnabled else { return }
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            if feedback == .selection { UISelectionFeedbackGenerator().selectionChanged() }
            else { UIImpactFeedbackGenerator(style: feedback == .punch ? .heavy : .light).impactOccurred() }
            return
        }
        do {
            if hapticEngine == nil { hapticEngine = try CHHapticEngine() }
            try hapticEngine?.start()
            let times: [Double] = feedback == .arrival ? [0, 0.12, 0.24] : [0]
            let intensity: Float = feedback == .punch ? 0.9 : feedback == .selection ? 0.3 : 0.5
            let events = times.map { CHHapticEvent(eventType: .hapticTransient, parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity), CHHapticEventParameter(parameterID: .hapticSharpness, value: feedback == .punch ? 0.9 : 0.45)], relativeTime: $0) }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            hapticEngine = nil
            errorMessage = String(localized: "触感暂时不可用，计时将继续。")
        }
    }
    private func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
    }
    private func resource(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Audio") ?? Bundle.main.url(forResource: name, withExtension: "wav")
    }
    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        stopTask?.cancel()
        previewTask?.cancel()
        ambient?.stop()
    }
}
