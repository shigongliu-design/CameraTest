//
//  BeautyEngine.swift
//  CameraTest
//
//  On-device beauty pipeline (Vision + Core Image, no network):
//    美型 warp (瘦脸 / 鼻型 / 下巴) → 大眼 → 肌肤 (磨皮 / 祛痘 / 美白 / 红润 / 黑眼圈)
//    → AI 美化 → 调整 → 滤镜
//
//  Editing runs on a downscaled preview; saving re-runs the same pipeline on
//  the full-size photo. Create and use it off the main thread.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit

nonisolated final class BeautyEngine: @unchecked Sendable {
    let fullImage: CGImage
    let previewImage: CGImage
    let faces: [FaceInfo]

    private let context = CIContext(options: [.cacheIntermediates: false])
    private let lock = NSLock()
    private var cachedShapeKey: ShapeKey?
    private var cachedWarpedPreview: CIImage?
    private lazy var autoFilters: [CIFilter] = CIImage(cgImage: previewImage)
        .autoAdjustmentFilters(options: [.redEye: false])

    init?(image: UIImage, previewMaxDimension: CGFloat = 1440, fullMaxDimension: CGFloat = 4096) {
        guard let upright = BeautyEngine.uprightCGImage(image) else { return nil }
        fullImage = BeautyEngine.downscale(upright, maxDimension: fullMaxDimension)
        previewImage = BeautyEngine.downscale(upright, maxDimension: previewMaxDimension)
        faces = FaceAnalyzer.detectFaces(in: previewImage)
    }

    var hasFaces: Bool { !faces.isEmpty }

    // MARK: - Rendering

    func render(_ p: BeautyParameters, fullResolution: Bool = false) -> CGImage? {
        lock.lock()
        defer { lock.unlock() }

        let base = fullResolution ? fullImage : previewImage
        let size = CGSize(width: base.width, height: base.height)
        let extent = CGRect(origin: .zero, size: size)

        // 1. 美型 warp (cached for the preview, since it is the slowest step)
        var image: CIImage
        if !fullResolution, let cached = cachedWarpedPreview, cachedShapeKey == p.shapeKey {
            image = cached
        } else {
            let warped = FaceWarp.apply(warpOps(p, size: size), to: base) ?? base
            image = CIImage(cgImage: warped)
            if !fullResolution {
                cachedWarpedPreview = image
                cachedShapeKey = p.shapeKey
            }
        }

        // 2. 大眼
        image = applyBigEyes(image, strength: p.bigEyes / 100, size: size)

        // 3. 肌肤
        if hasFaces {
            let faceScale = largestFaceWidth(size: size)
            let face = faceMask(size: size)
            let skin = ImageOps.multiply(face, ImageOps.invert(featureMask(size: size)))
            image = smoothSkin(image, strength: p.smoothing / 100, skinMask: skin, faceScale: faceScale, extent: extent)
            image = removeBlemishes(image, strength: p.acne / 100, skinMask: skin, faceScale: faceScale, extent: extent)
            image = whiten(image, strength: p.whitening / 100, faceMask: face)
            image = rosy(image, strength: p.rosy / 100, skinMask: skin)
            image = reduceDarkCircles(image, strength: p.darkCircles / 100, size: size)
        }

        // 4. AI 美化
        image = applyAIBeauty(image, strength: p.aiIntensity / 100, size: size, extent: extent)

        // 5. 调整
        image = applyAdjustments(image, p, extent: extent)

        // 6. 滤镜
        image = p.filter.apply(to: image, intensity: p.filterIntensity / 100)

        return context.createCGImage(image.cropped(to: extent), from: extent)
    }

    /// Small previews of every filter, for the 滤镜 strip.
    func filterThumbnails(maxDimension: CGFloat = 160) -> [FilterPreset: CGImage] {
        lock.lock()
        defer { lock.unlock() }
        let small = BeautyEngine.downscale(previewImage, maxDimension: maxDimension)
        let input = CIImage(cgImage: small)
        var result: [FilterPreset: CGImage] = [:]
        for preset in FilterPreset.allCases {
            let output = preset.apply(to: input, intensity: 1).cropped(to: input.extent)
            if let cg = context.createCGImage(output, from: input.extent) {
                result[preset] = cg
            }
        }
        return result
    }

    // MARK: - 美型

    private func warpOps(_ p: BeautyParameters, size: CGSize) -> [WarpOp] {
        var ops: [WarpOp] = []
        // Vision points are bottom-left normalized; the warp works in top-left pixels.
        func px(_ n: CGPoint) -> CGPoint { CGPoint(x: n.x * size.width, y: (1 - n.y) * size.height) }

        for face in faces {
            let fw = face.bounds.width * size.width
            let fh = face.bounds.height * size.height
            let cx = face.bounds.midX * size.width
            let contour = face.faceContour.map(px)

            // 瘦脸: pull both sides of the jaw gently toward the middle of the face.
            // Small moves spread over a wide radius look natural; big local moves look warped.
            if p.slimFace > 0, contour.count >= 5,
               let topY = contour.map(\.y).min(), let bottomY = contour.map(\.y).max() {
                let s = CGFloat(p.slimFace / 100)
                for side: CGFloat in [-1, 1] {
                    let sidePoints = contour.filter { ($0.x - cx) * side > fw * 0.12 }
                    guard !sidePoints.isEmpty else { continue }
                    var used = Set<Int>()
                    for fraction: CGFloat in [0.4, 0.55, 0.7, 0.85] {
                        let targetY = topY + (bottomY - topY) * fraction
                        guard let index = sidePoints.indices.min(by: {
                            abs(sidePoints[$0].y - targetY) < abs(sidePoints[$1].y - targetY)
                        }), !used.contains(index) else { continue }
                        used.insert(index)
                        ops.append(WarpOp(center: sidePoints[index],
                                          vector: CGVector(dx: -side * fw * 0.014 * s, dy: 0),
                                          radius: fw * 0.3))
                    }
                }
            }

            // 鼻型: push the nostril wings toward the nose's center line.
            if p.nose > 0, face.nose.count >= 3 {
                let nose = face.nose.map(px)
                let noseWidth = Geo.width(nose)
                let s = CGFloat(p.nose / 100)
                if noseWidth > 2,
                   let left = nose.min(by: { $0.x < $1.x }),
                   let right = nose.max(by: { $0.x < $1.x }) {
                    ops.append(WarpOp(center: left, vector: CGVector(dx: noseWidth * 0.16 * s, dy: 0), radius: noseWidth * 0.6))
                    ops.append(WarpOp(center: right, vector: CGVector(dx: -noseWidth * 0.16 * s, dy: 0), radius: noseWidth * 0.6))
                }
            }

            // 下巴: lengthen the chin a little and slim its sides, with soft falloff.
            if p.chin > 0, let tip = contour.max(by: { $0.y < $1.y }) {
                let s = CGFloat(p.chin / 100)
                ops.append(WarpOp(center: CGPoint(x: tip.x, y: tip.y - fh * 0.1),
                                  vector: CGVector(dx: 0, dy: fh * 0.022 * s),
                                  radius: fh * 0.3))
                for side: CGFloat in [-1, 1] {
                    let target = CGPoint(x: tip.x + side * fw * 0.2, y: tip.y - fh * 0.05)
                    if let point = contour.min(by: { Geo.distance($0, target) < Geo.distance($1, target) }) {
                        ops.append(WarpOp(center: point,
                                          vector: CGVector(dx: -side * fw * 0.012 * s, dy: 0),
                                          radius: fw * 0.22))
                    }
                }
            }
        }
        return ops
    }

    private func applyBigEyes(_ image: CIImage, strength s: Double, size: CGSize) -> CIImage {
        guard s > 0 else { return image }
        var output = image
        for face in faces {
            let eyes: [(pupil: CGPoint?, outline: [CGPoint])] = [(face.leftPupil, face.leftEye), (face.rightPupil, face.rightEye)]
            for eye in eyes where !eye.outline.isEmpty {
                let center = eye.pupil ?? Geo.centroid(eye.outline)
                let eyeWidth = Geo.width(eye.outline) * size.width
                guard eyeWidth > 2 else { continue }
                let bump = CIFilter.bumpDistortion()
                bump.inputImage = output
                bump.center = CGPoint(x: center.x * size.width, y: center.y * size.height)
                bump.radius = Float(eyeWidth * 1.4)
                bump.scale = Float(0.35 * s)
                output = bump.outputImage ?? output
            }
        }
        return output
    }

    // MARK: - Masks (Core Image coordinates: pixels, origin bottom-left)

    private func largestFaceWidth(size: CGSize) -> CGFloat {
        (faces.map { $0.bounds.width }.max() ?? 0.3) * size.width
    }

    /// White over each face (forehead to chin).
    private func faceMask(size: CGSize) -> CIImage {
        var mask = ImageOps.blackMask
        for face in faces {
            let rect = CGRect(x: face.bounds.minX * size.width, y: face.bounds.minY * size.height,
                              width: face.bounds.width * size.width, height: face.bounds.height * size.height)
            let ellipse = ImageOps.ellipseMask(center: CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.05),
                                               radiusX: rect.width * 0.62,
                                               radiusY: rect.height * 0.72,
                                               feather: 0.6)
            mask = ImageOps.maximum(ellipse, mask)
        }
        return mask
    }

    /// White over eyes, eyebrows and lips, so smoothing keeps them sharp.
    private func featureMask(size: CGSize) -> CIImage {
        var mask = ImageOps.blackMask
        func add(_ points: [CGPoint], rx: CGFloat, ry: CGFloat) {
            guard !points.isEmpty else { return }
            let c = Geo.centroid(points)
            let w = Geo.width(points) * size.width
            mask = ImageOps.maximum(ImageOps.ellipseMask(center: CGPoint(x: c.x * size.width, y: c.y * size.height),
                                                         radiusX: w * rx, radiusY: w * ry, feather: 0.5), mask)
        }
        for face in faces {
            face.eyes.forEach { add($0, rx: 0.9, ry: 0.6) }
            face.eyebrows.forEach { add($0, rx: 0.65, ry: 0.32) }
            add(face.outerLips, rx: 0.68, ry: 0.42)
        }
        return mask
    }

    // MARK: - 肌肤

    private func smoothSkin(_ image: CIImage, strength s: Double, skinMask: CIImage, faceScale: CGFloat, extent: CGRect) -> CIImage {
        guard s > 0 else { return image }
        let smooth = ImageOps.blur(image, sigma: Double(faceScale) * 0.012, extent: extent)
        // Keep a little texture even at 100 so skin doesn't look plastic.
        return ImageOps.blend(smooth, over: image, mask: ImageOps.scaleMask(skinMask, by: s * 0.85))
    }

    private func removeBlemishes(_ image: CIImage, strength s: Double, skinMask: CIImage, faceScale: CGFloat, extent: CGRect) -> CIImage {
        guard s > 0 else { return image }
        // Spots are darker than their surroundings: lighten-blend with a local average.
        let local = ImageOps.blur(image, sigma: Double(faceScale) * 0.008, extent: extent)
        let cleared = local.applyingFilter("CILightenBlendMode", parameters: [kCIInputBackgroundImageKey: image])
        return ImageOps.blend(cleared, over: image, mask: ImageOps.scaleMask(skinMask, by: s))
    }

    private func whiten(_ image: CIImage, strength s: Double, faceMask: CIImage) -> CIImage {
        guard s > 0 else { return image }
        let bright = ImageOps.colorControls(ImageOps.exposure(image, ev: 0.35), brightness: 0.03, saturation: 0.88)
        return ImageOps.blend(bright, over: image, mask: ImageOps.scaleMask(faceMask, by: s))
    }

    private func rosy(_ image: CIImage, strength s: Double, skinMask: CIImage) -> CIImage {
        guard s > 0 else { return image }
        let warm = ImageOps.colorControls(ImageOps.colorMatrix(image, r: 1.07, g: 0.98, b: 0.97), saturation: 1.08)
        return ImageOps.blend(warm, over: image, mask: ImageOps.scaleMask(skinMask, by: s))
    }

    private func reduceDarkCircles(_ image: CIImage, strength s: Double, size: CGSize) -> CIImage {
        guard s > 0 else { return image }
        var mask = ImageOps.blackMask
        for face in faces {
            for eye in face.eyes {
                let c = Geo.centroid(eye)
                let w = Geo.width(eye) * size.width
                guard w > 2 else { continue }
                let center = CGPoint(x: c.x * size.width, y: c.y * size.height - w * 0.42)
                mask = ImageOps.maximum(ImageOps.ellipseMask(center: center, radiusX: w * 0.6, radiusY: w * 0.28, feather: 0.35), mask)
            }
        }
        let shadows = CIFilter.highlightShadowAdjust()
        shadows.inputImage = image
        shadows.shadowAmount = 1
        let lifted = ImageOps.exposure(shadows.outputImage ?? image, ev: 0.25)
        return ImageOps.blend(lifted, over: image, mask: ImageOps.scaleMask(mask, by: s))
    }

    // MARK: - AI 美化

    /// One-tap enhancement: auto light & color, plus gentle skin smoothing and
    /// brightening on faces. 0 = original, 50 = natural, 100 = strong.
    private func applyAIBeauty(_ image: CIImage, strength s: Double, size: CGSize, extent: CGRect) -> CIImage {
        guard s > 0 else { return image }
        var enhanced = image
        for filter in autoFilters {
            filter.setValue(enhanced, forKey: kCIInputImageKey)
            enhanced = filter.outputImage ?? enhanced
        }
        if hasFaces {
            let faceScale = largestFaceWidth(size: size)
            let face = faceMask(size: size)
            let skin = ImageOps.multiply(face, ImageOps.invert(featureMask(size: size)))
            enhanced = smoothSkin(enhanced, strength: 0.5, skinMask: skin, faceScale: faceScale, extent: extent)
            enhanced = whiten(enhanced, strength: 0.3, faceMask: face)
        }
        enhanced = ImageOps.vibrance(enhanced, 0.3)
        return ImageOps.mix(image, enhanced, s)
    }

    // MARK: - 调整

    private func applyAdjustments(_ image: CIImage, _ p: BeautyParameters, extent: CGRect) -> CIImage {
        var output = image
        if p.brightness != 0 || p.contrast != 0 || p.saturation != 0 {
            output = ImageOps.colorControls(output,
                                            brightness: p.brightness / 100 * 0.25,
                                            contrast: 1 + p.contrast / 100 * 0.5,
                                            saturation: 1 + p.saturation / 100)
        }
        if p.warmth != 0 {
            output = ImageOps.warmth(output, p.warmth / 100 * 0.15)
        }
        if p.sharpen > 0 {
            let sharpen = CIFilter.sharpenLuminance()
            sharpen.inputImage = output
            sharpen.sharpness = Float(p.sharpen / 100 * 1.2)
            output = sharpen.outputImage ?? output
        }
        if p.vignette > 0 {
            let vignette = CIFilter.vignette()
            vignette.inputImage = output
            vignette.intensity = Float(p.vignette / 100 * 1.5)
            vignette.radius = 2
            output = vignette.outputImage ?? output
        }
        return output.cropped(to: extent)
    }

    // MARK: - Image helpers

    /// Redraws the photo so its pixels are upright (no EXIF rotation left).
    static func uprightCGImage(_ image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cg = image.cgImage { return cg }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.cgImage
    }

    static func downscale(_ image: CGImage, maxDimension: CGFloat) -> CGImage {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let scale = min(1, maxDimension / max(w, h))
        guard scale < 1 else { return image }
        let newWidth = max(1, Int((w * scale).rounded()))
        let newHeight = max(1, Int((h * scale).rounded()))
        guard let context = CGContext(data: nil,
                                      width: newWidth,
                                      height: newHeight,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage() ?? image
    }
}
