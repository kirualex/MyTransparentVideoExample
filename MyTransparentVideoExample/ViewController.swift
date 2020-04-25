//
//  ViewController.swift
//  MyTransparentVideoExample
//
//  Created by Quentin on 27/10/2017.
//  Copyright © 2017 Quentin Fasquel. All rights reserved.
//

import AVFoundation
import UIKit
import os.log

class ViewController: UIViewController {
    
    @IBOutlet var playerView : PlayerView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let itemUrl: URL = Bundle.main.url(forResource: "playdoh-bat", withExtension: "mp4")!
        playerView.contentMode = .scaleAspectFit
        playerView.delegate = self
        playerView.play(itemUrl, isTransparent: true, type: .loop)
    }
}

extension ViewController : PlayerViewDelegate {
    
    func didFail(error: Error, playerView: PlayerView) {
        print("Something went wrong : \(error)")
    }
    
    func didStartPlayback(playerView: PlayerView) {
        print("didStart")
    }
    
    func didLoop(playerView: PlayerView) {
        print("didLoop")
    }
    
    func didEndPlayback(playerView: PlayerView) {
        print("didEnd")
    }
    
}
