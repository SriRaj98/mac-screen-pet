import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var petWindow: PetWindow!
    var viewModel: PetViewModel!
    var statusItem: NSStatusItem!
    
    // Combine cancellables
    var cancellables = Set<AnyCancellable>()
    
    // Placement overlay and food window
    var foodWindow: FoodWindow?
    var placementWindow: FoodPlacementWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Create View Model
        viewModel = PetViewModel()
        
        viewModel.onFoodEaten = { [weak self] in
            DispatchQueue.main.async {
                self?.foodWindow?.orderOut(nil)
                self?.foodWindow = nil
            }
        }
        
        viewModel.onFeedRequested = { [weak self] in
            self?.menuFeed()
        }
        
        // Listen to food positions to move the FoodWindow in real-time (supporting food gravity!)
        viewModel.$activeFood
            .receive(on: RunLoop.main)
            .sink { [weak self] foodPos in
                guard let self = self, let foodWin = self.foodWindow else { return }
                if let pos = foodPos {
                    let foodSize: CGFloat = 40
                    let centeredOrigin = CGPoint(x: pos.x - foodSize/2, y: pos.y)
                    foodWin.setFrameOrigin(centeredOrigin)
                }
            }
            .store(in: &cancellables)
        
        // 2. Create the transparent pet window
        let size = viewModel.petSize
        let contentRect = NSRect(x: 100, y: 100, width: size, height: size * 2.0)
        
        petWindow = PetWindow(contentRect: contentRect)
        viewModel.window = petWindow
        
        // 3. Set the SwiftUI View
        let hostingView = NSHostingView(rootView: PetView(viewModel: viewModel))
        petWindow.contentView = hostingView
        
        // Set initial mouse overlay state
        petWindow.setClickThrough(viewModel.clickThrough)
        
        // Move to default bottom-center screen position
        viewModel.setupPositionOnScreen()
        
        // Show pet
        petWindow.makeKeyAndOrderFront(nil)
        
        // 4. Configure system menu bar tray
        setupStatusItem()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.title = "🐾"
            // Tooltip on hover
            button.toolTip = "Screen Pet Companion"
        }
        
        // Status bar dropdown menu
        let menu = NSMenu()
        
        let feedItem = NSMenuItem(title: "Feed Companion 🐟", action: #selector(menuFeed), keyEquivalent: "f")
        feedItem.target = self
        menu.addItem(feedItem)
        
        let playItem = NSMenuItem(title: "Play Together 🎾", action: #selector(menuPlay), keyEquivalent: "p")
        playItem.target = self
        menu.addItem(playItem)
        
        let teleportItem = NSMenuItem(title: "Call Pet (Center) 📍", action: #selector(menuTeleport), keyEquivalent: "t")
        teleportItem.target = self
        menu.addItem(teleportItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let prefItem = NSMenuItem(title: "Preferences... ⚙️", action: #selector(menuPreferences), keyEquivalent: ",")
        prefItem.target = self
        menu.addItem(prefItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Screen Pet ❌", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func menuFeed() {
        // Prevent double feeding overlay
        guard foodWindow == nil && placementWindow == nil else { return }
        
        let screen = petWindow.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.frame
        
        // Spawn initial food window at cursor position
        let initialMouse = NSEvent.mouseLocation
        let foodWin = FoodWindow(type: viewModel.petType, initialLocation: initialMouse)
        self.foodWindow = foodWin
        foodWin.makeKeyAndOrderFront(nil)
        
        // Spawn cursor-tracking fullscreen overlay
        let placementWin = FoodPlacementWindow(
            screenFrame: screenFrame,
            onMoved: { [weak self] mouseLoc in
                DispatchQueue.main.async {
                    // Center the food window on the cursor
                    let foodSize: CGFloat = 40
                    let centeredOrigin = CGPoint(x: mouseLoc.x - foodSize/2, y: mouseLoc.y - foodSize/2)
                    self?.foodWindow?.setFrameOrigin(centeredOrigin)
                }
            },
            onClicked: { [weak self] clickLoc in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    // Close the overlay
                    self.placementWindow?.orderOut(nil)
                    self.placementWindow = nil
                    
                    // Drop food from current cursor coordinates (will fall under gravity)
                    self.viewModel.startFeeding(at: clickLoc)
                }
            }
        )
        self.placementWindow = placementWin
        placementWin.makeKeyAndOrderFront(nil)
    }
    
    @objc func menuPlay() {
        viewModel.playWithPet()
    }
    
    @objc func menuTeleport() {
        viewModel.teleportToCenter()
    }
    
    @objc func menuPreferences() {
        SettingsWindow.showShared(viewModel: viewModel)
    }
    
    @objc func menuQuit() {
        NSApplication.shared.terminate(nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stopTimers()
    }
}
