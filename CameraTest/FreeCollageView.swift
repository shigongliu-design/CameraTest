
import SwiftUI
import Combine

// --- Data Models ---

class PlacedImage: Identifiable, ObservableObject {
    let id = UUID()
    let image: UIImage
    @Published var relativePosition: UnitPoint
    @Published var relativeWidth: CGFloat = 0.3
    @Published var rotation: Angle = .zero
    @Published var shape: CollageShape = .rectangle

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

enum CollageShape: String, CaseIterable, Identifiable {
    case rectangle = "square.on.square"
    case circle = "circle"
    case star = "star"
    case heart = "heart"
    case hexagon = "hexagon"
    var id: String { self.rawValue }
}

// --- Shape Definitions and Type Erasure ---

struct AnyShape: Shape {
    private let _path: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        self._path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        return self._path(rect)
    }
}

struct Star: Shape {
    let points: Int
    let smoothness: CGFloat

    func path(in rect: CGRect) -> Path {
        guard points >= 2 else { return Path() }
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * smoothness
        var path = Path()
        let angleIncrement = .pi * 2 / CGFloat(points)
        for i in 0..<points {
            let angle = CGFloat(i) * angleIncrement - .pi / 2
            let point = CGPoint(x: center.x + outerRadius * cos(angle), y: center.y + outerRadius * sin(angle))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            let innerAngle = angle + angleIncrement / 2
            let innerPoint = CGPoint(x: center.x + innerRadius * cos(innerAngle), y: center.y + innerRadius * sin(innerAngle))
            path.addLine(to: innerPoint)
        }
        path.closeSubpath()
        return path
    }
}

struct Heart: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.height * 0.25), control1: CGPoint(x: rect.midX - rect.width * 0.4, y: rect.height * 0.8), control2: CGPoint(x: rect.minX, y: rect.height * 0.5))
        path.addArc(center: CGPoint(x: rect.width * 0.25, y: rect.height * 0.25), radius: rect.width * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addArc(center: CGPoint(x: rect.width * 0.75, y: rect.height * 0.25), radius: rect.width * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control1: CGPoint(x: rect.maxX, y: rect.height * 0.5), control2: CGPoint(x: rect.midX + rect.width * 0.4, y: rect.height * 0.8))
        path.closeSubpath()
        return path
    }
}

struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let points = (0..<6).map { i -> CGPoint in
            let angle = .pi / 3 * CGFloat(i)
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}

// --- Image Saving Helper ---
class ImageSaver: NSObject {
    var onSuccess: () -> Void
    var onError: (Error) -> Void
    init(onSuccess: @escaping () -> Void, onError: @escaping (Error) -> Void) {
        self.onSuccess = onSuccess
        self.onError = onError
    }
    func writeToPhotoAlbum(image: UIImage) { UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil) }
    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error { onError(error) } else { onSuccess() }
    }
}

// --- Reusable Canvas View ---
struct CanvasView: View {
    @Binding var placedImages: [PlacedImage]
    @Binding var selectedImageId: UUID?
    let background: BackgroundTemplate?
    let size: CGSize
    
    @State private var dragOffsets: [UUID: CGSize] = [:]
    @State private var rotations: [UUID: Angle] = [:]
    @State private var scales: [UUID: CGFloat] = [:]

    private func shape(for collageShape: CollageShape) -> AnyShape {
        switch collageShape {
        case .rectangle: return AnyShape(Rectangle())
        case .circle:    return AnyShape(Circle())
        case .star:      return AnyShape(Star(points: 5, smoothness: 0.4))
        case .heart:     return AnyShape(Heart())
        case .hexagon:   return AnyShape(Hexagon())
        }
    }

    var body: some View {
        ZStack {
            if let background = background {
                background.color.opacity(0.2)
                Image(systemName: background.symbolName).font(.system(size: size.width * 0.4)).foregroundColor(background.color.opacity(0.3)).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.white
            }

            ForEach(Array(placedImages.enumerated()), id: \.element.id) { imageIndex, placedImage in
                let dragGesture = DragGesture()
                    .onChanged { self.dragOffsets[placedImage.id] = $0.translation }
                    .onEnded { value in
                        let relativeDrag = CGSize(width: value.translation.width / self.size.width, height: value.translation.height / self.size.height)
                        self.placedImages[imageIndex].relativePosition.x += relativeDrag.width
                        self.placedImages[imageIndex].relativePosition.y += relativeDrag.height
                        self.dragOffsets[placedImage.id] = .zero
                    }

                let rotationGesture = RotationGesture()
                    .onChanged { self.rotations[placedImage.id] = $0 }
                    .onEnded { value in self.placedImages[imageIndex].rotation += value; self.rotations[placedImage.id] = .zero }

                let magnificationGesture = MagnificationGesture()
                    .onChanged { self.scales[placedImage.id] = $0 }
                    .onEnded { value in self.placedImages[imageIndex].relativeWidth *= value; self.scales[placedImage.id] = 1.0 }
                
                let combinedGesture = dragGesture.simultaneously(with: rotationGesture.simultaneously(with: magnificationGesture))
                let dragOffset = self.dragOffsets[placedImage.id] ?? .zero
                let rotationAngle = self.rotations[placedImage.id] ?? .zero
                let scaleEffect = self.scales[placedImage.id] ?? 1.0
                
                Image(uiImage: placedImage.image)
                    .resizable().scaledToFill()
                    .frame(width: (placedImage.relativeWidth * self.size.width) * scaleEffect, height: (placedImage.relativeWidth * self.size.width) * scaleEffect)
                    .clipShape(shape(for: placedImage.shape))
                    .rotationEffect(placedImage.rotation + rotationAngle)
                    .overlay(shape(for: placedImage.shape).stroke(Color.blue, lineWidth: selectedImageId == placedImage.id ? 3 : 0))
                    .position(x: (placedImage.relativePosition.x * self.size.width) + dragOffset.width, y: (placedImage.relativePosition.y * self.size.height) + dragOffset.height)
                    .gesture(combinedGesture)
                    .onTapGesture { selectedImageId = placedImage.id }
            }
        }
        .frame(width: size.width, height: size.height)
        .onTapGesture { selectedImageId = nil }
    }
}

// --- Main Collage View ---
struct FreeCollageView: View {
    private let backgroundTemplates: [BackgroundTemplate] = [
        .init(displayName: "旅行", color: .blue, symbolName: "airplane"),
        .init(displayName: "时尚", color: .purple, symbolName: "wand.and.stars"),
        .init(displayName: "艺术", color: .indigo, symbolName: "paintpalette"),
        .init(displayName: "生日", color: .pink, symbolName: "gift"),
        .init(displayName: "宠物", color: .brown, symbolName: "pawprint"),
        .init(displayName: "学校", color: .green, symbolName: "book"),
        .init(displayName: "假日", color: .red, symbolName: "snowflake"),
    ]
    
    let selectedImagesData: [Data]
    @State private var images: [UIImage]
    @State private var placedImages: [PlacedImage] = []
    @State private var selectedBackground: BackgroundTemplate? = nil
    @State private var selectedImageId: UUID? = nil
    
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    private var selectedImageIndex: Int? { placedImages.firstIndex(where: { $0.id == selectedImageId }) }

    init(selectedImagesData: [Data]) {
        self.selectedImagesData = selectedImagesData
        _images = State(initialValue: selectedImagesData.compactMap { UIImage(data: $0) })
    }

    var body: some View {
        VStack {
            GeometryReader { geometry in
                CanvasView(placedImages: $placedImages, selectedImageId: $selectedImageId, background: selectedBackground, size: geometry.size)
                    .background(Color.gray.opacity(0.1)).cornerRadius(10).clipped()
                    .dropDestination(for: UIImage.self) { items, location in
                        guard let droppedImage = items.first else { return false }
                        let relativePosition = UnitPoint(x: location.x / geometry.size.width, y: location.y / geometry.size.height)
                        let newPlacedImage = PlacedImage(image: droppedImage, relativePosition: relativePosition)
                        placedImages.append(newPlacedImage)
                        selectedImageId = newPlacedImage.id
                        return true
                    }
            }.padding()

            if selectedImageId != nil {
                VStack {
                    Text("改变形状").font(.caption).foregroundColor(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(CollageShape.allCases) { shape in
                                Button(action: { if let index = selectedImageIndex { placedImages[index].shape = shape } }) {
                                    Image(systemName: shape.rawValue).font(.title2).foregroundColor(.primary).frame(width: 60, height: 50).background(Color.white).cornerRadius(10).shadow(radius: 2)
                                }
                            }
                        }.padding(.horizontal)
                    }
                }.frame(height: 70)
            }

            VStack {
                Text("选择背景").font(.caption).foregroundColor(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        Button(action: { selectedBackground = nil }) {
                            ZStack { Circle().fill(Color.white).shadow(radius: 2); Image(systemName: "nosign") }.frame(width: 60, height: 60)
                        }
                        ForEach(backgroundTemplates) { template in
                            Button(action: { selectedBackground = template }) {
                                VStack {
                                    Image(systemName: template.symbolName).font(.title2).foregroundColor(template.color)
                                    Text(template.displayName).font(.caption).foregroundColor(.primary)
                                }.frame(width: 60, height: 60).background(Color.white).cornerRadius(10).shadow(radius: 2)
                            }
                        }
                    }.padding(.horizontal)
                }
            }.frame(height: 80).padding(.bottom, selectedImageId != nil ? 0 : 10)

            ScrollView(.horizontal, showsIndicators: false) {
                 HStack {
                     ForEach(images, id: \.self) { image in
                         Image(uiImage: image).resizable().scaledToFit().frame(height: 100).cornerRadius(8).shadow(radius: 3).draggable(image)
                     }
                 }.padding()
            }.frame(height: 120)
        }
        .navigationTitle("自由拼图").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { Button("保存", action: renderAndSaveImage) }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("好的")))
        }
    }
    
    @MainActor
    private func renderAndSaveImage() {
        let exportSize = CGSize(width: 1024, height: 1024)
        let viewToRender = CanvasView(placedImages: .constant(placedImages), selectedImageId: .constant(nil), background: selectedBackground, size: exportSize)
        let renderer = ImageRenderer(content: viewToRender)
        renderer.scale = 2.0
        guard let image = renderer.uiImage else { alertTitle = "错误"; alertMessage = "无法生成图片。"; showAlert = true; return }
        let imageSaver = ImageSaver(onSuccess: { self.alertTitle = "已保存"; self.alertMessage = "您的作品已成功保存到相册。"; self.showAlert = true }, onError: { self.alertTitle = "错误"; self.alertMessage = "保存失败: \($0.localizedDescription)"; self.showAlert = true })
        imageSaver.writeToPhotoAlbum(image: image)
    }
}
