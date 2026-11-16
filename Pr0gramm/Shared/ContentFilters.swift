import Foundation

extension ContentFlags {
    static let filters: [(flag: ContentFlags, title: String, subtitle: String)] = [
        (.sfw, "SFW", "Safe for work"),
        (.nsfw, "NSFW", "Nackte Haut, Pornos und leicht offensiver Kram"),
        (.nsfl, "NSFL", "Alles. Gewalt, ekliger Scheiß"),
        (.pol, "POL", "Politik, Wirtschaft, Kriminalität, Konflikte"),
    ]

    static func filterTitles(in flags: ContentFlags) -> [String] {
        filters.filter { flags.contains($0.flag) }.map(\.title)
    }
}
