//
//  ViewController.swift
//  Lambpage
//
//  Created by Arthur Conner on 1/24/20.
//  Copyright © 2020 Nick Lockwood. All rights reserved.
//

import Cocoa
import EngineX

private let maximumTimeStep: Double = 1 / 20
private let worldTimeStep: Double = 1 / 120

public func loadMap() -> Tilemap {
    let jsonURL = Bundle.main.url(forResource: "Map", withExtension: "json")!
    let jsonData = try! Data(contentsOf: jsonURL)
    return try! JSONDecoder().decode(Tilemap.self, from: jsonData)
}

public func loadTextures() -> Textures {
    return Textures(loader: { name in
        Bitmap(image:NSImage(named: name)!)!
    })
}

enum KeyboardActions : String, CaseIterable {
    case forward = "w"
    case back = "s"
    case turnLeft = "a"
    case turnRight = "d"
    case toggleMap = "m"
    case toggleLights = "l"
    case space = " "
    
}

class ViewController: NSViewController {
    
    private let imageView = NSImageView()
    private let textures = loadTextures()
    private var world = World(map: loadMap())
    private var lastFrameTime = CACurrentMediaTime()
    
    
    var timer:Timer?
    
    var keyboardActions = Set<KeyboardActions>()
    var keyboardRemovals = Set<KeyboardActions>()
    var isRender = false
    var is3D = true
    
    private var inputVector: Vector {
        var vector = Vector(x: 0, y: 0)
        if keyboardActions.contains(.forward) {
            vector.y -= 1
        }
        if keyboardActions.contains(.back) {
            vector.y += 1
        }
        if keyboardActions.contains(.turnLeft) {
            vector.x -= 1
        }
        if keyboardActions.contains(.turnRight) {
            vector.x += 1
        }
        return vector
    }
    
    
    override func viewDidLoad() {
        guard NSClassFromString("XCTestCase") == nil else {
            return
        }
        
        super.viewDidLoad()
        setUpImageView()
        timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(update), userInfo: nil, repeats: true)
        
        NSEvent.addLocalMonitorForEvents(matching: .keyUp, handler: keyU)
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: keyD)
        // Do any additional setup after loading the view.
    }
    
    func keyU(event:NSEvent)->NSEvent{
        guard
            let act = KeyboardActions(rawValue: event.characters ?? "") else{
                return event
        }
        
        keyboardRemovals.insert(act)
        return event
    }
    
    func keyD(event:NSEvent)->NSEvent?{
        guard
            let act = KeyboardActions(rawValue: event.characters ?? "") else {
                return event
        }
        
        keyboardActions.insert(act)
        return event
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    @objc func update() {
        
        guard !isRender else {
            return
            
        }
        isRender = true
        
        let currentTime = CACurrentMediaTime()
        let timeStep = min(maximumTimeStep, currentTime - lastFrameTime)
        let inputVector = self.inputVector
        let rotation = inputVector.x * world.player.turningSpeed * worldTimeStep
        
        let input = Input(
            speed: -inputVector.y,
            rotation: Rotation(sine: sin(rotation), cosine: cos(rotation)),
            isFiring: keyboardRemovals.contains(.space)
        )
        
        let worldSteps = (timeStep / worldTimeStep).rounded(.up)
        for _ in 0 ..< Int(worldSteps) {
            world.update(timeStep: timeStep / worldSteps, input: input)
        }
        lastFrameTime = currentTime
        
        
        var width = Int(imageView.bounds.width), height = Int(imageView.bounds.height)
        
        if width > 480 {
            height = Int(imageView.bounds.height*480/imageView.bounds.width)
            width = 480
        }
        var renderer = Renderer(width: width, height: height, textures: textures)
        
        
        if keyboardRemovals.contains(.toggleMap){
            is3D = !is3D
        }
        
        if keyboardRemovals.contains(.toggleLights){
            world.isRevealed = !world.isRevealed
        }
        
        if  is3D{
            renderer.draw(world)
        } else {
            renderer.draw2D(world)
        }
        
        imageView.image = NSImage(bitmap: renderer.bitmap)
        keyboardActions.subtract(keyboardRemovals)
        keyboardRemovals.removeAll()
        isRender = false
    }
    
    
    func setUpImageView() {
        view.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        imageView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        imageView.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        imageView.imageScaling = .scaleAxesIndependently
        imageView.imageAlignment = .alignTopLeft
        /*
         imageView.backgroundColor = .black
         imageView.layer.magnificationFilter = .nearest
         */
    }
    
    
}

