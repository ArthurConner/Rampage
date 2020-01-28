//
//  World.swift
//  Engine
//
//  Created by Nick Lockwood on 02/06/2019.
//  Copyright © 2019 Nick Lockwood. All rights reserved.



public struct World {
    public let map: Tilemap
    public var seen = WorldVision(height: 1,width: 1)
    public private(set) var effects: [Effect]
    
    public private(set) var player: Player!
    public private(set) var monsters: [Monster] = []
    
    var sprites: [Billboard] {
        let spritePlane = player.direction.orthogonal
        return monsters.map { monster in
            Billboard(
                start: monster.position - spritePlane / 2,
                direction: spritePlane,
                length: 1,
                texture: monster.animation.texture
            )
        }
    }
    
    mutating func reset() {
        self.monsters = []
        for y in 0 ..< map.height {
            for x in 0 ..< map.width {
                let position = Vector(x: Double(x) + 0.5, y: Double(y) + 0.5)
                let thing = map.things[y * map.width + x]
                switch thing {
                case .nothing:
                    break
                case .player:
                    self.player = Player(position: position)
                case .monster:
                    monsters.append(Monster(position: position))
                }
            }
        }
        self.seen = WorldVision(height: map.height, width: map.width)
    }
    
    public init(map: Tilemap) {
        self.map = map
        self.monsters = []
        self.effects = []
        reset()
    }
    
}

public extension World {
    var size: Vector {
        return map.size
    }
    
    mutating func update(timeStep: Double, input: Input) {
        
        
        // Update effects
        effects = effects.compactMap { effect in
            if effect.isCompleted {
                return nil
            }
            var effect = effect
            effect.time += timeStep
            return effect
        }
        
        // Update player
        if player.isDead == false {
            player.direction = player.direction.rotated(by: input.rotation)
            player.velocity = player.direction * input.speed * player.speed
            player.position += player.velocity * timeStep
        } else if effects.isEmpty {
            reset()
            return
        }
        
        player.direction = player.direction.rotated(by: input.rotation)
        player.velocity = player.direction * input.speed * player.speed
        player.position += player.velocity * timeStep
        while let intersection = player.intersection(with: map) {
            player.position -= intersection
        }
        
        seen.update(self)
        
        // Update monsters
        for i in 0 ..< monsters.count {
            var monster = monsters[i]
            monster.update(in: &self)
            monster.position += monster.velocity * timeStep
            monsters[i] = monster
        }
        
        // Handle collisions
        for i in monsters.indices {
            var monster = monsters[i]
            if let intersection = player.intersection(with: monster) {
                player.position -= intersection / 2
                monster.position += intersection / 2
                
                for j in i + 1 ..< monsters.count  {
                    if let intersection = monster.intersection(with: monsters[j]) {
                        monster.position -= intersection / 2
                        monsters[j].position += intersection / 2
                    }
                }
                while let intersection = monster.intersection(with: map) {
                    monster.position -= intersection
                }
            }
            
            monster.animation.time += timeStep
            monsters[i] = monster
        }
        
    }
    
    mutating func hurtPlayer(_ damage: Double) {
        if player.isDead {
            return
        }
        
        player.health -= damage
        print("player is at \(player.health)")
        effects.append(Effect(type: .fadeIn, color: .red, duration: 0.2))
        if player.isDead {
            effects.append(Effect(type: .fizzleOut, color: .red, duration: 2))
        }
    }
}
