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

enum FontName {
    static let main = "Chalkduster"
}

class GameScene: SKScene, SKPhysicsContactDelegate {

    let motionManager = CMMotionManager()
    let queue = OperationQueue()

    var fish: SKSpriteNode
    let food: SKShapeNode
    let scoreLabel: SKLabelNode
    let gameOverTitle: SKLabelNode
    let gameOverBody: SKLabelNode
    let gameOverNode: SKNode

    var bubbles: [SKSpriteNode] = []
    var score = 0
    var bubbleAddedTime: TimeInterval = 0
    var gameOver = false
    var canRestart = false
    var horizontalAngle: CGFloat = 0

    override init(size: CGSize) {

        scoreLabel = .init(fontNamed: FontName.main)
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

        gameOverTitle = SKLabelNode(fontNamed: FontName.main)
        gameOverTitle.text = "You hit a bubble! ☹️"
        gameOverTitle.fontSize = 22
        gameOverTitle.fontColor = .red
        gameOverTitle.position.y += 16
        gameOverTitle.isHidden = true

        gameOverBody = SKLabelNode(fontNamed: FontName.main)
        gameOverBody.text = "Tap to try again"
        gameOverBody.fontSize = 14
        gameOverBody.fontColor = .red
        gameOverBody.position.y -= 16
        gameOverBody.isHidden = true

        gameOverNode = SKNode()
        gameOverNode.position = .init(x: size.width / 2, y: size.height / 2)
        gameOverNode.zPosition = 1000
        gameOverNode.addChild(gameOverTitle)
        gameOverNode.addChild(gameOverBody)

        super.init(size: size)

        addChild(scoreLabel)
        addChild(fish)
        addChild(food)
        addChild(gameOverNode)

        scaleMode = .aspectFit

        scene?.backgroundColor = UIColor(red: 180 / 255.0, green: 230 / 255.0, blue: 255 / 255.0, alpha: 1)

        physicsWorld.contactDelegate = self

        motionManager.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: .main) { [weak self] motion, error in
            if let error {
                return print(error.localizedDescription)
            }

            guard let self, let motion else { return }

            self.processGravity(motion.gravity)
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
            var gravity = CMAcceleration()

            switch (UIDevice.current.orientation) {
            case .landscapeRight:
                gravity.x = amount
            case .portraitUpsideDown:
                gravity.y = amount
            case .landscapeLeft:
                gravity.x = -amount
            default:
                gravity.y = -amount
            }

            self?.processGravity(gravity)
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
        fish.physicsBody!.linearDamping = 1
        fish.physicsBody!.categoryBitMask = .bitMask(.fish)
        fish.physicsBody!.contactTestBitMask = .bitMask(.food) | .bitMask(.bubble)
        fish.yScale = 0.1
        fish.xScale = -0.1
        fish.position = view!.center

        addChild(fish)

        placeFood()
        updateScore()

        gameOver = false
    }

    func processGravity(_ gravity: CMAcceleration) {

        horizontalAngle = atan2(gravity.y, gravity.x) + .pi / 2

        let gravityMultiplier: CGFloat = 5

        physicsWorld.gravity = .init(
            dx: -gravity.x * gravityMultiplier,
            dy: -gravity.y * gravityMultiplier
        )

        guard !fish.hasActions() && !gameOver else { return }

        fish.run(.rotate(toAngle: horizontalAngle, duration: 0.5, shortestUnitArc: true))
    }

    func createBubble() {
        let bubble = SKSpriteNode(imageNamed: "bubble")
        let scale: CGFloat = 0.2 + CGFloat(arc4random() % 4) / 10.0
        bubble.xScale = -scale
        bubble.yScale = scale
        let radius = bubble.size.width / 2
        var location = randomPoint()

        location.x += sin(horizontalAngle) * (size.width + radius)
        location.y -= cos(horizontalAngle) * (size.height + radius)

        bubble.physicsBody = .init(circleOfRadius: radius)
        bubble.physicsBody!.allowsRotation = false
        bubble.physicsBody!.mass = scale
        bubble.physicsBody!.linearDamping = 1 / scale
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
        gameOverNode.zRotation = horizontalAngle

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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

        gameOverNode.zRotation = horizontalAngle

        if currentTime - bubbleAddedTime > 1 && !gameOver {
            bubbleAddedTime = currentTime
            createBubble()
        }

        let maxSpeed: CGFloat = gameOver ? 0 : 200
        for bubble in bubbles {
            let body = bubble.physicsBody!
            let v = body.velocity
            body.velocity = CGVector(
                dx: v.dx > 0 ? min(v.dx, maxSpeed) : max(v.dx, -maxSpeed),
                dy: v.dy > 0 ? min(v.dy, maxSpeed) : max(v.dy, -maxSpeed)
            )
            bubble.zRotation = horizontalAngle
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {

        super.touchesBegan(touches, with: event)

        if canRestart {
            return restart()
        }

        guard !gameOver, let touch = touches.first else { return }

        let location = touch.location(in: self)

        fish.removeAllActions()
        fish.run(.sequence([
                .move(to: location, duration: 1),
                .rotate(toAngle: horizontalAngle, duration: 0.1, shortestUnitArc: true)
        ]))

        let currentOrientation: PointOrientation = fish.xScale < 0 ? .right : .left
        let relativeOrientation = pointOrientationAfterRotation(
            center: fish.position,
            point: location,
            angleInRadians: -fish.zRotation
        )

        switch (currentOrientation, relativeOrientation) {
        case (.left, .right), (.right, .left):
                fish.xScale.negate()
        default:
            break
        }
    }

    enum PointOrientation {
        case right
        case left
        case none
    }

    func pointOrientationAfterRotation(center: CGPoint, point: CGPoint, angleInRadians: CGFloat) -> PointOrientation {
        // Step 1: Calculate the center-relative coordinates of the given point
        let relativeX = point.x - center.x
        let relativeY = point.y - center.y

        // Step 2: Apply the rotation to the point's coordinates
        let cosAngle = cos(angleInRadians)
        let sinAngle = sin(angleInRadians)
        let rotatedX = relativeX * cosAngle - relativeY * sinAngle

        // Step 3: Compare the x-coordinate of the rotated point with the center's x-coordinate
        if rotatedX > 0 {
            return .right
        } else if rotatedX < 0 {
            return .left
        } else {
            // Handle special case when the point lies on the y-axis
            return .none
        }
    }

    func didBegin(_ contact: SKPhysicsContact) {

        guard !gameOver, contact.bodyA.node == fish else { return }

        switch contact.bodyB.categoryBitMask {
        case .bitMask(.food):
            score += 1
            updateScore()
            placeFood()

        case .bitMask(.bubble):
            gameOver = true
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
