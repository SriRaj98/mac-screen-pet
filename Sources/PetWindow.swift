import Cocoa
import SwiftUI

class PetWindow: NSPanel {
    
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.level = .statusBar
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false // false enables drag and interaction
        
        // This is key: it allows the pet to appear on all spaces/desktops
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Enable mouse tracking
        self.acceptsMouseMovedEvents = true
    }
    
    override var canBecomeKey: Bool {
        return false // Prevents the window from stealing keyboard focus
    }
    
    override var canBecomeMain: Bool {
        return false
    }
    
    // Allow dragging by clicking anywhere on the non-transparent part of the window
    func setClickThrough(_ clickThrough: Bool) {
        DispatchQueue.main.async {
            self.ignoresMouseEvents = clickThrough
        }
    }
}
