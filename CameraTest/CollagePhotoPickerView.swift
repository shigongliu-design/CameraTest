import SwiftUI
import PhotosUI
import UniformTypeIdentifiers // For UTType

struct CollagePhotoPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImageData: [Data] = []
    @State private var showLayoutRecommendation = false
    
    let selectionLimit: Int = 9
    
    var body: some View {
        NavigationView {
            VStack {
                Text("拼图")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("已选择 \(selectedImageData.count)/\(selectionLimit)")
                    .font(.headline)
                    .padding(.bottom)
                
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
                                        Text("\(index + 1)")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .background(Circle().fill(.blue).frame(width: 20, height: 20))
                                            .offset(x: 7, y: -7)
                                    }
                                    .onTapGesture {
                                        // Deselect photo action
                                        selectedItems.remove(at: index)
                                        selectedImageData.remove(at: index)
                                    }
                            }
                        }
                    }
                    .padding(5)
                }
                
                // Selected photos horizontal preview with reordering
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(0..<selectedImageData.count, id: \.self) { index in
                            if let uiImage = UIImage(data: selectedImageData[index]) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(5)
                                    .overlay(alignment: .topTrailing) {
                                        Text("\(index + 1)")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .background(Circle().fill(.blue).frame(width: 15, height: 15))
                                            .offset(x: 5, y: -5)
                                    }
                                    .onDrag { NSItemProvider(object: String(index) as NSString) } // Make image draggable
                                    .onDrop(of: [.text], delegate: PhotoDropDelegate(currentImageIndex: index, images: $selectedImageData, items: $selectedItems)) // Handle dropping
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 70)
                
                Button(action: {
                    // Action for Next button
                    if selectedImageData.count >= 2 {
                        showLayoutRecommendation = true
                    }
                }) {
                    Text("下一步")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(selectedImageData.count < 2 ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                .disabled(selectedImageData.count < 2)
                .padding()
                .sheet(isPresented: $showLayoutRecommendation) {
                    LayoutRecommendationView(selectedImagesData: selectedImageData)
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

struct PhotoDropDelegate: DropDelegate {
    let currentImageIndex: Int
    @Binding var images: [Data]
    @Binding var items: [PhotosPickerItem]

    func performDrop(info: DropInfo) -> Bool {
        if let item = info.itemProviders(for: [.text]).first {
            item.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (data, error) in
                if let data = data as? Data, let draggedIndexString = String(data: data, encoding: .utf8), let draggedIndex = Int(draggedIndexString) {
                    DispatchQueue.main.async {
                        let draggedImage = images.remove(at: draggedIndex)
                        let draggedItem = items.remove(at: draggedIndex)
                        
                        let dropIndex = determineDropIndex(info: info)
                        
                        images.insert(draggedImage, at: dropIndex)
                        items.insert(draggedItem, at: dropIndex)
                    }
                }
            }
            return true
        }
        return false
    }
    
    func dropEntered(info: DropInfo) {
        // Visual feedback when dragging over a target
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal {
        DropProposal(operation: .move)
    }
    
    private func determineDropIndex(info: DropInfo) -> Int {
        // This is a simplified logic. For precise placement, you'd need to calculate the exact index
        // based on the drop location relative to the visible cells.
        let location = info.location
        // For now, let's just assume dropping before or after current image based on x-coordinate
        return currentImageIndex
    }
}

struct CollagePhotoPickerView_Previews: PreviewProvider {
    static var previews: some View {
        CollagePhotoPickerView()
    }
}
