import AVKit
import SwiftUI

struct MediaView: View {
    let item: FeedItem
    let isActive: Bool
    let playback: VideoPlayback
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
            LoopingVideoView(item: item, isActive: isActive, playback: playback)
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

/// A post's video player. Kept by the post's page rather than by `LoopingVideoView`, so playback
/// carries on when the page switches layouts, e.g. when an iPhone Duo is opened or rotated.
@Observable
final class VideoPlayback {
    var looping: LoopingPlayer?
    var userStarted = false

    func stop() {
        looping?.player.pause()
        looping = nil
        userStarted = false
    }
}

struct LoopingVideoView: View {
    @Environment(PlaybackSettings.self) private var playbackSettings
    let item: FeedItem
    let isActive: Bool
    let playback: VideoPlayback

    var body: some View {
        ZStack {
            if let looping = playback.looping {
                VideoPlayer(player: looping.player)
            } else {
                AsyncImage(url: item.thumbnailURL) { image in
                    image.resizable().scaledToFit().blur(radius: 8)
                } placeholder: {
                    Color.black
                }
                Button {
                    playback.userStarted = true
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
    }

    private func update() {
        guard isActive, playbackSettings.autoplayVideos || playback.userStarted else {
            playback.looping?.player.pause()
            if !isActive { playback.stop() }
            return
        }
        if playback.looping == nil {
            playback.looping = LoopingPlayer(url: item.mediaURL, muted: playbackSettings.startMuted && !playback.userStarted)
        }
        playback.looping?.player.play()
    }
}
