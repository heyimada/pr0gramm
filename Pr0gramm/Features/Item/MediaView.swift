import AVKit
import SwiftUI

/// Displays an item's image or looping video, sized to its aspect ratio.
struct MediaView: View {
    let item: FeedItem
    let isActive: Bool
    let maxHeight: CGFloat

    @State private var showsViewer = false
    @Environment(\.openWindow) private var openWindow

    /// Very tall images (long screenshots, comics) are shown at full width and scroll with the page.
    private var isTallImage: Bool { !item.isVideo && item.aspectRatio < 0.5 }

    var body: some View {
        media
            .aspectRatio(item.aspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: isTallImage ? nil : maxHeight)
            .background(Color.black)
    }

    @ViewBuilder
    private var media: some View {
        if item.isVideo {
            LoopingVideoView(item: item, isActive: isActive)
        } else {
            RemoteImage(url: item.mediaURL)
                .onTapGesture { openViewer() }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Bild vergrößern")
                #if os(iOS)
                .fullScreenCover(isPresented: $showsViewer) {
                    ZoomableImageViewer(url: item.fullsizeURL ?? item.mediaURL, aspectRatio: item.aspectRatio)
                }
                #endif
        }
    }

    private func openViewer() {
        #if os(visionOS)
        openWindow(id: MediaWindow.id, value: item)
        #else
        showsViewer = true
        #endif
    }
}

struct RemoteImage: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            case .failure:
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.secondary)
            default:
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Owns an `AVQueuePlayer` that loops a single video.
@Observable
final class LoopingPlayer {
    let player = AVQueuePlayer()
    @ObservationIgnored private var looper: AVPlayerLooper?

    init(url: URL, muted: Bool) {
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        player.isMuted = muted
    }
}

struct LoopingVideoView: View {
    @Environment(Session.self) private var session
    let item: FeedItem
    let isActive: Bool

    @State private var looping: LoopingPlayer?
    @State private var userStarted = false

    var body: some View {
        ZStack {
            if let looping {
                VideoPlayer(player: looping.player)
            } else {
                AsyncImage(url: item.thumbnailURL) { image in
                    image.resizable().scaledToFit().blur(radius: 8)
                } placeholder: {
                    Color.black
                }
                Button {
                    userStarted = true
                    update()
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 64))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Video abspielen")
            }
        }
        .onChange(of: isActive, initial: true) { update() }
        .onDisappear {
            looping?.player.pause()
            looping = nil
            userStarted = false
        }
    }

    /// Plays while this page is the visible one; tears the player down when it isn't to save memory.
    private func update() {
        guard isActive, session.autoplayVideos || userStarted else {
            looping?.player.pause()
            if !isActive { looping = nil; userStarted = false }
            return
        }
        if looping == nil {
            looping = LoopingPlayer(url: item.mediaURL, muted: session.startMuted && !userStarted)
        }
        looping?.player.play()
    }
}
