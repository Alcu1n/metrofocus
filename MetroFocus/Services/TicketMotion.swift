import CoreMotion
import Observation

/// Owned by ticket detail; never runs on station, timer, or ticket export surfaces.
@MainActor @Observable
final class TicketMotion {
    private(set) var pitch: Double = 0
    private(set) var roll: Double = 0
    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var origin: (pitch: Double, roll: Double)?
    func start(reduceMotion: Bool = false) {
        stop()
        guard !reduceMotion, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let p = motion.attitude.pitch
            let r = motion.attitude.roll
            Task { @MainActor [weak self] in
                guard let self, self.manager.isDeviceMotionActive else { return }
                if self.origin == nil { self.origin = (p, r) }
                self.pitch = min(0.35, max(-0.35, p - (self.origin?.pitch ?? p)))
                self.roll = min(0.35, max(-0.35, r - (self.origin?.roll ?? r)))
            }
        }
    }
    func stop() {
        manager.stopDeviceMotionUpdates()
        origin = nil
        pitch = 0
        roll = 0
    }
    deinit { manager.stopDeviceMotionUpdates() }
}
