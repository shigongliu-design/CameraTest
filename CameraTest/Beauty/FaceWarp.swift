//
//  FaceWarp.swift
//  CameraTest
//
//  A small "liquify" warp used for 瘦脸 / 鼻型 / 下巴.
//  Each WarpOp moves the content around `center` by `vector`, fading out
//  smoothly to zero at `radius`. Coordinates are pixels, origin top-left.
//  Only the area touched by the ops is processed, so it stays fast.
//

import CoreGraphics
import Foundation

nonisolated struct WarpOp: Sendable {
    var center: CGPoint
    var vector: CGVector
    var radius: CGFloat
}

nonisolated enum FaceWarp {
    static func apply(_ ops: [WarpOp], to image: CGImage) -> CGImage? {
        let ops = ops.filter { $0.radius > 1 && (abs($0.vector.dx) > 0.01 || abs($0.vector.dy) > 0.01) }
        guard !ops.isEmpty else { return image }

        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        // Decode into an RGBA buffer (row 0 = top of the image).
        var source = [UInt8](repeating: 0, count: height * bytesPerRow)
        let decoded: Bool = source.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow,
                                          space: colorSpace,
                                          bitmapInfo: bitmapInfo) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard decoded else { return nil }

        var output = source

        // Only process the area the ops can reach.
        var minX = CGFloat.greatestFiniteMagnitude, minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        for op in ops {
            minX = min(minX, op.center.x - op.radius)
            minY = min(minY, op.center.y - op.radius)
            maxX = max(maxX, op.center.x + op.radius)
            maxY = max(maxY, op.center.y + op.radius)
        }
        let x0 = max(0, Int(minX.rounded(.down)))
        let y0 = max(0, Int(minY.rounded(.down)))
        let x1 = min(width - 1, Int(maxX.rounded(.up)))
        let y1 = min(height - 1, Int(maxY.rounded(.up)))
        guard x0 <= x1, y0 <= y1 else { return image }

        struct PackedOp { var cx: Float; var cy: Float; var dx: Float; var dy: Float; var r2: Float }
        let packed = ops.map {
            PackedOp(cx: Float($0.center.x), cy: Float($0.center.y),
                     dx: Float($0.vector.dx), dy: Float($0.vector.dy),
                     r2: Float($0.radius * $0.radius))
        }

        source.withUnsafeBytes { srcBuffer in
            output.withUnsafeMutableBytes { dstBuffer in
                guard let src = srcBuffer.bindMemory(to: UInt8.self).baseAddress,
                      let dst = dstBuffer.bindMemory(to: UInt8.self).baseAddress else { return }
                let maxXf = Float(width - 1)
                let maxYf = Float(height - 1)

                for y in y0...y1 {
                    let py = Float(y)
                    for x in x0...x1 {
                        let px = Float(x)
                        var dx: Float = 0
                        var dy: Float = 0
                        var reach: Float = 0
                        for op in packed {
                            let ox = px - op.cx
                            let oy = py - op.cy
                            let dist2 = ox * ox + oy * oy
                            if dist2 < op.r2 {
                                let t = 1 - dist2 / op.r2
                                let falloff = t * t
                                dx += falloff * op.dx
                                dy += falloff * op.dy
                                reach = max(reach, op.r2)
                            }
                        }
                        if dx == 0 && dy == 0 { continue }

                        // Overlapping ops add up; cap the move at 20% of the radius so
                        // the image never folds over itself (the "melted" look).
                        let maxMove = 0.2 * reach.squareRoot()
                        let move = (dx * dx + dy * dy).squareRoot()
                        if move > maxMove {
                            dx *= maxMove / move
                            dy *= maxMove / move
                        }

                        // Inverse mapping: this output pixel shows the content from (p - d).
                        let sx = min(max(px - dx, 0), maxXf)
                        let sy = min(max(py - dy, 0), maxYf)
                        let ix = Int(sx), iy = Int(sy)
                        let ix1 = min(ix + 1, width - 1), iy1 = min(iy + 1, height - 1)
                        let fx = sx - Float(ix), fy = sy - Float(iy)
                        let w00 = (1 - fx) * (1 - fy), w10 = fx * (1 - fy)
                        let w01 = (1 - fx) * fy, w11 = fx * fy
                        let i00 = iy * bytesPerRow + ix * 4
                        let i10 = iy * bytesPerRow + ix1 * 4
                        let i01 = iy1 * bytesPerRow + ix * 4
                        let i11 = iy1 * bytesPerRow + ix1 * 4
                        let o = y * bytesPerRow + x * 4
                        for c in 0..<4 {
                            let v = Float(src[i00 + c]) * w00 + Float(src[i10 + c]) * w10
                                  + Float(src[i01 + c]) * w01 + Float(src[i11 + c]) * w11
                            dst[o + c] = UInt8(min(max(v + 0.5, 0), 255))
                        }
                    }
                }
            }
        }

        guard let provider = CGDataProvider(data: Data(output) as CFData) else { return nil }
        return CGImage(width: width,
                       height: height,
                       bitsPerComponent: 8,
                       bitsPerPixel: 32,
                       bytesPerRow: bytesPerRow,
                       space: colorSpace,
                       bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                       provider: provider,
                       decode: nil,
                       shouldInterpolate: true,
                       intent: .defaultIntent)
    }
}
