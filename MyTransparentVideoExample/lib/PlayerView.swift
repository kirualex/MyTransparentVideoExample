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
    public var type : Repeat = .once {
        didSet { setupEndCallback() }
    }
    public private(set) var player: AVPlayer? {
        set { playerLayer.player = newValue }
        get { return playerLayer.player }
    }
    
    private var playerItemStatusObserver: NSKeyValueObservation?
    private(set) var playerItem: AVPlayerItem? = nil {
        didSet {
            setupEndCallback()
        }
    }
    
    public func play(_ url: URL, isTransparent: Bool = false, type: Repeat = .once) {
        
        self.type = type
        let playerItem = isTransparent ? createTransparentItem(url: url) : AVPlayerItem.init(url: url)
        if isTransparent {
            self.playerLayer.pixelBufferAttributes = [(kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA]
        }
        
        let player = AVPlayer(playerItem: playerItem)
        
        self.player = player
        self.playerItem = playerItem
        
        playerItemStatusObserver = playerItem.observe(\.status) { [weak self] item, _ in
            guard let self = self else { return }
            switch item.status {
            case .failed:
                self.delegate?.didFail(error: item.error!, playerView: self)
            case .readyToPlay:
                self.player?.play()
                self.playerItemStatusObserver = nil
                self.delegate?.didStartPlayback(playerView: self)
            case .unknown:
                break
            @unknown default:
                fatalError()
            }
        }
    }
    
    // MARK: - Looping Handler
    
    private var didPlayToEndTimeObsever: NSObjectProtocol? = nil {
        willSet(newObserver) {
            if let observer = didPlayToEndTimeObsever, didPlayToEndTimeObsever !== newObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    private func setupEndCallback() {
        
        guard let playerItem = self.playerItem, let player = self.player else { return }
        
        didPlayToEndTimeObsever = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: nil, using: { _ in
                
                switch self.type {
                case .once:
                    self.delegate?.didEndPlayback(playerView: self)
                    break
                case .loop:
                    player.seek(to: CMTime.zero, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero) { _ in
                        player.play()
                    }
                    self.delegate?.didLoop(playerView: self)
                    break
                }
                
        })
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
                return request.finish(with: error)
            }
        })
        
        composition.renderSize = asset.videoSize.applying(CGAffineTransform(scaleX: 1.0, y: 0.5))
        return composition
    }
}
