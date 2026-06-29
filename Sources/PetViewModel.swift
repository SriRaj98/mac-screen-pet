import Foundation
import Cocoa
import SwiftUI
import Combine
import CoreGraphics

enum PetState: String, Equatable {
    case idle
    case walking
    case sleeping
    case dragging
    case falling
    case eating
}

enum Direction {
    case left
    case right
}

enum PetType: String, CaseIterable, Identifiable {
    case cat = "Cat"
    case shiba = "Shiba"
    case fox = "Fox"
    
    var id: String { self.rawValue }
}

struct ZzzBubble: Identifiable {
    let id = UUID()
    var offset: CGSize
    var opacity: Double
    var scale: CGFloat
    var birthTime: Date
}

struct HeartParticle: Identifiable {
    let id = UUID()
    var offset: CGSize
    var opacity: Double
    var scale: CGFloat
    var birthTime: Date
}

struct WindowBounds {
    let rect: NSRect
    let owner: String
}

class PetViewModel: ObservableObject {
    weak var window: PetWindow?
    
    // User Settings (Stored in UserDefaults for persistence)
    @Published var petType: PetType {
        didSet {
            UserDefaults.standard.set(petType.rawValue, forKey: "petType")
        }
    }
    @Published var petSize: CGFloat {
        didSet {
            UserDefaults.standard.set(petSize, forKey: "petSize")
            resizeWindow()
            // Force origin update to re-apply the new feetOffset
            let currentPos = self.position
            self.position = currentPos
        }
    }
    @Published var speed: CGFloat {
        didSet {
            UserDefaults.standard.set(speed, forKey: "speed")
        }
    }
    @Published var gravityEnabled: Bool {
        didSet {
            UserDefaults.standard.set(gravityEnabled, forKey: "gravityEnabled")
            if gravityEnabled && petState != .dragging {
                petState = .falling
                velocityY = 0
            }
        }
    }
    @Published var clickThrough: Bool {
        didSet {
            UserDefaults.standard.set(clickThrough, forKey: "clickThrough")
            window?.setClickThrough(clickThrough)
        }
    }
    @Published var skinColor: String {
        didSet {
            UserDefaults.standard.set(skinColor, forKey: "skinColor")
        }
    }
    
    // Live State
    @Published var petState: PetState = .idle {
        didSet {
            if petState == .sleeping {
                hearts.removeAll()
            }
        }
    }
    @Published var direction: Direction = .right
    var feetOffset: CGFloat {
        switch petType {
        case .cat:
            return petSize * 0.125
        case .shiba, .fox:
            return petSize * 0.14
        }
    }

    @Published var position: CGPoint = .zero {
        didSet {
            // Offset the visual window origin downward so the pet's feet align precisely with the ground/ledge
            DispatchQueue.main.async {
                let adjustedY = self.position.y - self.feetOffset
                self.window?.setFrameOrigin(CGPoint(x: self.position.x, y: adjustedY))
            }
        }
    }
    @Published var animationFrame: Int = 0
    @Published var zzzBubbles: [ZzzBubble] = []
    @Published var hearts: [HeartParticle] = []
    @Published var activeFood: CGPoint? = nil
    @Published var isShowingFood: Bool = false
    
    // Callbacks for window-based food placing
    var onFoodEaten: (() -> Void)?
    var onFeedRequested: (() -> Void)?
    
    // Timers
    private var physicsTimer: Timer?
    private var animationTimer: Timer?
    
    // Physics, dragging and window list cache
    private var velocityY: CGFloat = 0
    private let gravityStrength: CGFloat = 0.8
    private let bounceDamping: CGFloat = 0.3
    private var targetX: CGFloat = 0
    private var dragStartMouseLocation: NSPoint = .zero
    private var dragStartWindowOrigin: NSPoint = .zero
    private var nextBehaviorCountdown: TimeInterval = 4.0
    private var lastZzzSpawn: Date = Date()
    private var eatingDuration: TimeInterval = 0
    
    // Jump mechanics and pathfinding for higher window ledge targets
    private var jumpAttempts = 0
    private let maxJumpHeight: CGFloat = 340.0
    private var isWaitingBetweenJumps = false
    private var waitTimer: TimeInterval = 0
    private var foodPath: [CGPoint] = []
    
    // Food gravity physics
    private var foodVelocityY: CGFloat = 0
    
    // On-screen window cache to maintain <1% CPU overhead
    private var cachedWindows: [WindowBounds] = []
    private var lastWindowScanTime: Date = Date.distantPast
    
    init() {
        let savedType = UserDefaults.standard.string(forKey: "petType") ?? PetType.cat.rawValue
        self.petType = PetType(rawValue: savedType) ?? .cat
        
        let savedSize = UserDefaults.standard.double(forKey: "petSize")
        self.petSize = savedSize > 0 ? CGFloat(savedSize) : 90.0
        
        let savedSpeed = UserDefaults.standard.double(forKey: "speed")
        self.speed = savedSpeed > 0 ? CGFloat(savedSpeed) : 2.5
        
        if UserDefaults.standard.object(forKey: "gravityEnabled") != nil {
            self.gravityEnabled = UserDefaults.standard.bool(forKey: "gravityEnabled")
        } else {
            self.gravityEnabled = true
        }
        
        self.clickThrough = UserDefaults.standard.bool(forKey: "clickThrough")
        self.skinColor = UserDefaults.standard.string(forKey: "skinColor") ?? "Default"
        
        startTimers()
    }
    
    deinit {
        stopTimers()
    }
    
    func startTimers() {
        stopTimers()
        
        physicsTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.updatePhysics()
        }
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tickAnimation()
        }
    }
    
    func stopTimers() {
        physicsTimer?.invalidate()
        animationTimer?.invalidate()
    }
    
    // MARK: - Layout & Window Sizing
    
    func setupPositionOnScreen() {
        let frame = currentScreenFrame
        let startX = frame.origin.x + (frame.size.width - petSize) / 2
        let startY = frame.origin.y
        self.position = CGPoint(x: startX, y: startY)
        
        if gravityEnabled {
            self.petState = .falling
        } else {
            self.petState = .idle
        }
    }
    
    func resizeWindow() {
        DispatchQueue.main.async {
            guard let window = self.window else { return }
            let currentOrigin = window.frame.origin
            let newSize = CGSize(width: self.petSize, height: self.petSize * 2.0)
            window.setFrame(NSRect(origin: currentOrigin, size: newSize), display: true)
        }
    }
    
    var currentScreenFrame: NSRect {
        if let window = self.window {
            return window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        }
        return NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
    
    // MARK: - CoreGraphics Window Platform Scanning
    
    func getOnScreenWindows() -> [WindowBounds] {
        var windowsList: [WindowBounds] = []
        
        // Scan visible windows, excluding desktop components
        let options = CGWindowListOption([.optionOnScreenOnly, .excludeDesktopElements])
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        guard let screen = NSScreen.main else { return [] }
        let screenHeight = screen.frame.size.height
        
        for info in infoList {
            // normal application layer is 0
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else {
                continue
            }
            
            // exclude our own app's floating panel
            guard let owner = info[kCGWindowOwnerName as String] as? String, owner != "ScreenPet" else {
                continue
            }
            
            // exclude system windows
            if owner == "Dock" || owner == "Window Server" || owner == "SystemUIServer" || owner == "ControlCenter" || owner == "NotificationCenter" {
                continue
            }
            
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                continue
            }
            
            // Convert CG coordinates (Y-down) to Cocoa coordinates (Y-up)
            let cocoaRect = NSRect(
                x: rect.origin.x,
                y: screenHeight - rect.origin.y - rect.size.height,
                width: rect.size.width,
                height: rect.size.height
            )
            
            // Filter out small or invisible overlays
            if cocoaRect.size.height > 60 && cocoaRect.size.width > 60 {
                windowsList.append(WindowBounds(rect: cocoaRect, owner: owner))
            }
        }
        
        return windowsList
    }
    
    func findGroundY(for x: CGFloat, currentY: CGFloat) -> CGFloat {
        let screen = currentScreenFrame
        var highestGroundY = screen.origin.y // base desk height
        
        // Refresh cache if > 0.5s elapsed
        let now = Date()
        if now.timeIntervalSince(lastWindowScanTime) > 0.5 {
            cachedWindows = getOnScreenWindows()
            lastWindowScanTime = now
        }
        
        let petCenterX = x + petSize / 2
        
        for (i, win) in cachedWindows.enumerated() {
            let winRect = win.rect
            // Check if pet center falls horizontally inside the window bounds
            if winRect.minX <= petCenterX && petCenterX <= winRect.maxX {
                // Determine shadow offset based on application owner name to align pet perfectly flush
                let owner = win.owner.lowercased()
                var shadowOffset: CGFloat = 6.0
                if owner.contains("chrome") || owner.contains("safari") || owner.contains("finder") {
                    shadowOffset = 5.5
                } else if owner.contains("slack") || owner.contains("discord") || owner.contains("electron") || owner.contains("vscode") || owner.contains("code") || owner.contains("spotify") || owner.contains("screenpet") || owner.contains("chat") || owner.contains("gemini") || owner.contains("antigravity") || owner.contains("google") {
                    shadowOffset = 24.5
                } else {
                    shadowOffset = 12.0
                }
                
                let winTopY = winRect.maxY - shadowOffset
                
                // Land only on window tops underneath the pet's feet with minor buffer
                if winTopY <= currentY + 5.0 {
                    // Visibility Check: Ensure this point on the ledge is not occluded by any window in front
                    var isOccluded = false
                    for j in 0..<i {
                        let frontRect = cachedWindows[j].rect
                        if frontRect.minX <= petCenterX && petCenterX <= frontRect.maxX {
                            if winTopY >= frontRect.minY && winTopY < frontRect.maxY - 2.0 {
                                isOccluded = true
                                break
                            }
                        }
                    }
                    
                    if !isOccluded {
                        if winTopY > highestGroundY {
                            highestGroundY = winTopY
                        }
                    }
                }
            }
        }
        
        return highestGroundY
    }
    
    // MARK: - Window Pathfinding Node & BFS Solver
    
    private struct PlatformNode {
        let id: Int
        let y: CGFloat
        let minX: CGFloat
        let maxX: CGFloat
    }
    
    private func isPointVisible(x: CGFloat, y: CGFloat, platformNodeId: Int) -> Bool {
        guard platformNodeId > 0 && platformNodeId - 1 < cachedWindows.count else {
            return true // Screen base is always visible
        }
        let winIdx = platformNodeId - 1
        for j in 0..<winIdx {
            let frontRect = cachedWindows[j].rect
            if frontRect.minX <= x && x <= frontRect.maxX {
                if y >= frontRect.minY && y < frontRect.maxY - 2.0 {
                    return false
                }
            }
        }
        return true
    }

    private func findPathToFood(from startPos: CGPoint, to foodPos: CGPoint) -> [CGPoint] {
        let screen = currentScreenFrame
        var nodes: [PlatformNode] = []
        
        // 1. Add screen floor platform
        nodes.append(PlatformNode(id: 0, y: screen.origin.y, minX: screen.minX, maxX: screen.maxX))
        
        // 2. Add application windows as platforms
        for (index, win) in cachedWindows.enumerated() {
            nodes.append(PlatformNode(id: index + 1, y: win.rect.maxY, minX: win.rect.minX, maxX: win.rect.maxX))
        }
        
        // 3. Add target food destination platform
        let foodNodeId = nodes.count + 1
        nodes.append(PlatformNode(id: foodNodeId, y: foodPos.y, minX: foodPos.x - 20, maxX: foodPos.x + 20))
        
        // Find which platform the pet is currently standing on
        var startNodeIndex = 0
        var closestDist: CGFloat = 999999
        for (i, node) in nodes.enumerated() {
            if i == nodes.count - 1 { continue } // skip food destination node itself
            let heightDiff = abs(node.y - startPos.y)
            if heightDiff < 8.0 {
                let petCenter = startPos.x + petSize / 2
                if petCenter >= node.minX && petCenter <= node.maxX {
                    startNodeIndex = i
                    break
                }
                if heightDiff < closestDist {
                    closestDist = heightDiff
                    startNodeIndex = i
                }
            }
        }
        
        let foodNodeIndex = nodes.count - 1
        
        // BFS traversal queue
        var queue: [Int] = [startNodeIndex]
        var visited = Set<Int>([startNodeIndex])
        var parent: [Int: Int] = [:]
        
        var found = false
        while !queue.isEmpty {
            let currIdx = queue.removeFirst()
            if currIdx == foodNodeIndex {
                found = true
                break
            }
            
            let curr = nodes[currIdx]
            
            for (nextIdx, nextNode) in nodes.enumerated() {
                if visited.contains(nextIdx) { continue }
                
                // Platforms must step upwards
                let heightStep = nextNode.y - curr.y
                guard heightStep > 5.0 && heightStep <= maxJumpHeight else { continue }
                
                // Platforms must overlap horizontally within 80px gap tolerance
                let overlapMin = max(curr.minX, nextNode.minX)
                let overlapMax = min(curr.maxX, nextNode.maxX)
                
                // Check if there is at least one visible point in the overlap
                var hasVisibleOverlap = false
                if overlapMin <= overlapMax + 80.0 {
                    let testPoints = [
                        overlapMin + 5,
                        (overlapMin + overlapMax) / 2,
                        overlapMax - 5
                    ]
                    for px in testPoints {
                        if isPointVisible(x: px, y: curr.y, platformNodeId: curr.id) &&
                           isPointVisible(x: px, y: nextNode.y, platformNodeId: nextNode.id) {
                            hasVisibleOverlap = true
                            break
                        }
                    }
                }
                
                if hasVisibleOverlap {
                    visited.insert(nextIdx)
                    parent[nextIdx] = currIdx
                    queue.append(nextIdx)
                }
            }
        }
        
        guard found else {
            // No connected path: Try jumping directly (will fail if above maxJumpHeight)
            return [foodPos]
        }
        
        // Trace back path
        var pathNodeIndices: [Int] = []
        var curr = foodNodeIndex
        while let p = parent[curr] {
            pathNodeIndices.append(curr)
            curr = p
        }
        pathNodeIndices.reverse()
        
        // Map path node sequence to target coordinates
        var targets: [CGPoint] = []
        for idx in pathNodeIndices {
            let nextNode = nodes[idx]
            let currentMinX = targets.isEmpty ? nodes[startNodeIndex].minX : nodes[pathNodeIndices[pathNodeIndices.firstIndex(of: idx)! - 1]].minX
            let currentMaxX = targets.isEmpty ? nodes[startNodeIndex].maxX : nodes[pathNodeIndices[pathNodeIndices.firstIndex(of: idx)! - 1]].maxX
            
            let overlapMin = max(currentMinX, nextNode.minX)
            let overlapMax = min(currentMaxX, nextNode.maxX)
            var targetX: CGFloat = (overlapMin + overlapMax) / 2
            
            // Search for a visible X coordinate in the overlap
            let testPoints = [
                (overlapMin + overlapMax) / 2,
                overlapMin + 15,
                overlapMax - 15
            ]
            for px in testPoints {
                if isPointVisible(x: px, y: nextNode.y, platformNodeId: nextNode.id) {
                    targetX = px
                    break
                }
            }
            
            targets.append(CGPoint(x: targetX, y: nextNode.y))
        }
        
        return targets
    }
    
    // MARK: - Dragging Lifecycle
    
    func handleDragStarted() {
        guard !clickThrough else { return }
        petState = .dragging
        velocityY = 0
        dragStartMouseLocation = NSEvent.mouseLocation
        // Use logical position as starting origin to avoid double-offsetting via visual window frame
        dragStartWindowOrigin = position
    }
    
    func handleDragChanged(_ gesture: DragGesture.Value) {
        guard !clickThrough else { return }
        if petState != .dragging {
            handleDragStarted()
        }
        
        let currentMouse = NSEvent.mouseLocation
        let deltaX = currentMouse.x - dragStartMouseLocation.x
        let deltaY = currentMouse.y - dragStartMouseLocation.y
        
        let screen = currentScreenFrame
        let targetX = dragStartWindowOrigin.x + deltaX
        let targetY = dragStartWindowOrigin.y + deltaY
        
        let clampedX = max(screen.minX - petSize/2, min(targetX, screen.maxX - petSize/2))
        let clampedY = max(screen.minY, min(targetY, screen.maxY - petSize))
        
        self.position = CGPoint(x: clampedX, y: clampedY)
    }
    
    func handleDragEnded() {
        guard petState == .dragging else { return }
        if gravityEnabled {
            petState = .falling
            velocityY = 0
        } else {
            petState = .idle
        }
    }
    
    // MARK: - Physics & AI Update Loop
    
    private func startJumpingToFood() {
        guard !foodPath.isEmpty else { return }
        let targetY = foodPath[0].y
        let heightDiff = targetY - position.y
        if heightDiff <= 10.0 { return } // Already reached
        
        if isWaitingBetweenJumps { return }
        
        let reqVelocity = sqrt(2.0 * gravityStrength * heightDiff) + 2.5
        if heightDiff <= maxJumpHeight {
            velocityY = min(reqVelocity, 24.0) // Reach the platform Y
        } else {
            velocityY = 9.0 // Frustrated reach-limit jump
        }
        petState = .falling
    }
    
    private func updatePhysics() {
        let screen = currentScreenFrame
        
        updateParticles()
        
        // Update food gravity physics
        if let foodPos = activeFood {
            var nextFoodY = foodPos.y
            if gravityEnabled {
                foodVelocityY -= gravityStrength
                nextFoodY += foodVelocityY
                
                // Get ground height under the food's X
                let foodGroundY = findGroundY(for: foodPos.x - 20, currentY: foodPos.y)
                if nextFoodY <= foodGroundY {
                    nextFoodY = foodGroundY
                    foodVelocityY = 0
                }
            } else {
                foodVelocityY = 0
            }
            
            // Update published food position
            let updatedFood = CGPoint(x: foodPos.x, y: nextFoodY)
            if updatedFood != foodPos {
                self.activeFood = updatedFood
                if abs(updatedFood.y - foodPos.y) > 5.0 {
                    // Rebuild path since the platform Y shifted!
                    self.foodPath = findPathToFood(from: self.position, to: updatedFood)
                    if !self.foodPath.isEmpty {
                        self.targetX = self.foodPath[0].x - self.petSize / 2
                        self.direction = self.targetX > self.position.x ? .right : .left
                    }
                } else if !self.foodPath.isEmpty {
                    foodPath[foodPath.count - 1] = updatedFood
                }
            }
        }
        
        // Wait delay ticking between jump attempts
        if isWaitingBetweenJumps {
            waitTimer -= (1.0/30.0)
            if waitTimer <= 0 {
                isWaitingBetweenJumps = false
                startJumpingToFood()
            }
            petState = .idle
        }
        
        switch petState {
        case .falling:
            if gravityEnabled {
                velocityY -= gravityStrength
                var nextY = position.y + velocityY
                
                // Drift horizontally towards current path target during active jump
                var nextX = position.x
                if !foodPath.isEmpty {
                    let targetX = foodPath[0].x - petSize/2
                    let diffX = targetX - position.x
                    let driftSpeed = speed * 0.8
                    if abs(diffX) > 2.0 {
                        nextX += diffX > 0 ? driftSpeed : -driftSpeed
                    }
                }
                
                // Query ground under current X (includes active windows)
                let groundY = findGroundY(for: nextX, currentY: position.y)
                if nextY <= groundY {
                    nextY = groundY
                    if abs(velocityY) > 2.0 {
                        velocityY = -velocityY * bounceDamping
                    } else {
                        velocityY = 0
                        petState = .idle
                        nextBehaviorCountdown = Double.random(in: 3.0...6.0)
                        
                        // Evaluate jump landing results for path targets
                        if !foodPath.isEmpty {
                            let currentTarget = foodPath[0]
                            let newHeightDiff = currentTarget.y - nextY
                            if newHeightDiff > 10.0 {
                                // Failed jump! Try again or give up
                                jumpAttempts += 1
                                if jumpAttempts >= 2 {
                                    clearActiveFood() // vanish food and give up
                                } else {
                                    isWaitingBetweenJumps = true
                                    waitTimer = 1.0 // 1-second frustrated pause
                                }
                            } else {
                                // Landed successfully on this step of the path!
                                jumpAttempts = 0
                                foodPath.removeFirst()
                                
                                if foodPath.isEmpty {
                                    // Reached the food! Eat it!
                                    activeFood = nil
                                    isShowingFood = true
                                    petState = .eating
                                    eatingDuration = 3.0
                                } else {
                                    // Walk to next path step
                                    let nextTarget = foodPath[0]
                                    targetX = nextTarget.x - petSize / 2
                                    petState = .walking
                                    direction = targetX > position.x ? .right : .left
                                }
                            }
                        }
                    }
                }
                
                let minX = screen.minX
                let maxX = screen.maxX - petSize
                let finalX = max(minX, min(nextX, maxX))
                
                self.position = CGPoint(x: finalX, y: nextY)
            } else {
                petState = .idle
            }
            
        case .walking:
            let moveAmount = speed
            var currentX = position.x
            
            if direction == .left {
                currentX -= moveAmount
                if currentX <= screen.minX {
                    currentX = screen.minX
                    direction = .right
                    targetX = CGFloat.random(in: screen.minX + petSize...(screen.maxX - petSize))
                }
            } else {
                currentX += moveAmount
                if currentX >= screen.maxX - petSize {
                    currentX = screen.maxX - petSize
                    direction = .left
                    targetX = CGFloat.random(in: screen.minX...(screen.maxX - petSize*2))
                }
            }
            
            // Food attraction to path steps
            if !foodPath.isEmpty {
                let pathTargetX = foodPath[0].x - petSize / 2
                let diff = pathTargetX - currentX
                if abs(diff) < speed {
                    currentX = pathTargetX
                    direction = diff > 0 ? .right : .left
                } else {
                    direction = diff > 0 ? .right : .left
                }
            }
            
            // Platform gravity & walls
            if gravityEnabled {
                let nextGroundY = findGroundY(for: currentX, currentY: position.y)
                let heightDiff = nextGroundY - position.y
                
                if heightDiff > 15.0 {
                    if !foodPath.isEmpty {
                        // Walking along path and hit a wall: start jump!
                        startJumpingToFood()
                    } else {
                        // Hits a window wall: Turn around!
                        direction = (direction == .left) ? .right : .left
                        targetX = position.x
                    }
                } else if heightDiff < -10.0 {
                    if !foodPath.isEmpty && foodPath[0].y > position.y {
                        // Instead of falling off the ledge, trigger the jump to the next higher platform in our path!
                        startJumpingToFood()
                    } else {
                        // Walks off window ledge: Fall!
                        self.position.x = currentX
                        self.petState = .falling
                        self.velocityY = 0
                    }
                } else {
                    // Climbs title bars / steps smoothly
                    self.position = CGPoint(x: currentX, y: nextGroundY)
                }
            } else {
                self.position = CGPoint(x: currentX, y: position.y)
            }
            
            // Food eating and jump trigger check along path targets
            if !foodPath.isEmpty, abs(currentX - (foodPath[0].x - petSize / 2)) < moveAmount {
                let heightDiff = foodPath[0].y - position.y
                if heightDiff > 10.0 {
                    // Reached horizontal target X but it is higher: Trigger jump!
                    startJumpingToFood()
                } else {
                    // Same level! If this is the last step (the food itself):
                    if foodPath.count == 1 {
                        self.position.x = foodPath[0].x - petSize / 2
                        foodPath.removeFirst()
                        activeFood = nil
                        petState = .eating
                        eatingDuration = 3.0
                        isShowingFood = true
                    } else {
                        // Intermediate step reached! Remove it and walk to next
                        self.position.x = foodPath[0].x - petSize / 2
                        foodPath.removeFirst()
                        let nextTarget = foodPath[0]
                        targetX = nextTarget.x - petSize / 2
                        direction = targetX > position.x ? .right : .left
                    }
                }
            } else if activeFood == nil && foodPath.isEmpty && abs(currentX - targetX) < moveAmount {
                petState = .idle
                nextBehaviorCountdown = Double.random(in: 4.0...8.0)
            }
            
        case .eating:
            eatingDuration -= (1.0/30.0)
            if eatingDuration <= 0 {
                activeFood = nil
                isShowingFood = false
                petState = .idle
                nextBehaviorCountdown = Double.random(in: 3.0...6.0)
                spawnHearts(count: 3)
                onFoodEaten?() // Hide the FoodWindow
            }
            
        case .sleeping:
            let groundY = findGroundY(for: position.x, currentY: position.y)
            if gravityEnabled && position.y > groundY {
                var nextY = position.y - 2.0
                if nextY < groundY { nextY = groundY }
                self.position = CGPoint(x: position.x, y: nextY)
            }
            
            if Date().timeIntervalSince(lastZzzSpawn) > 1.5 {
                spawnZzz()
                lastZzzSpawn = Date()
            }
            
            nextBehaviorCountdown -= (1.0/30.0)
            if nextBehaviorCountdown <= 0 {
                wakeUp()
            }
            
        case .idle:
            let groundY = findGroundY(for: position.x, currentY: position.y)
            if gravityEnabled && position.y > groundY {
                var nextY = position.y - 4.0
                if nextY < groundY { nextY = groundY }
                self.position = CGPoint(x: position.x, y: nextY)
            }
            
            nextBehaviorCountdown -= (1.0/30.0)
            if nextBehaviorCountdown <= 0 {
                rollNewBehavior()
            }
            
        case .dragging:
            break
        }
    }
    
    private func updateParticles() {
        let now = Date()
        
        zzzBubbles = zzzBubbles.compactMap { bubble in
            let lifetime = now.timeIntervalSince(bubble.birthTime)
            if lifetime > 2.5 { return nil }
            
            var updated = bubble
            updated.offset.height -= 1.0
            updated.offset.width += CGFloat(sin(lifetime * 4.0) * 0.6)
            if lifetime > 1.5 {
                updated.opacity = 1.0 - (lifetime - 1.5)
            }
            updated.scale = bubble.scale + 0.005
            return updated
        }
        
        hearts = hearts.compactMap { heart in
            let lifetime = now.timeIntervalSince(heart.birthTime)
            if lifetime > 2.0 { return nil }
            
            var updated = heart
            updated.offset.height -= 1.5
            updated.offset.width += CGFloat(cos(lifetime * 5.0) * 0.8)
            if lifetime > 1.0 {
                updated.opacity = 1.0 - (lifetime - 1.0)
            }
            return updated
        }
    }
    
    private func tickAnimation() {
        animationFrame = (animationFrame + 1) % 1000
    }
    
    private func rollNewBehavior() {
        let screen = currentScreenFrame
        let roll = Double.random(in: 0...100)
        
        if activeFood != nil {
            targetX = (activeFood?.x ?? position.x) - petSize/2
            petState = .walking
            direction = targetX > position.x ? .right : .left
            return
        }
        
        if roll < 50 {
            let minX = screen.minX
            let maxX = screen.maxX - petSize
            targetX = CGFloat.random(in: minX...maxX)
            petState = .walking
            direction = targetX > position.x ? .right : .left
        } else if roll < 80 {
            petState = .idle
            nextBehaviorCountdown = Double.random(in: 3.0...7.0)
        } else {
            petState = .sleeping
            nextBehaviorCountdown = Double.random(in: 12.0...25.0)
        }
    }
    
    // MARK: - Interactions
    
    func wakeUp() {
        if petState == .sleeping {
            petState = .idle
            nextBehaviorCountdown = Double.random(in: 3.0...6.0)
            spawnHearts(count: 1)
        }
    }
    
    func forceSleep() {
        petState = .sleeping
        nextBehaviorCountdown = Double.random(in: 20.0...40.0)
    }
    
    func teleportToCenter() {
        clearActiveFood()
        let screen = currentScreenFrame
        let targetX = screen.origin.x + (screen.size.width - petSize) / 2
        let targetY = screen.origin.y + (screen.size.height) / 2
        self.position = CGPoint(x: targetX, y: targetY)
        
        if gravityEnabled {
            petState = .falling
            velocityY = 0
        } else {
            petState = .idle
        }
        spawnHearts(count: 2)
    }
    
    func feedPet() {
        onFeedRequested?() // Trigger cursor placement overlay
    }
    
    func startFeeding(at targetPosition: CGPoint) {
        activeFood = targetPosition
        isShowingFood = true
        jumpAttempts = 0
        isWaitingBetweenJumps = false
        
        // Scan windows now to build fresh map
        cachedWindows = getOnScreenWindows()
        lastWindowScanTime = Date()
        
        // Build optimal path via intermediate window platforms
        foodPath = findPathToFood(from: position, to: targetPosition)
        
        if petState == .sleeping {
            wakeUp()
        }
        
        if !foodPath.isEmpty {
            targetX = foodPath[0].x - petSize / 2
            petState = .walking
            direction = targetX > position.x ? .right : .left
        } else {
            petState = .idle
        }
    }
    
    func clearActiveFood() {
        if activeFood != nil || !foodPath.isEmpty {
            activeFood = nil
            isShowingFood = false
            foodPath.removeAll()
            jumpAttempts = 0
            isWaitingBetweenJumps = false
            onFoodEaten?()
        }
    }
    
    func playWithPet() {
        clearActiveFood()
        if petState == .sleeping {
            wakeUp()
        }
        spawnHearts(count: 5)
        
        if petState == .idle {
            petState = .falling
            velocityY = 6.0
        }
    }
    
    // MARK: - Spawning Particles
    
    private func spawnZzz() {
        let offset = CGSize(width: CGFloat.random(in: -10...10) + (direction == .right ? 20 : -20), height: -20)
        let bubble = ZzzBubble(
            offset: offset,
            opacity: 1.0,
            scale: CGFloat.random(in: 0.6...0.9),
            birthTime: Date()
        )
        zzzBubbles.append(bubble)
    }
    
    private func spawnHearts(count: Int) {
        for _ in 0..<count {
            let offset = CGSize(
                width: CGFloat.random(in: -20...20),
                height: CGFloat.random(in: -30...(-10))
            )
            let heart = HeartParticle(
                offset: offset,
                opacity: 1.0,
                scale: CGFloat.random(in: 0.7...1.2),
                birthTime: Date()
            )
            hearts.append(heart)
        }
    }
}
