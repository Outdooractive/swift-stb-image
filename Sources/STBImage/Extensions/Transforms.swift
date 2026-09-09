//
//  Created by Thomas Rasch on 27.02.26.
//

// MARK: - Transforms

extension STBImage {

    /// Returns a copy of the image rotated by `quarterTurns * 90°`.
    /// Positive values rotate clockwise.
    public func rotated(quarterTurns: Int) -> STBImage {
        switch ((quarterTurns % 4) + 4) % 4 {
        case 1:
            // 90° clockwise
            return mapped(width: height, height: width) { x, y in
                (x: height - 1 - y, y: x)
            }
        case 2:
            // 180°
            return mapped(width: width, height: height) { x, y in
                (x: width - 1 - x, y: height - 1 - y)
            }
        case 3:
            // 90° counter-clockwise
            return mapped(width: height, height: width) { x, y in
                (x: y, y: width - 1 - x)
            }
        default:
            return self
        }
    }

    /// Returns a copy of the image, mirrored along the vertical axis.
    public func flippedHorizontally() -> STBImage {
        mapped(width: width, height: height) { x, y in
            (x: width - 1 - x, y: y)
        }
    }

    /// Returns a copy of the image, mirrored along the horizontal axis.
    public func flippedVertically() -> STBImage {
        mapped(width: width, height: height) { x, y in
            (x: x, y: height - 1 - y)
        }
    }

    /// Returns a bilinearly rescaled copy of the image, or `nil` for invalid
    /// dimensions.
    ///
    /// Channels are interpolated independently, alpha is treated as straight
    /// (not premultiplied), which can produce halos around hard transparency
    /// edges. Bilinear rescaling of very large downscale factors will alias;
    /// consider decoding WebP with the scaling options instead.
    public func resized(width: Int, height: Int) -> STBImage? {
        guard width > 0, height > 0 else { return nil }
        guard width != self.width || height != self.height else { return self }

        let channels = self.channels
        let sourceWidth = self.width
        let sourceHeight = self.height
        let xScale = Float(sourceWidth) / Float(width)
        let yScale = Float(sourceHeight) / Float(height)

        var output = [UInt8](repeating: 0, count: width * height * channels)

        data.withUnsafeBufferPointer { source in
            guard let sourceBase = source.baseAddress else { return }
            output.withUnsafeMutableBufferPointer { destination in
                guard let destinationBase = destination.baseAddress else { return }

                for dy in 0 ..< height {
                    let sourceY = (Float(dy) + 0.5) * yScale - 0.5
                    let y0f = sourceY.rounded(.down)
                    let weightY = max(0, min(1, sourceY - y0f))
                    let y0 = max(0, min(sourceHeight - 1, Int(y0f)))
                    let y1 = min(sourceHeight - 1, y0 + 1)

                    for dx in 0 ..< width {
                        let sourceX = (Float(dx) + 0.5) * xScale - 0.5
                        let x0f = sourceX.rounded(.down)
                        let weightX = max(0, min(1, sourceX - x0f))
                        let x0 = max(0, min(sourceWidth - 1, Int(x0f)))
                        let x1 = min(sourceWidth - 1, x0 + 1)

                        let p00 = sourceBase + (y0 * sourceWidth + x0) * channels
                        let p10 = sourceBase + (y0 * sourceWidth + x1) * channels
                        let p01 = sourceBase + (y1 * sourceWidth + x0) * channels
                        let p11 = sourceBase + (y1 * sourceWidth + x1) * channels
                        let out = destinationBase + (dy * width + dx) * channels

                        for c in 0 ..< channels {
                            let top = (1 - weightX) * Float(p00[c]) + weightX * Float(p10[c])
                            let bottom = (1 - weightX) * Float(p01[c]) + weightX * Float(p11[c])
                            let value = (1 - weightY) * top + weightY * bottom
                            out[c] = UInt8(max(0, min(255, value.rounded())))
                        }
                    }
                }
            }
        }

        return STBImage(width: width, height: height, channels: channels, data: output)
    }

    /// Copies the image into a new image of the given dimensions, reading
    /// source pixel `(x, y)` from the position returned by `mapping`.
    private func mapped(
        width newWidth: Int,
        height newHeight: Int,
        mapping: (Int, Int) -> (x: Int, y: Int)
    ) -> STBImage {
        var output = [UInt8](repeating: 0, count: newWidth * newHeight * channels)

        data.withUnsafeBufferPointer { source in
            guard let sourceBase = source.baseAddress else { return }
            output.withUnsafeMutableBufferPointer { destination in
                guard let destinationBase = destination.baseAddress else { return }

                for y in 0 ..< height {
                    for x in 0 ..< width {
                        let destinationPosition = mapping(x, y)
                        let sourceIndex = (y * width + x) * channels
                        let destinationIndex = (destinationPosition.y * newWidth + destinationPosition.x) * channels

                        for c in 0 ..< channels {
                            destinationBase[destinationIndex + c] = sourceBase[sourceIndex + c]
                        }
                    }
                }
            }
        }

        return STBImage(width: newWidth, height: newHeight, channels: channels, data: output)
    }

}
