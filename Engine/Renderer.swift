//
//  Renderer.swift
//  Engine
//
//  Created by Nick Lockwood on 02/06/2019.
//  Copyright © 2019 Nick Lockwood. All rights reserved.
//

private let fizzle = (0 ..< 10000).shuffled()

public struct Renderer {
    public private(set) var bitmap: Bitmap
    private let textures: Textures
    
    
    public init(width: Int, height: Int, textures: Textures) {
        self.bitmap = Bitmap(width: width, height: height, color: .black)
        self.textures = textures
    }
}

public extension Renderer {
    
    mutating func applyEffects(_ world: World) {
        for effect in world.effects {
            switch effect.type {
            case .fadeIn:
                bitmap.tint(with: effect.color, opacity: 1 - effect.progress)
            case .fadeOut:
                bitmap.tint(with: effect.color, opacity: effect.progress)
            case .fizzleOut:
                let threshold = Int(effect.progress * Double(fizzle.count))
                
                for y in 0 ..< bitmap.height {
                    for x in 0 ..< bitmap.width {
                        let granularity = 4
                        let index = y / granularity * bitmap.width + x / granularity
                        let fizzledIndex = fizzle[index % fizzle.count]
                        if fizzledIndex <= threshold {
                            bitmap[x, y] = effect.color
                        }
                    }
                }
                
            }
        }
    }
    
    
    
    mutating func draw2D(_ world: World) {
        let scale = Double(bitmap.height) / world.size.y
        let flashlight = Color(r: 252, g: 252, b: 222)
        let radius = Vector(x:0.5,y:0.5)
        
        func drawRect(centered pos:Vector,texture:Texture){
            
            let rect = Rect(min: (pos - radius)*scale , max: (pos + radius)*scale)
            
            bitmap.drawImage(
                textures[texture],
                at:rect.min,
                size:rect.size
            )
        }
        
        for door in world.doors {
            let position = door.position + door.direction * (door.offset )
            drawRect(centered:position, texture: door.billboard.texture)
        }
        
        for pushWall in world.pushwalls {
            drawRect(centered: pushWall.position, texture:pushWall.billboards(facing: Vector(x: 0, y: 0))[0].texture)
        }
        
        
        // Draw switch
        for y in 0 ..< world.map.height {
            for x in 0 ..< world.map.width{
                
                if world.map[x, y].isWall {
                    let center = Vector(x: Double(x), y: Double(y))+radius
                    
                    drawRect(centered:center, texture: world.map[x,y].textures[0])
                    
                    if let s = world.switch(at: x, y) {
                        drawRect(centered:center, texture: s.animation.texture)
                    }
                }
            }
        }
        
        
        
        
        
        // Draw player
        var rect = world.player.rect
        rect.min *= scale
        rect.max *= scale
        bitmap.fill(rect: rect, color: .blue)
        
        // Draw view plane
        let caster = RayCaster(focalLength: 1.0,
                               viewWidth: 1.0,
                               direction: world.player.direction,
                               origin: world.player.position,
                               columns: 15)
        
        //    bitmap.drawLine(from: caster.viewStart * scale, to: (caster.viewStart + caster.viewPlane) * scale, color: .red)
        
        for ray in caster {
            var end = world.hitTest(ray)
            for sprite in world.sprites {
                guard let hit = sprite.hitTest(ray) else {
                    continue
                }
                let spriteDistance = (hit - ray.origin).length
                if spriteDistance > (end - ray.origin).length {
                    continue
                }
                end = hit
            }
            
            bitmap.drawFadeLine(from: ray.origin * scale, to: end * scale, color: flashlight)
        }
        
        for monster in world.monsters {
            let rect = Rect(min: monster.rect.min * scale, max: monster.rect.max * scale)
            bitmap.drawImage(
                textures[monster.animation.texture],
                at:rect.min,
                size:rect.size
            )
        }
        
        if  !world.isRevealed {
        for y in 0 ..< world.map.height {
            for x in 0 ..< world.map.width {
                if let c = world.seen[x, y]{
                    let rect = Rect(
                        min: Vector(x: Double(x), y: Double(y)) * scale,
                        max: Vector(x: Double(x + 1), y: Double(y + 1)) * scale
                    )
                    bitmap.fillBlend(rect: rect, color: c.color, opacity: c.progress)
                }
            }
        }
        }
        
        // Effects
        applyEffects( world)
        
    }
    
    
    mutating func draw(_ world: World) {
        
        
        let caster = RayCaster(focalLength: 1.0,
                               viewWidth: Double(bitmap.width) / Double(bitmap.height),
                               direction: world.player.direction,
                               origin: world.player.position,
                               columns: bitmap.width)
        
        for (x, ray) in caster.enumerated() {
            let end = world.map.hitTest(ray)
            let wallDistance = (end - ray.origin).length
            
            // Draw wall
            let wallHeight = 1.0
            let distanceRatio = caster.distanceRatio(x)
            let perpendicular = wallDistance / distanceRatio
            let height = wallHeight * caster.focalLength / perpendicular * Double(bitmap.height)
            let wallTexture: Bitmap
            let wallX: Double
            
            let (tileX, tileY) = world.map.tileCoords(at: end, from: ray.direction)
            let tile = world.map[tileX, tileY]
            
            if end.x.rounded(.down) == end.x {
                let neighborX = tileX + (ray.direction.x > 0 ? -1 : 1)
                let isDoor = world.isDoor(at: neighborX, tileY)
                wallTexture = textures[isDoor ? .doorjamb : tile.textures[0]]
                wallX = end.y - end.y.rounded(.down)
            } else {
                let neighborY = tileY + (ray.direction.y > 0 ? -1 : 1)
                let isDoor = world.isDoor(at: tileX, neighborY)
                wallTexture = textures[isDoor ? .doorjamb2 : tile.textures[1]]
                wallX = end.x - end.x.rounded(.down)
            }
            let textureX = Int(wallX * Double(wallTexture.width))
            let wallStart = Vector(x: Double(x), y: (Double(bitmap.height) - height) / 2 + 0.001)
            bitmap.drawColumn(textureX, of: wallTexture, at: wallStart, height: height)
            
            
            // Draw switch
            if let s = world.switch(at: tileX, tileY) {
                let switchTexture = textures[s.animation.texture]
                bitmap.drawColumn(textureX, of: switchTexture, at: wallStart, height: height)
            }
            // Draw floor and ceiling
            var floorTile: Tile!
            var floorTexture, ceilingTexture: Bitmap!
            let floorStart = Int(wallStart.y + height) + 1
            for y in min(floorStart, bitmap.height) ..< bitmap.height {
                let normalizedY = (Double(y) / Double(bitmap.height)) * 2 - 1
                let perpendicular = wallHeight * caster.focalLength / normalizedY
                let distance = perpendicular * distanceRatio
                let mapPosition = ray.origin + ray.direction * distance
                let tileX = mapPosition.x.rounded(.down), tileY = mapPosition.y.rounded(.down)
                let tile = world.map[Int(tileX), Int(tileY)]
                if tile != floorTile {
                    floorTexture = textures[tile.textures[0]]
                    ceilingTexture = textures[tile.textures[1]]
                    floorTile = tile
                }
                let textureX = mapPosition.x - tileX, textureY = mapPosition.y - tileY
                bitmap[x, y] = floorTexture[normalized: textureX, textureY]
                bitmap[x, bitmap.height - y] = ceilingTexture[normalized: textureX, textureY]
            }
            
            // Sort sprites by distance
            var spritesByDistance: [(hit: Vector, distance: Double, sprite: Billboard)] = []
            for sprite in world.sprites {
                guard let hit = sprite.hitTest(ray) else {
                    continue
                }
                let spriteDistance = (hit - ray.origin).length
                if spriteDistance > wallDistance {
                    continue
                }
                spritesByDistance.append(
                    (hit: hit, distance: spriteDistance, sprite: sprite)
                )
            }
            
            // Draw sprites
            for (hit, spriteDistance, sprite) in spritesByDistance {
                if spriteDistance > wallDistance {
                    continue
                }
                let perpendicular = spriteDistance / distanceRatio
                let height = wallHeight / perpendicular * Double(bitmap.height)
                let spriteX = (hit - sprite.start).length / sprite.length
                let spriteTexture = textures[sprite.texture]
                let textureX = min(Int(spriteX * Double(spriteTexture.width)), spriteTexture.width - 1)
                let start = Vector(x: Double(x), y: (Double(bitmap.height) - height) / 2 + 0.001)
                bitmap.drawColumn(textureX, of: spriteTexture, at: start, height: height)
            }
            
            
        }
        
        // Player weapon
        let screenHeight = Double(bitmap.height)
        bitmap.drawImage(
            textures[world.player.animation.texture],
            at: Vector(x: Double(bitmap.width) / 2 - screenHeight / 2, y: 0),
            size: Vector(x: screenHeight, y: screenHeight)
        )
        
        // Effects
        applyEffects(world)
        
    }
    
    
    
}
