//
//  EraseView.swift
//  CameraTest
//
//  消除: brush over anything you want gone, tap 消除, and LaMa fills it in on device.
//

import SwiftUI
import UIKit

struct EraseView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Stroke {
        var points: [CGPoint]   // image pixel coordinates (top-left origin)
        var width: CGFloat      // image pixels
    }

    @State private var currentImage: CGImage?
    @State private var originalImage: CGImage?
    @State private var history: [CGImage] = []
    @State private var strokes: [Stroke] = []
    @State private var activeStroke: Stroke?
    @State private var brushSize: Double = 40        // on-screen points
    @State private var isProcessing = false
    @State private var isShowingOriginal = false
    @State private var errorMessage: String?
    @State private var isShowingSaveConfirmation = false

    private let sourceImage: UIImage

    init(image: UIImage) {
        sourceImage = image
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            canvas
            controls
        }
        .navigationBarHidden(true)
        .interactiveDismissDisabled() // brushing must not swipe the sheet away
        .task { await prepare() }
        .alert("提示", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("保存成功", isPresented: $isShowingSaveConfirmation) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("照片已保存到你的相册")
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.title2)
            }
            Spacer()
            Text("消除").font(.headline)
            Spacer()
            Button("保存") { save() }
                .fontWeight(.bold)
                .disabled(currentImage == nil || isProcessing)
        }
        .padding()
    }

    // MARK: Canvas

    private var canvas: some View {
        GeometryReader { geo in
            if let image = isShowingOriginal ? originalImage : currentImage {
                let imageSize = CGSize(width: image.width, height: image.height)
                let frame = fittedRect(for: imageSize, in: geo.size)
                let scale = frame.width / imageSize.width   // screen points per image pixel

                ZStack(alignment: .topLeading) {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .frame(width: frame.width, height: frame.height)
                        .offset(x: frame.minX, y: frame.minY)

                    if !isShowingOriginal {
                        Canvas { context, _ in
                            for stroke in strokes + (activeStroke.map { [$0] } ?? []) {
                                var path = Path()
                                let pts = stroke.points.map {
                                    CGPoint(x: frame.minX + $0.x * scale, y: frame.minY + $0.y * scale)
                                }
                                guard let first = pts.first else { continue }
                                path.move(to: first)
                                if pts.count == 1 {
                                    path.addLine(to: first)
                                } else {
                                    pts.dropFirst().forEach { path.addLine(to: $0) }
                                }
                                context.stroke(path,
                                               with: .color(.red.opacity(0.45)),
                                               style: StrokeStyle(lineWidth: stroke.width * scale, lineCap: .round, lineJoin: .round))
                            }
                        }
                        .allowsHitTesting(false)
                    }

                    if isProcessing {
                        ProgressView("正在消除…")
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard !isProcessing, !isShowingOriginal else { return }
                            let p = CGPoint(x: (value.location.x - frame.minX) / scale,
                                            y: (value.location.y - frame.minY) / scale)
                            if activeStroke == nil {
                                activeStroke = Stroke(points: [p], width: CGFloat(brushSize) / scale)
                            } else {
                                activeStroke?.points.append(p)
                            }
                        }
                        .onEnded { _ in
                            if let stroke = activeStroke { strokes.append(stroke) }
                            activeStroke = nil
                        }
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal)
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 12) {
            Text(strokes.isEmpty ? "用手指涂抹想要消除的部分" : "涂抹完成后点「消除」")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "paintbrush.pointed").foregroundStyle(.secondary)
                Slider(value: $brushSize, in: 10...100, step: 1)
                Circle()
                    .fill(Color.red.opacity(0.45))
                    .frame(width: max(10, brushSize / 2), height: max(10, brushSize / 2))
                    .frame(width: 50)
            }
            .padding(.horizontal)

            HStack(spacing: 16) {
                Button {
                    if !strokes.isEmpty {
                        strokes.removeLast()
                    } else if let previous = history.popLast() {
                        currentImage = previous
                    }
                } label: {
                    Label("撤销", systemImage: "arrow.uturn.backward")
                }
                .disabled(strokes.isEmpty && history.isEmpty)

                Text(isShowingOriginal ? "原图" : "按住对比")
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.15), in: Capsule())
                    .onLongPressGesture(minimumDuration: 0, perform: {}, onPressingChanged: { pressing in
                        isShowingOriginal = pressing
                    })

                Spacer()

                Button {
                    erase()
                } label: {
                    Label("消除", systemImage: "eraser.fill")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(strokes.isEmpty ? Color.gray : Color.purple)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .disabled(strokes.isEmpty || isProcessing)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
    }

    // MARK: Actions

    private func prepare() async {
        guard currentImage == nil else { return }
        let source = sourceImage
        let prepared = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            guard let upright = BeautyEngine.uprightCGImage(source) else { return nil }
            return BeautyEngine.downscale(upright, maxDimension: 2048)
        }.value
        currentImage = prepared
        originalImage = prepared
        if !Inpainter.shared.isModelAvailable {
            errorMessage = Inpainter.InpaintError.modelMissing.errorDescription
        }
    }

    private func erase() {
        guard let image = currentImage, !strokes.isEmpty,
              let mask = makeMask(size: CGSize(width: image.width, height: image.height)) else { return }
        isProcessing = true
        Task {
            let result: Result<CGImage, Error> = await Task.detached(priority: .userInitiated) {
                do {
                    return .success(try Inpainter.shared.inpaint(image: image, mask: mask))
                } catch {
                    return .failure(error)
                }
            }.value
            isProcessing = false
            switch result {
            case .success(let output):
                history.append(image)
                currentImage = output
                strokes.removeAll()
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    /// White strokes on black, at the photo's pixel size.
    private func makeMask(size: CGSize) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor.black.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            cg.setStrokeColor(UIColor.white.cgColor)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            for stroke in strokes {
                guard let first = stroke.points.first else { continue }
                cg.setLineWidth(stroke.width)
                cg.beginPath()
                cg.move(to: first)
                if stroke.points.count == 1 {
                    cg.addLine(to: first)
                } else {
                    stroke.points.dropFirst().forEach { cg.addLine(to: $0) }
                }
                cg.strokePath()
            }
        }
        return image.cgImage
    }

    private func save() {
        guard let image = currentImage else { return }
        PhotoSaver().writeToPhotoAlbum(image: UIImage(cgImage: image))
        isShowingSaveConfirmation = true
    }

    private func fittedRect(for imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (container.width - size.width) / 2,
                      y: (container.height - size.height) / 2,
                      width: size.width,
                      height: size.height)
    }
}
