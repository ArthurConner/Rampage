//
//  RampageTests.swift
//  RampageTests
//
//  Created by Arthur Conner on 2/3/20.
//  Copyright © 2020 Nick Lockwood. All rights reserved.
//

import XCTest
import Rampage
import Engine

class RampageTests: XCTestCase {
    let world = World(map: loadMap())
    let textures = loadTextures()
    
    func testRenderFrame() {
        self.measure {
            var renderer = Renderer(width: 1000, height: 1000, textures: textures)
            renderer.draw(world)
        }
    }
}
