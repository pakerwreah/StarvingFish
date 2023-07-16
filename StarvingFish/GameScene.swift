//
//  GameScene.swift
//  StarvingFish
//
//  Created by Paker on 15/07/23.
//  Copyright © 2023 Paker. All rights reserved.
//

import SpriteKit
import CoreMotion

enum CollisionCategory: UInt32 {
    case fish
    case food
    case bubble
}

extension UInt32 {
    static func bitMask(_ category: CollisionCategory) -> UInt32 { 1 << category.rawValue }
}

class GameScene: SKScene, SKPhysicsContactDelegate {

    let motionManager = CMMotionManager()
    let queue = OperationQueue()

    var fish: SKSpriteNode
    let food: SKShapeNode
    let scoreLabel: SKLabelNode
    let gameOverTitle: SKLabelNode
    let gameOverBody: SKLabelNode

    var bubbles: [SKSpriteNode] = []
    var score = 0
    var bubbleAddedTime: TimeInterval = 0
    var gamePaused = false
    var canRestart = false
    var horizontalAngle: CGFloat = 0

    override init(size: CGSize) {

        scoreLabel = .init(fontNamed: "Chalkduster")
        scoreLabel.fontSize = 16
        scoreLabel.fontColor = .black
        scoreLabel.position = .init(x: 20, y: 20)
        scoreLabel.horizontalAlignmentMode = .left

        fish = .init()

        let foodRadius: CGFloat = 3
        food = .init(circleOfRadius: foodRadius)
        food.physicsBody = .init(circleOfRadius: foodRadius)
        food.physicsBody!.isDynamic = false
        food.physicsBody!.affectedByGravity = false
        food.physicsBody!.categoryBitMask = .bitMask(.food)
        food.strokeColor = .black
        food.fillColor = .brown

        gameOverTitle = SKLabelNode(fontNamed: "Chalkduster")
        gameOverTitle.text = "You hit a bubble! ☹️"
        gameOverTitle.fontSize = 22
        gameOverTitle.fontColor = .red
        gameOverTitle.position = .init(x: size.width / 2, y: size.height / 2 + 30)
        gameOverTitle.zPosition = 1000
        gameOverTitle.isHidden = true

        gameOverBody = SKLabelNode(fontNamed: "Chalkduster")
        gameOverBody.text = "Tap to try again"
        gameOverBody.fontSize = 14
        gameOverBody.fontColor = .red
        gameOverBody.position = .init(x: size.width / 2, y: size.height / 2)
        gameOverBody.zPosition = 1000
        gameOverBody.isHidden = true

        super.init(size: size)

        addChild(scoreLabel)
        addChild(fish)
        addChild(food)
        addChild(gameOverTitle)
        addChild(gameOverBody)

        scaleMode = .aspectFit

        scene?.backgroundColor = UIColor(red: 180 / 255.0, green: 230 / 255.0, blue: 255 / 255.0, alpha: 1)

        physicsWorld.contactDelegate = self

        motionManager.deviceMotionUpdateInterval = 0.1

        motionManager.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: queue) { [weak self] motion, error in
            if let error {
                return print(error.localizedDescription)
            }

            guard let self, let motion else { return }

            DispatchQueue.main.async {
                self.processGravity(x: motion.gravity.x, y: motion.gravity.y)
            }
        }

        #if targetEnvironment(simulator)
            simulateGravity()
        #endif
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func simulateGravity() {
        Timer.scheduledTimer(withTimeInterval: motionManager.deviceMotionUpdateInterval, repeats: true) { [weak self] _ in
            let amount = 1.0
            var x = 0.0
            var y = 0.0

            switch (UIDevice.current.orientation) {
            case .landscapeRight:
                x = amount
            case .portraitUpsideDown:
                y = amount
            case .landscapeLeft:
                x = -amount
            default:
                y = -amount
            }

            self?.processGravity(x: x, y: y)
        }
    }

    override func didMove(to view: SKView) {

        super.didMove(to: view)

        restart()
    }

    func randomPoint(margin: Int = 0) -> CGPoint {
        let x = CGFloat(margin + Int(arc4random()) % (Int(frame.width) - 2 * margin))
        let y = CGFloat(margin + Int(arc4random()) % (Int(frame.height) - 2 * margin))
        return .init(x: x, y: y)
    }

    func placeFood() {
        food.run(.move(to: randomPoint(margin: 50), duration: 0))
    }

    func updateScore() {
        scoreLabel.text = "Score: \(score)"
    }

    func restart() {
        canRestart = false

        hideGameOver()
        removeBubbles()

        score = 0
        bubbleAddedTime = 0

        fish = .init(imageNamed: "fish")
        fish.physicsBody = .init(texture: fish.texture!, size: fish.texture!.size())
        fish.physicsBody!.allowsRotation = false
        fish.physicsBody!.affectedByGravity = false
        fish.physicsBody!.categoryBitMask = .bitMask(.fish)
        fish.physicsBody!.contactTestBitMask = .bitMask(.food) | .bitMask(.bubble)
        fish.yScale = 0.1
        fish.xScale = -0.1
        fish.position = view!.center

        addChild(fish)

        placeFood()
        updateScore()

        gamePaused = false
    }

    func processGravity(x: Double, y: Double) {

        physicsWorld.gravity = .init(dx: -x / 2, dy: -y / 2)

        guard !fish.hasActions() && !gamePaused else { return }

        horizontalAngle = atan2(y, x) + .pi / 2

        fish.run(.rotate(toAngle: horizontalAngle, duration: 0.5, shortestUnitArc: true))
    }

    func createBubble() {
        let bubble = SKSpriteNode(imageNamed: "bubble")
        let scale: CGFloat = 0.2 + CGFloat(arc4random() % 4) / 10.0
        bubble.xScale = scale
        bubble.yScale = scale
        let radius = bubble.size.width / 2
        var location = randomPoint()

        location.x -= physicsWorld.gravity.dx * size.width * 2
        location.y -= physicsWorld.gravity.dy * size.height * 2

        bubble.physicsBody = .init(circleOfRadius: radius)
        bubble.physicsBody!.allowsRotation = false
        bubble.physicsBody!.density = scale
        bubble.physicsBody!.affectedByGravity = true
        bubble.physicsBody!.categoryBitMask = .bitMask(.bubble)
        bubble.position = location

        addChild(bubble)
        bubbles.append(bubble)

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.removeBubble(bubble)
        }
    }

    func removeBubbles() {
        removeChildren(in: bubbles)
        bubbles = []
    }

    func showGameOver() {
        gameOverTitle.isHidden = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.gameOverBody.isHidden = false
            self.canRestart = true
        }
    }

    func hideGameOver() {
        gameOverTitle.isHidden = true
        gameOverBody.isHidden = true
    }

    func removeBubble(_ bubble: SKSpriteNode) {

        guard let index = bubbles.firstIndex(of: bubble) else { return }

        bubbles.remove(at: index)
        bubble.removeFromParent()
    }

    override func update(_ currentTime: TimeInterval) {

        super.update(currentTime)

        guard frame.size != .zero else { return }

        if currentTime - bubbleAddedTime > 2 && !gamePaused {
            bubbleAddedTime = currentTime
            createBubble()
        }

        let maxSpeed: CGFloat = gamePaused ? 0 : 150
        for bubble in bubbles {
            let body = bubble.physicsBody!
            let v = body.velocity
            body.velocity = CGVector(
                dx: v.dx > 0 ? min(v.dx, maxSpeed) : max(v.dx, -maxSpeed),
                dy: v.dy > 0 ? min(v.dy, maxSpeed) : max(v.dy, -maxSpeed)
            )
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {

        super.touchesBegan(touches, with: event)

        if canRestart {
            return restart()
        }

        guard !gamePaused, let touch = touches.first else { return }

        let location = touch.location(in: self)

        fish.removeAllActions()
        fish.run(.sequence([
                .move(to: location, duration: 1),
                .rotate(toAngle: horizontalAngle, duration: 0.1, shortestUnitArc: true)
        ]))

        var right = fish.xScale < 0

        fish.xScale *= (right && location.x < fish.position.x) || (!right && location.x > fish.position.x) ? -1 : 1

        right = fish.xScale < 0

        let dx = right ? (location.x - fish.position.x) : (fish.position.x - location.x)
        let dy = right ? (location.y - fish.position.y) : (fish.position.y - location.y)

        fish.run(.rotate(toAngle: atan2(dy, dx), duration: 0.1, shortestUnitArc: true))
    }

    func didBegin(_ contact: SKPhysicsContact) {

        guard !gamePaused, contact.bodyA.node == fish else { return }

        switch contact.bodyB.categoryBitMask {
        case .bitMask(.food):
            score += 1
            updateScore()
            placeFood()

        case .bitMask(.bubble):
            gamePaused = true
            fish.removeAllActions()
            fish.run(.setTexture(.init(imageNamed: "deadfish")))
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [fish] in
                fish.removeFromParent()
            }
            showGameOver()

        default:
            break
        }
    }
}
