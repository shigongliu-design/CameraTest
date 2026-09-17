
import SwiftUI
import Combine

// --- Data Model for a freely placed image ---
class PlacedImage: Identifiable, ObservableObject {
    let id = UUID()
    let image: UIImage
    @Published var position: CGPoint
    @Published var scale: CGFloat = 1.0
    @Published var rotation: Angle = .zero

    init(image: UIImage, position: CGPoint) {
        self.image = image
        self.position = position
    }
}

// --- The Main View, now a true free-form canvas ---
struct FreeCollageView: View {
    let selectedImagesData: [Data]
    @State private var images: [UIImage]
    @State private var placedImages: [PlacedImage] = []

    init(selectedImagesData: [Data]) {
        self.selectedImagesData = selectedImagesData
        _images = State(initialValue: selectedImagesData.compactMap { UIImage(data: $0) })
    }

    var body: some View {
        VStack {
            // The Canvas - now the entire ZStack is a drop target
            GeometryReader { geometry in
                ZStack {
                    // Background of the canvas
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .cornerRadius(10)

                    // Render all the images that have been placed
                    ForEach(placedImages) { placedImage in
                        Image(uiImage: placedImage.image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150) // A default size for dropped images
                            .position(placedImage.position)
                    }
                }
                .dropDestination(for: UIImage.self) { items, location in
                    guard let droppedImage = items.first else { return false }
                    // Create a new PlacedImage at the drop location and add it to our array
                    let newPlacedImage = PlacedImage(image: droppedImage, position: location)
                    placedImages.append(newPlacedImage)
                    return true
                }
            }
            .padding()

            // Photo Gallery at the bottom
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(images, id: \.self) { image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 100)
                            .cornerRadius(8)
                            .shadow(radius: 3)
                            .draggable(image)
                    }
                }
                .padding()
            }
            .frame(height: 120)
        }
        .navigationTitle("自由拼图")
        .navigationBarTitleDisplayMode(.inline)
    }
}
