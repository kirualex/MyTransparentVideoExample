//
//  AVPlayerView.swift
//  MyTransparentVideoExample
//
//  Created by Quentin on 27/10/2017.
//  Copyright © 2017 Quentin Fasquel. All rights reserved.
//

import AVFoundation
import UIKit

public protocol PlayerViewDelegate {
    func didFail(error: Error,playerView: PlayerView)
    func didStartPlayback(playerView: PlayerView)
    func didEndPlayback(playerView: PlayerView)
}

// Make delegate methods optional
public extension PlayerViewDelegate {
    func didFail(error: Error,playerView: PlayerView) {}
    func didStartPlayback(playerView: PlayerView) {}
    func didEndPlayback(playerView: PlayerView) {}
}

public class PlayerView: UIView {
    
    public var delegate : PlayerViewDelegate?
    
    public private(set) var player: AVPlayer? {
        set { playerLayer.player = newValue}
        get { return playerLayer.player }
    }
    public override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    public var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    public var isPlaying: Bool {
        guard let player = player else {return false}
        return player.rate != 0 && player.error == nil
    }
    
    private var observer: NSKeyValueObservation?
    private var url: URL?
    private var isSeeking = false
    
    // MARK: - Public API
    
    public func load(_ url: URL, isTransparent: Bool = false) {
        guard url != self.url else { return }
        self.url = url
        let playerItem = isTransparent
            ? AVAsset(url: url).createTransparentItem()
            : AVPlayerItem(url: url)
        
        self.playerLayer.pixelBufferAttributes = [(kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA]
        
        if let player = self.player {
            player.replaceCurrentItem(with: playerItem)
        } else {
            self.player = AVPlayer(playerItem: playerItem)
        }
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(videoDidEnd),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: nil)
        
    }
    
    public func pauseAt(percent: Double) {
        guard let player = self.player, let item = player.currentItem, !isSeeking else { return }
        let halfTime = CMTime.init(seconds: item.duration.seconds * percent, preferredTimescale: 30)
        self.isSeeking = true
        player.seek(to: halfTime, toleranceBefore: .zero, toleranceAfter: .zero) { success in
            self.isSeeking = false
            guard success else {
                self.pauseAt(percent:percent)
                return
            }
            player.pause()
        }
    }
    
    public func play(from start: CMTime = .zero, atRate: Float = 1.0) {
        guard let player = self.player, !isPlaying, !isSeeking else { return }
        self.isSeeking = true
        player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero) { success in
            self.isSeeking = false
            guard success else {
                self.play(from: start, atRate: atRate)
                return
            }
            player.playImmediately(atRate: atRate)
            self.delegate?.didStartPlayback(playerView: self)
        }
    }
    
    @objc func videoDidEnd(notification: NSNotification) {
        self.delegate?.didEndPlayback(playerView: self)
    }
    
    // MARK : Cleaning
    
    public func unload() {
        self.player = nil
    }
    
    deinit {
        self.unload()
    }
}

public extension AVAsset {
    
    func createTransparentItem() -> AVPlayerItem {
        let playerItem = AVPlayerItem(asset: self)
        playerItem.seekingWaitsForVideoCompositionRendering = true
        playerItem.videoComposition = self.createVideoComposition()
        return playerItem
    }
    
    func createVideoComposition() -> AVVideoComposition {
        let filter = AlphaFrameFilter(renderingMode: .builtInFilter)
        let composition = AVMutableVideoComposition(asset: self, applyingCIFiltersWithHandler: { request in
            do {
                let (inputImage, maskImage) = request.sourceImage.verticalSplit()
                let outputImage = try filter.process(inputImage, mask: maskImage)
                return request.finish(with: outputImage, context: nil)
            } catch {
                print("Video composition error: %s", String(describing: error))
                return request.finish(with: error)
            }
        })
        composition.renderSize = self.videoSize.applying(CGAffineTransform(scaleX: 1.0, y: 0.5))
        return composition
    }
}
