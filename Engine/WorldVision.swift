//
//  WorldVision.swift
//  Rampage
//
//  Created by Arthur Conner on 1/25/20.
//  Copyright © 2020 Nick Lockwood. All rights reserved.
//

import Foundation



fileprivate struct SightLine: Sequence {
    let ray:Ray
    let world:World
    let distanceToHit:Double
    
    init(ray r:Ray,map w:World){
        ray = r
        world = w
        
        let whereWeHit = w.hitTest(r)
        distanceToHit = (r.origin - whereWeHit).length
        
    }
    
    func makeIterator() -> SightLineIterator {
        return SightLineIterator(self)
    }
    
    func nextPostion(pos:Vector)->Vector{
        
        var position = pos
        
        let edgeDistanceX, edgeDistanceY: Double
        if ray.direction.x > 0 {
            edgeDistanceX = position.x.rounded(.down) + 1 - position.x
        } else {
            edgeDistanceX = position.x.rounded(.up) - 1 - position.x
        }
        if ray.direction.y > 0 {
            edgeDistanceY = position.y.rounded(.down) + 1 - position.y
        } else {
            edgeDistanceY = position.y.rounded(.up) - 1 - position.y
        }
        
        let slope = ray.direction.x / ray.direction.y
        let step1 = Vector(x: edgeDistanceX, y: edgeDistanceX / slope)
        let step2 = Vector(x: edgeDistanceY * slope, y: edgeDistanceY)
        if step1.length < step2.length {
            position += step1
        } else {
            position += step2
        }
        
        
        return position
    }
    
    
    func hitSomething (currentLocation:Vector)->Bool {
        let distanceTravelled = (self.ray.origin - currentLocation).length
        return distanceTravelled > distanceToHit
    }
    
    
    func last()->Vector{
        var pos = ray.origin
        for x in self {
            pos = x
        }
        return pos
    }
    
}

fileprivate struct SightLineIterator: IteratorProtocol {
    let sight: SightLine
    var position:Vector?
    
    
    init(_ sight: SightLine) {
        self.sight = sight
    }
    
    mutating func next() -> Vector? {
        
        guard let position = position else {
            self.position =  sight.ray.origin
            return self.position
        }
        
        self.position = sight.nextPostion(pos: position)
        
        if sight.hitSomething(currentLocation: position){
            return nil
        }
        
        return position
    }
}

public struct WorldVision {
    private var tiles: [Date?]
    
    public let width: Int
    private let duration = 5.0
    private let delay = 2.0
    private let completionPercentage = 0.7
}

extension WorldVision {
    
    var height: Int {
        return tiles.count / width
    }
    
    
    private func lookup(x: Int, y: Int) -> Date? {
        return tiles[y * width + x]
    }
    
    subscript(x: Int, y: Int) -> Effect?{
        var effect = Effect(type: .fadeOut, color: .gray, duration: duration)
        
        guard let val = lookup(x: x,y: y) else {
            effect.time = duration
            return effect
        }
        
        let timeSinceSeen = -val.timeIntervalSinceNow
        if timeSinceSeen < delay {
            return nil
        }
        
     
        
        effect.time = min((timeSinceSeen - delay),duration * completionPercentage)
        return effect
        
    }
    
    init(height:Int,width w:Int){
        tiles = Array.init(repeating: nil, count: Int(height*w))
        width = w
    }
    
    private mutating func markSeen(_ ray: Ray,world:World) {
        let now = Date()
        let line = SightLine(ray: ray, map: world)
        
        for point in line {
            let (x,y) = world.map.tileCoords(at: point, from: ray.direction) //line.nearestInts(of: point)
            tiles[y * width + x] = now
        }
        
    }
    
    
    mutating func update(_ world: World){
        
        let caster = RayCaster(focalLength: 1.0,
                               viewWidth: 1.0,
                               direction: world.player.direction,
                               origin: world.player.position,
                               columns: 10)
        
        for ray in caster {
            self.markSeen(ray, world:world)
        }
        
    }
    
}
