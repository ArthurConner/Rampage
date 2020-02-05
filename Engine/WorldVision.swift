//
//  WorldVision.swift
//  Rampage
//
//  Created by Arthur Conner on 1/25/20.
//  Copyright © 2020 Nick Lockwood. All rights reserved.
//

import Foundation

public struct WorldVision {
    private var tiles: [(Date,Bool)?]
    
    public let width: Int
    private let duration = 15.0
    private let delay = 2.0
    private let finalAlpha = 0.95
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
        
        effect.time = min((timeSinceSeen - delay),duration)
        return effect
        
    }
    
    
    init(height:Int,width w:Int){
        tiles = Array.init(repeating: nil, count: Int(height*w))
        width = w
    }
    
    private mutating func markSeen(_ ray: Ray,tileMap:Tilemap) {
        let now = Date()
        
        
        var position = ray.origin
        
        
        func updatePos(){
            
            var offsetX = 0, offsetY = 0
            if position.x.rounded(.down) == position.x {
                offsetX = ray.direction.x > 0 ? 0 : -1
            }
            if position.y.rounded(.down) == position.y {
                offsetY = ray.direction.y > 0 ? 0 : -1
            }
            
            let x = Int(position.x) + offsetX
            let y = Int(position.y) + offsetY
            
            let index =  y * width + x
            tiles[index] = (now, tileMap.tile(at: position, from: ray.direction).isWall)
        }
        
        updatePos()
        
        let slope = ray.direction.x / ray.direction.y
        repeat {
            
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
            
            let step1 = Vector(x: edgeDistanceX, y: edgeDistanceX / slope)
            let step2 = Vector(x: edgeDistanceY * slope, y: edgeDistanceY)
            if step1.length < step2.length {
                position += step1
            } else {
                position += step2
            }
            
            updatePos()
            
        } while tileMap.tile(at: position, from: ray.direction).isWall == false
        // let end = world.map.hitTest(ray)
        updatePos()
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
            
            self.markSeen(ray, tileMap:world.map)
            columnPosition += step
        }
        
    }
    
}
