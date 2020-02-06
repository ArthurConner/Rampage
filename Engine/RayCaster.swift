//
//  RayCaster.swift
//  Rampage
//
//  Created by Arthur Conner on 2/5/20.
//  Copyright © 2020 Nick Lockwood. All rights reserved.
//

import Foundation

struct RayCaster: Sequence {
    let focalLength, viewWidth:Double
    let viewPlane, viewCenter, origin:Vector
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
    
    func distanceRatio(_ x:Int)->Double{
        let position = viewStart + (Double(x) * step)
        let viewPlaneDistance = (position - origin).length
        return viewPlaneDistance / focalLength
        
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
