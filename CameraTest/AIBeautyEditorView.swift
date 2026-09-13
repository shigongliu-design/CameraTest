import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit // Import UIKit for UIImage and UIHostingController

struct AIBeautyEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var originalImage: Image
    @State private var processedImage: Image
    @State private var aiBeautyIntensity: Double = 50.0 {
        didSet {
            applyMockAIBeautyEffect()
        }
    }
    @State private var selectedTab: Int = 0 // 0: AI 美化, 1: 美颜, 2: 调整, 3: 滤镜
    @State private var showExportView = false
    
    init(image: Image) {
        _originalImage = State(initialValue: image)
        _processedImage = State(initialValue: image) // Initialize processed image with original
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
                Text("AI 美化")
                    .font(.headline)
                Spacer()
                Button(action: {
                    // Action for Save
                    showExportView = true
                }) {
                    Text("保存")
                        .font(.body)
                        .fontWeight(.bold)
                }
            }
            .padding()
            
            // Main Image Preview with Before/After Slider (Placeholder)
            Spacer()
            processedImage
                .resizable()
                .scaledToFit()
                .padding(.horizontal)
            // Placeholder for Before/After Slider
            Text("Before/After Slider Placeholder")
                .font(.caption)
                .padding(.vertical, 5)
            Spacer()
            
            // Bottom Toolbar
            VStack {
                Picker("", selection: $selectedTab) {
                    Text("AI 美化").tag(0)
                    Text("美颜").tag(1)
                    Text("调整").tag(2)
                    Text("滤镜").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                if selectedTab == 0 {
                    // AI 美化 tab content
                    VStack {
                        Text("AI 美化强度: \(Int(aiBeautyIntensity))%")
                        Slider(value: $aiBeautyIntensity, in: 0...100) {
                            Text("Intensity")
                        } minimumValueLabel: {
                            Text("0")
                        } maximumValueLabel: {
                            Text("100")
                        }
                        .padding(.horizontal)
                    }
                } else if selectedTab == 1 {
                    // 美颜 tab content
                    ScrollView {
                        VStack(spacing: 20) {
                            Text("美颜功能")
                                .font(.subheadline)

                            // 肌肤 (Skin) controls
                            Group {
                                Text("肌肤")
                                    .font(.callout)
                                    .fontWeight(.bold)
                                HStack {
                                    Button("磨皮") { /* action */ }.buttonStyle(.bordered)
                                    Button("美白") { /* action */ }.buttonStyle(.bordered)
                                    Button("红润") { /* action */ }.buttonStyle(.bordered)
                                    Button("祛痘") { /* action */ }.buttonStyle(.bordered)
                                    Button("黑眼圈") { /* action */ }.buttonStyle(.bordered)
                                }
                                // Example slider for one skin property
                                Slider(value: .constant(0.5), in: 0...1) { Text("磨皮强度") } minimumValueLabel: { Text("0") } maximumValueLabel: { Text("1") }
                                    .padding(.horizontal)
                            }

                            // 美型 (Face Shape) controls
                            Group {
                                Text("美型")
                                    .font(.callout)
                                    .fontWeight(.bold)
                                HStack {
                                    Button("瘦脸") { /* action */ }.buttonStyle(.bordered)
                                    Button("大眼") { /* action */ }.buttonStyle(.bordered)
                                    Button("鼻型") { /* action */ }.buttonStyle(.bordered)
                                    Button("下巴") { /* action */ }.buttonStyle(.bordered)
                                }
                                // Example slider for one face shape property
                                Slider(value: .constant(0.5), in: 0...1) { Text("瘦脸程度") } minimumValueLabel: { Text("0") } maximumValueLabel: { Text("1") }
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                } else if selectedTab == 2 {
                    Text("调整功能 (Placeholder)")
                } else if selectedTab == 3 {
                    Text("滤镜功能 (Placeholder)")
                }
            }
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.1))
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showExportView) {
            ExportView(exportedImage: processedImage)
        }
        .onAppear(perform: applyMockAIBeautyEffect)
    }
    
    private func applyMockAIBeautyEffect() {
        guard let uiImage = originalImage.asUIImage() else { return }
        let context = CIContext()
        if let ciImage = CIImage(image: uiImage) {
            guard let filter = CIFilter(name: "CIBrightnessContrast") else { return }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(Float(aiBeautyIntensity - 50) / 100.0, forKey: kCIInputBrightnessKey)
            
            if let outputImage = filter.outputImage,
               let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                self.processedImage = Image(uiImage: UIImage(cgImage: cgImage))
            }
        }
    }
}

struct AIBeautyEditorView_Previews: PreviewProvider {
    static var previews: some View {
        AIBeautyEditorView(image: Image(systemName: "photo.fill"))
    }
}
