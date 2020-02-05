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
    let map:Tilemap
    let halt:(Tilemap,SightLine,Vector)->Bool
    
    
    init(ray r:Ray,map w:Tilemap, halt h:@escaping (Tilemap,SightLine,Vector)->Bool) {
        ray = r
        map = w
        halt = h
        
    }
    func makeIterator() -> SightLineIterator {
        return SightLineIterator(self)
    }
    
    
    func coord(_ position:Vector) -> (Int,Int) {
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
    
    static func hitWall (map:Tilemap,line:SightLine, pos:Vector)->Bool {
        let (x,y) = line.coord(pos)
        return map[x,y].isWall
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
        
        if (sight.halt(sight.map,sight,position)){
            isLast = true
        }
        
        return position
    }
}


struct RayCaster: Sequence {
    let focalLength, viewWidth:Double
    let viewPlane, viewCenter,origin:Vector
    let columns:Int
    let step:Vector
    
    var viewStart:Vector{
        viewCenter - viewPlane / 2
    }

    init(focalLength:Double,viewWidth:Double, direction:Vector, origin:Vector,columns:Int) {
        self.focalLength = focalLength
        self.viewWidth = viewWidth
        let vp = direction.orthogonal * viewWidth
        self.viewPlane = vp
        self.viewCenter = origin + direction * focalLength
        self.origin = origin
        self.columns = columns
        step = vp / Double(columns)
        
    }
    
    func makeIterator() -> RayCasterIterator {
        return RayCasterIterator(self)
    }
    
    func rayDirection(x:Int)->Vector{
        return viewStart + (Double(x) * step) - origin
    }
    
 
}

struct RayCasterIterator: IteratorProtocol {
    let caster:RayCaster
    var columnPosition:Vector?
    var counter = -1

    init(_ r: RayCaster) {
        self.caster = r
    }
    
    func rayFor(position:Vector)-> Ray {
       // let rayDirection = caster.rayDirection(x: counter)
        let rayDirection = position - caster.origin
        let viewPlaneDistance = rayDirection.length
        
        let ray = Ray(
            origin: caster.origin,
            direction: rayDirection / viewPlaneDistance
        )
        return ray
    }
    
   
    
    mutating func next() -> Ray? {
        
        counter += 1
        
        guard counter < caster.columns else {
            return nil
        }
        
        guard let cp = columnPosition else {
            columnPosition = caster.viewStart
            return rayFor(position: columnPosition!)
        }
        
        columnPosition = cp + caster.step
        return rayFor(position: columnPosition!)
        
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
        
        let points = SightLine(ray: ray, map: world.map,halt:SightLine.hitWall)
        var index = 0
        
        for i in points {
            let (x,y) = points.coord(i)
            index =  y * width + x
            tiles[index] = (now, false)
        }
        tiles[index] = (now, true)
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
