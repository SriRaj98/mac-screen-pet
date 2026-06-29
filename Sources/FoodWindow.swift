import Cocoa
import SwiftUI

// A transparent, borderless floating window for the food item (fish or bone)
class FoodWindow: NSPanel {
    init(type: PetType, initialLocation: NSPoint) {
        super.init(
            contentRect: NSRect(origin: initialLocation, size: CGSize(width: 40, height: 40)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.level = .statusBar
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.ignoresMouseEvents = true // Click-through so it doesn't block actions
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let hostingView: NSHostingView<AnyView>
        if type == .cat {
            hostingView = NSHostingView(rootView: AnyView(FishShape()))
        } else {
            hostingView = NSHostingView(rootView: AnyView(BoneShape()))
        }
        self.contentView = hostingView
    }
}

// A fullscreen transparent capture overlay window to follow mouse and catch click
class FoodPlacementWindow: NSPanel {
    private var placementView: FoodPlacementNSView!
    
    init(screenFrame: NSRect, onMoved: @escaping (NSPoint) -> Void, onClicked: @escaping (NSPoint) -> Void) {
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.level = .statusBar + 1 // Sits above normal pet window
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false // Intercept click!
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let view = FoodPlacementNSView(onMoved: onMoved, onClicked: onClicked)
        view.frame = NSRect(origin: .zero, size: screenFrame.size)
        self.contentView = view
    }
}

// Custom NSView capturing mouse tracking and mouse clicks
class FoodPlacementNSView: NSView {
    var onMoved: (NSPoint) -> Void
    var onClicked: (NSPoint) -> Void
    
    init(onMoved: @escaping (NSPoint) -> Void, onClicked: @escaping (NSPoint) -> Void) {
        self.onMoved = onMoved
        self.onClicked = onClicked
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            // Setup tracking area for cursor updates
            let trackingArea = NSTrackingArea(
                rect: bounds,
                options: [.activeAlways, .mouseMoved, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(trackingArea)
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        // Cocoa window location (origin at bottom-left)
        let screenPoint = event.locationInWindow
        onMoved(screenPoint)
    }
    
    override func mouseDown(with event: NSEvent) {
        let screenPoint = event.locationInWindow
        onClicked(screenPoint)
    }
}
