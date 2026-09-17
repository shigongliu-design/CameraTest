
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
    let placedImages: [PlacedImage]
    let background: BackgroundTemplate?

    var body: some View {
        ZStack {
            // Layer 1: Programmatic Background
            if let background = background {
                background.color.opacity(0.2)
                Image(systemName: background.symbolName)
                    .font(.system(size: 200))
                    .foregroundColor(background.color.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.white // Use a solid white background for export if no theme is selected
            }

            // Layer 2: Placed Images
            ForEach(placedImages) { placedImage in
                Image(uiImage: placedImage.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150 * placedImage.scale)
                    .rotationEffect(placedImage.rotation)
                    .position(placedImage.position)
            }
        }
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
    
    // State for save operation
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    init(selectedImagesData: [Data]) {
        self.selectedImagesData = selectedImagesData
        _images = State(initialValue: selectedImagesData.compactMap { UIImage(data: $0) })
    }

    var body: some View {
        VStack {
            // The Canvas
            GeometryReader { geometry in
                CanvasView(placedImages: placedImages, background: selectedBackground)
                    .background(Color.gray.opacity(0.1)) // Visual background for the editor
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
        
        let viewToRender = CanvasView(placedImages: placedImages, background: selectedBackground)
            .frame(width: 1024, height: 1024) // Define a fixed export resolution

        let renderer = ImageRenderer(content: viewToRender)
        renderer.scale = 2.0 // Render at 2x for better quality
        
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
