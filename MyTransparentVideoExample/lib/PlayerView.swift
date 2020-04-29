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
    public override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    public var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    public private(set) var player: AVPlayer? {
        set { playerLayer.player = newValue}
        get { return playerLayer.player }
    }
    
    private var playerItemContext = 0
    private var playerItem: AVPlayerItem? = nil {
        didSet{ self.player?.replaceCurrentItem(with: playerItem)}
    }
    private var startTime : CMTime = .zero
    private var endTime : CMTime?
    private var url: URL?
    
    // MARK: - Public API
    
    public var isPlaying: Bool {
        guard let player = player else {return false}
        return player.rate != 0 && player.error == nil
    }
    
    public func unload() {
        self.removeBoundaryTimeObserver()
        self.playerItem = nil
        self.player = nil
    }
    
    public func load(_ url: URL, isTransparent: Bool = false) {
        guard url != self.url else { return }
        self.url = url
        self.removeBoundaryTimeObserver()

        let playerItem = isTransparent ? self.createTransparentItem(url: url) : AVPlayerItem(url: url)
        if isTransparent {
            self.playerLayer.pixelBufferAttributes = [(kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA]
        }
        playerItem.addObserver(self,
                               forKeyPath: #keyPath(AVPlayerItem.status),
                               options: [.old, .new],
                               context: &playerItemContext)
        
        self.playerItem = playerItem
    }
    
    public func play(from startTime: CMTime = .zero, to endTime: CMTime? = nil) {
        self.startTime = startTime
        self.endTime = endTime
        if let player = player {
            self.playNow(from: player)
        } else {
            let player = AVPlayer(playerItem: playerItem)
            self.player = player
        }
    }
    
    // MARK: - Private API
    
    private func playNow(from player: AVPlayer) {
        guard let item = self.playerItem else { return }
        let end = self.endTime ?? item.duration
        self.addBoundaryTimeObserver(to:player, at: end)
        player.seek(to: self.startTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self]  _ in
            guard let self = self else {return}
            player.play()
            self.delegate?.didStartPlayback(playerView: self)
        }
    }

    
    // MARK: - Time boundary
    
    var timeObserverToken: Any?
    func addBoundaryTimeObserver(to player: AVPlayer, at time: CMTime) {
        self.removeBoundaryTimeObserver()
        self.timeObserverToken = player.addBoundaryTimeObserver(forTimes: [NSValue(time: time)], queue: .main) {
            self.delegate?.didEndPlayback(playerView: self)
        }
    }
    
    func removeBoundaryTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            self.player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    // MARK: - Observe state
    
    override public func observeValue(forKeyPath keyPath: String?,
                                      of object: Any?,
                                      change: [NSKeyValueChangeKey : Any]?,
                                      context: UnsafeMutableRawPointer?) {
        
        // Only handle observations for the playerItemContext
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }
        
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            
            // Switch over status value
            switch status {
            case .readyToPlay:
                if let player = self.player {
                    self.playNow(from: player)
                }
                break
            case .failed:
                self.delegate?.didFail(error: self.playerItem!.error!, playerView: self)
                break
            default:
                print("Unknown")
                break
            }
        }
    }
    
    deinit {
        self.removeBoundaryTimeObserver()
        self.player = nil
    }
}

extension PlayerView {
    
    func createTransparentItem(url: URL) -> AVPlayerItem {
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.seekingWaitsForVideoCompositionRendering = true
        playerItem.videoComposition = createVideoComposition(for: asset)
        return playerItem
    }
    
    func createVideoComposition(for asset: AVAsset) -> AVVideoComposition {
        let filter = AlphaFrameFilter(renderingMode: .builtInFilter)
        let composition = AVMutableVideoComposition(asset: asset, applyingCIFiltersWithHandler: { request in
            do {
                let (inputImage, maskImage) = request.sourceImage.verticalSplit()
                let outputImage = try filter.process(inputImage, mask: maskImage)
                return request.finish(with: outputImage, context: nil)
            } catch {
                print("Video composition error: %s", String(describing: error))
                self.delegate?.didFail(error: error, playerView: self)
                return request.finish(with: error)
            }
        })
        
        composition.renderSize = asset.videoSize.applying(CGAffineTransform(scaleX: 1.0, y: 0.5))
        return composition
    }
}
