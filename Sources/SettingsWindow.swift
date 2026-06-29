import Cocoa
import SwiftUI

class SettingsWindow: NSWindow {
    private static var currentInstance: SettingsWindow?
    
    static func showShared(viewModel: PetViewModel) {
        if let existing = currentInstance {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = SettingsWindow(viewModel: viewModel)
        currentInstance = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    init(viewModel: PetViewModel) {
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 490),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        
        self.title = "Screen Pet Preferences"
        self.contentView = NSHostingView(rootView: SettingsView(viewModel: viewModel))
        self.isReleasedWhenClosed = false
        self.center()
        
        // Handle window closing
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: self
        )
    }
    
    @objc private func windowWillClose() {
        SettingsWindow.currentInstance = nil
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: PetViewModel
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Text("🐾 Screen Pet Preferences")
                    .font(.title3.bold())
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Form {
                Section {
                    Picker("Pet Type", selection: $viewModel.petType) {
                        ForEach(PetType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: viewModel.petType) { newType in
                        // Set standard skin defaults on type swap
                        switch newType {
                        case .cat:
                            viewModel.skinColor = "Orange"
                        case .shiba:
                            viewModel.skinColor = "Red"
                        case .fox:
                            viewModel.skinColor = "Default"
                        }
                    }
                    
                    if viewModel.petType == .cat {
                        Picker("Coat Color", selection: $viewModel.skinColor) {
                            Text("🐱 Orange Tabby").tag("Orange")
                            Text("🐱 Calico Cream").tag("Calico")
                            Text("🐱 Tuxedo Black").tag("Black")
                        }
                    } else if viewModel.petType == .shiba {
                        Picker("Coat Color", selection: $viewModel.skinColor) {
                            Text("🐕 Red Shiba").tag("Red")
                            Text("🐕 Black & Tan").tag("Black & Tan")
                        }
                    } else if viewModel.petType == .fox {
                        Picker("Coat Color", selection: $viewModel.skinColor) {
                            Text("🦊 Classic Red").tag("Default")
                        }
                        .disabled(true)
                    }
                } header: {
                    Text("Pet Companion")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Slider(value: $viewModel.petSize, in: 60...150, step: 10) {
                            HStack {
                                Text("Size: \(Int(viewModel.petSize)) px")
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                        Text("Scale of the pet floating window on screen.")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Slider(value: $viewModel.speed, in: 1.0...5.0, step: 0.5) {
                            HStack {
                                Text("Walk Speed: \(String(format: "%.1f", viewModel.speed))")
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                } header: {
                    Text("Scale & Speed")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Toggle("Enable Gravity (Stick to Dock)", isOn: $viewModel.gravityEnabled)
                        .help("Pulls the pet down to the bottom of the screen when falling.")
                    
                    Toggle("Click-Through Mode (Overlay)", isOn: $viewModel.clickThrough)
                        .help("Clicks pass through the pet so it doesn't block window interactions.")
                } header: {
                    Text("Physics & Overlay")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            
            if viewModel.clickThrough {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.amber)
                        Text("Click-Through Enabled")
                            .font(.system(size: 11, weight: .bold))
                    }
                    Text("The pet is now click-through. To move it or change settings, click the status bar icon 🐾 at the top of your screen.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .padding(.horizontal, 20)
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("Close") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
                .frame(width: 80)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 15)
        }
        .frame(width: 380, height: 490)
    }
}

// Extra color helper for warnings
extension Color {
    static let amber = Color(red: 0.96, green: 0.65, blue: 0.14)
}
