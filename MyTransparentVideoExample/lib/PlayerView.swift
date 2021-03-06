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
    
    public func load(_ url: URL, isTransparent: Bool = false, tint: UIColor? = nil) {
        guard url != self.url else { return }
        self.url = url
        let playerItem = isTransparent
            ? AVAsset(url: url).createTransparentItem(withTint: tint)
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
                                               object: self.player?.currentItem)
        
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
    
    func createTransparentItem(withTint: UIColor? = nil) -> AVPlayerItem {
        let playerItem = AVPlayerItem(asset: self)
        playerItem.seekingWaitsForVideoCompositionRendering = true
        playerItem.videoComposition = self.createVideoComposition(withTint: withTint)
        return playerItem
    }
    
    func createVideoComposition(withTint: UIColor? = nil) -> AVVideoComposition {
        let filter = AlphaFrameFilter(renderingMode: .builtInFilter)
        
        var bwFilter: CIFilter?
        if let tint = withTint {
            bwFilter = CIFilter(name: "CIColorMonochrome")!
            bwFilter?.setValue(CIColor.init(color: tint), forKey: "inputColor")
            bwFilter?.setValue(1.0, forKey: "inputIntensity")
        }
        
        let composition = AVMutableVideoComposition(asset: self, applyingCIFiltersWithHandler: { request in
            do {
                let (inputImage, maskImage) = request.sourceImage.verticalSplit()
                var outputImage = try filter.process(inputImage, mask: maskImage)
                if let bwFilter = bwFilter {
                    bwFilter.setValue(outputImage, forKey: "inputImage")
                    outputImage = bwFilter.outputImage!
                }
                
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
