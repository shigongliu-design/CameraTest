import SwiftUI
import PhotosUI

struct PhotoPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImageData: [Data] = []
    @State private var navigateToAIProcessing = false
    @State private var processedImage: Image? = nil
    
    let selectionLimit: Int // 1 for single, >1 for multi
    let mode: PhotoPickerMode
    
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
                
                Button(action: {
                    if mode == .aiBeautify, let imageData = selectedImageData.first, let uiImage = UIImage(data: imageData) {
                        processedImage = Image(uiImage: uiImage)
                        navigateToAIProcessing = true
                    } else {
                        // Action for Collage or other modes
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Text("下一步")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(selectedImageData.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                .disabled(selectedImageData.isEmpty)
                .padding()
                .sheet(isPresented: $navigateToAIProcessing) {
                    if let image = processedImage {
                        AIProcessingView(selectedImage: image)
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
                        selectedImageData.append(data)
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
