//
//  Monster.swift
//  Rampage
//
//  Created by Arthur Conner on 1/24/20.
//  Copyright © 2020 Nick Lockwood. All rights reserved.
//

import Foundation

public enum MonsterState {
    case idle
    case chasing
    case scratching
}

public struct Monster : Actor {
    public var position: Vector
    public let radius: Double = 0.4375
    public var state: MonsterState = .idle
    public var animation: Animation = .monsterIdle
    
    public var velocity: Vector = Vector(x: 0, y: 0)
    public let speed: Double = 0.5
    public let attackCooldown: Double = 0.4
    public private(set) var lastAttackTime: Double = 0
    
    public init(position: Vector) {
        self.position = position
    }

}


public extension Monster {
    
    func canSeePlayer(in world: World) -> Bool {
        let direction = world.player.position - position
        let playerDistance = direction.length
        let ray = Ray(origin: position, direction: direction / playerDistance)
        let wallHit = world.map.hitTest(ray)
        
        let wallDistance = (wallHit - position).length
        return wallDistance > playerDistance
        
    }
    
    func canReachPlayer(in world: World) -> Bool {
        let reach = 0.25
        let playerDistance = (world.player.position - position).length
        return playerDistance - radius - world.player.radius < reach
    }
    
    
    
    mutating func update(in world: inout World) {
        switch state {
        case .idle:
            if canSeePlayer(in: world) {
                state = .chasing
                animation = .monsterWalk
            }
            
            velocity = Vector(x: 0, y: 0)
        case .chasing:
            guard canSeePlayer(in: world) else {
                state = .idle
                animation = .monsterIdle
                break
            }
            
            if canReachPlayer(in: world) {
                state = .scratching
                animation = .monsterScratch
                lastAttackTime = -attackCooldown
            }
            
            let direction = world.player.position - position
            velocity = direction * (speed / direction.length)
            
        case .scratching:
            guard canReachPlayer(in: world) else {
                state = .chasing
                animation = .monsterWalk
                break
            }
            if animation.time - lastAttackTime >= attackCooldown {
                lastAttackTime = animation.time
                world.hurtPlayer(10)
            }
        }
    }
    
}

public extension Animation {
    static let monsterIdle = Animation(frames: [
        .monster
    ], duration: 0)
    static let monsterWalk = Animation(frames: [
        .monsterWalk1,
        .monster,
        .monsterWalk2,
        .monster
    ], duration: 0.5)
    
    
    
    static let monsterScratch = Animation(frames: [
        .monsterScratch1,
        .monsterScratch2,
        .monsterScratch3,
        .monsterScratch4,
        .monsterScratch5,
        .monsterScratch6,
        .monsterScratch7,
        .monsterScratch8,
    ], duration: 0.8)
    
}
