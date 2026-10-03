//
//  SwiftyCrop.swift
//  CameraTest
//

import SwiftUI

struct SwiftyCropView: View {
    @Environment(\.dismiss) private var dismiss

    private let image: UIImage
    private let maskShape: MaskShape
    private let config: SwiftyCropConfig

    @State private var cropContainerSize: CGSize = .zero
    @State private var currentScale: CGFloat = 1
    @State private var finalScale: CGFloat = 1
    @State private var currentOffset: CGSize = .zero
    @State private var finalOffset: CGSize = .zero

    init(
        image: UIImage,
        maskShape: MaskShape,
        config: SwiftyCropConfig
    ) {
        self.image = image.normalizedForCropping()
        self.maskShape = maskShape
        self.config = config
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            cropArea
                .layoutPriority(1)

            Text("拖动或缩放图片来选择裁剪区域")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.7))
                .padding(.vertical, 12)
        }
        .background(config.backgroundColor.ignoresSafeArea())
    }

    private var toolbar: some View {
        HStack {
            Button(config.cancelButtonTitle) {
                dismiss()
            }
            .font(config.cancelButtonFont)
            .foregroundColor(config.cancelButtonColor)

            Spacer()

            Text(config.title)
                .font(config.titleFont)
                .foregroundColor(config.titleColor)

            Spacer()

            Button(config.cropButtonTitle) {
                crop()
            }
            .font(config.cropButtonFont)
            .foregroundColor(config.cropButtonColor)
        }
        .padding()
    }

    private var cropArea: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size
            let cropSide = maskShape.sideLength(in: containerSize)
            let totalScale = max(finalScale * currentScale, 1)
            let totalOffset = CGSize(
                width: finalOffset.width + currentOffset.width,
                height: finalOffset.height + currentOffset.height
            )

            ZStack {
                Color.black

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(totalScale)
                    .offset(totalOffset)
                    .frame(width: containerSize.width, height: containerSize.height)

                cropGuide(side: cropSide)
            }
            .clipped()
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .simultaneousGesture(magnificationGesture)
            .onAppear {
                cropContainerSize = containerSize
            }
            .onChange(of: containerSize) { _, newSize in
                cropContainerSize = newSize
            }
        }
    }

    private func cropGuide(side: CGFloat) -> some View {
        Rectangle()
            .stroke(Color.white, lineWidth: 3)
            .background(Color.white.opacity(0.08))
            .frame(width: side, height: side)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                currentOffset = value.translation
            }
            .onEnded { value in
                finalOffset.width += value.translation.width
                finalOffset.height += value.translation.height
                currentOffset = .zero
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                currentScale = value
            }
            .onEnded { value in
                finalScale = max(finalScale * value, 1)
                currentScale = 1
            }
    }

    private func crop() {
        guard cropContainerSize.width > 0, cropContainerSize.height > 0 else {
            config.onCrop(image.centerSquareCropped())
            dismiss()
            return
        }

        let totalScale = max(finalScale * currentScale, 1)
        let totalOffset = CGSize(
            width: finalOffset.width + currentOffset.width,
            height: finalOffset.height + currentOffset.height
        )

        let baseScale = min(
            cropContainerSize.width / image.size.width,
            cropContainerSize.height / image.size.height
        )
        let displayScale = baseScale * totalScale
        let displayedSize = CGSize(
            width: image.size.width * displayScale,
            height: image.size.height * displayScale
        )

        let imageOriginInView = CGPoint(
            x: (cropContainerSize.width - displayedSize.width) / 2 + totalOffset.width,
            y: (cropContainerSize.height - displayedSize.height) / 2 + totalOffset.height
        )
        let cropSide = maskShape.sideLength(in: cropContainerSize)
        let cropOriginInView = CGPoint(
            x: (cropContainerSize.width - cropSide) / 2,
            y: (cropContainerSize.height - cropSide) / 2
        )

        let cropRect = CGRect(
            x: (cropOriginInView.x - imageOriginInView.x) / displayScale,
            y: (cropOriginInView.y - imageOriginInView.y) / displayScale,
            width: cropSide / displayScale,
            height: cropSide / displayScale
        )
        .intersection(CGRect(origin: .zero, size: image.size))

        guard let croppedImage = image.crop(to: cropRect) else {
            config.onCrop(image.centerSquareCropped())
            dismiss()
            return
        }

        config.onCrop(croppedImage)
        dismiss()
    }
}

struct SwiftyCropConfig {
    var title: String
    var titleFont: Font
    var titleColor: Color
    var backgroundColor: Color
    var cropButtonTitle: String
    var cropButtonFont: Font
    var cropButtonColor: Color
    var cancelButtonTitle: String
    var cancelButtonFont: Font
    var cancelButtonColor: Color
    var onCrop: (UIImage?) -> Void

    init(
        title: String = "裁剪照片",
        titleFont: Font = .headline,
        titleColor: Color = .white,
        backgroundColor: Color = .black,
        cropButtonTitle: String = "完成",
        cropButtonFont: Font = .body,
        cropButtonColor: Color = .blue,
        cancelButtonTitle: String = "取消",
        cancelButtonFont: Font = .body,
        cancelButtonColor: Color = .red,
        onCrop: @escaping (UIImage?) -> Void
    ) {
        self.title = title
        self.titleFont = titleFont
        self.titleColor = titleColor
        self.backgroundColor = backgroundColor
        self.cropButtonTitle = cropButtonTitle
        self.cropButtonFont = cropButtonFont
        self.cropButtonColor = cropButtonColor
        self.cancelButtonTitle = cancelButtonTitle
        self.cancelButtonFont = cancelButtonFont
        self.cancelButtonColor = cancelButtonColor
        self.onCrop = onCrop
    }
}

enum MaskShape {
    case circle
    case square

    func sideLength(in viewSize: CGSize) -> CGFloat {
        min(viewSize.width, viewSize.height) * 0.82
    }
}

private extension UIImage {
    func normalizedForCropping() -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func crop(to rect: CGRect) -> UIImage? {
        guard !rect.isNull, !rect.isEmpty else {
            return nil
        }

        let integralRect = CGRect(
            x: rect.origin.x.rounded(.down),
            y: rect.origin.y.rounded(.down),
            width: rect.width.rounded(.down),
            height: rect.height.rounded(.down)
        )

        guard let cgImage = cgImage?.cropping(to: integralRect) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    func centerSquareCropped() -> UIImage {
        let side = min(size.width, size.height)
        let rect = CGRect(
            x: (size.width - side) / 2,
            y: (size.height - side) / 2,
            width: side,
            height: side
        )

        return crop(to: rect) ?? self
    }
}
