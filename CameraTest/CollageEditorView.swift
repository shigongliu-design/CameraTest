import SwiftUI

struct CollageEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    let selectedImagesData: [Data]
    @State private var selectedLayout: Int = 0 // Placeholder for selected layout
    @State private var showExportView = false
    
    @State private var selectedTool: CollageTool = .none
    @State private var collageSpacing: Double = 0
    @State private var collageCornerRadius: Double = 0
    
    enum CollageTool: Identifiable, CaseIterable {
        case layout, spacing, cornerRadius, background, text, none
        
        var id: Self { self }
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
                Text("拼图")
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
            
            // Collage Canvas
            Spacer()
            GeometryReader {
                geometry in
                let numberOfImages = selectedImagesData.count
                let grid: (columns: Int, rows: Int) = {
                    switch numberOfImages {
                    case 2:
                        return (2, 1)
                    case 3:
                        return (3, 1)
                    case 4:
                        return (2, 2)
                    case 5, 6:
                        return (3, 2)
                    case 7, 8, 9:
                        return (3, 3)
                    default:
                        return (1, 1)
                    }
                }()
                let columns = grid.columns
                let rows = grid.rows
                let itemWidth = geometry.size.width / CGFloat(columns)
                let itemHeight = geometry.size.height / CGFloat(rows)
                
                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<columns, id: \.self) { column in
                                let index = row * columns + column
                                if index < numberOfImages, let uiImage = UIImage(data: selectedImagesData[index]) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: itemWidth, height: itemHeight)
                                        .clipped()
                                }
                            }
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .aspectRatio(1, contentMode: .fit) // Keep aspect ratio of collage square for now
            .padding()
            Spacer()
            
            // Bottom Toolbar
            VStack {
                HStack(spacing: 20) {
                    Button(action: {
                        selectedTool = .layout
                    }) {
                        VStack {
                            Image(systemName: "square.grid.2x2.fill")
                            Text("布局")
                        }
                    }
                    Button(action: {
                        selectedTool = .spacing
                    }) {
                        VStack {
                            Image(systemName: "rectangle.split.3x1")
                            Text("间距")
                        }
                    }
                    Button(action: {
                        selectedTool = .cornerRadius
                    }) {
                        VStack {
                            Image(systemName: "rectangle.roundedbottom")
                            Text("圆角")
                        }
                    }
                    Button(action: {
                        selectedTool = .background
                    }) {
                        VStack {
                            Image(systemName: "photo.fill")
                            Text("背景")
                        }
                    }
                    Button(action: {
                        selectedTool = .text
                    }) {
                        VStack {
                            Image(systemName: "textformat.alt")
                            Text("文字")
                        }
                    }
                }
                .font(.caption)
                .padding(.horizontal)
                
                if selectedTool == .spacing {
                    Slider(value: $collageSpacing, in: 0...30) {
                        Text("间距")
                    } minimumValueLabel: { Text("0") } maximumValueLabel: { Text("30") }
                    .padding(.horizontal)
                } else if selectedTool == .cornerRadius {
                    Slider(value: $collageCornerRadius, in: 0...40) {
                        Text("圆角")
                    } minimumValueLabel: { Text("0") } maximumValueLabel: { Text("40") }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.1))
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showExportView) {
            // For now, passing the first image as a placeholder for the collage
            if let uiImage = UIImage(data: selectedImagesData.first ?? Data()) {
                ExportView(exportedImage: Image(uiImage: uiImage))
            }
        }
    }
}

struct CollageEditorView_Previews: PreviewProvider {
    static var previews: some View {
        CollageEditorView(selectedImagesData: [Data(), Data()]) // Provide some dummy data
    }
}
