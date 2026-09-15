import SwiftUI
import UniformTypeIdentifiers

struct FreeCollageView: View {
    let selectedImagesData: [Data]
    @State private var images: [UIImage]
    @State private var puzzleCells: [PuzzleCell]
    @State private var selectedCellID: UUID?

    init(selectedImagesData: [Data]) {
        self.selectedImagesData = selectedImagesData
        _images = State(initialValue: selectedImagesData.compactMap { UIImage(data: $0) })
        _puzzleCells = State(initialValue: [])
    }

    var body: some View {
        VStack {
            // Top Bar
            HStack {
                // ... (Top bar implementation)
            }
            .padding()

            // Template Browser
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    Button("模板 1") { applyTemplate1() }
                    Button("模板 2") { applyTemplate2() }
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
                        PuzzleCellView(cell: cell)
                            .frame(width: cell.frame.width * geometry.size.width, height: cell.frame.height * geometry.size.height)
                            .position(x: cell.frame.midX * geometry.size.width, y: cell.frame.midY * geometry.size.height)
                            .onTapGesture { self.selectedCellID = cell.id }
                            .onDrop(of: [UTType.image], isTargeted: nil) { providers, _ in
                                providers.first?.loadObject(ofClass: UIImage.self) { (image, error) in
                                    if let image = image as? UIImage {
                                        if let index = self.puzzleCells.firstIndex(where: { $0.id == cell.id }) {
                                            self.puzzleCells[index].image = image
                                        }
                                    }
                                }
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
                            .onDrag { NSItemProvider(object: image) }
                    }
                }
                .padding()
            }
        }
    }

    private func applyTemplate1() {
        self.puzzleCells = [
            PuzzleCell(frame: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5), shape: .square),
            PuzzleCell(frame: CGRect(x: 0.75, y: 0.25, width: 0.5, height: 0.5), shape: .square),
            PuzzleCell(frame: CGRect(x: 0.5, y: 0.75, width: 1, height: 0.5), shape: .square),
        ]
        distributeImages()
    }

    private func applyTemplate2() {
        self.puzzleCells = [
            PuzzleCell(frame: CGRect(x: 0.5, y: 0.25, width: 1, height: 0.5), shape: .square),
            PuzzleCell(frame: CGRect(x: 0.25, y: 0.75, width: 0.5, height: 0.5), shape: .square),
            PuzzleCell(frame: CGRect(x: 0.75, y: 0.75, width: 0.5, height: 0.5), shape: .square),
        ]
        distributeImages()
    }

    private func distributeImages() {
        for (index, cell) in puzzleCells.enumerated() {
            if index < images.count {
                if let cellIndex = self.puzzleCells.firstIndex(where: { $0.id == cell.id }) {
                    self.puzzleCells[cellIndex].image = images[index]
                }
            }
        }
    }
}

struct PuzzleCell: Identifiable {
    let id = UUID()
    var frame: CGRect
    var shape: MaskShape
    var image: UIImage? = nil
}

enum MaskShape: String, CaseIterable, Identifiable {
    case square, circle, triangle, pentagon, hexagon, star
    var id: String { self.rawValue }

    func path(in rect: CGRect) -> Path {
        switch self {
        case .square:
            return Path(CGRect(origin: .zero, size: rect.size))
        case .circle:
            return Path(ellipseIn: CGRect(origin: .zero, size: rect.size))
        case .triangle:
            return Path { path in
                path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.closeSubpath()
            }
        case .pentagon:
            return Path { path in
                let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
                let radius = min(rect.width, rect.height) / 2
                let angle = CGFloat.pi / 2
                let points = (0..<5).map {
                    CGPoint(x: center.x + radius * cos(angle + CGFloat($0) * 2 * CGFloat.pi / 5), y: center.y - radius * sin(angle + CGFloat($0) * 2 * CGFloat.pi / 5))
                }
                path.addLines(points)
                path.closeSubpath()
            }
        case .hexagon:
            return Path { path in
                let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
                let radius = min(rect.width, rect.height) / 2
                let points = (0..<6).map {
                    CGPoint(x: center.x + radius * cos(CGFloat($0) * CGFloat.pi / 3), y: center.y + radius * sin(CGFloat($0) * CGFloat.pi / 3))
                }
                path.addLines(points)
                path.closeSubpath()
            }
        case .star:
            return Path { path in
                let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
                let radius = min(rect.width, rect.height) / 2
                let points = (0..<10).map { i -> CGPoint in
                    let r = (i % 2 == 0) ? radius : radius / 2.5
                    let angle = CGFloat.pi / 2 + CGFloat(i) * CGFloat.pi / 5
                    return CGPoint(x: center.x + r * cos(angle), y: center.y - r * sin(angle))
                }
                path.addLines(points)
                path.closeSubpath()
            }
        }
    }
}

struct PuzzleCellView: View {
    let cell: PuzzleCell

    var body: some View {
        ZStack {
            if let image = cell.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.3)
            }
        }
        .mask(cell.shape.path(in: CGRect(origin: .zero, size: cell.frame.size)))
        .overlay(
            cell.shape.path(in: CGRect(origin: .zero, size: cell.frame.size))
                .stroke(Color.black, lineWidth: 1)
        )
    }
}
