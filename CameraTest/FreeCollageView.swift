import SwiftUI

struct FreeCollageView: View {
    @Environment(\.presentationMode) var presentationMode
    let selectedImagesData: [Data]
    @State private var draggableImages: [DraggableImage] = []
    
    struct DraggableImage: Identifiable {
        let id = UUID()
        let uiImage: UIImage
        var offset: CGSize = .zero
        var scale: CGFloat = 1.0
        var rotation: Angle = .zero
    }
    
    var body: some View {
        VStack {
            // Top Bar
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                }
                Spacer()
                Text("自由拼图")
                    .font(.headline)
                Spacer()
                Button(action: {
                    // Action for Save
                }) {
                    Text("保存")
                        .font(.body)
                        .fontWeight(.bold)
                }
            }
            .padding()
            
            // Free Collage Canvas
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                
                ForEach($draggableImages) { $draggableImage in
                    Image(uiImage: draggableImage.uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150) // Default size
                        .offset(draggableImage.offset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    draggableImage.offset = value.translation
                                }
                                .onEnded { value in
                                    draggableImage.offset = value.translation
                                }
                        )
                }
            }
            .padding()
            
            // Bottom Tools
            HStack(spacing: 20) {
                Button("自动排列") { /* Action */ }.buttonStyle(.bordered)
                Button("删除") { /* Action */ }.buttonStyle(.bordered)
                Button("替换") { /* Action */ }.buttonStyle(.bordered)
            }
            .padding(.bottom)
        }
        .navigationBarHidden(true)
        .onAppear {
            for imageData in selectedImagesData {
                if let uiImage = UIImage(data: imageData) {
                    draggableImages.append(DraggableImage(uiImage: uiImage))
                }
            }
        }
    }
}

struct FreeCollageView_Previews: PreviewProvider {
    static var previews: some View {
        FreeCollageView(selectedImagesData: [Data(), Data()])
    }
}
