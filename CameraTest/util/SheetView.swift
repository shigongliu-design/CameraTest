import SwiftUI

enum SheetView: Identifiable {
    case crop(UIImage)
    case process(Image)

    var id: String {
        switch self {
        case .crop:
            return "crop"
        case .process:
            return "process"
        }
    }
}
