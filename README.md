# macOS Screen Pet 🐾

A native, interactive desktop companion for macOS that walks, jumps, sleeps, and interacts with your open windows in real-time.

---

## Features 🌟

* **Real-time Window Snapping**: The pet companion interacts directly with your open application windows (Chrome, Finder, Slack, etc.). It detects the top ledges of windows and walks along them.
* **Visibility & Occlusion Aware**: The pet is fully aware of overlapping windows. If a window ledge is partially covered by another window in front of it, the pet will only stand on the visible parts and drop down if it crosses into an occluded segment.
* **BFS-Based Stepping Stone Pathfinding**: When food is placed, the pet calculates the shortest path across multiple overlapping window ledges (treating them as steps) to climb up and reach the food.
* **Interactive Feeding (With Live Gravity)**: Drop food (fish/bone) anywhere on your screen. The food is physical—it drops from your cursor under gravity and lands on the nearest visible window ledge or the screen floor. If you drag the window out from under the food, the food falls down to the next surface.
* **Cute Animations & Skins**:
  * Customizable companion types: Cat 🐱, Shiba Inu 🐶, and Fox 🦊.
  * Various skin styles (Tuxedo, Calico, Orange Tabby, Black & Tan, etc.).
  * Smooth animations: Pendulum leg-swings, bobbing heads, wiggling tails, blushing cheeks, and floating hearts/sleep particles.
  * Cozy sleeping mode: The companion curls up flat against window bars.

---

## Getting Started 🚀

### Prerequisites
* macOS 12.0 or higher
* Swift 5.5+ / Xcode Command Line Tools installed

### Building & Running
You can compile and launch the application bundle using the provided shell build script:

1. **Open your Terminal** in the project directory:
   ```bash
   cd /Users/sriraj/.gemini/antigravity/scratch/mac-screen-pet
   ```

2. **Build and Launch** the app:
   ```bash
   ./build.sh && open build/ScreenPet.app
   ```

---

## How to Interact 🎮

* **Drag and Drop**: Click and hold the companion to drag them anywhere. If gravity is enabled, releasing the pet will drop them back down.
* **Context Menu (Right Click)**: Right-click the pet to open options:
  * **Feed 🐟**: Spawn a food drop overlay (click anywhere on screen to place).
  * **Play 🎾**: Spawn heart particles.
  * **Sleep 💤 / Wake Up ☀️**: Manually toggle sleep.
  * **Preferences**: Custom Settings menu to swap pet types, skins, gravity strengths, size, and toggle click-through behavior.
* **Status Bar Menu**: Access preferences and feeding modes from the macOS system menu bar at the top of your screen.
