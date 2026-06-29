import SwiftUI

// Colors for the pet skins
struct PetColors {
    let primary: Color
    let secondary: Color
    let detail: Color
    let eyeColor: Color
    let noseColor: Color
    
    static func colors(for type: PetType, skin: String) -> PetColors {
        switch type {
        case .cat:
            switch skin {
            case "Calico":
                return PetColors(
                    primary: Color(red: 0.95, green: 0.95, blue: 0.93), // Creamy white
                    secondary: Color(red: 0.88, green: 0.53, blue: 0.25), // Orange
                    detail: Color(red: 0.23, green: 0.23, blue: 0.23), // Dark grey
                    eyeColor: Color(red: 0.15, green: 0.15, blue: 0.15),
                    noseColor: Color(red: 0.95, green: 0.65, blue: 0.70)
                )
            case "Black":
                return PetColors(
                    primary: Color(red: 0.15, green: 0.15, blue: 0.15), // Tuxedo body
                    secondary: Color(red: 0.95, green: 0.95, blue: 0.95), // White chest
                    detail: Color(red: 0.12, green: 0.12, blue: 0.12),
                    eyeColor: Color(red: 0.85, green: 0.80, blue: 0.15), // Green/yellow eyes
                    noseColor: Color(red: 0.95, green: 0.65, blue: 0.70)
                )
            case "Orange":
                fallthrough
            default:
                return PetColors(
                    primary: Color(red: 0.92, green: 0.58, blue: 0.23), // Orange tabby
                    secondary: Color(red: 0.98, green: 0.82, blue: 0.65), // Light cream
                    detail: Color(red: 0.82, green: 0.45, blue: 0.12), // Dark orange stripes
                    eyeColor: Color(red: 0.15, green: 0.15, blue: 0.15),
                    noseColor: Color(red: 0.95, green: 0.65, blue: 0.70)
                )
            }
            
        case .shiba:
            switch skin {
            case "Black & Tan":
                return PetColors(
                    primary: Color(red: 0.18, green: 0.18, blue: 0.18), // Dark body
                    secondary: Color(red: 0.95, green: 0.93, blue: 0.88), // Cream chest
                    detail: Color(red: 0.76, green: 0.48, blue: 0.25), // Tan details
                    eyeColor: Color(red: 0.15, green: 0.15, blue: 0.15),
                    noseColor: Color(red: 0.1, green: 0.1, blue: 0.1)
                )
            case "Red":
                fallthrough
            default:
                return PetColors(
                    primary: Color(red: 0.88, green: 0.51, blue: 0.22), // Shiba orange-brown
                    secondary: Color(red: 0.96, green: 0.94, blue: 0.91), // White chest
                    detail: Color(red: 0.70, green: 0.38, blue: 0.14),
                    eyeColor: Color(red: 0.15, green: 0.15, blue: 0.15),
                    noseColor: Color(red: 0.1, green: 0.1, blue: 0.1)
                )
            }
            
        case .fox:
            return PetColors(
                primary: Color(red: 0.88, green: 0.35, blue: 0.15), // Fox red
                secondary: Color(red: 0.96, green: 0.96, blue: 0.96), // White chest/cheeks/tail tip
                detail: Color(red: 0.15, green: 0.15, blue: 0.15), // Dark socks/ears
                eyeColor: Color(red: 0.15, green: 0.15, blue: 0.15),
                noseColor: Color(red: 0.1, green: 0.1, blue: 0.1)
            )
        }
    }
}

// Vector shapes for drawing components programmatically

struct TailShape: Shape {
    var sway: CGFloat
    
    var animatableData: CGFloat {
        get { sway }
        set { sway = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Start at bottom right of the tail bounding box (where it meets the cat's rear)
        path.move(to: CGPoint(x: rect.maxX * 0.9, y: rect.maxY * 0.9))
        
        // S-curve upwards and to the left representing a cute cat tail
        let control1 = CGPoint(
            x: rect.maxX * 0.4 + sway * rect.width * 0.1,
            y: rect.maxY * 0.65
        )
        let control2 = CGPoint(
            x: rect.minX + sway * rect.width * 0.15,
            y: rect.minY + rect.height * 0.35
        )
        let endPoint = CGPoint(
            x: rect.minX + rect.width * 0.3 + sway * rect.width * 0.25,
            y: rect.minY + rect.height * 0.15
        )
        
        path.addCurve(to: endPoint, control1: control1, control2: control2)
        return path
    }
}

struct FluffyTailShape: Shape {
    var sway: CGFloat
    
    var animatableData: CGFloat {
        get { sway }
        set { sway = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Fox/Shiba fluffy tail shape
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.8))
        
        // Upper edge
        path.addCurve(
            to: CGPoint(x: rect.maxX * 0.9, y: rect.minY + rect.height * (0.1 - sway * 0.3)),
            control1: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.minY + rect.height * 0.3),
            control2: CGPoint(x: rect.minX + rect.width * 0.7, y: rect.minY + rect.height * 0.0)
        )
        // Tip
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * (0.3 - sway * 0.3)),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        // Lower edge
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY * 0.9),
            control1: CGPoint(x: rect.maxX * 0.8, y: rect.maxY * 0.8),
            control2: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.maxY * 1.1)
        )
        path.closeSubpath()
        return path
    }
}

struct CurledTailShape: Shape {
    var wag: CGFloat
    
    var animatableData: CGFloat {
        get { wag }
        set { wag = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Curly Shiba tail
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.7))
        
        // Curl up and spiral
        path.addCurve(
            to: CGPoint(x: rect.maxX * 0.6, y: rect.minY + rect.height * (0.2 + wag * 0.1)),
            control1: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.minY + rect.height * 0.1),
            control2: CGPoint(x: rect.maxX * 1.0, y: rect.minY - rect.height * 0.1)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX * 0.3, y: rect.minY + rect.height * (0.5 + wag * 0.1)),
            control1: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.4),
            control2: CGPoint(x: rect.maxX * 0.1, y: rect.minY + rect.height * 0.7)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.maxY * 0.8),
            control1: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.maxY * 0.9),
            control2: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.maxY * 0.8)
        )
        path.closeSubpath()
        return path
    }
}

// Fish food drawing for Cat
struct FishShape: View {
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            var bodyPath = Path()
            // Body
            bodyPath.addEllipse(in: CGRect(x: rect.minX, y: rect.minY + rect.height*0.2, width: rect.width*0.7, height: rect.height*0.6))
            context.fill(bodyPath, with: .color(Color(red: 0.55, green: 0.72, blue: 0.80)))
            
            // Tail Fin
            var tailPath = Path()
            tailPath.move(to: CGPoint(x: rect.width*0.65, y: rect.height*0.5))
            tailPath.addLine(to: CGPoint(x: rect.width, y: rect.height*0.2))
            tailPath.addLine(to: CGPoint(x: rect.width*0.85, y: rect.height*0.5))
            tailPath.addLine(to: CGPoint(x: rect.width, y: rect.height*0.8))
            tailPath.closeSubpath()
            context.fill(tailPath, with: .color(Color(red: 0.45, green: 0.62, blue: 0.70)))
            
            // Eye
            var eyePath = Path()
            eyePath.addEllipse(in: CGRect(x: rect.width*0.15, y: rect.height*0.4, width: rect.width*0.08, height: rect.height*0.15))
            context.fill(eyePath, with: .color(.black))
            
            // Stripes
            var linePath = Path()
            linePath.move(to: CGPoint(x: rect.width*0.35, y: rect.height*0.25))
            linePath.addLine(to: CGPoint(x: rect.width*0.35, y: rect.height*0.75))
            linePath.move(to: CGPoint(x: rect.width*0.48, y: rect.height*0.3))
            linePath.addLine(to: CGPoint(x: rect.width*0.48, y: rect.height*0.7))
            context.stroke(linePath, with: .color(Color(red: 0.35, green: 0.52, blue: 0.60)), lineWidth: 1.5)
        }
        .frame(width: 25, height: 15)
        .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
    }
}

// Bone food drawing for Shiba/Fox
struct BoneShape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            
            // Central shaft
            var shaft = Path()
            shaft.addRoundedRect(in: CGRect(x: w*0.2, y: h*0.35, width: w*0.6, height: h*0.3), cornerSize: CGSize(width: 2, height: 2))
            context.fill(shaft, with: .color(.white))
            
            // Left knobs
            var knobLeft = Path()
            knobLeft.addEllipse(in: CGRect(x: w*0.08, y: h*0.18, width: w*0.2, height: h*0.4))
            knobLeft.addEllipse(in: CGRect(x: w*0.08, y: h*0.42, width: w*0.2, height: h*0.4))
            context.fill(knobLeft, with: .color(.white))
            
            // Right knobs
            var knobRight = Path()
            knobRight.addEllipse(in: CGRect(x: w*0.72, y: h*0.18, width: w*0.2, height: h*0.4))
            knobRight.addEllipse(in: CGRect(x: w*0.72, y: h*0.42, width: w*0.2, height: h*0.4))
            context.fill(knobRight, with: .color(.white))
        }
        .frame(width: 25, height: 15)
        .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
    }
}
