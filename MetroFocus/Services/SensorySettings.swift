import Foundation
import Observation

enum Soundscape: String, CaseIterable, Identifiable, Codable {
    case metro, rain, air
    var id: String { rawValue }
    var title: String {
        switch self { case .metro: return String(localized: "地下铁"); case .rain: return String(localized: "雨夜列车"); case .air: return String(localized: "安静气流") }
    }
    var symbol: String {
        switch self { case .metro: return "tram.fill"; case .rain: return "cloud.rain.fill"; case .air: return "wind" }
    }
}

@MainActor @Observable
final class SensorySettings {
    @ObservationIgnored private let defaults: UserDefaults
    var soundscape: Soundscape { didSet { defaults.set(soundscape.rawValue, forKey: "sensory.soundscape") } }
    var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: "sensory.sound") } }
    var announcementsEnabled: Bool { didSet { defaults.set(announcementsEnabled, forKey: "sensory.announcements") } }
    var effectsEnabled: Bool { didSet { defaults.set(effectsEnabled, forKey: "sensory.effects") } }
    var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: "sensory.haptics") } }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        soundscape = Soundscape(rawValue: defaults.string(forKey: "sensory.soundscape") ?? "metro") ?? .metro
        soundEnabled = defaults.object(forKey: "sensory.sound") as? Bool ?? false
        announcementsEnabled = defaults.object(forKey: "sensory.announcements") as? Bool ?? false
        effectsEnabled = defaults.object(forKey: "sensory.effects") as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: "sensory.haptics") as? Bool ?? true
    }
}
