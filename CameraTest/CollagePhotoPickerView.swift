import SwiftUI
import PhotosUI

struct CollagePhotoPickerView: View {
    @State private var selectedItems = [PhotosPickerItem]()
    @State private var selectedImagesData = [Data]()
    @State private var showingImagePicker = true

    var body: some View {
        VStack {
            if !selectedImagesData.isEmpty {
                Text("已选择 \(selectedImagesData.count) 张照片")
                    .font(.headline)
                    .padding()
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                    ForEach(selectedImagesData, id: \.self) { data in
                        if let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .frame(height: 100)
                                .clipped()
                        }
                    }
                }
            }

            Spacer()

            if selectedImagesData.count >= 2 {
                NavigationLink(destination: LayoutRecommendationView(selectedImagesData: selectedImagesData)) {
                    Text("下一步")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            } else {
                Text("请选择2-9张照片")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .navigationTitle("选择照片")
        .photosPicker(
            isPresented: $showingImagePicker,
            selection: $selectedItems,
            maxSelectionCount: 9,
            matching: .images
        )
        .onChange(of: selectedItems) { newItems in
            selectedImagesData = []
            for item in newItems {
                item.loadTransferable(type: Data.self) { result in
                    switch result {
                    case .success(let data?):
                        DispatchQueue.main.async {
                            selectedImagesData.append(data)
                        }
                    case .failure(let error):
                        print("Error loading image data: \(error)")
                    case .success(nil):
                        break
                    }
                }
            }
        }
    }
}
