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
    func didLoop(playerView: PlayerView)
    func didEndPlayback(playerView: PlayerView)
}

// Make delegate methods optional
public extension PlayerViewDelegate {
    func didFail(error: Error,playerView: PlayerView) {}
    func didStartPlayback(playerView: PlayerView) {}
    func didLoop(playerView: PlayerView) {}
    func didEndPlayback(playerView: PlayerView) {}
}

public class PlayerView: UIView {
    
    public enum Repeat {
        case once
        case loop
    }
    
    public var delegate : PlayerViewDelegate?
    public override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    public var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    public var type : Repeat = .once
    public private(set) var player: AVPlayer? {
        set { playerLayer.player = newValue }
        get { return playerLayer.player }
    }
    
    private var playerItemStatusObserver: NSKeyValueObservation?
    private(set) var playerItem: AVPlayerItem? = nil
    
    private var startTime : CMTime = .zero
    private var endTime : CMTime? = nil
    
    public func load(_ url: URL, isTransparent: Bool = false, type: Repeat = .once, playWhenReady: Bool = false) {
        
        self.type = type
        let playerItem = isTransparent ? createTransparentItem(url: url) : AVPlayerItem.init(url: url)
        if isTransparent {
            self.playerLayer.pixelBufferAttributes = [(kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA]
        }
        
        self.removeBoundaryTimeObserver()
        
        let player = AVPlayer(playerItem: playerItem)
        self.player = player
        self.playerItem = playerItem
        
        playerItemStatusObserver = self.player?.currentItem?.observe(\.status) { [weak self] item, _ in
            guard let self = self else { return }
            self.playerItemStatusObserver = nil
            switch item.status {
            case .failed:
                self.delegate?.didFail(error: item.error!, playerView: self)
            case .readyToPlay:
                
                if playWhenReady {
                    self.play(from: self.startTime, to: self.endTime, type: self.type)
                }
            case .unknown:
                break
            @unknown default:
                fatalError()
            }
        }
    }
    
    public func play(_ url: URL, isTransparent: Bool = false, type: Repeat = .once) {
        self.load(url, isTransparent: isTransparent, type: type, playWhenReady: true)
    }
    
    public func play(from startTime: CMTime = .zero, to endTime: CMTime? = nil, type: Repeat = .once) {
        guard let player = player, let item = playerItem else { return }
        let endTime = endTime ?? item.duration
        
        self.startTime = startTime
        self.startTime = endTime
        
        player.pause()
        player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
        self.addBoundaryTimeObserver(to:player, at: endTime)
        player.play()
        self.delegate?.didStartPlayback(playerView: self)
    }
    
    //
    var timeObserverToken: Any?
    func addBoundaryTimeObserver(to player: AVPlayer, at time: CMTime) {
        self.removeBoundaryTimeObserver()
        self.timeObserverToken = player.addBoundaryTimeObserver(forTimes: [NSValue(time: time)], queue: .main) {
            switch self.type {
            case .loop:
                self.play(from: self.startTime, to: self.endTime, type: self.type)
                self.delegate?.didLoop(playerView: self)
                break
            case .once:
                self.delegate?.didEndPlayback(playerView: self)
                break
            }
        }
    }
    
    func removeBoundaryTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            self.player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    deinit {
        playerItem = nil
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
