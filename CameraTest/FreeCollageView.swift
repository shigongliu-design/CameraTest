
import SwiftUI
import Combine

// --- Data Models ---

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

struct BackgroundTemplate: Identifiable, Hashable {
    let id = UUID()
    let displayName: String
    let color: Color
    let symbolName: String
}

// --- Main View ---

struct FreeCollageView: View {
    // Static list of available background templates
    private let backgroundTemplates: [BackgroundTemplate] = [
        BackgroundTemplate(displayName: "旅行", color: .blue, symbolName: "airplane"),
        BackgroundTemplate(displayName: "时尚", color: .purple, symbolName: "wand.and.stars"),
        BackgroundTemplate(displayName: "艺术", color: .indigo, symbolName: "paintpalette"),
        BackgroundTemplate(displayName: "生日", color: .pink, symbolName: "gift"),
        BackgroundTemplate(displayName: "宠物", color: .brown, symbolName: "pawprint"),
        BackgroundTemplate(displayName: "学校", color: .green, symbolName: "book"),
        BackgroundTemplate(displayName: "假日", color: .red, symbolName: "snowflake"),
    ]
    
    let selectedImagesData: [Data]
    @State private var images: [UIImage]
    @State private var placedImages: [PlacedImage] = []
    @State private var selectedBackground: BackgroundTemplate? = nil

    init(selectedImagesData: [Data]) {
        self.selectedImagesData = selectedImagesData
        _images = State(initialValue: selectedImagesData.compactMap { UIImage(data: $0) })
    }

    var body: some View {
        VStack {
            // The Canvas
            GeometryReader { geometry in
                ZStack {
                    // Layer 1: Programmatic Background
                    if let background = selectedBackground {
                        background.color.opacity(0.2)
                        Image(systemName: background.symbolName)
                            .font(.system(size: 100))
                            .foregroundColor(background.color.opacity(0.4))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Rectangle().fill(Color.gray.opacity(0.1))
                    }

                    // Layer 2: Placed Images
                    ForEach(placedImages) { placedImage in
                        Image(uiImage: placedImage.image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150)
                            .position(placedImage.position)
                    }
                }
                .cornerRadius(10)
                .clipped()
                .dropDestination(for: UIImage.self) { items, location in
                    guard let droppedImage = items.first else { return false }
                    let newPlacedImage = PlacedImage(image: droppedImage, position: location)
                    placedImages.append(newPlacedImage)
                    return true
                }
            }
            .padding()

            // Background Selector
            VStack {
                Text("选择背景").font(.caption).foregroundColor(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        Button(action: { selectedBackground = nil }) {
                            ZStack {
                                Circle().fill(Color.white).shadow(radius: 2)
                                Image(systemName: "nosign")
                            }
                            .frame(width: 60, height: 60)
                        }
                        
                        ForEach(backgroundTemplates) { template in
                            Button(action: { selectedBackground = template }) {
                                VStack {
                                    Image(systemName: template.symbolName)
                                        .font(.title2)
                                        .foregroundColor(template.color)
                                    Text(template.displayName)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 60, height: 60)
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 2)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }.frame(height: 80)

            // Photo Gallery
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
