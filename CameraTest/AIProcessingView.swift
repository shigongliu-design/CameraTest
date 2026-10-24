import SwiftUI
import UIKit

struct AIProcessingView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var processingStep: Int = 0
    @State private var showAIBeautyEditor = false
    @State private var processingFailed = false
    let selectedImage: UIImage
    
    let processingMessages = [
        "正在优化你的照片",
        "✓ 光线",
        "✓ 色彩",
        "✓ 人像",
        "✓ 清晰度"
    ]
    
    var body: some View {
        VStack {
            Spacer()
            
            Image(uiImage: selectedImage)
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .cornerRadius(10)
                .padding(.bottom, 50)
            
            if !processingFailed {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .padding(.bottom, 20)
            }
            
            Text(processingMessages[processingStep])
                .font(.title2)
                .padding()
            
            Spacer()
            
            // Error buttons visible on processing failure
            Group {
                Button(action: {
                    // Action for retry
                    processingFailed = false
                    processingStep = 0
                    startProcessingAnimation()
                }) {
                    Text("重试")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                .padding(.horizontal)
                
                Button(action: {
                    // Action to enter normal editor (e.g., dismiss processing view and go to editor)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("进入普通编辑器")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                .padding(.horizontal)
            }
            .opacity(processingFailed ? 1 : 0) // Show only if failed
        }
        .navigationBarHidden(true)
        .onAppear {
            startProcessingAnimation()
        }
        .fullScreenCover(isPresented: $showAIBeautyEditor, onDismiss: {
            presentationMode.wrappedValue.dismiss()
        }) {
            AIBeautyEditorView(uiImage: selectedImage)
        }
    }
    
    private func startProcessingAnimation() {
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
            if processingStep < processingMessages.count - 1 {
                processingStep += 1
            } else {
                timer.invalidate()
                // The beauty engine runs on device inside the editor, so always continue.
                // Set processingFailed = true here to show the retry UI for real errors.
                showAIBeautyEditor = true
            }
        }
    }
}

struct AIProcessingView_Previews: PreviewProvider {
    static var previews: some View {
        AIProcessingView(selectedImage: UIImage(systemName: "photo.fill") ?? UIImage())
    }
}
