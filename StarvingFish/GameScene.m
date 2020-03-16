//
//  GameScene.m
//  StarvingFish
//
//  Created by Paker on 04/06/16.
//  Copyright (c) 2016 Paker. All rights reserved.
//

#import "GameScene.h"
#import <CoreMotion/CoreMotion.h>

typedef NS_OPTIONS(uint32_t, CollisionCategory) {
    CollisionCategoryFish = 1 << 0,
    CollisionCategoryFood = 1 << 1,
    CollisionCategoryBubble = 1 << 2
};

@interface GameScene() <SKPhysicsContactDelegate>

@end

@implementation GameScene {
    CMMotionManager *motionManager;
    NSOperationQueue *deviceQueue;
    SKSpriteNode *fish;
    SKShapeNode *food;
    SKLabelNode *scoreLabel;
    int score;
    int bubbleAddedTime;
    float horizontalAngle;
    NSMutableArray *bubbles;
    BOOL paused, can_restart;
    int death_count;
    NSString *fish_sprite;
}

-(void)didMoveToView:(SKView *)view {
    /* Setup your scene here */
    death_count = 0;
    fish_sprite = @"fish";
    
    self.physicsWorld.contactDelegate = self;
    self.scene.backgroundColor = [UIColor colorWithRed:180/255.0f green:230/255.0f blue:255/255.0f alpha:1];
    
    [self restart];
    
    motionManager = [[CMMotionManager alloc] init];
    motionManager.deviceMotionUpdateInterval = 0.1;
    
    deviceQueue = [[NSOperationQueue alloc] init];
    
    [motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryCorrectedZVertical
                                                       toQueue:deviceQueue
                                                   withHandler:^(CMDeviceMotion *motion, NSError *error) {
        [self processGravity: motion.gravity];
    }];
    
    #if TARGET_IPHONE_SIMULATOR
        [NSTimer scheduledTimerWithTimeInterval: 0.1 target:self selector:@selector(simulateGravity) userInfo:nil repeats:YES];
    #endif
}

- (void) simulateGravity {
    CMAcceleration gravity = {0,0,0};
    double amount = 1;
    
    UIDeviceOrientation orientation = UIDevice.currentDevice.orientation;
    
    switch (orientation) {
        case UIDeviceOrientationLandscapeRight:
            gravity.x = amount;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            gravity.y = amount;
            break;
        case UIDeviceOrientationLandscapeLeft:
            gravity.x = -amount;
            break;
        default:
            gravity.y = -amount;
            break;
    }
    
    [self processGravity: gravity];
}

-(void) processGravity: (CMAcceleration) gravity {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{

        CGFloat x = gravity.x;
        CGFloat y = gravity.y;
        
        self.physicsWorld.gravity = CGVectorMake(-x/2, -y/2);
        
        if(!fish.hasActions && !paused)
        {
            float angle = atan2(y, x) + M_PI_2;
            if(angle != horizontalAngle) {
                horizontalAngle = angle;
                [fish runAction:[SKAction rotateToAngle:horizontalAngle duration:0.5 shortestUnitArc:YES]];
            }
        }
    }];
}

-(void) restart {
    [self removeAllChildren];
    
    can_restart = NO;
    
    if(death_count > 5)
        fish_sprite = @"deadfish";
    
    bubbles = [NSMutableArray array];
    
    score = 0;
    bubbleAddedTime = 0;
    horizontalAngle = 999;
    
    scoreLabel = [SKLabelNode labelNodeWithFontNamed:@"Chalkduster"];
    scoreLabel.fontSize = 16;
    scoreLabel.fontColor = [UIColor blackColor];
    scoreLabel.position = CGPointMake(20,20);
    scoreLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeLeft;
    [self updateScore];
    
    [self addChild:scoreLabel];
    
    fish = [SKSpriteNode spriteNodeWithImageNamed:fish_sprite];
    fish.physicsBody = [SKPhysicsBody bodyWithTexture:fish.texture size:fish.size];
    fish.physicsBody.allowsRotation = NO;
    fish.physicsBody.affectedByGravity = NO;
    fish.physicsBody.categoryBitMask = CollisionCategoryFish;
    fish.physicsBody.contactTestBitMask = CollisionCategoryFood | CollisionCategoryBubble;
    fish.yScale *= 0.1;
    fish.xScale *= -0.1;
    fish.position = CGPointMake(CGRectGetMidX(self.frame),CGRectGetMidY(self.frame));
    
    [self addChild:fish];
    
    [self createFoodAt:[self randomPointWithMargin:50]];
    
    paused = NO;
}

-(void) createBubble {
    SKSpriteNode *bubble = [SKSpriteNode spriteNodeWithImageNamed:@"bubble"];
    CGFloat scale = 0.2 + (arc4random() % 4)/10.0f;
    bubble.xScale = scale;
    bubble.yScale = scale;
    int radius = bubble.size.width/2;
    CGPoint location = [self randomPointWithMargin:0];
    
    location.x -= self.physicsWorld.gravity.dx * self.size.width * 2;
    location.y -= self.physicsWorld.gravity.dy * self.size.height * 2;
    
    bubble.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:radius];
    bubble.physicsBody.allowsRotation = NO;
    bubble.physicsBody.density = scale;
    bubble.physicsBody.affectedByGravity = YES;
    bubble.physicsBody.categoryBitMask = CollisionCategoryBubble;
    bubble.position = location;
    
    [self addChild:bubble];
    
    [bubbles addObject:bubble];
}

-(void) createFoodAt:(CGPoint)location {
    int radius = 3;
    food = [SKShapeNode shapeNodeWithCircleOfRadius:radius];
    food.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:radius];
    food.physicsBody.dynamic = NO;
    food.physicsBody.affectedByGravity = NO;
    food.physicsBody.categoryBitMask = CollisionCategoryFood;
    food.position = location;
    food.strokeColor = [UIColor blackColor];
    food.fillColor = [UIColor brownColor];
    
    [self addChild:food];
}


-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /* Called when a touch begins */
    
    for (UITouch *touch in touches)
        if(paused) {
            if(can_restart)
                [self restart];
        }
        else
        {
            CGPoint location = [touch locationInNode:self];
            
            [fish removeAllActions];
            
            [fish runAction:[SKAction moveTo:location duration:1] completion:^{
                [fish runAction:[SKAction rotateToAngle:horizontalAngle duration:0.1 shortestUnitArc:YES]];
            }];
            
            BOOL right = fish.xScale < 0;
            
            fish.xScale *= (right && location.x < fish.position.x) || (!right && location.x > fish.position.x) ? -1 : 1;
            
            right = fish.xScale < 0;
            
            float dx = right ? location.x - fish.position.x : fish.position.x - location.x;
            float dy = right ? location.y - fish.position.y : fish.position.y - location.y;
            
            double angle = atan2f(dy, dx);
            
            [fish runAction:[SKAction rotateToAngle:angle duration:0.1 shortestUnitArc:YES]];
        }
}

-(void)updateScore {
    scoreLabel.text = [NSString stringWithFormat:@"Score: %d",score];
}

-(void)didBeginContact:(SKPhysicsContact *)contact
{
    SKPhysicsBody *firstBody, *secondBody;
    
    firstBody = contact.bodyA;
    secondBody = contact.bodyB;
    
    if(firstBody == fish.physicsBody) {
        if(secondBody == food.physicsBody) {
            [self removeChildrenInArray:@[food]];
            score++;
            [self updateScore];
            [self createFoodAt:[self randomPointWithMargin:50]];
        }
        else if(secondBody.categoryBitMask == CollisionCategoryBubble) {
            paused = YES;
            death_count++;
            [fish removeAllActions];
            
            SKLabelNode *label = [SKLabelNode labelNodeWithFontNamed:@"Chalkduster"];
            label.fontSize = 22;
            label.fontColor = [UIColor redColor];
            label.position = CGPointMake(CGRectGetMidX(self.frame),CGRectGetMidY(self.frame) + 60);
            label.zPosition = 1000;
            label.text = @"You hit a bubble! ☹️";
            [self addChild:label];
            
            SKLabelNode *tap = [SKLabelNode labelNodeWithFontNamed:@"Chalkduster"];
            tap.fontSize = 14;
            tap.fontColor = [UIColor redColor];
            tap.position = CGPointMake(CGRectGetMidX(self.frame),CGRectGetMidY(self.frame) + 30);
            tap.zPosition = 1000;
            [self addChild:tap];
            
            if(death_count==1)
            {
                SKLabelNode *tip1 = [SKLabelNode labelNodeWithFontNamed:@"Chalkduster"];
                tip1.fontSize = 14;
                tip1.fontColor = [UIColor blueColor];
                tip1.text = @"The bubbles float up!";
                tip1.position = CGPointMake(CGRectGetMidX(self.frame),CGRectGetMidY(self.frame) - 30);
                tip1.zPosition = 1000;
                
                [self addChild:tip1];
                
                SKLabelNode *tip2 = [SKLabelNode labelNodeWithFontNamed:@"Chalkduster"];
                tip2.fontSize = 14;
                tip2.fontColor = [UIColor blueColor];
                tip2.text = @"Rotate to take advantage 😉";
                tip2.position = CGPointMake(CGRectGetMidX(self.frame),CGRectGetMidY(self.frame) - 60);
                tip2.zPosition = 1000;
                
                [self addChild:tip2];
            }
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                tap.text = @"Tap to try again";
                can_restart = YES;
            });
        }
    }
}

-(CGPoint) randomPointWithMargin:(int)margin {
    CGFloat x = margin + (arc4random() % ((int)self.frame.size.width - 2*margin));
    CGFloat y = margin + (arc4random() % ((int)self.frame.size.height - 2*margin));
    return CGPointMake(x, y);
}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
    if(currentTime - bubbleAddedTime > 2 && !paused) {
        bubbleAddedTime = (int)currentTime;
        [self createBubble];
    }
    
    int max_speed = paused ? 0 : 50;
    for(SKSpriteNode *bubble in bubbles)
    {
        SKPhysicsBody *body = bubble.physicsBody;
        CGVector v = body.velocity;
        body.velocity = CGVectorMake(v.dx > 0 ? MIN(v.dx,max_speed) : MAX(v.dx,-max_speed), v.dy > 0 ? MIN(v.dy,max_speed) : MAX(v.dy,-max_speed));
    }
}

@end
