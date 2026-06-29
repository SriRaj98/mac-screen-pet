import SwiftUI

struct PetView: View {
    @ObservedObject var viewModel: PetViewModel
    
    var body: some View {
        let colors = PetColors.colors(for: viewModel.petType, skin: viewModel.skinColor)
        let size = viewModel.petSize
        
        let petCenterX = size / 2
        let petCenterY = size * 1.5 // Center of pet body inside the 2.0x tall frame
        
        ZStack(alignment: .bottom) {
            // Background particles: Hearts (can float high above the head now!)
            ForEach(viewModel.hearts) { heart in
                Text("❤️")
                    .font(.system(size: 16))
                    .position(
                        x: petCenterX + heart.offset.width,
                        y: petCenterY + heart.offset.height
                    )
                    .opacity(heart.opacity)
                    .scaleEffect(heart.scale)
            }
            
            // Background particles: Zzz for sleep (can float high above the head now!)
            ForEach(viewModel.zzzBubbles) { bubble in
                Text("Z")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color.cyan.opacity(0.8))
                    .position(
                        x: petCenterX + bubble.offset.width,
                        y: petCenterY + bubble.offset.height
                    )
                    .opacity(bubble.opacity)
                    .scaleEffect(bubble.scale)
            }

            // Main Pet Body and features (Aligned at the bottom of the tall frame)
            renderPet(colors: colors)
                .scaleEffect(x: viewModel.direction == .left ? -1 : 1, y: 1) // Face direction
                .frame(width: size, height: size)
                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 3)
                .contentShape(Rectangle()) // Clickable only on the pet itself
                .gesture(
                    DragGesture(minimumDistance: 3, coordinateSpace: .global)
                        .onChanged { gesture in
                            viewModel.handleDragChanged(gesture)
                        }
                        .onEnded { _ in
                            viewModel.handleDragEnded()
                        }
                )
                .contextMenu {
                    Button("Feed 🐟") {
                        viewModel.feedPet()
                    }
                    Button("Play 🎾") {
                        viewModel.playWithPet()
                    }
                    if viewModel.petState == .sleeping {
                        Button("Wake Up ☀️") {
                            viewModel.wakeUp()
                        }
                    } else {
                        Button("Sleep 💤") {
                            viewModel.forceSleep()
                        }
                    }
                    Divider()
                    Button("Teleport to Center 📍") {
                        viewModel.teleportToCenter()
                    }
                    Divider()
                    Button("Quit ❌") {
                        NSApplication.shared.terminate(nil)
                    }
                }
        }
        .frame(width: size, height: size * 2.0, alignment: .bottom) // 2.0x height container aligned at bottom to prevent floating gaps
    }
    
    // MARK: - Pet Drawings Router
    
    @ViewBuilder
    private func renderPet(colors: PetColors) -> some View {
        switch viewModel.petType {
        case .cat:
            renderCat(colors: colors)
        case .shiba:
            renderShiba(colors: colors)
        case .fox:
            renderFox(colors: colors)
        }
    }
    
    // MARK: - Simple Leg Animation Helpers
    
    private func drawSimpleLeg(color: Color, pawColor: Color, legW: CGFloat, legH: CGFloat, angle: Double, legX: CGFloat, legY: CGFloat) -> some View {
        let pawW = legW * 1.5
        let pawH = legW * 0.95
        let pawY = legH - legW * 0.3
        
        return ZStack(alignment: .top) {
            // Straight Leg Shaft
            RoundedRectangle(cornerRadius: legW * 0.5)
                .fill(color)
                .frame(width: legW, height: legH)
            
            // Paw footprint (Horizontal ellipse pointing forward)
            Ellipse()
                .fill(pawColor)
                .frame(width: pawW, height: pawH)
                .offset(x: legW * 0.18, y: pawY)
        }
        .rotationEffect(Angle(degrees: angle), anchor: .top) // Swings like a pendulum
        .offset(x: legX, y: legY)
    }
    
    // MARK: - Cat Components
    
    private func catTail(colors: PetColors, state: PetState, tailSway: CGFloat) -> some View {
        let size = viewModel.petSize
        let w = size * 0.35
        let h = size * 0.35
        let lineWidth = size * 0.1
        let angle = state == .sleeping ? -40.0 : -10.0
        let ox = -size * 0.28
        let oy = size * 0.05
        
        return TailShape(sway: tailSway)
            .stroke(colors.primary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: w, height: h)
            .rotationEffect(Angle(degrees: angle))
            .offset(x: ox, y: oy)
    }
    
    private func catLegs(colors: PetColors, state: PetState, legAngle: Double, isFront: Bool) -> some View {
        let size = viewModel.petSize
        let legW = size * 0.08
        let legH = size * 0.25
        
        let xOffsetOffset = isFront ? size * 0.12 : -size * 0.12
        let angle1 = isFront ? legAngle : -legAngle
        let angle2 = isFront ? -legAngle : legAngle
        
        let legY = size * 0.28
        let legX1 = xOffsetOffset - size * 0.03
        let legX2 = xOffsetOffset + size * 0.03
        
        // Tuxedo skin (Black) gets cute white socks/paws!
        let isTuxedo = (viewModel.skinColor == "Black")
        let pawColor1 = isTuxedo ? colors.secondary : colors.detail
        let pawColor2 = isTuxedo ? colors.secondary : colors.primary
        
        return Group {
            if state != .sleeping {
                // Back leg
                drawSimpleLeg(color: colors.detail, pawColor: pawColor1, legW: legW, legH: legH, angle: angle1, legX: legX1, legY: legY)
                
                // Front leg
                drawSimpleLeg(color: colors.primary, pawColor: pawColor2, legW: legW, legH: legH, angle: angle2, legX: legX2, legY: legY)
            }
        }
    }
    
    private func catBody(colors: PetColors, breathScale: CGFloat, bodyRotation: Double) -> some View {
        let size = viewModel.petSize
        let bodyW = size * 0.5
        let bodyH = size * 0.35
        let radius = size * 0.2
        let ox = -size * 0.05
        let oy = viewModel.petState == .sleeping ? size * 0.22 : size * 0.1
        
        // Patch sizes
        let patchW1 = size * 0.25
        let patchH1 = size * 0.25
        let patchX1 = -size * 0.08
        let patchY1 = -size * 0.08
        
        let patchW2 = size * 0.2
        let patchH2 = size * 0.2
        let patchX2 = size * 0.08
        let patchY2 = size * 0.05
        
        let tuxW = size * 0.2
        let tuxH = size * 0.3
        let tuxX = size * 0.15
        let tuxY = size * 0.05
        
        // Collar & Bell details
        let collarW = size * 0.06
        let collarH = size * 0.20
        let collarX = size * 0.21
        let collarY = -size * 0.01
        
        let bellW = size * 0.075
        let bellH = size * 0.075
        let bellX = size * 0.23
        let bellY = size * 0.06
        
        let bellDotW = size * 0.025
        let bellDotH = size * 0.025
        let bellDotX = size * 0.23
        let bellDotY = size * 0.065
        
        return ZStack {
            // Main body shape
            RoundedRectangle(cornerRadius: radius)
                .fill(colors.primary)
                
            // Calico patch details
            if viewModel.skinColor == "Calico" {
                Circle()
                    .fill(colors.secondary)
                    .frame(width: patchW1, height: patchH1)
                    .offset(x: patchX1, y: patchY1)
                Circle()
                    .fill(colors.detail)
                    .frame(width: patchW2, height: patchH2)
                    .offset(x: patchX2, y: patchY2)
            }
            
            // Tabby stripes
            if viewModel.skinColor == "Orange" {
                Path { path in
                    let cx = bodyW / 2
                    let cy = bodyH / 2
                    path.move(to: CGPoint(x: cx - 2, y: cy - bodyH * 0.3))
                    path.addLine(to: CGPoint(x: cx - 2, y: cy + bodyH * 0.3))
                    path.move(to: CGPoint(x: cx + bodyW * 0.15, y: cy - bodyH * 0.2))
                    path.addLine(to: CGPoint(x: cx + bodyW * 0.15, y: cy + bodyH * 0.25))
                }
                .stroke(colors.detail, lineWidth: 2)
                .frame(width: bodyW, height: bodyH)
            }
            
            // Tuxedo chest
            if viewModel.skinColor == "Black" {
                Ellipse()
                    .fill(colors.secondary)
                    .frame(width: tuxW, height: tuxH)
                    .offset(x: tuxX, y: tuxY)
            }
            
            // Red Collar
            Capsule()
                .fill(Color.red)
                .frame(width: collarW, height: collarH)
                .rotationEffect(Angle(degrees: -10))
                .offset(x: collarX, y: collarY)
            
            // Golden Bell
            Circle()
                .fill(Color(red: 0.98, green: 0.82, blue: 0.15))
                .frame(width: bellW, height: bellH)
                .offset(x: bellX, y: bellY)
            
            // Bell center dot
            Circle()
                .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                .frame(width: bellDotW, height: bellDotH)
                .offset(x: bellDotX, y: bellDotY)
        }
        .frame(width: bodyW, height: bodyH)
        .scaleEffect(x: 1.0, y: breathScale, anchor: .bottom)
        .rotationEffect(Angle(degrees: bodyRotation))
        .offset(x: ox, y: oy)
    }
    
    private func catHead(colors: PetColors, frame: Int, state: PetState, headBob: CGFloat) -> some View {
        let size = viewModel.petSize
        
        let earW = size * 0.14
        let earH = size * 0.14
        let earLOffset = -size * 0.1
        let earROffset = size * 0.1
        let earY = -size * 0.2
        let earRotationRight = 15.0 + (frame % 50 == 0 ? 10.0 : 0.0)
        
        // Inner ear sizes
        let innerEarW = earW * 0.65
        let innerEarH = earH * 0.65
        let innerEarLOffset = -size * 0.1
        let innerEarROffset = size * 0.1
        let innerEarY = -size * 0.18
        
        let headW = size * 0.38
        let headH = size * 0.3
        
        let whiskerLeft = -size * 0.1
        let whiskerRight = size * 0.1
        let whiskerY1 = size * 0.02
        let whiskerY2 = size * 0.05
        let whiskerEndXLeft = -size * 0.22
        let whiskerEndXRight = size * 0.22
        let whiskerEndY1 = -size * 0.01
        let whiskerEndY2 = size * 0.06
        
        let eyeOffset = size * 0.08
        let noseY = size * 0.02
        let mouthY = size * 0.05
        
        let headX = size * 0.14
        let headY = -size * 0.06 + headBob
        
        // Blush details
        let blushW = size * 0.05
        let blushH = size * 0.03
        let blushLX = -size * 0.11
        let blushRX = size * 0.11
        let blushY = size * 0.015
        
        // Whisker pads (Peanut muzzle)
        let padW = size * 0.08
        let padH = size * 0.08
        let padLX = -size * 0.03
        let padRX = size * 0.03
        let padY = size * 0.04
        
        return ZStack {
            // Ears - Rotated around the bottom anchor to remain attached to the head curve
            Triangle()
                .fill(colors.primary)
                .frame(width: earW, height: earH)
                .rotationEffect(Angle(degrees: -15), anchor: .bottom)
                .offset(x: earLOffset, y: earY)
            
            // Left Inner Ear (Pink)
            Triangle()
                .fill(colors.noseColor)
                .frame(width: innerEarW, height: innerEarH)
                .rotationEffect(Angle(degrees: -15), anchor: .bottom)
                .offset(x: innerEarLOffset, y: innerEarY)
            
            Triangle()
                .fill(colors.primary)
                .frame(width: earW, height: earH)
                .rotationEffect(Angle(degrees: earRotationRight), anchor: .bottom)
                .offset(x: earROffset, y: earY)
                
            // Right Inner Ear (Pink)
            Triangle()
                .fill(colors.noseColor)
                .frame(width: innerEarW, height: innerEarH)
                .rotationEffect(Angle(degrees: earRotationRight), anchor: .bottom)
                .offset(x: innerEarROffset, y: innerEarY)
            
            // Head shape
            Ellipse()
                .fill(colors.primary)
                .frame(width: headW, height: headH)
            
            // Rosy cheeks (Blush)
            Ellipse()
                .fill(Color.red.opacity(0.28))
                .frame(width: blushW, height: blushH)
                .offset(x: blushLX, y: blushY)
            Ellipse()
                .fill(Color.red.opacity(0.28))
                .frame(width: blushW, height: blushH)
                .offset(x: blushRX, y: blushY)
            
            // Whisker pads
            Circle()
                .fill(colors.secondary)
                .frame(width: padW, height: padH)
                .offset(x: padLX, y: padY)
            Circle()
                .fill(colors.secondary)
                .frame(width: padW, height: padH)
                .offset(x: padRX, y: padY)
            
            // Face details: Whiskers (drawn relative to the center of the head shape)
            Path { path in
                let cx = headW / 2
                let cy = headH / 2
                
                path.move(to: CGPoint(x: cx + whiskerLeft, y: cy + whiskerY1))
                path.addLine(to: CGPoint(x: cx + whiskerEndXLeft, y: cy + whiskerEndY1))
                path.move(to: CGPoint(x: cx + whiskerLeft, y: cy + whiskerY2))
                path.addLine(to: CGPoint(x: cx + whiskerEndXLeft, y: cy + whiskerEndY2))
                
                path.move(to: CGPoint(x: cx + whiskerRight, y: cy + whiskerY1))
                path.addLine(to: CGPoint(x: cx + whiskerEndXRight, y: cy + whiskerEndY1))
                path.move(to: CGPoint(x: cx + whiskerRight, y: cy + whiskerY2))
                path.addLine(to: CGPoint(x: cx + whiskerEndXRight, y: cy + whiskerEndY2))
            }
            .stroke(colors.eyeColor.opacity(0.35), lineWidth: 1.2)
            .frame(width: headW, height: headH)
            
            // Eyes
            renderEyes(colors: colors, state: state, frame: frame, eyeOffset: eyeOffset)
            
            // Nose (layered on top of pads)
            Circle()
                .fill(colors.noseColor)
                .frame(width: 4, height: 3)
                .offset(y: noseY)
            
            // Mouth
            Path { path in
                let cx = headW / 2
                let cy = headH / 2
                let mouthCtrlY = cy + size * 0.06
                path.move(to: CGPoint(x: cx - 2, y: cy + mouthY))
                path.addQuadCurve(to: CGPoint(x: cx, y: mouthCtrlY), control: CGPoint(x: cx - 1, y: mouthCtrlY))
                path.addQuadCurve(to: CGPoint(x: cx + 2, y: cy + mouthY), control: CGPoint(x: cx + 1, y: mouthCtrlY))
            }
            .stroke(colors.eyeColor.opacity(0.6), lineWidth: 1.2)
            .frame(width: headW, height: headH)
        }
        .offset(x: headX, y: headY)
    }
    
    @ViewBuilder
    private func renderCat(colors: PetColors) -> some View {
        let frame = viewModel.animationFrame
        let state = viewModel.petState
        let (breathScale, legAngle, tailSway, headBob, bodyRotation) = getAnimationMetrics(frame: frame, state: state)
        
        ZStack {
            catTail(colors: colors, state: state, tailSway: tailSway)
            catLegs(colors: colors, state: state, legAngle: legAngle, isFront: false)
            catBody(colors: colors, breathScale: breathScale, bodyRotation: bodyRotation)
            catLegs(colors: colors, state: state, legAngle: legAngle, isFront: true)
            catHead(colors: colors, frame: frame, state: state, headBob: headBob)
        }
    }
    
    // MARK: - Shiba Components
    
    private func shibaTail(colors: PetColors, tailSway: CGFloat) -> some View {
        let size = viewModel.petSize
        let w = size * 0.25
        let h = size * 0.25
        let ox = -size * 0.24
        let oy = -size * 0.08
        
        return CurledTailShape(wag: tailSway)
            .fill(colors.primary)
            .frame(width: w, height: h)
            .offset(x: ox, y: oy)
    }
    
    private func shibaLegs(colors: PetColors, state: PetState, legAngle: Double, isFront: Bool) -> some View {
        let size = viewModel.petSize
        let legW = size * 0.09
        let legH = size * 0.26
        
        let xOffset = isFront ? size * 0.12 : -size * 0.12
        let angle1 = isFront ? legAngle : -legAngle
        let angle2 = isFront ? -legAngle : legAngle
        
        let legY = size * 0.26
        let legX1 = xOffset - size * 0.03
        let legX2 = xOffset + size * 0.03
        
        // Shiba always has white socks/paws!
        let pawColor = colors.secondary
        
        return Group {
            if state != .sleeping {
                // Back leg
                drawSimpleLeg(color: colors.primary.opacity(0.85), pawColor: pawColor, legW: legW, legH: legH, angle: angle1, legX: legX1, legY: legY)
                
                // Front leg
                drawSimpleLeg(color: colors.primary, pawColor: pawColor, legW: legW, legH: legH, angle: angle2, legX: legX2, legY: legY)
            }
        }
    }
    
    private func shibaBody(colors: PetColors, breathScale: CGFloat, bodyRotation: Double) -> some View {
        let size = viewModel.petSize
        let bodyW = size * 0.52
        let bodyH = size * 0.36
        let radius = size * 0.16
        let ox = -size * 0.05
        let oy = viewModel.petState == .sleeping ? size * 0.21 : size * 0.09
        let bellyW = size * 0.3
        let bellyH = size * 0.24
        let bellyX = size * 0.08
        let bellyY = size * 0.04
        
        return ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(colors.primary)
            
            // White belly patch
            Ellipse()
                .fill(colors.secondary)
                .frame(width: bellyW, height: bellyH)
                .offset(x: bellyX, y: bellyY)
        }
        .frame(width: bodyW, height: bodyH)
        .scaleEffect(x: 1.0, y: breathScale, anchor: .bottom)
        .rotationEffect(Angle(degrees: bodyRotation))
        .offset(x: ox, y: oy)
    }
    
    private func shibaHead(colors: PetColors, frame: Int, state: PetState, headBob: CGFloat) -> some View {
        let size = viewModel.petSize
        let earW = size * 0.13
        let earH = size * 0.15
        let earLX = -size * 0.08
        let earRX = size * 0.09
        let earY = -size * 0.22
        
        let headW = size * 0.38
        let headH = size * 0.32
        
        let cheekW = size * 0.34
        let cheekH = size * 0.2
        let cheekY = size * 0.04
        
        let eyebrowX = size * 0.07
        let eyebrowY = -size * 0.08
        
        let eyeOffset = size * 0.07
        
        let muzzleW = size * 0.16
        let muzzleH = size * 0.12
        let muzzleY = size * 0.05
        let noseY = size * 0.03
        let mouthY = size * 0.06
        
        let headX = size * 0.15
        let headY = -size * 0.06 + headBob
        
        return ZStack {
            // Ears - Rotated around the bottom anchor to remain attached to the head curve
            Triangle()
                .fill(colors.primary)
                .frame(width: earW, height: earH)
                .rotationEffect(Angle(degrees: -10), anchor: .bottom)
                .offset(x: earLX, y: earY)
            
            Triangle()
                .fill(colors.primary)
                .frame(width: earW, height: earH)
                .rotationEffect(Angle(degrees: 10), anchor: .bottom)
                .offset(x: earRX, y: earY)
            
            // Head
            Ellipse()
                .fill(colors.primary)
                .frame(width: headW, height: headH)
            
            // White cheeks
            Ellipse()
                .fill(colors.secondary)
                .frame(width: cheekW, height: cheekH)
                .offset(y: cheekY)
            
            // Eyebrow spots
            if viewModel.skinColor == "Black & Tan" {
                Circle()
                    .fill(colors.detail)
                    .frame(width: 5, height: 5)
                    .offset(x: -eyebrowX, y: eyebrowY)
                Circle()
                    .fill(colors.detail)
                    .frame(width: 5, height: 5)
                    .offset(x: eyebrowX, y: eyebrowY)
            }
            
            // Eyes
            renderEyes(colors: colors, state: state, frame: frame, eyeOffset: eyeOffset)
            
            // Muzzle
            Ellipse()
                .fill(colors.secondary)
                .frame(width: muzzleW, height: muzzleH)
                .offset(y: muzzleY)
            
            Circle()
                .fill(colors.noseColor)
                .frame(width: 5, height: 4)
                .offset(y: noseY)
            
            Path { path in
                let cx = headW / 2
                let cy = headH / 2
                let mouthCtrlY = cy + size * 0.08
                path.move(to: CGPoint(x: cx - 3, y: cy + mouthY))
                path.addQuadCurve(to: CGPoint(x: cx, y: mouthCtrlY), control: CGPoint(x: cx - 1.5, y: mouthCtrlY))
                path.addQuadCurve(to: CGPoint(x: cx + 3, y: cy + mouthY), control: CGPoint(x: cx + 1.5, y: mouthCtrlY))
            }
            .stroke(colors.eyeColor.opacity(0.6), lineWidth: 1.2)
            .frame(width: headW, height: headH)
        }
        .offset(x: headX, y: headY)
    }
    
    @ViewBuilder
    private func renderShiba(colors: PetColors) -> some View {
        let frame = viewModel.animationFrame
        let state = viewModel.petState
        let (breathScale, legAngle, tailSway, headBob, bodyRotation) = getAnimationMetrics(frame: frame, state: state)
        
        ZStack {
            shibaTail(colors: colors, tailSway: tailSway)
            shibaLegs(colors: colors, state: state, legAngle: legAngle, isFront: false)
            shibaBody(colors: colors, breathScale: breathScale, bodyRotation: bodyRotation)
            shibaLegs(colors: colors, state: state, legAngle: legAngle, isFront: true)
            shibaHead(colors: colors, frame: frame, state: state, headBob: headBob)
        }
    }
    
    // MARK: - Fox Components
    
    private func foxTail(colors: PetColors, tailSway: CGFloat) -> some View {
        let size = viewModel.petSize
        let tailW = size * 0.42
        let tailH = size * 0.28
        let tipW = size * 0.15
        let tipH = size * 0.1
        let ox = -size * 0.32
        let oy = size * 0.02
        
        return ZStack {
            FluffyTailShape(sway: tailSway)
                .fill(colors.primary)
                .frame(width: tailW, height: tailH)
                .offset(x: ox, y: oy)
            
            // White tail tip
            FluffyTailShape(sway: tailSway)
                .fill(colors.secondary)
                .frame(width: tipW, height: tipH)
                .offset(x: ox, y: oy)
                .mask(
                    FluffyTailShape(sway: tailSway)
                        .frame(width: tailW, height: tailH)
                        .offset(x: ox, y: oy)
                )
        }
    }
    
    private func foxLegs(colors: PetColors, state: PetState, legAngle: Double, isFront: Bool) -> some View {
        let size = viewModel.petSize
        let legW = size * 0.08
        let legH = size * 0.26
        
        let xOffset = isFront ? size * 0.12 : -size * 0.12
        let angle1 = isFront ? legAngle : -legAngle
        let angle2 = isFront ? -legAngle : legAngle
        
        let legY = size * 0.26
        let legX1 = xOffset - size * 0.03
        let legX2 = xOffset + size * 0.03
        
        // Fox has dark paws/socks (colors.detail)
        let pawColor = colors.detail
        
        return Group {
            if state != .sleeping {
                drawSimpleLeg(color: colors.primary, pawColor: pawColor, legW: legW, legH: legH, angle: angle1, legX: legX1, legY: legY)
                drawSimpleLeg(color: colors.primary, pawColor: pawColor, legW: legW, legH: legH, angle: angle2, legX: legX2, legY: legY)
            }
        }
    }
    
    private func foxBody(colors: PetColors, breathScale: CGFloat, bodyRotation: Double) -> some View {
        let size = viewModel.petSize
        let bodyW = size * 0.54
        let bodyH = size * 0.33
        let radius = size * 0.14
        let ox = -size * 0.05
        let oy = viewModel.petState == .sleeping ? size * 0.21 : size * 0.09
        let chestW = size * 0.22
        let chestH = size * 0.25
        let chestX = size * 0.13
        let chestY = size * 0.03
        
        return ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(colors.primary)
            // White chest layer
            Ellipse()
                .fill(colors.secondary)
                .frame(width: chestW, height: chestH)
                .offset(x: chestX, y: chestY)
        }
        .frame(width: bodyW, height: bodyH)
        .scaleEffect(x: 1.0, y: breathScale, anchor: .bottom)
        .rotationEffect(Angle(degrees: bodyRotation))
        .offset(x: ox, y: oy)
    }
    
    private func foxHead(colors: PetColors, frame: Int, state: PetState, headBob: CGFloat) -> some View {
        let size = viewModel.petSize
        let earW = size * 0.14
        let earH = size * 0.2
        let earLX = -size * 0.09
        let earRX = size * 0.10
        let earY = -size * 0.23
        let tipW = size * 0.12
        let tipH = size * 0.08
        let tipY = -size * 0.06
        
        let headW = size * 0.38
        let headH = size * 0.3
        
        let cheekW = size * 0.34
        let cheekH = size * 0.18
        let cheekY = size * 0.04
        
        let eyeOffset = size * 0.07
        let muzzleW = size * 0.04
        let muzzleY = size * 0.04
        let muzzleY2 = size * 0.14
        
        let noseY = size * 0.12
        
        let headX = size * 0.15
        let headY = -size * 0.06 + headBob
        
        return ZStack {
            // Left Ear - Rotated around the bottom anchor to remain attached to the head curve
            ZStack {
                Triangle()
                    .fill(colors.primary)
                Triangle()
                    .fill(colors.detail)
                    .frame(width: tipW, height: tipH)
                    .offset(y: tipY)
            }
            .frame(width: earW, height: earH)
            .rotationEffect(Angle(degrees: -15), anchor: .bottom)
            .offset(x: earLX, y: earY)
            
            // Right Ear - Rotated around the bottom anchor to remain attached to the head curve
            ZStack {
                Triangle()
                    .fill(colors.primary)
                Triangle()
                    .fill(colors.detail)
                    .frame(width: tipW, height: tipH)
                    .offset(y: tipY)
            }
            .frame(width: earW, height: earH)
            .rotationEffect(Angle(degrees: 15), anchor: .bottom)
            .offset(x: earRX, y: earY)
            
            // Head
            Ellipse()
                .fill(colors.primary)
                .frame(width: headW, height: headH)
            
            // White cheeks
            Ellipse()
                .fill(colors.secondary)
                .frame(width: cheekW, height: cheekH)
                .offset(y: cheekY)
            
            // Eyes
            renderEyes(colors: colors, state: state, frame: frame, eyeOffset: eyeOffset)
            
            // Muzzle
            Path { path in
                let cx = headW / 2
                let cy = headH / 2
                path.move(to: CGPoint(x: cx - muzzleW, y: cy + muzzleY))
                path.addLine(to: CGPoint(x: cx, y: cy + muzzleY2))
                path.addLine(to: CGPoint(x: cx + muzzleW, y: cy + muzzleY))
                path.closeSubpath()
            }
            .fill(colors.secondary)
            .frame(width: headW, height: headH)
            
            Circle()
                .fill(colors.noseColor)
                .frame(width: 4, height: 4)
                .offset(y: noseY)
        }
        .offset(x: headX, y: headY)
    }
    
    @ViewBuilder
    private func renderFox(colors: PetColors) -> some View {
        let frame = viewModel.animationFrame
        let state = viewModel.petState
        let (breathScale, legAngle, tailSway, headBob, bodyRotation) = getAnimationMetrics(frame: frame, state: state)
        
        ZStack {
            foxTail(colors: colors, tailSway: tailSway)
            foxLegs(colors: colors, state: state, legAngle: legAngle, isFront: false)
            foxBody(colors: colors, breathScale: breathScale, bodyRotation: bodyRotation)
            foxLegs(colors: colors, state: state, legAngle: legAngle, isFront: true)
            foxHead(colors: colors, frame: frame, state: state, headBob: headBob)
        }
    }
    
    // MARK: - Shared Eye Renderer
    
    @ViewBuilder
    private func renderEyes(colors: PetColors, state: PetState, frame: Int, eyeOffset: CGFloat) -> some View {
        let yOffset = -viewModel.petSize * 0.03
        
        if state == .sleeping {
            let sleepYOffset = -viewModel.petSize * 0.02
            HStack(spacing: eyeOffset) {
                Path { path in
                    path.addArc(center: CGPoint(x: 0, y: 0), radius: 3, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                }
                .stroke(colors.eyeColor, lineWidth: 1.5)
                .frame(width: 6, height: 3)
                
                Path { path in
                    path.addArc(center: CGPoint(x: 0, y: 0), radius: 3, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                }
                .stroke(colors.eyeColor, lineWidth: 1.5)
                .frame(width: 6, height: 3)
            }
            .offset(y: sleepYOffset)
        } else if state == .dragging || state == .falling {
            HStack(spacing: eyeOffset * 0.7) {
                ZStack {
                    Circle().fill(Color.white).frame(width: 10, height: 10)
                    Circle().fill(colors.eyeColor).frame(width: 5, height: 5)
                }
                ZStack {
                    Circle().fill(Color.white).frame(width: 10, height: 10)
                    Circle().fill(colors.eyeColor).frame(width: 5, height: 5)
                }
            }
            .offset(y: yOffset)
        } else {
            let isBlinking = (frame % 80 < 4)
            
            HStack(spacing: eyeOffset) {
                if isBlinking {
                    Rectangle()
                        .fill(colors.eyeColor)
                        .frame(width: 6, height: 1.5)
                    Rectangle()
                        .fill(colors.eyeColor)
                        .frame(width: 6, height: 1.5)
                } else {
                    Circle()
                        .fill(colors.eyeColor)
                        .frame(width: 5, height: 5)
                    Circle()
                        .fill(colors.eyeColor)
                        .frame(width: 5, height: 5)
                }
            }
            .offset(y: yOffset)
        }
    }
    
    // MARK: - Animation Engine
    
    private func getAnimationMetrics(frame: Int, state: PetState) -> (breathScale: CGFloat, legAngle: Double, tailSway: CGFloat, headBob: CGFloat, bodyRotation: Double) {
        var breathScale: CGFloat = 1.0
        var legAngle: Double = 0.0
        var tailSway: CGFloat = 0.0
        var headBob: CGFloat = 0.0
        var bodyRotation: Double = 0.0
        
        let size = viewModel.petSize
        
        switch state {
        case .idle:
            breathScale = 1.0 + CGFloat(sin(Double(frame) * 0.2)) * 0.02
            tailSway = CGFloat(sin(Double(frame) * 0.1)) * 0.4
            
        case .walking:
            legAngle = sin(Double(frame) * 0.6) * 24.0
            tailSway = CGFloat(sin(Double(frame) * 0.5)) * 0.8
            headBob = CGFloat(abs(sin(Double(frame) * 0.3))) * size * 0.04
            
        case .sleeping:
            breathScale = 1.0 + CGFloat(sin(Double(frame) * 0.1)) * 0.015
            tailSway = -0.2
            headBob = size * 0.03
            bodyRotation = 4.0
            
        case .dragging:
            legAngle = 5.0
            tailSway = -0.6
            headBob = -size * 0.04
            bodyRotation = -15.0
            
        case .falling:
            legAngle = sin(Double(frame) * 0.9) * 35.0
            tailSway = CGFloat(sin(Double(frame) * 0.8)) * 0.8
            headBob = -size * 0.02
            bodyRotation = 10.0
            
        case .eating:
            legAngle = 0.0
            tailSway = CGFloat(sin(Double(frame) * 0.3)) * 0.3
            let chew = sin(Double(frame) * 0.8)
            headBob = CGFloat(chew > 0 ? chew * size * 0.08 : 0.0)
        }
        
        return (breathScale, legAngle, tailSway, headBob, bodyRotation)
    }
}

// Simple Triangle Shape helper for ears
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
