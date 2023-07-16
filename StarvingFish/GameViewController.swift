//
//  GameViewController.swift
//  StarvingFish
//
//  Created by Paker on 15/07/23.
//  Copyright © 2023 Paker. All rights reserved.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {

    var skView: SKView { view as! SKView }

    override func loadView() {
        view = SKView()

//        skView.showsFPS = true
//        skView.showsNodeCount = true

        // Sprite Kit applies additional optimizations to improve rendering performance
        skView.ignoresSiblingOrder = true
    }

    override func viewDidLayoutSubviews() {

        super.viewDidLayoutSubviews()

        guard skView.scene == nil else { return }

        let scene = GameScene(size: skView.frame.size)

        skView.presentScene(scene)
    }
}
