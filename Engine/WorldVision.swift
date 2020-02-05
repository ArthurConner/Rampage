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
        
        let points = SightLine(ray: ray, map: world.map)
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
