
import SwiftUI
import Combine

// --- Data Models ---

class PlacedImage: Identifiable, ObservableObject {
    let id = UUID()
    let image: UIImage
    // Positions and sizes are now relative to the canvas size
    @Published var relativePosition: UnitPoint
    @Published var relativeWidth: CGFloat = 0.3 // Default to 30% of canvas width
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

// --- Reusable Canvas View (now uses relative coordinates) ---
struct CanvasView: View {
    let placedImages: [PlacedImage]
    let background: BackgroundTemplate?
    let size: CGSize

    var body: some View {
        ZStack {
            // Layer 1: Programmatic Background
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
                Image(uiImage: placedImage.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: placedImage.relativeWidth * size.width)
                    .rotationEffect(placedImage.rotation)
                    .position(
                        x: placedImage.relativePosition.x * size.width,
                        y: placedImage.relativePosition.y * size.height
                    )
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
                CanvasView(placedImages: placedImages, background: selectedBackground, size: geometry.size)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .clipped()
                    .dropDestination(for: UIImage.self) { items, location in
                        guard let droppedImage = items.first else { return false }
                        // Calculate relative position on drop
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
        // IMPORTANT: For saving to work, you must add a key to Info.plist:
        // "Privacy - Photo Library Additions Usage Description" with a reason.
        
        let exportSize = CGSize(width: 1024, height: 1024)
        let viewToRender = CanvasView(placedImages: placedImages, background: selectedBackground, size: exportSize)

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
