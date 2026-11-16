import AVKit
import SwiftUI

#if os(visionOS)
struct MediaWindow: View {
    static let id = "media"

    let item: FeedItem
    @State private var looping: LoopingPlayer?

    var body: some View {
        Group {
            if item.isVideo {
                if let looping {
                    VideoPlayer(player: looping.player)
                } else {
                    ProgressView()
                }
            } else {
                RemoteImage(url: item.bestURL)
            }
        }
        .aspectRatio(item.aspectRatio, contentMode: .fit)
        .frame(minWidth: 300, idealWidth: idealSize.width, minHeight: 300, idealHeight: idealSize.height)
        .onAppear {
            guard item.isVideo else { return }
            looping = LoopingPlayer(url: item.mediaURL, muted: false)
            looping?.player.play()
        }
        .onDisappear { looping?.player.pause() }
    }

    private var idealSize: CGSize {
        let longSide: CGFloat = 1000
        return item.aspectRatio >= 1
            ? CGSize(width: longSide, height: longSide / item.aspectRatio)
            : CGSize(width: longSide * item.aspectRatio, height: longSide)
    }
}
#endif
