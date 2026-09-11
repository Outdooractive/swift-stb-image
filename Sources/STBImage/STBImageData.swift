//
//  Created by Thomas Rasch on 27.02.26.
//

// MARK: ImageData

/// The sample bit depth of an `STBImageData`.
public enum STBImageBitDepth: Int, Sendable, Hashable {

    /// 8 bits per sample.
    case eight = 8

    /// 16 bits per sample.
    case sixteen = 16

    /// The number of bytes per sample.
    public var bytesPerSample: Int {
        self == .sixteen ? 2 : 1
    }

}

/// The raw image representation as returned by the decoders and accepted by
/// the encoders.
///
/// Unlike ``STBImage``, an `STBImageData` is not restricted to RGB and RGBA
/// images: grayscale (1) and gray+alpha (2) channel images are supported as
/// well, as reported by the decoders. 16-bit single-channel images are
/// supported alongside the usual 8-bit ones.
///
/// 16-bit sample values are stored as little-endian byte pairs regardless
/// of the source format's byte order.
public struct STBImageData: Sendable, Hashable {

    /// The image's width in pixels.
    public let width: Int

    /// The image's height in pixels.
    public let height: Int

    /// Samples per pixel: 1 (gray), 2 (gray+alpha), 3 (RGB) or 4 (RGBA).
    public let channels: Int

    /// The sample bit depth of the image. 16-bit images are single-channel
    /// only.
    public let bitDepth: STBImageBitDepth

    /// The raw pixel data, row by row, top to bottom, interleaved per
    /// pixel. 16-bit samples are stored as little-endian byte pairs.
    public var data: [UInt8]

    /// Bytes per pixel: `channels` for 8-bit images, `channels * 2` for
    /// 16-bit images.
    public var bytesPerPixel: Int {
        channels * bitDepth.bytesPerSample
    }

    /// Creates an image data value from raw pixel data.
    ///
    /// - Parameters:
    ///   - width: The image's width in pixels.
    ///   - height: The image's height in pixels.
    ///   - channels: Samples per pixel: 1 (gray), 2 (gray+alpha), 3 (RGB)
    ///     or 4 (RGBA). 16-bit images are single-channel only.
    ///   - bitDepth: The sample bit depth, `.eight` or `.sixteen`.
    ///     Defaults to `.eight`.
    ///   - data: The raw pixel data, expected to contain exactly
    ///     `width * height * bytesPerPixel` bytes.
    @inlinable
    public init(
        width: Int,
        height: Int,
        channels: Int,
        bitDepth: STBImageBitDepth = .eight,
        data: [UInt8]
    ) {
        precondition(
            bitDepth == .eight ? (1 ... 4).contains(channels) : channels == 1,
            "channels must be in 1...4 for 8-bit images and 1 for 16-bit images")

        self.width = width
        self.height = height
        self.channels = channels
        self.bitDepth = bitDepth
        self.data = data
    }

}

extension STBImageData {

    /// Returns a copy of the image converted to the specified bit depth.
    ///
    /// - Parameters:
    ///   - bitDepth: The target bit depth.
    /// - Returns: The converted image, or `self` when the bit depth
    ///   already matches.
    ///
    /// - Note: 16-bit images are single-channel only; converting an
    ///   8-bit multi-channel image to 16 bits is not supported and
    ///   returns `self` unchanged. Down-converting uses
    ///   `(value + 128) / 257` rounding, up-converting `value * 257`.
    public func convertedBitDepth(to bitDepth: STBImageBitDepth) -> STBImageData {
        guard bitDepth != self.bitDepth, channels == 1 else { return self }

        let pixelCount = width * height
        var output = [UInt8](repeating: 0, count: pixelCount * bitDepth.bytesPerSample)

        switch (self.bitDepth, bitDepth) {
        case (.sixteen, .eight):
            // Round to nearest: (value + 128) / 257
            output.withUnsafeMutableBytes { (outputBuffer: UnsafeMutableRawBufferPointer) in
                guard let outputBase = outputBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }

                data.withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) in
                    guard let sourceBase = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }

                    for index in 0 ..< pixelCount {
                        let low = sourceBase[index * 2]
                        let high = sourceBase[index * 2 + 1]
                        let value = UInt16(low) | (UInt16(high) << 8)
                        let converted = UInt8(truncatingIfNeeded: (Int(value) + 128) / 257)
                        outputBase[index] = converted
                    }
                }
            }

        case (.eight, .sixteen):
            // Scale: value * 257
            output.withUnsafeMutableBytes { (outputBuffer: UnsafeMutableRawBufferPointer) in
                guard let outputBase = outputBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }

                data.withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) in
                    guard let sourceBase = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }

                    for index in 0 ..< pixelCount {
                        let value = Int(sourceBase[index]) * 257
                        let low = UInt8(truncatingIfNeeded: value)
                        let high = UInt8(truncatingIfNeeded: value >> 8)
                        outputBase[index * 2] = low
                        outputBase[index * 2 + 1] = high
                    }
                }
            }

        default:
            break
        }

        return STBImageData(width: width, height: height, channels: channels, bitDepth: bitDepth, data: output)
    }

}

extension STBImageData {

    /// Converts the image to the specified channel count, replicating the
    /// gray channel or filling alpha with 255 as needed.
    ///
    /// 16-bit images are single-channel only; conversion applies to 8-bit
    /// images.
    func convertedChannels(to channels: Int) -> STBImageData {
        guard bitDepth == .eight, channels != self.channels, (1 ... 4).contains(channels) else {
            return self
        }

        let pixelCount = width * height
        let sourceChannels = self.channels
        var output = [UInt8](repeating: 0, count: pixelCount * channels)

        for index in 0 ..< pixelCount {
            let sourceOffset = index * sourceChannels
            let targetOffset = index * channels

            for channel in 0 ..< channels {
                if channel < sourceChannels {
                    output[targetOffset + channel] = data[sourceOffset + channel]
                }
                else {
                    // Replicate the last channel (alpha = 255) or fill
                    // with the first channel (grayscale expansion).
                    output[targetOffset + channel] = sourceChannels == 1
                        ? data[sourceOffset]
                        : 255
                }
            }
        }

        return STBImageData(width: width, height: height, channels: channels, bitDepth: bitDepth, data: output)
    }

}

// MARK: - 16-bit sample access

extension STBImageData {

    /// Reads or writes the 16-bit sample of the pixel at the given
    /// coordinates, assembling the little-endian byte pair.
    ///
    /// 16-bit images are single-channel, so no channel argument is
    /// needed.
    ///
    /// - Parameters:
    ///   - x: The pixel's x coordinate, in `0 ..< width`.
    ///   - y: The pixel's y coordinate, in `0 ..< height`.
    /// - Precondition: The coordinates must be in range and the image
    ///   must have 16-bit samples.
    @inlinable
    public subscript(x: Int, y: Int) -> UInt16 {
        get {
            precondition(bitDepth == .sixteen, "This accessor requires a 16-bit image.")
            precondition(x >= 0 && x < width, "Index out of range.")
            precondition(y >= 0 && y < height, "Index out of range.")

            let offset = (y * width + x) * 2
            return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        }
        set {
            precondition(bitDepth == .sixteen, "This accessor requires a 16-bit image.")
            precondition(x >= 0 && x < width, "Index out of range.")
            precondition(y >= 0 && y < height, "Index out of range.")

            let offset = (y * width + x) * 2
            data[offset] = UInt8(truncatingIfNeeded: newValue)
            data[offset + 1] = UInt8(truncatingIfNeeded: newValue >> 8)
        }
    }

    /// Reads or writes the 16-bit sample at the given sample index,
    /// assembling the little-endian byte pair.
    ///
    /// - Parameter index: The sample index, in `0 ..< width * height`.
    /// - Precondition: The index must be in range and the image must have
    ///   16-bit samples.
    @inlinable
    public subscript(data16 index: Int) -> UInt16 {
        get {
            precondition(bitDepth == .sixteen, "This accessor requires a 16-bit image.")
            precondition(index >= 0 && index < width * height, "Index out of range.")

            let offset = index * 2
            return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        }
        set {
            precondition(bitDepth == .sixteen, "This accessor requires a 16-bit image.")
            precondition(index >= 0 && index < width * height, "Index out of range.")

            let offset = index * 2
            data[offset] = UInt8(truncatingIfNeeded: newValue)
            data[offset + 1] = UInt8(truncatingIfNeeded: newValue >> 8)
        }
    }

    /// The image's samples as little-endian-decoded 16-bit values.
    ///
    /// The setter re-encodes the values as little-endian byte pairs.
    ///
    /// - Precondition: The image must have 16-bit samples and the new
    ///   sample count must match the image dimensions.
    public var samples16: [UInt16] {
        get {
            precondition(bitDepth == .sixteen, "This property requires a 16-bit image.")
            let pixelCount = width * height
            return data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> [UInt16] in
                guard let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return [] }

                var output = [UInt16](repeating: 0, count: pixelCount)
                output.withUnsafeMutableBufferPointer { target in
                    for index in 0 ..< pixelCount {
                        target[index] = UInt16(base[index * 2]) | (UInt16(base[index * 2 + 1]) << 8)
                    }
                }
                return output
            }
        }
        set {
            precondition(bitDepth == .sixteen, "This property requires a 16-bit image.")
            precondition(newValue.count == width * height, "Sample count does not match image dimensions.")

            var output = [UInt8](repeating: 0, count: newValue.count * 2)
            output.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
                guard let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }

                for index in 0 ..< newValue.count {
                    let value = newValue[index]
                    base[index * 2] = UInt8(truncatingIfNeeded: value)
                    base[index * 2 + 1] = UInt8(truncatingIfNeeded: value >> 8)
                }
            }

            data = output
        }
    }

}
