//
//  FaceAnalyzer.swift
//  CameraTest
//
//  Finds faces and their landmarks with the Vision framework (on device).
//  All points are normalized to the whole image (0…1) with the origin at the
//  bottom-left, which matches Core Image coordinates.
//

import CoreGraphics
import Vision

nonisolated struct FaceInfo: Sendable {
    var bounds: CGRect
    var faceContour: [CGPoint]
    var leftEye: [CGPoint]
    var rightEye: [CGPoint]
    var leftEyebrow: [CGPoint]
    var rightEyebrow: [CGPoint]
    var nose: [CGPoint]
    var outerLips: [CGPoint]
    var leftPupil: CGPoint?
    var rightPupil: CGPoint?

    var eyes: [[CGPoint]] { [leftEye, rightEye].filter { !$0.isEmpty } }
    var eyebrows: [[CGPoint]] { [leftEyebrow, rightEyebrow].filter { !$0.isEmpty } }
}

nonisolated enum FaceAnalyzer {
    static func detectFaces(in cgImage: CGImage) -> [FaceInfo] {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Face detection failed: \(error.localizedDescription)")
            return []
        }
        guard let observations = request.results else { return [] }

        return observations.map { observation in
            let box = observation.boundingBox
            let landmarks = observation.landmarks

            func points(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
                guard let region else { return [] }
                return region.normalizedPoints.map { p in
                    CGPoint(x: box.minX + p.x * box.width,
                            y: box.minY + p.y * box.height)
                }
            }

            return FaceInfo(
                bounds: box,
                faceContour: points(landmarks?.faceContour),
                leftEye: points(landmarks?.leftEye),
                rightEye: points(landmarks?.rightEye),
                leftEyebrow: points(landmarks?.leftEyebrow),
                rightEyebrow: points(landmarks?.rightEyebrow),
                nose: points(landmarks?.nose),
                outerLips: points(landmarks?.outerLips),
                leftPupil: points(landmarks?.leftPupil).first,
                rightPupil: points(landmarks?.rightPupil).first
            )
        }
    }
}

// MARK: - Small geometry helpers

nonisolated enum Geo {
    static func centroid(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }

    static func width(_ points: [CGPoint]) -> CGFloat {
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max() else { return 0 }
        return maxX - minX
    }

    static func height(_ points: [CGPoint]) -> CGFloat {
        guard let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else { return 0 }
        return maxY - minY
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
