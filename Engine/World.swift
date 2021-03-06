//
//  World.swift
//  Engine
//
//  Created by Nick Lockwood on 02/06/2019.
//  Copyright © 2019 Nick Lockwood. All rights reserved.
//

public enum WorldAction {
    case loadLevel(Int)
}

public struct World {
    public private(set) var map: Tilemap
    public var seen = WorldVision(height: 1,width: 1)
    public private(set) var monsters: [Monster]
    public private(set) var player: Player!
    public private(set) var effects: [Effect]
    public private(set) var doors: [Door]
    public private(set) var pushwalls: [Pushwall]
    public private(set) var switches: [Switch]
    public private(set) var isLevelEnded: Bool
    public var isRevealed: Bool
    
    public init(map: Tilemap) {
        self.map = map
        self.monsters = []
        self.effects = []
        self.doors = []
        self.pushwalls = []
        self.seen = WorldVision(height: map.height, width: map.width)
        self.switches = []
        self.isLevelEnded = false
        self.isRevealed = false
        reset()
    }
}

public extension World {
    var size: Vector {
        return map.size
    }
    
    //seen.update(self)
    mutating func update(timeStep: Double, input: Input) -> WorldAction?  {
        
        
        
        
        // Update effects
        effects = effects.compactMap { effect in
            guard effect.time < effect.duration else {
                return nil
            }
            var effect = effect
            effect.time += timeStep
            return effect
        }
        
        // Check for level end
     // Check for level end
        if isLevelEnded {
            if effects.isEmpty {
                effects.append(Effect(type: .fadeIn, color: .black, duration: 0.5))
                return .loadLevel(map.index + 1)
            }
            return nil
        }
        
        seen.update(self)
        
        // Update player
        if player.isDead == false {
            var player = self.player!
            player.animation.time += timeStep
            player.update(with: input, in: &self)
            player.position += player.velocity * timeStep
            self.player = player
        } else if effects.isEmpty {
            reset()
            effects.append(Effect(type: .fadeIn, color: .red, duration: 0.5))
            return nil
        }
        
        seen.update(self)
        
        // Update monsters
        for i in 0 ..< monsters.count {
            var monster = monsters[i]
            monster.animation.time += timeStep
            monster.update(in: &self)
            monster.position += monster.velocity * timeStep
            monsters[i] = monster
        }
        
        // Update doors
        for i in 0 ..< doors.count {
            var door = doors[i]
            door.time += timeStep
            door.update(in: &self)
            doors[i] = door
        }
        
        // Update switches
        for i in 0 ..< switches.count {
            var s = switches[i]
            s.animation.time += timeStep
            s.update(in: &self)
            switches[i] = s
        }
        
        // Update pushwalls
        for i in 0 ..< pushwalls.count {
            var pushwall = pushwalls[i]
            pushwall.update(in: &self)
            pushwall.position += pushwall.velocity * timeStep
            pushwalls[i] = pushwall
        }
        
        // Handle collisions
        for i in 0 ..< monsters.count {
            var monster = monsters[i]
            if let intersection = player.intersection(with: monster) {
                player.position -= intersection / 2
                monster.position += intersection / 2
            }
            for j in i + 1 ..< monsters.count {
                if let intersection = monster.intersection(with: monsters[j]) {
                    monster.position -= intersection / 2
                    monsters[j].position += intersection / 2
                }
            }
            monster.avoidWalls(in: self)
            
            monsters[i] = monster
        }
        
        // Check for stuck actors
        if player.isStuck(in: self) {
            hurtPlayer(1)
        }
        for i in 0 ..< monsters.count where monsters[i].isStuck(in: self) {
            hurtMonster(at: i, damage: 1)
        }
        
        player.avoidWalls(in: self)
        
        return nil
    }
    
    var sprites: [Billboard] {
        let ray = Ray(origin: player.position, direction: player.direction)
        return monsters.map { $0.billboard(for: ray) } + doors.map { $0.billboard }  + pushwalls.flatMap { $0.billboards(facing: player.position) }
    }
    
    mutating func hurtPlayer(_ damage: Double) {
        if player.isDead {
            return
        }
        player.health -= damage
        player.velocity = Vector(x: 0, y: 0)
        let color = Color(r: 255, g: 0, b: 0, a: 191)
        effects.append(Effect(type: .fadeIn, color: color, duration: 0.2))
        if player.isDead {
            effects.append(Effect(type: .fizzleOut, color: .red, duration: 2))
        }
    }
    
    mutating func hurtMonster(at index: Int, damage: Double) {
        var monster = monsters[index]
        if monster.isDead {
            return
        }
        monster.health -= damage
        monster.velocity = Vector(x: 0, y: 0)
        if monster.isDead {
            monster.state = .dead
            monster.animation = .monsterDeath
        } else {
            monster.state = .hurt
            monster.animation = .monsterHurt
        }
        monsters[index] = monster
    }
    
    mutating func endLevel() {
        isLevelEnded = true
        effects.append(Effect(type: .fadeOut, color: .black, duration: 2))
    }
    
    mutating func reset() {
        self.monsters = []
        self.doors = []
        self.switches = []
        self.isLevelEnded = false
        var pushwallCount = 0
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
                case .door:
                    precondition(y > 0 && y < map.height, "Door cannot be placed on map edge")
                    let isVertical = map[x, y - 1].isWall && map[x, y + 1].isWall
                    doors.append(Door(position: position, isVertical: isVertical))
                case .pushwall:
                    pushwallCount += 1
                    if pushwalls.count >= pushwallCount {
                        let tile = pushwalls[pushwallCount - 1].tile
                        pushwalls[pushwallCount - 1] = Pushwall(position: position, tile: tile)
                        break
                    }
                    var tile = map[x, y]
                    if tile.isWall {
                        map[x, y] = .floor
                    } else {
                        tile = map.closestFloorTile(to: x, y) ?? .wall
                    }
                    pushwalls.append(Pushwall(position: position, tile: tile))
                case .sw_tch:
                    precondition(map[x, y].isWall, "Switch must be placed on a wall tile")
                    switches.append(Switch(position: position))
                }
            }
        }
    }
    
    
    func pickMonster(_ ray: Ray) -> Int? {
        let wallHit = hitTest(ray)
        var distance = (wallHit - ray.origin).length
        var result: Int? = nil
        for i in monsters.indices {
            guard let hit = monsters[i].hitTest(ray) else {
                continue
            }
            let hitDistance = (hit - ray.origin).length
            guard hitDistance < distance else {
                continue
            }
            result = i
            distance = hitDistance
        }
        return result
    }
    
    func hitTest(_ ray: Ray) -> Vector {
        var wallHit = map.hitTest(ray)
        
        var distance = (wallHit - ray.origin).length
        let billboards = doors.map { $0.billboard } +
            pushwalls.flatMap { $0.billboards(facing: ray.origin) }
        for billboard in billboards {
            guard let hit = billboard.hitTest(ray) else {
                continue
            }
            let hitDistance = (hit - ray.origin).length
            guard hitDistance < distance else {
                continue
            }
            wallHit = hit
            distance = hitDistance
        }
        
        return wallHit
    }
    
    func isDoor(at x: Int, _ y: Int) -> Bool {
        return map.things[y * map.width + x] == .door
    }
    
    func `switch`(at x: Int, _ y: Int) -> Switch? {
        guard map.things[y * map.width + x] == .sw_tch else {
            return nil
        }
        return switches.first(where: {
            Int($0.position.x) == x && Int($0.position.y) == y
        })
    }
    
    mutating func setLevel(_ map: Tilemap) {
        let effects = self.effects
        self = World(map: map)
        self.effects = effects
    }
    
}
