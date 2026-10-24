//
//  BeautyParameters.swift
//  CameraTest
//
//  All editable values of the AI beauty editor. Every value is on a 0–100 scale
//  unless noted (调整 sliders that can go both ways use -100…100).
//

import Foundation

nonisolated struct BeautyParameters: Equatable, Sendable {
    // AI 美化
    var aiIntensity: Double = 50

    // 美颜 · 肌肤
    var smoothing: Double = 0     // 磨皮
    var whitening: Double = 0     // 美白
    var rosy: Double = 0          // 红润
    var acne: Double = 0          // 祛痘
    var darkCircles: Double = 0   // 黑眼圈

    // 美颜 · 美型
    var slimFace: Double = 0      // 瘦脸
    var bigEyes: Double = 0       // 大眼
    var nose: Double = 0          // 鼻型 (narrower nose)
    var chin: Double = 0          // 下巴 (longer, slimmer chin)

    // 调整
    var brightness: Double = 0    // -100…100
    var contrast: Double = 0      // -100…100
    var saturation: Double = 0    // -100…100
    var warmth: Double = 0        // -100…100
    var sharpen: Double = 0       // 0…100
    var vignette: Double = 0      // 0…100

    // 滤镜
    var filter: FilterPreset = .original
    var filterIntensity: Double = 100

    /// The values that need the (slower) pixel warp to be recomputed.
    var shapeKey: ShapeKey {
        ShapeKey(slimFace: slimFace, nose: nose, chin: chin)
    }
}

nonisolated struct ShapeKey: Equatable, Sendable {
    var slimFace: Double
    var nose: Double
    var chin: Double
}
