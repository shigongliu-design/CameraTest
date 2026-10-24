import SwiftUI
import PhotosUI

struct PhotoPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImageData: [Data] = []
    @State private var sheetView: SheetView?
    @State private var selectedImage: UIImage? = nil
    @State private var processedImage: Image? = nil
    @State private var pendingBeautyImage: UIImage? = nil
    
    let selectionLimit: Int // 1 for single, >1 for multi
    let mode: PhotoPickerMode
    /// The editor tab to open after cropping. `.ai` runs the AI 美化 flow;
    /// other tabs (from the home quick tools) open the editor directly.
    var initialTab: EditorTab = .ai
    /// 消除 from the home screen: skip cropping and open the eraser on the whole photo.
    var openEraser: Bool = false
    
    enum PhotoPickerMode {
        case aiBeautify
        case collage
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Text(mode == .aiBeautify ? "选择照片" : "已选择 \(selectedImageData.count)/\(selectionLimit)")
                    .font(.headline)
                    .padding()
                
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 5) {
                        PhotosPicker(selection: $selectedItems,
                                     maxSelectionCount: selectionLimit,
                                     matching: .images) {
                            Image(systemName: "plus.square.on.square.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .foregroundColor(.gray)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(5)
                        }
                        
                        ForEach(0..<selectedImageData.count, id: \.self) { index in
                            if let uiImage = UIImage(data: selectedImageData[index]) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                                    .cornerRadius(5)
                                    .overlay(alignment: .topTrailing) {
                                        if mode == .collage {
                                            Text("\(index + 1)")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .background(Circle().fill(.blue).frame(width: 20, height: 20))
                                                .offset(x: 7, y: -7)
                                        }
                                    }
                            }
                        }
                    }
                    .padding(5)
                }
                

                .sheet(item: $sheetView, onDismiss: {
                    // After cropping in AI 美化 mode, open the processing → editor flow.
                    if let image = pendingBeautyImage {
                        pendingBeautyImage = nil
                        sheetView = initialTab == .ai ? .process(image) : .edit(image, initialTab)
                    }
                }) { item in
                    switch item {
                    case .crop(let image):
                        SwiftyCropView(image: image, maskShape: .square, config: SwiftyCropConfig(onCrop: { croppedImage in
                            guard let croppedImage = croppedImage else { return }
                            if mode == .aiBeautify {
                                pendingBeautyImage = croppedImage
                            } else {
                                let imageSaver = PhotoSaver()
                                imageSaver.writeToPhotoAlbum(image: croppedImage)
                                presentationMode.wrappedValue.dismiss()
                            }
                        }))
                    case .process(let image):
                        AIProcessingView(selectedImage: image)
                    case .edit(let image, let tab):
                        AIBeautyEditorView(uiImage: image, initialTab: tab)
                    case .erase(let image):
                        EraseView(image: image)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onChange(of: selectedItems) {
            Task {
                selectedImageData.removeAll()
                for item in selectedItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            sheetView = openEraser ? .erase(uiImage) : .crop(uiImage)
                        }
                    }
                }
            }
        }
    }
}

struct PhotoPickerView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoPickerView(selectionLimit: 1, mode: .aiBeautify)
        PhotoPickerView(selectionLimit: 9, mode: .collage)
    }
}
