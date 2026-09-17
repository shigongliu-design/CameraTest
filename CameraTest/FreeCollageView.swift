
import SwiftUI
import Combine

// --- Data Models ---

class PlacedImage: Identifiable, ObservableObject {
    let id = UUID()
    let image: UIImage
    @Published var relativePosition: UnitPoint
    @Published var relativeWidth: CGFloat = 0.3
    @Published var rotation: Angle = .zero

    init(image: UIImage, relativePosition: UnitPoint) {
        self.image = image
        self.relativePosition = relativePosition
    }
}

struct BackgroundTemplate: Identifiable, Hashable {
    let id = UUID()
    let displayName: String
    let color: Color
    let symbolName: String
}

// --- Helper for saving images ---
class ImageSaver: NSObject {
    var onSuccess: () -> Void
    var onError: (Error) -> Void

    init(onSuccess: @escaping () -> Void, onError: @escaping (Error) -> Void) {
        self.onSuccess = onSuccess
        self.onError = onError
    }

    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            onError(error)
        } else {
            onSuccess()
        }
    }
}

// --- Reusable Canvas View ---
struct CanvasView: View {
    @Binding var placedImages: [PlacedImage]
    let background: BackgroundTemplate?
    let size: CGSize
    
    // Dictionary to track the drag offset for each individual image
    @State private var dragOffsets: [UUID: CGSize] = [:]

    var body: some View {
        ZStack {
            // Layer 1: Background
            if let background = background {
                background.color.opacity(0.2)
                Image(systemName: background.symbolName)
                    .font(.system(size: size.width * 0.4))
                    .foregroundColor(background.color.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.white
            }

            // Layer 2: Placed Images
            ForEach(placedImages) { placedImage in
                let dragGesture = DragGesture()
                    .onChanged { value in
                        self.dragOffsets[placedImage.id] = value.translation
                    }
                    .onEnded { value in
                        // Remove the temporary offset
                        self.dragOffsets[placedImage.id] = .zero
                        
                        // Find the index of the image being dragged
                        guard let imageIndex = self.placedImages.firstIndex(where: { $0.id == placedImage.id }) else { return }
                        
                        // Calculate the final relative position change
                        let relativeDrag = CGSize(
                            width: value.translation.width / self.size.width,
                            height: value.translation.height / self.size.height
                        )
                        
                        // Update the model's relative position
                        self.placedImages[imageIndex].relativePosition.x += relativeDrag.width
                        self.placedImages[imageIndex].relativePosition.y += relativeDrag.height
                    }

                let offset = self.dragOffsets[placedImage.id] ?? .zero
                
                Image(uiImage: placedImage.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: placedImage.relativeWidth * size.width)
                    .rotationEffect(placedImage.rotation)
                    .position(
                        x: (placedImage.relativePosition.x * self.size.width) + offset.width,
                        y: (placedImage.relativePosition.y * self.size.height) + offset.height
                    )
                    .gesture(dragGesture)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}


// --- Main Collage View ---

struct FreeCollageView: View {
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
    
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    init(selectedImagesData: [Data]) {
        self.selectedImagesData = selectedImagesData
        _images = State(initialValue: selectedImagesData.compactMap { UIImage(data: $0) })
    }

    var body: some View {
        VStack {
            GeometryReader { geometry in
                // CanvasView now needs a Binding to placedImages so it can modify it
                CanvasView(placedImages: $placedImages, background: selectedBackground, size: geometry.size)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .clipped()
                    .dropDestination(for: UIImage.self) { items, location in
                        guard let droppedImage = items.first else { return false }
                        let relativePosition = UnitPoint(
                            x: location.x / geometry.size.width,
                            y: location.y / geometry.size.height
                        )
                        let newPlacedImage = PlacedImage(image: droppedImage, relativePosition: relativePosition)
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存", action: renderAndSaveImage)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("好的")))
        }
    }
    
    @MainActor
    private func renderAndSaveImage() {
        let exportSize = CGSize(width: 1024, height: 1024)
        // We pass a copy of placedImages for rendering to avoid binding issues
        let viewToRender = CanvasView(placedImages: .constant(placedImages), background: selectedBackground, size: exportSize)

        let renderer = ImageRenderer(content: viewToRender)
        renderer.scale = 2.0
        
        guard let image = renderer.uiImage else {
            alertTitle = "错误"
            alertMessage = "无法生成图片。"
            showAlert = true
            return
        }
        
        let imageSaver = ImageSaver(
            onSuccess: {
                alertTitle = "已保存"
                alertMessage = "您的作品已成功保存到相册。"
                showAlert = true
            },
            onError: { error in
                alertTitle = "错误"
                alertMessage = "保存失败: \(error.localizedDescription)"
                showAlert = true
            }
        )
        imageSaver.writeToPhotoAlbum(image: image)
    }
}
