import AVFoundation
import SwiftUI

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer?
    var gravity: AVLayerVideoGravity = .resizeAspect

    final class LayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> LayerView {
        let view = LayerView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: LayerView, context: Context) {
        view.playerLayer.player = player
        view.playerLayer.videoGravity = gravity
    }
}

@Observable
final class LoopingPlayer {
    let player = AVQueuePlayer()
    @ObservationIgnored private var looper: AVPlayerLooper?

    init(url: URL, muted: Bool) {
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        player.isMuted = muted
    }
}
