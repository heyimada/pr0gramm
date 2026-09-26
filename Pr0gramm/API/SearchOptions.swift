import Foundation

/// State of the search panel, turned into pr0gramm's extended search syntax
/// (`! katze s:1000 -video -hund`) the same way the website does.
struct SearchOptions {
    enum Media: CaseIterable {
        case videos, all, images

        var title: String {
            switch self {
            case .videos: "nur videos"
            case .all: "bilder + videos"
            case .images: "nur bilder"
            }
        }
    }

    var text = ""
    var stream: FeedStream = .top
    var media: Media = .all
    var requiresMinimumScore = false
    /// Slider position 0...100, mapped quadratically onto 0...9000 Benis like the website.
    var scoreSlider: Double = 50
    var excludedTags = ""

    var minimumScore: Int {
        let score = Int(pow(scoreSlider / 100, 2) * 9000)
        return Int(0.5 + Double(score) / 100) * 100
    }

    var query: FeedQuery? {
        let words = { (text: String) in text.split(whereSeparator: \.isWhitespace).map(String.init) }
        var raw = text.trimmingCharacters(in: .whitespaces)
        let wasExtended = raw.hasPrefix("!")
        if wasExtended { raw.removeFirst() }

        var advanced: [String] = []
        if requiresMinimumScore, minimumScore > 0 { advanced.append("s:\(minimumScore)") }
        switch media {
        case .videos: advanced.append("video")
        case .images: advanced.append("-video")
        case .all: break
        }
        advanced += words(excludedTags).map { $0.hasPrefix("-") ? $0 : "-\($0)" }

        let terms = words(raw) + advanced
        guard !terms.isEmpty else { return nil }
        let tags = (wasExtended || !advanced.isEmpty ? "! " : "") + terms.joined(separator: " ")
        return FeedQuery(stream: stream, tags: tags)
    }
}
