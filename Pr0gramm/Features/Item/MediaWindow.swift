import AVKit
import SwiftUI

#if os(visionOS)
/// Stand-alone window showing just an item's media, which the user can resize and place freely.
struct MediaWindow: View {
    static let id = "media"

    @Environment(Session.self) private var session
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
                RemoteImage(url: item.fullsizeURL ?? item.mediaURL)
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

    /// Fits the media into roughly 1000pt on its longer side.
    private var idealSize: CGSize {
        let longSide: CGFloat = 1000
        return item.aspectRatio >= 1
            ? CGSize(width: longSide, height: longSide / item.aspectRatio)
            : CGSize(width: longSide * item.aspectRatio, height: longSide)
    }
}
#endif
