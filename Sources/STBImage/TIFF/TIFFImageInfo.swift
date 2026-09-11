#if EnableTIFF
import Foundation

/// A summary of a TIFF file's contents, without decoding pixel data.
public struct TIFFImageInfo: Sendable, Hashable {

    /// The image's width in pixels.
    public let width: Int

    /// The image's height in pixels.
    public let height: Int

    /// Number of samples per pixel: 1 (gray), 2 (gray+alpha), 3 (RGB) or
    /// 4 (RGBA) for 8-bit images, 1 for 16-bit images.
    public let channels: Int

    /// The sample bit depth of the image.
    public let bitDepth: STBImageBitDepth

    /// True when the image data is organized in tiles.
    public let isTiled: Bool

    /// The compression method stored in the file.
    public let compression: TIFFCompression

    /// The georeferencing information, when the file is a GeoTIFF.
    public let geoTIFFInfo: GeoTIFFInfo?

}

#endif
