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

/*
 
  var lhs = ray, rhs = Ray(origin: start, direction: direction)

 let epsilon = 0.00001
 if abs(lhs.direction.x) < epsilon {
     lhs.direction.x = epsilon
 }
 if abs(rhs.direction.x) < epsilon {
     rhs.direction.x = epsilon
 }
  
  //let slope = direction.y / direction.x
  //let intercept = origin.y - slope * origin.x
  
  let (slope1, intercept1) = lhs.slopeIntercept
  let (slope2, intercept2) = rhs.slopeIntercept
  
  if slope1 == slope2 {
      return nil
  }

  // Find intersection point
  let x = (intercept1 - intercept2) / (slope2 - slope1)
  let y = slope1 * x + intercept1

  // Check intersection point is in range
  let distanceAlongRay = (x - lhs.origin.x) / lhs.direction.x
  if distanceAlongRay < 0 {
      return nil
  }
  let distanceAlongBillboard = (x - rhs.origin.x) / rhs.direction.x
  if distanceAlongBillboard < 0 || distanceAlongBillboard > length {
      return nil
  }
  return Vector(x: x, y: y)
 }
 
 */


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
        
        let focalLength = 1.0
        let viewWidth = 1.0
        let viewPlane = world.player.direction.orthogonal * viewWidth
        let viewCenter = world.player.position + world.player.direction * focalLength
        let viewStart = viewCenter - viewPlane / 2
        
        // Cast rays
        let columns = 10
        let step = viewPlane / Double(columns)
        var columnPosition = viewStart
        for _ in 0 ..< columns {
            let rayDirection = columnPosition - world.player.position
            
            let viewPlaneDistance = rayDirection.length
            let ray = Ray(
                origin: world.player.position,
                direction: rayDirection / viewPlaneDistance
            )
            
            self.markSeen(ray, world:world)
            columnPosition += step
        }
        
    }
    
}
