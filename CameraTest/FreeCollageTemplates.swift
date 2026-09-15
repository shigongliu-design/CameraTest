import SwiftUI

// Defines standard shapes for image masking
public enum MaskShape: String, CaseIterable, Identifiable {
    case rectangle = "Rectangle"
    case circle = "Circle"
    case triangle = "Triangle"
    case pentagon = "Pentagon"
    
    public var id: String { self.rawValue }
    
    // Returns a path for the shape, scaled to fit a given rect
    public func path(in rect: CGRect) -> Path {
        switch self {
        case .rectangle:
            return Path(rect)
        case .circle:
            return Path(ellipseIn: rect)
        case .triangle:
            return Path { path in
                path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.closeSubpath()
            }
        case .pentagon:
            return Path { path in
                let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
                let radius = min(rect.width, rect.height) / 2
                let angle = CGFloat.pi * 2 / 5
                
                let points = (0..<5).map { i -> CGPoint in
                    let currentAngle = CGFloat(i) * angle - CGFloat.pi / 2
                    return CGPoint(x: center.x + radius * cos(currentAngle),
                                   y: center.y + radius * sin(currentAngle))
                }
                path.addLines(points)
                path.closeSubpath()
            }
        }
    }
}

// Defines a collage template structure
public struct CollageTemplate: Identifiable {
    public let id = UUID()
    public let name: String
    public let shapes: [ShapeInTemplate]
}

// Defines a shape within a template, including its position and size
public struct ShapeInTemplate: Identifiable {
    public let id = UUID()
    public let shape: MaskShape
    public let frame: CGRect // Position and size relative to a 1x1 canvas
}

// Generates predefined collage templates
public func generateCollageTemplates() -> [CollageTemplate] {
    return [
        CollageTemplate(name: "Two Vertical", shapes: [
            ShapeInTemplate(shape: .rectangle, frame: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.35)),
            ShapeInTemplate(shape: .rectangle, frame: CGRect(x: 0.1, y: 0.55, width: 0.8, height: 0.35))
        ]),
        CollageTemplate(name: "Three Horizontal", shapes: [
            ShapeInTemplate(shape: .circle, frame: CGRect(x: 0.05, y: 0.3, width: 0.25, height: 0.4)),
            ShapeInTemplate(shape: .circle, frame: CGRect(x: 0.375, y: 0.3, width: 0.25, height: 0.4)),
            ShapeInTemplate(shape: .circle, frame: CGRect(x: 0.7, y: 0.3, width: 0.25, height: 0.4))
        ]),
        CollageTemplate(name: "Mixed Shapes", shapes: [
            ShapeInTemplate(shape: .triangle, frame: CGRect(x: 0.1, y: 0.1, width: 0.4, height: 0.4)),
            ShapeInTemplate(shape: .pentagon, frame: CGRect(x: 0.5, y: 0.4, width: 0.4, height: 0.5)),
            ShapeInTemplate(shape: .rectangle, frame: CGRect(x: 0.2, y: 0.6, width: 0.3, height: 0.3))
        ])
    ]
}
