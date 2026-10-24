//
//  FilterPreset.swift
//  CameraTest
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

nonisolated enum FilterPreset: String, CaseIterable, Identifiable, Sendable {
    case original, fresh, warm, cool, film, vintage, mono, vivid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original: return "原图"
        case .fresh: return "清新"
        case .warm: return "暖阳"
        case .cool: return "冷调"
        case .film: return "胶片"
        case .vintage: return "复古"
        case .mono: return "黑白"
        case .vivid: return "浓郁"
        }
    }

    /// intensity 0…1
    func apply(to image: CIImage, intensity: Double) -> CIImage {
        guard self != .original, intensity > 0 else { return image }
        return ImageOps.mix(image, filtered(image), intensity)
    }

    private func filtered(_ image: CIImage) -> CIImage {
        switch self {
        case .original:
            return image
        case .fresh:
            let bright = ImageOps.colorControls(image, brightness: 0.03, contrast: 0.95, saturation: 1.1)
            return ImageOps.warmth(bright, -0.05)
        case .warm:
            return ImageOps.colorControls(ImageOps.warmth(image, 0.1), brightness: 0.01, contrast: 1.02, saturation: 1.05)
        case .cool:
            return ImageOps.colorControls(ImageOps.warmth(image, -0.1), saturation: 0.95)
        case .film:
            return image.applyingFilter("CIPhotoEffectInstant")
        case .vintage:
            let sepia = CIFilter.sepiaTone()
            sepia.inputImage = image
            sepia.intensity = 0.55
            let vignette = CIFilter.vignette()
            vignette.inputImage = sepia.outputImage ?? image
            vignette.intensity = 0.8
            vignette.radius = 2
            return vignette.outputImage ?? image
        case .mono:
            return image.applyingFilter("CIPhotoEffectMono")
        case .vivid:
            return ImageOps.colorControls(image, contrast: 1.08, saturation: 1.35)
        }
    }
}
