//
//  Renderer.swift
//  Engine
//
//  Created by Nick Lockwood on 02/06/2019.
//  Copyright © 2019 Nick Lockwood. All rights reserved.
//

public struct Renderer {
    public private(set) var bitmap: Bitmap
    private let textures: Textures
    private let fizzle = (0 ..< 10000).shuffled()
    
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
        
        // Draw map
        for y in 0 ..< world.map.height {
            for x in 0 ..< world.map.width where world.map[x, y].isWall {
                let rect = Rect(
                    min: Vector(x: Double(x), y: Double(y)) * scale,
                    max: Vector(x: Double(x + 1), y: Double(y + 1)) * scale
                )
                bitmap.fill(rect: rect, color: .red)
                let tile = world.map[x,y]
                let wallTexture = textures[tile.textures[0]]
                bitmap.draw(bitmap: wallTexture, inRect: rect)
                // Draw wall
                
                
            }
        }
        
        
        // Draw player
        var rect = world.player.rect
        rect.min *= scale
        rect.max *= scale
        bitmap.fill(rect: rect, color: .blue)
        
        // Draw view plane
        let focalLength = 1.0
        let viewWidth = 1.0
        let viewPlane = world.player.direction.orthogonal * viewWidth
        let viewCenter = world.player.position + world.player.direction * focalLength
        let viewStart = viewCenter - viewPlane / 2
        let viewEnd = viewStart + viewPlane
        bitmap.drawLine(from: viewStart * scale, to: viewEnd * scale, color: .red)
        
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
            var end = world.map.hitTest(ray)
            
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
            
            
            bitmap.drawLine(from: ray.origin * scale, to: end * scale, color: .green)
            columnPosition += step
        }
        
        
        for monster in world.monsters{
            
            let t = textures[monster.animation.texture]
            let rect = Rect(min: monster.rect.min * scale, max: monster.rect.max * scale)
            bitmap.draw(bitmap: t, inRect: rect)
            // Draw wall
        }
        

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
        
        // Effects
         applyEffects( world)
        
    }
    
    
    mutating func draw(_ world: World) {
        let focalLength = 1.0
        let viewWidth = Double(bitmap.width) / Double(bitmap.height)
        let viewPlane = world.player.direction.orthogonal * viewWidth
        let viewCenter = world.player.position + world.player.direction * focalLength
        let viewStart = viewCenter - viewPlane / 2
        
        // Sort sprites by distance
        var spritesByDistance: [(distance: Double, sprite: Billboard)] = []
        for sprite in world.sprites {
            let spriteDistance = (sprite.start - world.player.position).length
            spritesByDistance.append(
                (distance: spriteDistance, sprite: sprite)
            )
        }
        spritesByDistance.sort(by: { $0.distance > $1.distance })
        // Cast rays
        let columns = bitmap.width
        let step = viewPlane / Double(columns)
        var columnPosition = viewStart
        for x in 0 ..< columns {
            let rayDirection = columnPosition - world.player.position
            let viewPlaneDistance = rayDirection.length
            let ray = Ray(
                origin: world.player.position,
                direction: rayDirection / viewPlaneDistance
            )
            let end = world.map.hitTest(ray)
            let wallDistance = (end - ray.origin).length
            
            // Draw wall
            let wallHeight = 1.0
            let distanceRatio = viewPlaneDistance / focalLength
            let perpendicular = wallDistance / distanceRatio
            let height = wallHeight * focalLength / perpendicular * Double(bitmap.height)
            let wallTexture: Bitmap
            let wallX: Double
            let tile = world.map.tile(at: end, from: ray.direction)
            if end.x.rounded(.down) == end.x {
                wallTexture = textures[tile.textures[0]]
                wallX = end.y - end.y.rounded(.down)
            } else {
                wallTexture = textures[tile.textures[1]]
                wallX = end.x - end.x.rounded(.down)
            }
            let textureX = Int(wallX * Double(wallTexture.width))
            let wallStart = Vector(x: Double(x), y: (Double(bitmap.height) - height) / 2 + 0.001)
            bitmap.drawColumn(textureX, of: wallTexture, at: wallStart, height: height)
            
            // Draw floor and ceiling
            var floorTile: Tile!
            var floorTexture, ceilingTexture: Bitmap!
            let floorStart = Int(wallStart.y + height) + 1
            for y in min(floorStart, bitmap.height) ..< bitmap.height {
                let normalizedY = (Double(y) / Double(bitmap.height)) * 2 - 1
                let perpendicular = wallHeight * focalLength / normalizedY
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
            
            // Draw sprites
            
            for (_, sprite) in spritesByDistance  {
                guard let hit = sprite.hitTest(ray) else {
                    continue
                }
                let spriteDistance = (hit - ray.origin).length
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
            
            columnPosition += step
        }
        
        
        // Effects
     applyEffects(world)
        
    }
}
