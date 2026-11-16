import Foundation

// Behavior pin for the untangle refactor. Prints the observable result of the app's pure logic
// for fixed inputs; `scripts/verify/pin.sh` diffs it against `pin.baseline.txt`, recorded on the
// code before the refactor.
//
// Ways the refactor could break this logic, each covered by a section below:
// - A saved feed with `-tag` loses or doubles the extended-search prefix.
// - A feed created from a search keeps "!" or stray spaces in its name.
// - A search drops or reorders the minimum score, media or excluded terms, or adds "!" wrongly.
// - The Reels filter stops quoting tags with spaces, or merges a feed's "!" twice.
// - A stream sends the wrong promoted / show_junk / following parameters.
// - A pr0gramm link opens the wrong screen, or a foreign link gets captured.
// - Comment threads change order, lose orphans, or count replies differently.
// - A filter-bound feed shows or hides under the wrong filter combination.
// - Saved data (feeds, default feed, tab order, votes, Reels filter, downloads) changes format,
//   so existing installs lose it after the update.

func show(_ label: String, _ value: Any?) {
    print("\(label) => \(value.map { String(describing: $0) } ?? "nil")")
}

func json<T: Encodable>(_ value: T) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = .secondsSince1970
    return (try? encoder.encode(value)).flatMap { String(data: $0, encoding: .utf8) } ?? "encode failed"
}

func plist(_ value: Any?) -> String {
    guard let value else { return "nil" }
    if let data = value as? Data { return String(data: data, encoding: .utf8) ?? "\(data)" }
    return String(describing: value)
}

let fixedID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

print("## CustomFeed.query")
for tags in ["kadse", "kadse -süßvieh", "  kadse   -süßvieh  ", "! kadse -süßvieh", "!kadse s:1000", "-video", "", "kadse - x"] {
    var feed = CustomFeed(name: "n", tags: tags, stream: .new)
    feed.id = fixedID
    show("tags=\(json(tags))", json(feed.query))
}

print("## CustomFeed(query:).name")
for tags in ["kadse", "! kadse s:1000", "!kadse", "  ! kadse ", "", "!"] {
    show("tags=\(json(tags))", json(CustomFeed(query: FeedQuery(stream: .junk, tags: tags)).name))
}
show("tags=nil", json(CustomFeed(query: FeedQuery(stream: .top)).name))

print("## SearchOptions.query")
func search(_ configure: (inout SearchOptions) -> Void) -> String {
    var options = SearchOptions()
    configure(&options)
    return json(options.query)
}
show("empty", search { _ in })
show("text", search { $0.text = "kadse" })
show("text spaces", search { $0.text = "  kadse  fogel " })
show("extended text", search { $0.text = "! kadse" })
show("extended no space", search { $0.text = "!kadse" })
show("only bang", search { $0.text = "!" })
show("videos", search { $0.text = "kadse"; $0.media = .videos })
show("images", search { $0.text = "kadse"; $0.media = .images })
show("videos no text", search { $0.media = .videos })
show("stream new", search { $0.text = "kadse"; $0.stream = .new })
show("min score off", search { $0.text = "kadse"; $0.scoreSlider = 80 })
show("min score 50", search { $0.text = "kadse"; $0.requiresMinimumScore = true })
show("min score 0", search { $0.text = "kadse"; $0.requiresMinimumScore = true; $0.scoreSlider = 0 })
show("min score 3", search { $0.text = "kadse"; $0.requiresMinimumScore = true; $0.scoreSlider = 3 })
show("min score 100", search { $0.text = "kadse"; $0.requiresMinimumScore = true; $0.scoreSlider = 100 })
show("excluded", search { $0.text = "kadse"; $0.excludedTags = "hund -fogel  süßvieh" })
show("everything", search {
    $0.text = "! kadse frise"; $0.stream = .junk; $0.media = .images
    $0.requiresMinimumScore = true; $0.scoreSlider = 70; $0.excludedTags = "hund"
})
for slider in stride(from: 0.0, through: 100, by: 12.5) {
    var options = SearchOptions()
    options.scoreSlider = slider
    show("minimumScore slider=\(slider)", options.minimumScore)
}

print("## ReelsFilter.query(for:)")
func reels(_ feed: FeedQuery, _ configure: (inout ReelsFilter) -> Void = { _ in }) -> String {
    var filter = ReelsFilter()
    configure(&filter)
    return json(filter.query(for: feed))
}
show("default top", reels(FeedQuery(stream: .top)))
show("no videos top", reels(FeedQuery(stream: .top)) { $0.onlyVideos = false })
show("feed tags", reels(FeedQuery(stream: .new, tags: "kadse")))
show("feed extended", reels(FeedQuery(stream: .new, tags: "! kadse -süßvieh")))
show("feed extended no space", reels(FeedQuery(stream: .new, tags: "!kadse")))
show("feed blank tags", reels(FeedQuery(stream: .junk, tags: "   ")) { $0.onlyVideos = false })
show("included/excluded", reels(FeedQuery(stream: .top)) {
    $0.include("steile frise"); $0.include("kadse"); $0.exclude("süßvieh"); $0.exclude("hund katze")
})
show("include then exclude same", reels(FeedQuery(stream: .top)) { $0.include("kadse"); $0.exclude("kadse") })
show("exclude then include same", reels(FeedQuery(stream: .top)) { $0.exclude("kadse"); $0.include(" kadse ") })
show("blank include", reels(FeedQuery(stream: .top)) { $0.include("  "); $0.onlyVideos = false })
var filterSample = ReelsFilter()
filterSample.include("kadse")
filterSample.exclude("hund")
show("ReelsFilter json", json(filterSample))

print("## FeedQuery.parameters")
for stream in FeedStream.allCases {
    let parameters = FeedQuery(stream: stream, tags: "kadse", user: "cha0s").parameters
    show("\(stream)", parameters.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value ?? "nil")" }.joined(separator: "&"))
}
show("top plain", FeedQuery(stream: .top).parameters.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value ?? "nil")" }.joined(separator: "&"))
show("titles", FeedStream.allCases.map(\.title))
show("query title", [FeedQuery(stream: .new, tags: "kadse").title, FeedQuery(stream: .new, user: "x").title, FeedQuery(stream: .junk).title])

print("## Router.route(for:)")
func describe(_ route: Route?) -> String {
    switch route {
    case nil: "nil"
    case .feed(let query): "feed \(json(query))"
    case .user(let name): "user \(name)"
    case .item(let id): "item \(id)"
    case .download(let id): "download \(id)"
    case .pager: "pager"
    case .tag(let tag): "tag \(tag)"
    default: "other \(String(describing: route))"
    }
}
for link in [
    "https://pr0gramm.com/top/123", "https://pr0gramm.com/new/katze/123", "https://pr0gramm.com/new/123:comment456",
    "https://pr0gramm.com/user/cha0s", "https://pr0gramm.com/user/cha0s/uploads/123", "https://pr0gramm.com/user/cha0s/likes",
    "https://pr0gramm.com/top/steile%20frise", "https://pr0gramm.com/#top/123", "https://pr0gramm.com/#new/kadse",
    "https://img.pr0gramm.com/2024/01/x.jpg", "https://pr0.app/top/9", "https://example.com/top/123",
    "https://pr0gramm.com/", "https://pr0gramm.com/stalk/kadse", "https://pr0gramm.com/new",
] {
    show(link, describe(Router.route(for: URL(string: link)!)))
}

print("## CommentNode.flatten")
func comment(_ id: Int, parent: Int, confidence: Double) -> Comment {
    Comment(id: id, parent: parent, content: "c\(id)", created: 0, up: 0, down: 0, confidence: confidence, name: "u", mark: 0)
}
let thread = [
    comment(1, parent: 0, confidence: 0.2), comment(2, parent: 0, confidence: 0.9),
    comment(3, parent: 1, confidence: 0.5), comment(4, parent: 1, confidence: 0.7),
    comment(5, parent: 4, confidence: 0.1), comment(6, parent: 99, confidence: 0.4),
    comment(7, parent: 2, confidence: 0.3),
]
for collapsed in [Set<Int>(), [1], [4], [2, 4]] {
    let nodes = CommentNode.flatten(thread, collapsed: collapsed)
    show("collapsed=\(collapsed.sorted())", nodes.map { "\($0.id)@\($0.depth)+\($0.replyCount)" }.joined(separator: " "))
}

print("## CustomFeed.isVisible(with:)")
let combos: [ContentFlags] = [[], .sfw, .nsfw, [.sfw, .nsfw], [.nsfw, .nsfl], [.nsfw, .nsfp], .pol, [.sfw, .nsfw, .nsfl, .pol]]
for bound in [ContentFlags(), .nsfw, [.nsfw, .nsfl], .sfw] {
    var feed = CustomFeed(name: "n", tags: "t")
    feed.flags = bound
    show("bound=\(bound.rawValue)", combos.map { "\($0.rawValue):\(feed.isVisible(with: $0) ? "y" : "n")" }.joined(separator: " "))
}

print("## Persisted formats")
var savedFeed = CustomFeed(name: "Katzen", tags: "kadse -süßvieh", stream: .new)
savedFeed.id = fixedID
savedFeed.flags = [.nsfw, .nsfl]
savedFeed.isProtected = true
show("CustomFeed", json(savedFeed))
show("FeedSource.stream", json(FeedSource.stream(.junk)))
show("FeedSource.custom", json(FeedSource.custom(fixedID)))
let legacyFeed = #"{"id":"00000000-0000-0000-0000-000000000002","name":"Alt","tags":"kadse","stream":"top"}"#
show("legacy CustomFeed", (try? JSONDecoder().decode(CustomFeed.self, from: Data(legacyFeed.utf8))).map(json))
let itemJSON = #"{"id":42,"promoted":7,"userId":3,"up":10,"down":2,"created":1700000000,"image":"2024/a.webm","thumb":"2024/a.jpg","fullsize":"","preview":null,"width":640,"height":360,"audio":true,"source":" https://example.com/x ","flags":2,"user":"cha0s","mark":2,"variants":[{"name":"vp9","path":"2024/a.webm","codec":"vp9","width":640,"height":360},{"name":"h264","path":"2024/a.mp4","codec":"h264","width":640,"height":360}]}"#
let item = try! JSONDecoder().decode(FeedItem.self, from: Data(itemJSON.utf8))
show("FeedItem urls", [item.mediaURL.absoluteString, item.thumbnailURL.absoluteString, item.fullsizeURL?.absoluteString ?? "nil", item.sourceURL?.absoluteString ?? "nil"])
show("FeedItem derived", "video=\(item.isVideo) score=\(item.score) ratio=\(item.aspectRatio) flags=\(item.contentFlags.rawValue)")
show("Download", json(Download(item: item, fileName: "42.mp4", date: Date(timeIntervalSince1970: 1_700_000_100))))

print("## Session votes from saved data")
let votesSuite = "pin.votes"
let votesDefaults = UserDefaults(suiteName: votesSuite)!
votesDefaults.removePersistentDomain(forName: votesSuite)
votesDefaults.set(Data(#"{"items":{"1":1,"2":-1},"comments":{"3":1},"tags":{"4":-1}}"#.utf8), forKey: "votes")
votesDefaults.set(17, forKey: "syncOffset")
votesDefaults.set(ContentFlags([.sfw, .nsfw]).rawValue, forKey: "contentFlags")
let session = Session(defaults: votesDefaults)
show("votes", [session.vote(for: .item, id: 1), session.vote(for: .item, id: 2), session.vote(for: .comment, id: 3),
               session.vote(for: .tag, id: 4), session.vote(for: .item, id: 3), session.vote(for: .tag, id: 1)])
show("guest flags", session.flags.rawValue)
show("selected flags", session.selectedFlags.rawValue)
show("autoplay/muted/resets", [PlaybackSettings(defaults: votesDefaults).autoplayVideos, PlaybackSettings(defaults: votesDefaults).startMuted, session.resetsFlagsOnLaunch])
votesDefaults.set(true, forKey: "resetsFlagsOnLaunch")
show("selected flags after reset-on-launch", Session(defaults: votesDefaults).selectedFlags.rawValue)
votesDefaults.removePersistentDomain(forName: votesSuite)

print("## Vote log")
// Record layout from the site: little-endian Int32 id, then an action byte (1-3 item, 4-6 comment,
// 7-9 tag; value = action - middle).
var log = Data()
for (id, action) in [(258, UInt8(3)), (7, 1), (65_536, 6), (9, 7), (10, 2), (11, 12)] {
    withUnsafeBytes(of: UInt32(id).littleEndian) { log.append(contentsOf: $0) }
    log.append(action)
}
show("vote log base64", log.base64EncodedString())
show("decoded", Session.votes(fromLog: log).map { "\($0.target):\($0.id)=\($0.value)" })

print("## Added after review")
show("search -word", search { $0.text = "kadse -hund" })
show("search extended -word", search { $0.text = "! kadse -hund" })
show("reels feed tagged !", reels(FeedQuery(stream: .new, tags: "!")))
show("Site", [Site.post(42), Site.user("cha0s"), Site.badge("a.png"), Site.api].map(\.absoluteString))
show("Site.isOwn", ["https://pr0gramm.com/x", "https://img.pr0gramm.com/x", "https://pr0.app/x", "https://evil-pr0gramm.com/x"]
    .map { Site.isOwn(URL(string: $0)!) })
let infoJSON = #"{"tags":[{"id":1,"confidence":0.2,"tag":"b"},{"id":2,"confidence":0.9,"tag":"a"},{"id":3,"confidence":0.5,"tag":"c"}],"comments":[]}"#
show("ItemInfo tag order", (try? JSONDecoder().decode(ItemInfo.self, from: Data(infoJSON.utf8)))?.tags.map(\.tag))
let scoreSuite = "pin.score"
let scoreDefaults = UserDefaults(suiteName: scoreSuite)!
scoreDefaults.removePersistentDomain(forName: scoreSuite)
scoreDefaults.set(Data(#"{"items":{"42":1},"comments":{},"tags":{}}"#.utf8), forKey: "votes")
let scoreSession = Session(defaults: scoreDefaults)
show("score with an earlier vote", [scoreSession.score(of: item), scoreSession.score(of: item)])
scoreDefaults.removePersistentDomain(forName: scoreSuite)
