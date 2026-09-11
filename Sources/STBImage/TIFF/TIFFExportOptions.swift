#if EnableTIFF
import Foundation

/// Options for TIFF export.
///
/// All values have sensible defaults. The encoder always writes strip-based
/// files.
public struct TIFFExportOptions: Sendable, Hashable {

    /// The compression method for the output file.
    public var compression: TIFFCompression

    /// Optional georeferencing information (GeoTIFF): EPSG code, raster
    /// type, pixel scale and tiepoint. When set, the output is a GeoTIFF.
    public var geoTIFFInfo: GeoTIFFInfo?

    /// Creates TIFF export options.
    ///
    /// - Parameters:
    ///   - compression: The compression method, defaults to `.deflate`.
    ///   - geoTIFFInfo: Optional GeoTIFF georeferencing information.
    public init(
        compression: TIFFCompression = .deflate,
        geoTIFFInfo: GeoTIFFInfo? = nil
    ) {
        self.compression = compression
        self.geoTIFFInfo = geoTIFFInfo
    }

}

#endif
