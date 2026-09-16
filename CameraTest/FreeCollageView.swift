
import SwiftUI
import Combine

// --- Data Model and Cell View ---
class PuzzleCell: Identifiable, ObservableObject {
    let id = UUID()
    var frame: CGRect // Using CGRect for relative positioning within a 0-1 space
    var shape: MaskShape
    @Published var image: UIImage? = nil

    init(frame: CGRect, shape: MaskShape, image: UIImage? = nil) {
        self.frame = frame
        self.shape = shape
        self.image = image
    }
}

enum MaskShape: String, CaseIterable, Identifiable {
    case square, circle
    var id: String { self.rawValue }

    func path(in rect: CGRect) -> Path {
        switch self {
        case .square:
            return Path(rect)
        case .circle:
            return Path(ellipseIn: rect)
        }
    }
}

// --- Cell View ---
struct PuzzleCellView: View {
    @ObservedObject var cell: PuzzleCell
    let geometry: GeometryProxy

    var body: some View {
        let cellWidth = cell.frame.width * geometry.size.width
        let cellHeight = cell.frame.height * geometry.size.height
        
        ZStack {
            if let image = cell.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cellWidth, height: cellHeight)
            } else {
                Color.gray.opacity(0.3)
            }
        }
        .clipShape(cell.shape.path(in: CGRect(x: 0, y: 0, width: cellWidth, height: cellHeight)))
        .frame(width: cellWidth, height: cellHeight)
        .position(x: cell.frame.midX * geometry.size.width, y: cell.frame.midY * geometry.size.height)
        .contentShape(cell.shape.path(in: CGRect(x: 0, y: 0, width: cellWidth, height: cellHeight)))
    }
}

// --- Main Collage View ---
struct FreeCollageView: View {
    let selectedImagesData: [Data]
    @State private var images: [UIImage]
    @State private var puzzleCells: [PuzzleCell]

    init(selectedImagesData: [Data]) {
        self.selectedImagesData = selectedImagesData
        _images = State(initialValue: selectedImagesData.compactMap { UIImage(data: $0) })
        _puzzleCells = State(initialValue: [])
    }

    var body: some View {
        VStack {
            // Template Browser
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    Button("Apply Template 1") { applyTemplate(1) }
                    Button("Apply Template 2") { applyTemplate(2) }
                }
                .padding()
            }

            // Puzzle Canvas
            GeometryReader { geometry in
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .cornerRadius(10)

                    ForEach(puzzleCells) { cell in
                        PuzzleCellView(cell: cell, geometry: geometry)
                            .dropDestination(for: UIImage.self) { items, location in
                                guard let droppedImage = items.first else { return false }
                                // Directly update the image on the cell object
                                cell.image = droppedImage
                                return true
                            }
                    }
                }
            }
            .padding()

            // Photo Gallery
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(images, id: \.self) { image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 100)
                            .draggable(image)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("手工拼图")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: { applyTemplate(1) })
    }

    private func applyTemplate(_ number: Int) {
        // ... (template definitions remain the same)
        if number == 1 {
            self.puzzleCells = [
                PuzzleCell(frame: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5), shape: .square),
                PuzzleCell(frame: CGRect(x: 0.75, y: 0.25, width: 0.5, height: 0.5), shape: .square),
                PuzzleCell(frame: CGRect(x: 0.25, y: 0.75, width: 0.5, height: 0.5), shape: .square),
                PuzzleCell(frame: CGRect(x: 0.75, y: 0.75, width: 0.5, height: 0.5), shape: .square),
            ]
        } else {
            self.puzzleCells = [
                PuzzleCell(frame: CGRect(x: 0.5, y: 0.3, width: 0.8, height: 0.4), shape: .square),
                PuzzleCell(frame: CGRect(x: 0.5, y: 0.75, width: 0.8, height: 0.4), shape: .square),
            ]
        }
    }

}
