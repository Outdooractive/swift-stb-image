import CSTBImage
import Foundation

// MARK: STBImage

/// An RGB or RGBA image with its pixel data in a single `[UInt8]` buffer.
///
/// Pixels are stored row by row, top to bottom, interleaved per pixel
/// (R, G, B, A). The type is a `Sendable` and `Hashable` value type.
public struct STBImage {

    /// The image's width in pixels.
    public let width: Int

    /// The image's height in pixels.
    public let height: Int

    /// The number of channels: 3 (RGB) or 4 (RGBA).
    public private(set) var channels: Int

    /// True when the image has an alpha channel.
    public var hasAlpha: Bool {
        channels == RGBA.channels
    }

    @usableFromInline
    var data: [UInt8]

    /// Creates an image from raw pixel data.
    ///
    /// - Parameters:
    ///   - width: The image's width in pixels.
    ///   - height: The image's height in pixels.
    ///   - channels: The number of channels, 3 (RGB) or 4 (RGBA).
    ///   - data: The raw pixel data, expected to contain exactly
    ///     `width * height * channels` bytes.
    /// - Precondition: The data size must match the image dimensions.
    public init(
        width: Int,
        height: Int,
        channels: Int,
        data: [UInt8]
    ) {
        precondition(width >= 0 && height >= 0, "Width and height must be non-negative.")
        precondition(channels > 0, "Number of channels must be positive.")
        precondition(data.count == width * height * channels, "Data size does not match image dimensions.")

        self.width = width
        self.height = height
        self.channels = channels
        self.data = data
    }

    /// Creates an RGBA image filled with a single value.
    ///
    /// - Parameters:
    ///   - width: The image's width in pixels.
    ///   - height: The image's height in pixels.
    ///   - value: The value for all channels of all pixels.
    public init(
        width: Int,
        height: Int,
        value: UInt8
    ) {
        let data = [UInt8](repeating: value, count: width*height*RGBA.channels)
        self.init(width: width, height: height, channels: RGBA.channels, data: data)
    }

    /// Creates an image filled with a single color.
    ///
    /// When `alpha` is omitted, the image has three (RGB) channels,
    /// otherwise four (RGBA).
    public init(
        width: Int,
        height: Int,
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        alpha: UInt8? = nil
    ) {
        precondition(width >= 0 && height >= 0, "Width and height must be non-negative.")

        let channels = alpha == nil ? RGB.channels : RGBA.channels
        var data = [UInt8](repeating: 0, count: width * height * channels)

        for index in stride(from: 0, to: data.count, by: channels) {
            data[index] = red
            data[index + 1] = green
            data[index + 2] = blue
            if let alpha {
                data[index + 3] = alpha
            }
        }

        self.init(width: width, height: height, channels: channels, data: data)
    }

    /// Creates an image from raw image data.
    ///
    /// - Parameter imageData: The raw image data, requires `bpp` 3 or 4.
    ///   Returns `nil` for grayscale (1) and gray+alpha (2) images, or use
    ///   ``STBImage/init?(data:desiredChannels:)`` to convert them.
    public init?(imageData: STBImageData) {
        guard imageData.bpp == 3 || imageData.bpp == 4 else { return nil }

        self.init(
            width: imageData.width,
            height: imageData.height,
            channels: imageData.bpp,
            data: imageData.data)
    }

    /// Loads an image from encoded PNG, JPG or WebP data.
    ///
    /// The format is detected from the file signature.
    ///
    /// - Parameter data: The encoded image data.
    /// - Returns: `nil` for unrecognized formats and undecodable data.
    ///   Use ``STBImageCoder/load(from:desiredChannels:)`` for error details.
    public init?(data: Data) {
        guard let imageData = try? STBImageCoder.load(from: data) else { return nil }

        self.init(imageData: imageData)
    }

    /// Loads an image from encoded data, converting it to the specified
    /// number of channels (e.g. grayscale images as RGB with
    /// `desiredChannels: 3`).
    ///
    /// - Parameters:
    ///   - data: The encoded image data.
    ///   - desiredChannels: Number of channels to convert the image to,
    ///     1 to 4. Applies to PNG and JPG only; WebP output is RGB or RGBA
    ///     depending on the bitstream.
    /// - Returns: `nil` for unrecognized formats and undecodable data.
    public init?(data: Data, desiredChannels: Int) {
        guard let imageData = try? STBImageCoder.load(from: data, desiredChannels: desiredChannels) else { return nil }

        self.init(imageData: imageData)
    }

    /// Loads an image from a file.
    ///
    /// The format is detected from the file signature.
    ///
    /// - Parameter url: The file URL.
    /// - Returns: `nil` when the file can not be read, the format is
    ///   unrecognized, or the data is undecodable.
    public init?(url: URL) {
        guard let data = try? Data(contentsOf: url),
              let imageData = try? STBImageCoder.load(from: data)
        else { return nil }

        self.init(imageData: imageData)
    }

    /// Loads an image from an URL, converting it to the specified number of
    /// channels (e.g. grayscale images as RGB with `desiredChannels: 3`).
    ///
    /// - Parameters:
    ///   - url: The file URL.
    ///   - desiredChannels: Number of channels to convert the image to,
    ///     1 to 4. Applies to PNG and JPG only; WebP output is RGB or RGBA
    ///     depending on the bitstream.
    /// - Returns: `nil` when the file can not be read, the format is
    ///   unrecognized, or the data is undecodable.
    public init?(url: URL, desiredChannels: Int) {
        guard let data = try? Data(contentsOf: url),
              let imageData = try? STBImageCoder.load(from: data, desiredChannels: desiredChannels)
        else { return nil }

        self.init(imageData: imageData)
    }

    /// The image as raw image data, with the channel count as `bpp`.
    @inlinable
    public var imageData: STBImageData {
        STBImageData(width: width, height: height, bpp: channels, data: data)
    }

    /// Encodes the image.
    ///
    /// - Parameter pngCompressionLevel: PNG compression level, 0 = fastest to
    ///   9 = best compression. Defaults to 6.
    public func export(
        _ format: STBExportFormat,
        pngCompressionLevel: Int = 6
    ) throws -> Data {
        try STBImageCoder.export(imageData: imageData, format: format, pngCompressionLevel: pngCompressionLevel)
    }

}

extension STBImage {

    /// Read/write pixel value.
    @inlinable
    public subscript(data index: Int) -> UInt8 {
        get {
            data[index]
        }
        set {
            data[index] = newValue
        }
    }

    /// Get the index of specified pixel/channel in buffer.
    @inlinable
    public func dataIndex(
        x: Int,
        y: Int,
        c: Int = 0
    ) -> Int {
        STBImage.dataIndex(
            x: x,
            y: y,
            c: c,
            width: width,
            height: height,
            channels: channels)
    }

    /// Get the index of specified pixel/channel in buffer.
    ///
    /// This function can be used before initialize image.
    @inlinable
    public static func dataIndex(
        x: Int,
        y: Int,
        c: Int = 0,
        width: Int,
        height: Int,
        channels: Int
    ) -> Int {
        precondition(x >= 0 && x < width, "Index out of range.")
        precondition(y >= 0 && y < height, "Index out of range.")
        precondition(c >= 0 && c < channels, "Index out of range.")

        return (y * width + x) * channels + c
    }

    /// Reads or writes a single pixel channel by coordinates.
    ///
    /// - Parameters:
    ///   - x: The pixel's x coordinate, in `0 ..< width`.
    ///   - y: The pixel's y coordinate, in `0 ..< height`.
    ///   - c: The channel index, in `0 ..< channels`.
    /// - Precondition: The coordinates and channel must be in range.
    @inlinable
    public subscript(
        x: Int,
        y: Int,
        c: Int
    ) -> UInt8 {
        get {
            data[dataIndex(x: x, y: y, c: c)]
        }
        set {
            data[dataIndex(x: x, y: y, c: c)] = newValue
        }
    }

    /// Reads or writes a single pixel channel by coordinates, using the
    /// ``STBImage/RGBA`` channel names.
    ///
    /// - Parameters:
    ///   - x: The pixel's x coordinate, in `0 ..< width`.
    ///   - y: The pixel's y coordinate, in `0 ..< height`.
    ///   - c: The channel, i.e. `.red`, `.green`, `.blue` or `.alpha`.
    ///     Accessing `.alpha` on an RGB image is a precondition failure.
    /// - Precondition: The coordinates and channel must be in range.
    @inlinable
    public subscript(x: Int, y: Int, c: RGBA) -> UInt8 {
        get {
            self[x, y, c.rawValue]
        }
        set {
            self[x, y, c.rawValue] = newValue
        }
    }

}

// MARK: - Alpha

extension STBImage {

    /// True when the image has at least one pixel with an alpha value
    /// below 255.
    ///
    /// Always `false` for RGB images.
    public var isTransparent: Bool {
        guard hasAlpha else { return false }

        let pixelCount = width * height
        let alphaIndex = RGBA.alphaIndex
        let channels = self.channels

        return data.withUnsafeBufferPointer { buffer in
            guard var pixel = buffer.baseAddress else { return false }

            for _ in 0 ..< pixelCount {
                if pixel[alphaIndex] < 255 {
                    return true
                }
                pixel += channels
            }

            return false
        }
    }

    /// Removes the alpha channel from the image in place, converting it
    /// from RGBA to RGB.
    ///
    /// RGB images are returned unchanged. Requires that the buffer size
    /// matches `width * height * 4`.
    ///
    /// - Precondition: The data size must match the image dimensions.
    public mutating func dropAlpha() {
        guard hasAlpha else { return }

        let pixelCount = width * height
        precondition(data.count == pixelCount * RGBA.channels, "Data size does not match image dimensions.")

        data.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }

            var source = baseAddress + RGBA.channels
            var destination = baseAddress + RGB.channels
            let end = baseAddress + pixelCount * RGBA.channels

            while source < end {
                destination[0] = source[0]
                destination[1] = source[1]
                destination[2] = source[2]
                source += RGBA.channels
                destination += RGB.channels
            }
        }

        channels = RGB.channels
        data.removeLast(pixelCount)
    }

}

// MARK: - Equatable

extension STBImage: Equatable {

    /// Compares dimensions, channel count and all pixel values.
    @inlinable
    public static func ==(lhs: STBImage, rhs: STBImage) -> Bool {
        guard lhs.width == rhs.width,
              lhs.height == rhs.height,
              lhs.channels == rhs.channels
        else { return false }

        return lhs.data == rhs.data
    }

}

// MARK: - Hashable

extension STBImage: Hashable {}

// MARK: - Sendable

extension STBImage: Sendable {}

// MARK: - CustomStringConvertible

extension STBImage: CustomStringConvertible {

    /// A short description, i.e. `Image<RGBA>(width: 256, height: 256)`.
    @inlinable
    public var description: String {
        "Image<\(hasAlpha ? "RGBA" : "RGB")>(width: \(width), height: \(height))"
    }

}

// MARK: - Same Pixel/Data type conversion

extension STBImage {

    /// Convert pixels.
    /// - Note: `UnsafePixelRef` contains `UnsafeMutableBufferPointer`.
    /// So it's unsafe to bring it outside closure.
    @inlinable
    public mutating func unsafePixelwiseConvert(_ body: (UnsafePixelRef) -> Void) {
        unsafePixelwiseConvert(0 ..< width, 0 ..< height, body)
    }

    /// Convert pixels in specified range.
    /// - Note: `UnsafePixelRef` contains `UnsafeMutableBufferPointer`.
    /// So it's unsafe to bring it outside closure.
    @inlinable
    public mutating func unsafePixelwiseConvert(
        _ xRange: Range<Int>,
        _ yRange: Range<Int>,
        _ body: (UnsafePixelRef) -> Void
    ) {
        precondition(xRange.startIndex >= 0 && xRange.endIndex <= width, "xRange out of range.")
        precondition(yRange.startIndex >= 0 && yRange.endIndex <= height, "yRange out of range.")

        var rowStart = dataIndex(x: xRange.startIndex, y: yRange.startIndex)
        let rowSize = self.width * channels

        data.withUnsafeMutableBufferPointer { bp in
            for y in yRange {
                var start = rowStart
                for x in xRange {
                    let ref = UnsafePixelRef(x: x, y: y, channels: channels, rebasing: bp[start ..< start + channels])
                    body(ref)
                    start += channels
                }
                rowStart += rowSize
            }
        }
    }

}

// MARK: - Blending

extension STBImage {

    /// Draw image with alpha blending.
    ///
    /// Pixel values are assumed to be in range [0, 255].
    public mutating func blendWith(_ other: STBImage) {
        precondition(other.width == width && other.height == height, "Image dimensions do not match.")

        blendWith(other, at: 0, y: 0)
    }

    /// Draw image at the specified position with alpha blending.
    ///
    /// The image is placed with its top left corner at `(x, y)`. Negative
    /// positions and overhang beyond the image bounds are allowed and get
    /// clipped. Pixel values are assumed to be in range [0, 255].
    public mutating func blendWith(_ other: STBImage, at x: Int, y: Int) {
        let xStart = max(0, x)
        let xEnd = min(width, x + other.width)
        let yStart = max(0, y)
        let yEnd = min(height, y + other.height)
        guard xStart < xEnd, yStart < yEnd else { return }

        blendWith(
            images: [other],
            at: [(x: x, y: y)],
            xRange: xStart ..< xEnd,
            yRange: yStart ..< yEnd)
    }

    /// Draw images with alpha blending, stacked in order.
    ///
    /// All images must match the dimensions of the image.
    /// Pixel values are assumed to be in range [0, 255].
    public mutating func blendWith(images: [STBImage]) {
        guard !images.isEmpty else { return }

        for other in images {
            precondition(other.width == width && other.height == height, "Image dimensions do not match.")
        }

        blendWith(
            images: images,
            at: [(x: Int, y: Int)](repeating: (x: 0, y: 0), count: images.count),
            xRange: 0 ..< width,
            yRange: 0 ..< height)
    }

    /// Blends `images` positioned at `offsets` into the given ranges.
    /// `offsets` contain the position of each image's top left corner
    /// relative to this image.
    ///
    /// The inner loop uses plain index arithmetic instead of the bounds
    /// checked subscripts, avoiding several preconditions per pixel.
    mutating func blendWith(
        images: [STBImage],
        at offsets: [(x: Int, y: Int)],
        xRange: Range<Int>,
        yRange: Range<Int>
    ) {
        guard !images.isEmpty, !xRange.isEmpty, !yRange.isEmpty else { return }

        let selfHasAlpha = hasAlpha
        let alphaIndex = RGBA.alphaIndex

        unsafePixelwiseConvert(xRange, yRange) { ref in
            let selfAlpha = selfHasAlpha ? Int(ref[alphaIndex]) : 255

            for index in images.indices {
                let other = images[index]
                let offset = offsets[index]

                let imageX = ref.x - offset.x
                let imageY = ref.y - offset.y
                let otherIndex = (imageY * other.width + imageX) * other.channels

                if !other.hasAlpha {
                    // Opaque other pixel overwrites self completely
                    ref[0] = other.data[otherIndex]
                    ref[1] = other.data[otherIndex + 1]
                    ref[2] = other.data[otherIndex + 2]
                    if selfHasAlpha {
                        ref[alphaIndex] = 255
                    }
                    continue
                }

                let otherAlpha = Int(other.data[otherIndex + alphaIndex])

                // Other pixel not visible
                if otherAlpha == 0 {
                    continue
                }

                // Overwrite self with other if other is not transparent
                if otherAlpha == 255 {
                    ref[0] = other.data[otherIndex]
                    ref[1] = other.data[otherIndex + 1]
                    ref[2] = other.data[otherIndex + 2]
                    if selfHasAlpha {
                        ref[alphaIndex] = UInt8(otherAlpha)
                    }
                    continue
                }

                // Blend self with other
                let factor = (255 - otherAlpha) * selfAlpha
                let blendAlpha255 = (255 * otherAlpha + factor)

                ref[0] = UInt8((Int(ref[0]) * factor + 255 * otherAlpha * Int(other.data[otherIndex])) / blendAlpha255)
                ref[1] = UInt8((Int(ref[1]) * factor + 255 * otherAlpha * Int(other.data[otherIndex + 1])) / blendAlpha255)
                ref[2] = UInt8((Int(ref[2]) * factor + 255 * otherAlpha * Int(other.data[otherIndex + 2])) / blendAlpha255)
                if selfHasAlpha {
                    ref[alphaIndex] = UInt8(blendAlpha255 / 255)
                }
            }
        }
    }

    /// Blends the given images into a new image, stacking them in order.
    ///
    /// With less than two images, the first image is returned unchanged,
    /// with an empty array `nil` is returned.
    ///
    /// - Parameter images: The images to blend, all matching dimensions.
    /// - Returns: The blended image, or `nil` for an empty array.
    public static func blend(images: [STBImage]) -> STBImage? {
        guard images.count >= 2 else { return images.first }

        var baseImage = images[0]
        baseImage.blendWith(images: Array(images[1...]))

        return baseImage
    }

}

// MARK: - Extraction

extension STBImage {

    /// Returns a copy of the specified region, or `nil` when the region is
    /// not fully contained in the image.
    public func extract(x: Int, y: Int, width: Int, height: Int) -> STBImage? {
        guard width > 0, height > 0,
              x >= 0, y >= 0,
              x + width <= self.width, y + height <= self.height
        else { return nil }

        var data = [UInt8]()
        data.reserveCapacity(width * height * channels)

        for row in y ..< y + height {
            let rowStart = dataIndex(x: x, y: row, c: 0)
            data.append(contentsOf: self.data[rowStart ..< rowStart + width * channels])
        }

        return STBImage(width: width, height: height, channels: channels, data: data)
    }

}
