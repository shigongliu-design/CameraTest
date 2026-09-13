import SwiftUI

struct LayoutRecommendationView: View {
    @Environment(\.presentationMode) var presentationMode
    let selectedImagesData: [Data]
    @State private var showCollageEditor = false
    @State private var showFreeCollageEditor = false
    
    var body: some View {
        NavigationView {
            VStack {
                Text("为你推荐")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                ScrollView {
                    // First Card: Recommended Layout
                    VStack {
                        Text("⭐ 推荐")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow.opacity(0.8))
                            .cornerRadius(5)
                            .offset(x: -UIScreen.main.bounds.width / 2 + 50, y: 10) // Adjust position
                        
                        Image(systemName: "rectangle.split.3x3.fill") // Placeholder for large layout preview
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        
                        Button(action: {
                            // Action to use this layout
                            showCollageEditor = true
                        }) {
                            Text("使用此布局")
                                .font(.title2)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                    
                    // Layout Categories
                    VStack(alignment: .leading) {
                        Text("经典")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.leading)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(0..<5) { _ in
                                    Image(systemName: "rectangle.split.2x1.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(5)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Text("创意")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.leading)
                            .padding(.top)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(0..<5) { _ in
                                    Image(systemName: "rectangle.split.2x2.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(5)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Text("长图")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.leading)
                            .padding(.top)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(0..<5) { _ in
                                    Image(systemName: "rectangle.portrait.split.2x1.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(5)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Text("自由")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.leading)
                            .padding(.top)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                Button(action: {
                                    showFreeCollageEditor = true
                                }) {
                                    Image(systemName: "plus.rectangle.on.rectangle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(5)
                                        .overlay(
                                            Text("自由创作")
                                                .font(.caption2)
                                                .foregroundColor(.black)
                                        )
                                }
                                ForEach(0..<4) { _ in
                                    Image(systemName: "rectangle.split.3x1.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(5)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 20)
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
        .sheet(isPresented: $showCollageEditor) {
            CollageEditorView(selectedImagesData: selectedImagesData)
        }
        .sheet(isPresented: $showFreeCollageEditor) {
            FreeCollageView(selectedImagesData: selectedImagesData)
        }
    }
}

struct LayoutRecommendationView_Previews: PreviewProvider {
    static var previews: some View {
        LayoutRecommendationView(selectedImagesData: [])
    }
}
