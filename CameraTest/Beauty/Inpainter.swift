//
//  Inpainter.swift
//  CameraTest
//
//  消除: on-device object removal with the LaMa Core ML model.
//
//  Setup (one time): download LaMa.mlpackage from
//  https://huggingface.co/mlboydaisuke/LaMa-CoreML and drag it into the
//  CameraTest folder in Xcode. Xcode compiles it to LaMa.mlmodelc at build time.
//  Model I/O: image (RGB 800×800), mask (gray 800×800, white = remove) → output (RGB 800×800).
//
//  Only a square area around the brushed region is sent to the model, then the
//  result is blended back with a soft edge, so the rest of the photo keeps full quality.
//

import CoreGraphics
import CoreImage
import CoreML
import Foundation
import Vision

nonisolated final class Inpainter: @unchecked Sendable {
    static let shared = Inpainter()

    enum InpaintError: LocalizedError {
        case modelMissing
        case predictionFailed

        var errorDescription: String? {
            switch self {
            case .modelMissing:
                return "未找到消除模型。请把 LaMa.mlpackage 拖进 Xcode 项目后重新运行。"
            case .predictionFailed:
                return "消除失败，请重试。"
            }
        }
    }

    private var model: MLModel?
    private let lock = NSLock()
    private let context = CIContext(options: [.cacheIntermediates: false])

    private let imageInputName = "image"
    private let maskInputName = "mask"
    private let outputName = "output"

    var isModelAvailable: Bool {
        Bundle.main.url(forResource: "LaMa", withExtension: "mlmodelc") != nil
    }

    private func loadModel() throws -> MLModel {
        if let model { return model }
        guard let url = Bundle.main.url(forResource: "LaMa", withExtension: "mlmodelc") else {
            throw InpaintError.modelMissing
        }
        let config = MLModelConfiguration()
        config.computeUnits = .all // the configuration the conversion was verified with
        let loaded = try MLModel(contentsOf: url, configuration: config)
        model = loaded
        return loaded
    }

    /// Removes the white area of `mask` (same pixel size as `image`) and returns the filled photo.
    func inpaint(image: CGImage, mask: CGImage) throws -> CGImage {
        lock.lock()
        defer { lock.unlock() }

        let model = try loadModel()
        let width = image.width, height = image.height

        // 1. Grow the mask a little so object edges and shadows go too.
        let maskCI = CIImage(cgImage: mask)
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 6])
            .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        guard let grownMask = context.createCGImage(maskCI, from: maskCI.extent) else {
            throw InpaintError.predictionFailed
        }

        // 2. Find the brushed area (top-left pixel coordinates).
        guard let box = Inpainter.whiteBoundingBox(of: grownMask) else { return image }

        // 3. A square crop around it with plenty of context for the model.
        let crop = Inpainter.contextCrop(around: box, imageWidth: width, imageHeight: height)
        guard let imageCrop = image.cropping(to: crop),
              let maskCrop = grownMask.cropping(to: crop) else {
            throw InpaintError.predictionFailed
        }

        // 4. Run LaMa.
        let inputs = model.modelDescription.inputDescriptionsByName
        guard let imageConstraint = inputs[imageInputName]?.imageConstraint,
              let maskConstraint = inputs[maskInputName]?.imageConstraint else {
            throw InpaintError.predictionFailed
        }
        let options: [MLFeatureValue.ImageOption: Any] = [
            .cropAndScale: VNImageCropAndScaleOption.scaleFill.rawValue
        ]
        let imageValue = try MLFeatureValue(cgImage: imageCrop, constraint: imageConstraint, options: options)
        let maskValue = try MLFeatureValue(cgImage: maskCrop, constraint: maskConstraint, options: options)
        let provider = try MLDictionaryFeatureProvider(dictionary: [
            imageInputName: imageValue,
            maskInputName: maskValue
        ])
        let prediction = try model.prediction(from: provider)
        guard let buffer = prediction.featureValue(for: outputName)?.imageBufferValue else {
            throw InpaintError.predictionFailed
        }

        // 5. Scale the result back over the crop (Core Image is bottom-left origin).
        let filled = CIImage(cvPixelBuffer: buffer)
        let ciCropY = CGFloat(height) - crop.maxY
        let placed = filled
            .transformed(by: CGAffineTransform(scaleX: crop.width / filled.extent.width,
                                               y: crop.height / filled.extent.height))
            .transformed(by: CGAffineTransform(translationX: crop.minX, y: ciCropY))

        // 6. Blend into the full photo with a feathered mask.
        let fullExtent = CGRect(x: 0, y: 0, width: width, height: height)
        let softMask = CIImage(cgImage: grownMask)
            .clampedToExtent()
            .applyingGaussianBlur(sigma: 4)
            .cropped(to: fullExtent)
        let result = placed.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage(cgImage: image),
            kCIInputMaskImageKey: softMask
        ])
        guard let output = context.createCGImage(result.cropped(to: fullExtent), from: fullExtent) else {
            throw InpaintError.predictionFailed
        }
        return output
    }

    // MARK: - Helpers

    /// Bounding box of pixels brighter than 50%, in top-left pixel coordinates.
    static func whiteBoundingBox(of mask: CGImage) -> CGRect? {
        let width = mask.width, height = mask.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(data: buffer.baseAddress, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.draw(mask, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            let row = y * width
            for x in 0..<width where pixels[row + x] > 127 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// A square (when the photo allows) about twice the size of the box, kept inside the photo.
    static func contextCrop(around box: CGRect, imageWidth: Int, imageHeight: Int) -> CGRect {
        let w = CGFloat(imageWidth), h = CGFloat(imageHeight)
        var side = max(box.width, box.height) * 2
        side = max(side, min(512, min(w, h)))
        let cropW = min(side, w), cropH = min(side, h)
        var x = box.midX - cropW / 2
        var y = box.midY - cropH / 2
        x = min(max(0, x), w - cropW)
        y = min(max(0, y), h - cropH)
        return CGRect(x: x, y: y, width: cropW, height: cropH).integral
            .intersection(CGRect(x: 0, y: 0, width: w, height: h))
    }
}
