#if EnableTIFF
import Foundation

/// The pixel scale from the `ModelPixelScaleTag`: resolution in CRS units
/// per pixel along the X and Y axes, as stored in the tag (positive for
/// typical GeoTIFFs; the tiepoint carries the axis orientation).
public struct GeoTIFFScale: Sendable, Hashable {

    /// Resolution along the X axis.
    public let x: Double

    /// Resolution along the Y axis.
    public let y: Double

    /// Creates a pixel scale.
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

}

/// The raster position (in pixels) of the tiepoint.
public struct GeoTIFFRasterPoint: Sendable, Hashable {

    /// The raster column.
    public let i: Double

    /// The raster row.
    public let j: Double

    /// Creates a raster point.
    public init(i: Double, j: Double) {
        self.i = i
        self.j = j
    }

}

/// The world position (in CRS units) of the tiepoint.
public struct GeoTIFFWorldPoint: Sendable, Hashable {

    /// The world X coordinate (easting).
    public let x: Double

    /// The world Y coordinate (northing).
    public let y: Double

    /// Creates a world point.
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

}

/// The tiepoint from the `ModelTiepointTag`: the world coordinates of a
/// raster point (usually the raster origin `(0, 0)`).
public struct GeoTIFFTiepoint: Sendable, Hashable {

    /// The raster position (in pixels).
    public let raster: GeoTIFFRasterPoint

    /// The world position (in CRS units).
    public let world: GeoTIFFWorldPoint

    /// Creates a tiepoint.
    public init(
        raster: GeoTIFFRasterPoint,
        world: GeoTIFFWorldPoint
    ) {
        self.raster = raster
        self.world = world
    }

    /// Creates a tiepoint for the raster origin.
    public init(originX x: Double, originY y: Double) {
        self.raster = GeoTIFFRasterPoint(i: 0.0, j: 0.0)
        self.world = GeoTIFFWorldPoint(x: x, y: y)
    }

}

/// Georeferencing information from a GeoTIFF, as defined by the GeoTIFF
/// standard: a pixel-to-world affine mapping plus the coordinate reference
/// system identity.
///
/// This type models the raw tag contents only — it does not interpret EPSG
/// codes or perform any coordinate transformations. Consumers with CRS
/// semantics (e.g. GISTools) take it from here.
public struct GeoTIFFInfo: Sendable, Hashable {

    /// The raster type from the `GTRasterTypeGeoKey`: whether a pixel
    /// coordinate refers to the center of a pixel (`pixelIsPoint`) or to
    /// the pixel area (`pixelIsArea`, the GeoTIFF default).
    public enum RasterType: Int, Sendable, Hashable {

        /// Pixel fills a grid cell ("area"), the GeoTIFF default.
        case pixelIsArea = 1

        /// Pixel is a sample point ("point").
        case pixelIsPoint = 2

    }

    /// The EPSG code of the projected CRS
    /// (`ProjectedCSTypeGeoKey`), when present.
    public let epsgCode: Int?

    /// The EPSG code of the geographic CRS
    /// (`GeodeticCRSGeoKey`), when present.
    public let geographicEPSGCode: Int?

    /// The raster type, when specified.
    public let rasterType: RasterType?

    /// The pixel scale from the `ModelPixelScaleTag`:
    /// resolution in CRS units per pixel along X and Y, as stored in the
    /// tag (positive for typical GeoTIFFs; the tiepoint carries the axis
    /// orientation).
    public let pixelScale: GeoTIFFScale?

    /// The tiepoint from the `ModelTiepointTag`: the world coordinates
    /// of the raster point. Only the first tiepoint pair is reported.
    public let tiepoint: GeoTIFFTiepoint?

    /// Creates georeferencing information.
    public init(
        epsgCode: Int? = nil,
        geographicEPSGCode: Int? = nil,
        rasterType: RasterType? = nil,
        pixelScale: GeoTIFFScale? = nil,
        tiepoint: GeoTIFFTiepoint? = nil
    ) {
        self.epsgCode = epsgCode
        self.geographicEPSGCode = geographicEPSGCode
        self.rasterType = rasterType
        self.pixelScale = pixelScale
        self.tiepoint = tiepoint
    }

}

extension GeoTIFFInfo {

    /// True when the information contains any georeferencing at all.
    public var isEmpty: Bool {
        epsgCode == nil && geographicEPSGCode == nil && rasterType == nil
            && pixelScale == nil && tiepoint == nil
    }

}

#endif
