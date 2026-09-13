import SwiftUI
import UIKit

struct ExportView: View {
    @Environment(\.presentationMode) var presentationMode
    let exportedImage: Image
    @State private var showingSaveSuccess = false
    @State private var showingShareSheet = false
    @State private var selectedResolution: Int = 0
    
    var body: some View {
        VStack {
            // Top Bar
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark") // Close button
                        .font(.title2)
                }
                Spacer()
                Text("导出")
                    .font(.headline)
                Spacer()
            }
            .padding()
            
            // Work Preview
            Spacer()
            exportedImage
                .resizable()
                .scaledToFit()
                .padding(.horizontal)
            Spacer()
            
            // Resolution Options
            VStack(alignment: .leading) {
                Text("导出分辨率")
                    .font(.headline)
                Picker("分辨率", selection: $selectedResolution) {
                    Text("标准").tag(0)
                    Text("高清").tag(1)
                    Text("原尺寸 (Pro)").tag(2).disabled(true) // Disabled for Pro feature
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
            
            // Action Buttons
            VStack(spacing: 20) {
                Button(action: {
                    saveImageToPhotoLibrary()
                }) {
                    Label("保存图片", systemImage: "square.and.arrow.down")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                
                Button(action: {
                    showingShareSheet = true
                }) {
                    Label("分享", systemImage: "square.and.arrow.up")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .navigationBarHidden(true)
        .alert(isPresented: $showingSaveSuccess) {
            Alert(
                title: Text("已保存到相册"),
                message: Text("您的作品已成功保存到相册。"),
                primaryButton: .default(Text("继续编辑")) { presentationMode.wrappedValue.dismiss() },
                secondaryButton: .default(Text("分享")) { showingShareSheet = true }
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [exportedImage.asUIImageRendered() ?? UIImage()])
        }
    }
    
    private func saveImageToPhotoLibrary() {
        guard let uiImage = exportedImage.asUIImageRendered() else { return }
        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
        showingSaveSuccess = true
    }
}

// Helper to convert SwiftUI Image to UIImage (renamed to avoid clashes with other extensions)
extension Image {
    func asUIImageRendered(size: CGSize = CGSize(width: 500, height: 500), colorScheme: ColorScheme = .light) -> UIImage? {
        // Render the SwiftUI Image inside a hosting controller
        let hosting = UIHostingController(rootView: self
            .environment(\.colorScheme, colorScheme)
        )
        hosting.view.bounds = CGRect(origin: .zero, size: size)
        hosting.view.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true)
        }
    }
}

// UIActivityViewController wrapper for SwiftUI
struct ShareSheet: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIActivityViewController
    
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to do here
    }
}

struct ExportView_Previews: PreviewProvider {
    static var previews: some View {
        ExportView(exportedImage: Image(systemName: "photo.fill"))
    }
}
