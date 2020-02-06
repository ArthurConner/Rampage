//
//  Door.swift
//  Rampage
//
//  Created by Arthur Conner on 2/5/20.
//  Copyright © 2020 Nick Lockwood. All rights reserved.
//

import Foundation

public struct Door {
    public let position: Vector
    public let direction: Vector
    public let texture: Texture

    public init(position: Vector, isVertical: Bool) {
        self.position = position
        if isVertical {
            self.direction = Vector(x: 0, y: 1)
            self.texture = .door
        } else {
            self.direction = Vector(x: 1, y: 0)
            self.texture = .door2
        }
    }
}

public extension Door {
    var billboard: Billboard {
        return Billboard(
            start: position - direction * 0.5,
            direction: direction,
            length: 1,
            texture: texture
        )
    }
    
    var rect: Rect {
         let position = self.position - direction * 0.5
         return Rect(min: position, max: position + direction)
     }
    
    func hitTest(_ ray: Ray) -> Vector? {
        return billboard.hitTest(ray)
    }
}
