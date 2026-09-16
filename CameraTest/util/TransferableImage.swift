import SwiftUI
import UniformTypeIdentifiers

enum TransferError: Error {
    case importFailed
}

extension UIImage: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .png) { image in
            if let data = image.pngData() {
                return data
            } else {
                return Data()
            }
        } importing: { data in
            if let image = UIImage(data: data) {
                return image
            } else {
                throw TransferError.importFailed
            }
        }
    }
}
