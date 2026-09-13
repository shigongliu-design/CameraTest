import SwiftUI
import UIKit
import UniformTypeIdentifiers // For UTType

extension Image {
    func asUIImage() -> UIImage? {
        // Create a UIHostingController to render the SwiftUI Image to a UIImage
        let controller = UIHostingController(rootView: self)
        // Set the view size to match the image's intrinsic content size or a reasonable default
        // For simplicity, using a fixed size here. In a real app, you might want to calculate this.
        controller.view.bounds = CGRect(origin: .zero, size: CGSize(width: 500, height: 500))
        let renderer = UIGraphicsImageRenderer(bounds: controller.view.bounds)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}
