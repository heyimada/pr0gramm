import Foundation

/// A tag search as typed. A leading "!" switches pr0gramm to the extended syntax
/// (`! kadse s:1000 -video`), where `-tag` excludes.
struct TagQuery {
    let isExtended: Bool
    let body: String

    init(_ text: String) {
        var text = text.trimmingCharacters(in: .whitespaces)
        isExtended = text.hasPrefix("!")
        if isExtended { text.removeFirst() }
        body = text.trimmingCharacters(in: .whitespaces)
    }

    var words: [String] { body.split(whereSeparator: \.isWhitespace).map(String.init) }
}
