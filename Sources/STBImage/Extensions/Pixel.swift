//
//  Created by Thomas Rasch on 27.02.26.
//

extension STBImage {

    /// A single pixel value with its position.
    ///
    /// `alpha` is `nil` when the image has no alpha channel. Used by
    /// ``STBImage/forEachPixel(_:)`` and ``STBImage/mapPixels(_:)``.
    public struct Pixel: Equatable, Sendable {

        /// The pixel's x coordinate, starting at 0 on the left.
        public let x: Int

        /// The pixel's y coordinate, starting at 0 at the top.
        public let y: Int

        /// The pixel's red value.
        public var red: UInt8

        /// The pixel's green value.
        public var green: UInt8

        /// The pixel's blue value.
        public var blue: UInt8

        /// The pixel's alpha value, or `nil` when the image has no
        /// alpha channel.
        public var alpha: UInt8?

        /// Creates a pixel value.
        ///
        /// - Parameters:
        ///   - x: The pixel's x coordinate.
        ///   - y: The pixel's y coordinate.
        ///   - red: The pixel's red value.
        ///   - green: The pixel's green value.
        ///   - blue: The pixel's blue value.
        ///   - alpha: The pixel's alpha value, or `nil` when the image
        ///     has no alpha channel.
        public init(x: Int, y: Int, red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8? = nil) {
            self.x = x
            self.y = y
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }

    }

    /// Iterates over all pixels of the image.
    ///
    /// This is a safe, read-only alternative to
    /// ``STBImage/unsafePixelwiseConvert(_:)``.
    ///
    /// - Parameter body: A closure that is called once per pixel with the
    ///   pixel's position and channel values.
    @inlinable
    public func forEachPixel(_ body: (Pixel) -> Void) {
        let hasAlpha = self.hasAlpha
        let channels = self.channels

        data.withUnsafeBufferPointer { buffer in
            guard var pixel = buffer.baseAddress else { return }

            for y in 0 ..< height {
                for x in 0 ..< width {
                    body(Pixel(
                        x: x,
                        y: y,
                        red: pixel[0],
                        green: pixel[1],
                        blue: pixel[2],
                        alpha: hasAlpha ? pixel[3] : nil))
                    pixel += channels
                }
            }
        }
    }

    /// Transforms all pixels of the image.
    ///
    /// This is a safe alternative to ``STBImage/unsafePixelwiseConvert(_:)``.
    /// On images without an alpha channel the returned `alpha` value is
    /// ignored. When `alpha` is `nil`, the existing alpha value is kept.
    ///
    /// - Parameter transform: A closure that receives the current pixel and
    ///   returns the transformed pixel.
    @inlinable
    public mutating func mapPixels(_ transform: (Pixel) -> Pixel) {
        let hasAlpha = self.hasAlpha
        let channels = self.channels

        data.withUnsafeMutableBufferPointer { buffer in
            guard var pixel = buffer.baseAddress else { return }

            for y in 0 ..< height {
                for x in 0 ..< width {
                    let transformed = transform(Pixel(
                        x: x,
                        y: y,
                        red: pixel[0],
                        green: pixel[1],
                        blue: pixel[2],
                        alpha: hasAlpha ? pixel[3] : nil))

                    pixel[0] = transformed.red
                    pixel[1] = transformed.green
                    pixel[2] = transformed.blue
                    if hasAlpha, let alpha = transformed.alpha {
                        pixel[3] = alpha
                    }
                    pixel += channels
                }
            }
        }
    }

}
