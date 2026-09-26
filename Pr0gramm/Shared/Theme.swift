import SwiftUI

/// Colors taken from pr0.app's stylesheet.
extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    static let pr0Orange = Color(hex: 0xEE4D2E)
    static let pr0Background = Color(hex: 0x161618)
    /// Top and bottom bars.
    static let pr0Bar = Color(hex: 0x020306)
    static let pr0Pill = Color(hex: 0x252527)
    static let pr0Secondary = Color(hex: 0xA7A7A8)
    static let pr0ThreadLine = Color(hex: 0x333335)
    static let pr0Text = Color(hex: 0xF2F5F4)
    static let pr0Mention = Color(hex: 0x75C0C7)
    static let upvoteGreen = Color(hex: 0x5BB91C)

    static func mark(_ mark: Int) -> Color { Color(hex: UserMark.hex(mark)) }

    /// Stable per-user avatar color (String.hashValue is randomized per launch, so hash by hand).
    static func avatar(for name: String) -> Color {
        let hash = name.unicodeScalars.reduce(UInt32(5381)) { ($0 &<< 5) &+ $0 &+ $1.value }
        return Color(hue: Double(hash % 360) / 360, saturation: 0.75, brightness: 0.55)
    }
}

extension Date {
    /// pr0.app-style age: "21 s", "39 min", "5 h", "3 d", "4 Mon", "2 J".
    var pr0Age: String {
        let seconds = max(0, Int(-timeIntervalSinceNow))
        switch seconds {
        case ..<60: return "\(seconds) s"
        case ..<3600: return "\(seconds / 60) min"
        case ..<86_400: return "\(seconds / 3600) h"
        case ..<(86_400 * 30): return "\(seconds / 86_400) d"
        case ..<(86_400 * 365): return "\(seconds / (86_400 * 30)) Mon"
        default: return "\(seconds / (86_400 * 365)) J"
        }
    }

    /// pr0gramm hides scores during the first hour so early votes aren't biased.
    var isScoreHidden: Bool { timeIntervalSinceNow > -3600 }
}
