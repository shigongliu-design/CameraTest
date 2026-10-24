import SwiftUI

enum SheetView: Identifiable {
    case crop(UIImage)
    case process(UIImage)
    case edit(UIImage, EditorTab)
    case erase(UIImage)

    var id: String {
        switch self {
        case .crop:
            return "crop"
        case .process:
            return "process"
        case .edit:
            return "edit"
        case .erase:
            return "erase"
        }
    }
}
