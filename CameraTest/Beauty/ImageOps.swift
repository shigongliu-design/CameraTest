//
//  ImageOps.swift
//  CameraTest
//
//  Small Core Image building blocks shared by the beauty engine and filters.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

nonisolated enum ImageOps {
    static func colorControls(_ image: CIImage, brightness: Double = 0, contrast: Double = 1, saturation: Double = 1) -> CIImage {
        let f = CIFilter.colorControls()
        f.inputImage = image
        f.brightness = Float(brightness)
        f.contrast = Float(contrast)
        f.saturation = Float(saturation)
        return f.outputImage ?? image
    }

    /// amount > 0 warms (more red, less blue), amount < 0 cools. Roughly -0.2…0.2.
    static func warmth(_ image: CIImage, _ amount: Double) -> CIImage {
        guard amount != 0 else { return image }
        return colorMatrix(image, r: 1 + amount, g: 1 + amount * 0.15, b: 1 - amount)
    }

    static func colorMatrix(_ image: CIImage, r: Double, g: Double, b: Double) -> CIImage {
        let f = CIFilter.colorMatrix()
        f.inputImage = image
        f.rVector = CIVector(x: CGFloat(r), y: 0, z: 0, w: 0)
        f.gVector = CIVector(x: 0, y: CGFloat(g), z: 0, w: 0)
        f.bVector = CIVector(x: 0, y: 0, z: CGFloat(b), w: 0)
        f.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        return f.outputImage ?? image
    }

    static func exposure(_ image: CIImage, ev: Double) -> CIImage {
        let f = CIFilter.exposureAdjust()
        f.inputImage = image
        f.ev = Float(ev)
        return f.outputImage ?? image
    }

    static func vibrance(_ image: CIImage, _ amount: Double) -> CIImage {
        let f = CIFilter.vibrance()
        f.inputImage = image
        f.amount = Float(amount)
        return f.outputImage ?? image
    }

    static func blur(_ image: CIImage, sigma: Double, extent: CGRect) -> CIImage {
        guard sigma > 0.1 else { return image }
        return image.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: extent)
    }

    /// Cross-fade from `from` (t = 0) to `to` (t = 1).
    static func mix(_ from: CIImage, _ to: CIImage, _ t: Double) -> CIImage {
        if t <= 0 { return from }
        if t >= 1 { return to }
        let f = CIFilter.dissolveTransition()
        f.inputImage = from
        f.targetImage = to
        f.time = Float(t)
        return f.outputImage ?? to
    }

    /// Shows `effect` where the mask is white and `base` where it is black.
    static func blend(_ effect: CIImage, over base: CIImage, mask: CIImage) -> CIImage {
        let f = CIFilter.blendWithMask()
        f.inputImage = effect
        f.backgroundImage = base
        f.maskImage = mask
        return f.outputImage ?? base
    }

    /// Multiplies a grayscale mask by a constant 0…1.
    static func scaleMask(_ mask: CIImage, by s: Double) -> CIImage {
        colorMatrix(mask, r: s, g: s, b: s)
    }

    static func maximum(_ a: CIImage, _ b: CIImage) -> CIImage {
        a.applyingFilter("CIMaximumCompositing", parameters: [kCIInputBackgroundImageKey: b])
    }

    static func multiply(_ a: CIImage, _ b: CIImage) -> CIImage {
        a.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: b])
    }

    static func invert(_ image: CIImage) -> CIImage {
        image.applyingFilter("CIColorInvert")
    }

    /// A soft white ellipse on black. `feather` is the fraction of the radius that stays fully white.
    static func ellipseMask(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat, feather: CGFloat = 0.55) -> CIImage {
        let rx = max(radiusX, 1)
        let g = CIFilter.radialGradient()
        g.center = .zero
        g.radius0 = Float(rx * feather)
        g.radius1 = Float(rx)
        g.color0 = CIColor(red: 1, green: 1, blue: 1)
        g.color1 = CIColor(red: 0, green: 0, blue: 0)
        let transform = CGAffineTransform(scaleX: 1, y: max(radiusY, 1) / rx)
            .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
        return (g.outputImage ?? CIImage(color: CIColor(red: 0, green: 0, blue: 0))).transformed(by: transform)
    }

    static var blackMask: CIImage {
        CIImage(color: CIColor(red: 0, green: 0, blue: 0))
    }
}
