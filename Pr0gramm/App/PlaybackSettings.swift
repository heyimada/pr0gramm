import Foundation
import Observation

@Observable
final class PlaybackSettings {
    var autoplayVideos: Bool {
        didSet { defaults.set(autoplayVideos, forKey: Keys.autoplay) }
    }

    var startMuted: Bool {
        didSet { defaults.set(startMuted, forKey: Keys.muted) }
    }

    /// Reels show posts whole, with bars, unless filling the screen would cut off at most
    /// `reelsFillTolerance` of them. Off, reels always fill. Pinching a reel flips it.
    var reelsShowWhole: Bool {
        didSet { defaults.set(reelsShowWhole, forKey: Keys.reelsShowWhole) }
    }

    /// Share of a post that may be cut off to fill the screen while `reelsShowWhole` is on.
    var reelsFillTolerance: Double {
        didSet { defaults.set(reelsFillTolerance, forKey: Keys.reelsFillTolerance) }
    }

    static let fillToleranceRange: ClosedRange<Double> = 0...0.3

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        autoplayVideos = defaults.object(forKey: Keys.autoplay) as? Bool ?? true
        startMuted = defaults.object(forKey: Keys.muted) as? Bool ?? true
        reelsShowWhole = defaults.object(forKey: Keys.reelsShowWhole) as? Bool ?? true
        reelsFillTolerance = defaults.object(forKey: Keys.reelsFillTolerance) as? Double ?? 0.1
    }

    private enum Keys {
        static let autoplay = "autoplayVideos"
        static let muted = "startMuted"
        static let reelsShowWhole = "reelsShowWhole"
        static let reelsFillTolerance = "reelsFillTolerance"
    }
}
