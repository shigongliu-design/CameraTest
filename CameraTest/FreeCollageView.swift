import UniformTypeIdentifiers
import SwiftUI
import PhotosUI

struct FreeCollageView: View {
    @Environment(\.presentationMode) var presentationMode
    let selectedImagesData: [Data]
    
    @State private var canvasShapes: [ShapeProperties] = []
    @State private var selectedTemplate: CollageTemplate? = nil
    @State private var templates: [CollageTemplate] = generateCollageTemplates()
    @State private var selectedShapeID: UUID? = nil
    @State private var showPhotoPicker = false

    var body: some View {
        VStack {
            // Top Bar
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left").font(.title2)
                }
                Spacer()
                Text("自由拼图").font(.headline)
                Spacer()
                Button(action: { /* Save action */ }) {
                    Text("保存").font(.body).fontWeight(.bold)
                }
            }
            .padding()

            // Template Browser
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(templates) { template in
                        Button(action: {
                            applyTemplate(template)
                        }) {
                            Text(template.name)
                                .padding()
                                .background(selectedTemplate?.id == template.id ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedTemplate?.id == template.id ? .white : .black)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }

            // Free Collage Canvas
            GeometryReader { geometry in
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .cornerRadius(10)

                    ForEach(canvasShapes) { shape in
                        ShapeView(properties: shape, isSelected: selectedShapeID == shape.id)
                            .frame(width: shape.frame.width * geometry.size.width, height: shape.frame.height * geometry.size.height)
                            .position(x: shape.frame.midX * geometry.size.width, y: shape.frame.midY * geometry.size.height)
                            .onTapGesture {
                                selectedShapeID = shape.id
                                showPhotoPicker = true
                            }
                    }
                }
                .onDrop(of: [UTType.text], delegate: ShapeDropDelegate(shapes: $canvasShapes, frame: geometry.frame(in: .global)))
            }
            .padding()

            // Shape Gallery
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(MaskShape.allCases) { shape in
                        shape.path(in: CGRect(x: 0, y: 0, width: 50, height: 50))
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 50, height: 50)
                            .onDrag { NSItemProvider(object: shape.rawValue as NSString) }
                    }
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(selectionLimit: 1) { results in
                guard let result = results.first else { return }
                
                result.itemProvider.loadObject(ofClass: UIImage.self) { (object, error) in
                    if let image = object as? UIImage,
                       let index = canvasShapes.firstIndex(where: { $0.id == selectedShapeID }) {
                        DispatchQueue.main.async {
                            canvasShapes[index].image = image
                        }
                    }
                }
            }
        }
    }

    private func applyTemplate(_ template: CollageTemplate) {
        selectedTemplate = template
        canvasShapes = template.shapes.map { ShapeProperties(frame: $0.frame, maskShape: $0.shape) }
    }
}

struct ShapeDropDelegate: DropDelegate {
    @Binding var shapes: [ShapeProperties]
    let frame: CGRect

    func performDrop(info: DropInfo) -> Bool {
        guard info.hasItemsConforming(to: [UTType.text]) else {
            return false
        }

        let items = info.itemProviders(for: [UTType.text])
        
        for item in items {
            item.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (data, error) in
                if let data = data as? Data, let shapeName = String(data: data, encoding: .utf8), let shape = MaskShape(rawValue: shapeName) {
                    DispatchQueue.main.async {
                        let normalizedX = max(0, min(1, (info.location.x - frame.origin.x) / frame.width))
                        let normalizedY = max(0, min(1, (info.location.y - frame.origin.y) / frame.height))
                        let newShape = ShapeProperties(frame: CGRect(x: normalizedX, y: normalizedY, width: 0.3, height: 0.3), maskShape: shape)
                        shapes.append(newShape)
                    }
                }
            }
        }
        return true
    }
}

struct ShapeProperties: Identifiable {
    let id = UUID()
    var frame: CGRect
    let maskShape: MaskShape
    var image: UIImage? = nil
}

struct ShapeView: View {
    let properties: ShapeProperties
    let isSelected: Bool

    var body: some View {
        ZStack {
            if let image = properties.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.3)
            }
        }
        .mask(properties.maskShape.path(in: CGRect(origin: .zero, size: properties.frame.size)))
        .overlay(
            properties.maskShape.path(in: CGRect(origin: .zero, size: properties.frame.size))
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
        )
        .contentShape(properties.maskShape.path(in: CGRect(origin: .zero, size: properties.frame.size)))
    }
}

struct FreeCollageView_Previews: PreviewProvider {
    static var previews: some View {
        FreeCollageView(selectedImagesData: [Data(), Data()])
    }
}
