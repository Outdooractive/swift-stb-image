//
//  Created by Thomas Rasch on 27.02.26.
//

// MARK: ImageData

/// The raw image representation as returned by the decoders and accepted by
/// the encoders.
///
/// Unlike ``STBImage``, an `STBImageData` is not restricted to RGB and RGBA
/// images: grayscale (1) and gray+alpha (2) channel images are supported as
/// well, as reported by the decoders.
public struct STBImageData: Sendable {

    /// The image's width in pixels.
    public let width: Int

    /// The image's height in pixels.
    public let height: Int

    /// Bytes per pixel: 1 (gray), 2 (gray+alpha), 3 (RGB) or 4 (RGBA).
    public let bpp: Int

    /// The raw pixel data, row by row, top to bottom, interleaved per pixel.
    public let data: [UInt8]

    /// Creates an image data value from raw pixel data.
    ///
    /// - Parameters:
    ///   - width: The image's width in pixels.
    ///   - height: The image's height in pixels.
    ///   - bpp: Bytes per pixel: 1 (gray), 2 (gray+alpha), 3 (RGB) or 4 (RGBA).
    ///   - data: The raw pixel data, expected to contain exactly
    ///     `width * height * bpp` bytes.
    @inlinable
    public init(width: Int,
         height: Int,
         bpp: Int,
         data: [UInt8]
    ) {
        self.width = width
        self.height = height
        self.bpp = bpp
        self.data = data
    }

}
