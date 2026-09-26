import Foundation
import Observation

/// Keeps players for the visible reel and the next one, so swiping on starts instantly.
/// Everything further away is released to keep memory flat.
@Observable
final class ReelPlayerPool {
    private(set) var players: [Int: LoopingPlayer] = [:]
    private var activeID: Int?

    var isMuted = true {
        didSet { players.values.forEach { $0.player.isMuted = isMuted } }
    }

    func focus(on id: Int?, in items: [FeedItem]) {
        activeID = id
        guard let id, let index = items.firstIndex(where: { $0.id == id }) else { return pauseAll() }
        let keep = [index, index + 1].filter(items.indices.contains).map { items[$0] }.filter(\.isVideo)
        let keepIDs = Set(keep.map(\.id))

        for stale in players.keys where !keepIDs.contains(stale) {
            players[stale]?.player.pause()
            players[stale] = nil
        }
        for item in keep where players[item.id] == nil {
            players[item.id] = LoopingPlayer(url: item.mediaURL, muted: isMuted)
        }
        for (itemID, looping) in players {
            if itemID == id { looping.player.play() } else { looping.player.pause() }
        }
    }

    func pauseAll() {
        players.values.forEach { $0.player.pause() }
    }

    func resume() {
        if let activeID { players[activeID]?.player.play() }
    }
}
