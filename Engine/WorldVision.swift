//
//  WorldVision.swift
//  Rampage
//
//  Created by Arthur Conner on 1/25/20.
//  Copyright © 2020 Nick Lockwood. All rights reserved.
//

import Foundation



struct SightLine: Sequence {
    let ray:Ray
    let world:World
    let halt:(World,SightLine,Vector)->Bool
    
    
    init(ray r:Ray,map w:World, halt h:@escaping (World,SightLine,Vector)->Bool = SightLine.hitWall) {
        ray = r
        world = w
        halt = h
        
    }
    
    func makeIterator() -> SightLineIterator {
        return SightLineIterator(self)
    }
    
    func nearestInts(of position:Vector) -> (Int,Int) {
        var offsetX = 0, offsetY = 0
        if position.x.rounded(.down) == position.x {
            offsetX = ray.direction.x > 0 ? 0 : -1
        }
        if position.y.rounded(.down) == position.y {
            offsetY = ray.direction.y > 0 ? 0 : -1
        }
        
        let x = Int(position.x) + offsetX
        let y = Int(position.y) + offsetY
        
        return (x,y)
    }
    
    static func hitWall (world:World,line:SightLine, pos:Vector)->Bool {
        let (x,y) = line.nearestInts(of: pos)
        return world.map[x,y].isWall
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
    
    static func hitSomething (world:World,line:SightLine, pos:Vector)->Bool {
        //let (x,y) = line.nearestInts(of: pos)
        //return map[x,y].isWall
       
        
        let worldR = world.hitTest(line.ray)
        let maxD = (line.ray.origin - worldR).length
        
        let cur = (line.ray.origin - line.nextPostion(pos: pos)).length
        
        //print(cur,maxD)
        return cur > maxD
    }
    
    
    func last()->Vector{
        var pos = ray.origin
        for x in self {
            pos = x
        }
        return pos
    }
    
}

struct SightLineIterator: IteratorProtocol {
    let sight: SightLine
    var position:Vector?
    var isLast:Bool =  false
    
    init(_ sight: SightLine) {
        self.sight = sight
    }
    
    mutating func next() -> Vector? {
        
        guard !self.isLast else {
            return nil
        }
        
        guard var position = position else {
            self.position =  sight.ray.origin
            return self.position
        }
        
        let ray = sight.ray
        
        let edgeDistanceX, edgeDistanceY: Double
        if sight.ray.direction.x > 0 {
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
        
        self.position = position
        
        if (sight.halt(sight.world,sight,position)){
            isLast = true
        }
        
        return position
    }
}

public struct WorldVision {
    private var tiles: [(Date,Bool)?]
    
    public let width: Int
    private let duration = 15.0
    private let delay = 2.0
    private let completionPercentage = 0.8
}

extension WorldVision {
    
    var height: Int {
        return tiles.count / width
    }
    
    
    private func lookup(x: Int, y: Int) -> (Date,Bool)? {
        return tiles[y * width + x]
    }
    
    subscript(x: Int, y: Int) -> Effect?{
        var effect = Effect(type: .fadeOut, color: .gray, duration: duration)
        
        guard let (val,isWall) = lookup(x: x,y: y) else {
            effect.time = duration
            return effect
        }
        
        let timeSinceSeen = -val.timeIntervalSinceNow
        if timeSinceSeen < delay {
            return nil
        }
        
        if isWall {
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
        
        let line = SightLine(ray: ray, map: world, halt: SightLine.hitSomething)

        for point in line {
            let (x,y) = line.nearestInts(of: point)
            tiles[y * width + x] = (now, world.map[x,y].isWall)
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
