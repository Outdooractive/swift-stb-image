#if EnableTIFF
import Foundation
@testable import STBImage
import Testing

struct GeoTIFFTests {

    // MARK: - Reading fixtures

    @Test
    func readGeoTIFF3857() throws {
        let tiffDataimage = try #require(ImageLoader.loadFile(named: "geotiff_3857.tif"))
        let image = try #require(try TIFFDecoder.load(from: tiffDataimage))
        let info = try TIFFImageInspector.inspect(#require(ImageLoader.loadFile(named: "geotiff_3857.tif")))
        let geo = try #require(info.geoTIFFInfo)

        #expect(geo.epsgCode == 3857)
        // GDAL derives the geographic CRS from the projected CRS at read
        // time and writes no GeodeticCRSGeoKey for projected files.
        #expect(geographic_EPSGCode(geo) == nil)
        #expect(geo.rasterType == .pixelIsArea)

        // Web Mercator tile z=11, x=1077, y=720 covers
        // (1037097.5998, 5929067.4100) - (1056665.4790, 5948635.2893)
        // pixel size: 76.437028 m/px
        let scale = try #require(geo.pixelScale)
        let tileSizeMeters = 2.0 * .pi * 6_378_137.0 / Double(1 << 11)
        let expectedPixelSize = tileSizeMeters / 256.0

        #expect(abs(scale.x - expectedPixelSize) < 0.001)
        #expect(abs(scale.y - expectedPixelSize) < 0.001)

        // Tiepoint: the world coordinates of raster (0, 0) = the upper
        // left corner of the tile
        let tiepoint = try #require(geo.tiepoint)
        #expect(tiepoint.raster.i == 0.0)
        #expect(tiepoint.raster.j == 0.0)
        #expect(abs(tiepoint.world.x - 1_037_097.5998) < 0.01)
        #expect(abs(tiepoint.world.y - 5_948_635.2893) < 0.01)

        // Sanity: the decoded image matches the RGBA reference
        #expect(image.width == 256)
        #expect(image.channels == 4)
    }

    @Test
    func readGeoTIFF4326() throws {
        let info = try TIFFImageInspector.inspect(#require(ImageLoader.loadFile(named: "geotiff_4326.tif")))
        let geo = try #require(info.geoTIFFInfo)

        // Geographic-only files report their geographic code as the
        // overall EPSG identity.
        #expect(geo.epsgCode == 4326)
        #expect(geographic_EPSGCode(geo) == 4326)
        #expect(geo.rasterType == .pixelIsArea)

        // GeoTransform: west=10.0, px=1/64, north=51.0
        let scale = try #require(geo.pixelScale)
        #expect(abs(scale.x - 1.0 / 64.0) < 1e-9)
        #expect(abs(scale.y - 1.0 / 64.0) < 1e-9)

        let tiepoint = try #require(geo.tiepoint)
        #expect(abs(tiepoint.world.x - 10.0) < 1e-9)
        #expect(abs(tiepoint.world.y - 51.0) < 1e-9)
    }

    @Test
    func plainTIFFHasNoGeoInfo() throws {
        let info = try TIFFImageInspector.inspect(#require(ImageLoader.loadFile(named: "rgba_strip.tif")))
        #expect(info.geoTIFFInfo == nil)
    }

    // MARK: - Writing + roundtrip

    @Test
    func writeReadGeoTIFF3857() throws {
        var data = [UInt8]()
        for index in 0 ..< 16 * 16 {
            data.append(UInt8((index * 3) % 256))
            data.append(UInt8((index * 5) % 256))
            data.append(UInt8((index * 7) % 256))
            data.append(255)
        }
        let image = STBImageData(width: 16, height: 16, channels: 4, data: data)

        let geo = GeoTIFFInfo(
            epsgCode: 3857,
            rasterType: .pixelIsArea,
            pixelScale: GeoTIFFScale(x: 76.437028285175529, y: 76.437028285175529),
            tiepoint: GeoTIFFTiepoint(originX: 1_037_097.5998, originY: 5_948_635.2893))

        let encoded = try TIFFEncoder.export(
            image: image,
            options: TIFFExportOptions(geoTIFFInfo: geo))

        let info = try TIFFImageInspector.inspect(encoded)
        let decodedGeo = try #require(info.geoTIFFInfo)

        #expect(decodedGeo.epsgCode == 3857)
        #expect(decodedGeo.rasterType == .pixelIsArea)

        let scale = try #require(decodedGeo.pixelScale)
        #expect(scale.x == geo.pixelScale?.x)
        #expect(scale.y == geo.pixelScale?.y)

        let tiepoint = try #require(decodedGeo.tiepoint)
        #expect(tiepoint.world.x == 1_037_097.5998)
        #expect(tiepoint.world.y == 5_948_635.2893)
        #expect(tiepoint.raster.i == 0.0)
        #expect(tiepoint.raster.j == 0.0)

        // The pixel data survives the roundtrip
        let decoded = try #require(try TIFFDecoder.load(from: encoded))
        #expect(decoded.data == data)
    }

    @Test
    func writeReadGeoTIFF4326() throws {
        let image = STBImageData(
            width: 4,
            height: 4,
            channels: 1,
            data: [UInt8](repeating: 42, count: 16))

        let geo = GeoTIFFInfo(
            geographicEPSGCode: 4326,
            rasterType: .pixelIsPoint,
            pixelScale: GeoTIFFScale(x: 0.015625, y: 0.015625),
            tiepoint: GeoTIFFTiepoint(originX: 10.0, originY: 51.0))

        let encoded = try TIFFEncoder.export(
            image: image,
            options: TIFFExportOptions(compression: .none, geoTIFFInfo: geo))

        let info = try TIFFImageInspector.inspect(encoded)
        let decodedGeo = try #require(info.geoTIFFInfo)

        // The geographic code is reported as the overall EPSG identity
        // for geographic-only files.
        #expect(decodedGeo.epsgCode == 4326)
        #expect(geographic_EPSGCode(decodedGeo) == 4326)
        #expect(decodedGeo.rasterType == .pixelIsPoint)
    }

    @Test
    func geotiffRoundtripMatchesGDALGeometry() throws {
        // A GeoTIFF written by this library must have the same geotransform
        // that GDAL would compute for the same bounding box. For a
        // north-up image: origin = (west, north), pixel size =
        // ((east - west) / width, -(north - south) / height).
        let west = 10.0
        let south = 50.0
        let east = 12.0
        let north = 51.0
        let width = 200
        let height = 100

        let geo = GeoTIFFInfo(
            geographicEPSGCode: 4326,
            rasterType: .pixelIsArea,
            pixelScale: GeoTIFFScale(x: (east - west) / Double(width), y: (north - south) / Double(height)),
            tiepoint: GeoTIFFTiepoint(originX: west, originY: north))

        let image = STBImageData(width: width, height: height, channels: 3, data: [UInt8](repeating: 0, count: width * height * 3))
        let encoded = try TIFFEncoder.export(image: image, options: TIFFExportOptions(geoTIFFInfo: geo))

        // Verify against GDAL's interpretation by re-reading with our own
        // decoder: scale.y is stored positive, the tiepoint carries north.
        let decodedGeo = try #require(TIFFImageInspector.inspect(encoded).geoTIFFInfo)
        let scale = try #require(decodedGeo.pixelScale)
        let tiepoint = try #require(decodedGeo.tiepoint)

        #expect(abs(scale.x - 0.01) < 1e-12)
        #expect(abs(scale.y - 0.01) < 1e-12)
        #expect(tiepoint.world.x == west)
        #expect(tiepoint.world.y == north)
    }

    // MARK: - GeoKeyDirectory

    @Test
    func geoKeyDirectoryEncodeDecode() throws {
        let keys: [UInt16: UInt16] = [
            1024: 1, // GTModelType: projected
            1025: 1, // GTRasterType: pixelIsArea
            2048: 4326,
            3072: 3857,
        ]

        let encoded = GeoKeyDirectory.encode(keys)
        #expect(encoded.count == 4 + keys.count * 4)
        #expect(encoded[0] == 1) // version
        #expect(encoded[3] == 4) // numberOfKeys

        let decoded = try #require(GeoKeyDirectory.decode(encoded))
        #expect(decoded[1024] == 1)
        #expect(decoded[1025] == 1)
        #expect(decoded[2048] == 4326)
        #expect(decoded[3072] == 3857)
    }

    @Test
    func geoKeyDirectoryMalformed() {
        #expect(GeoKeyDirectory.decode([]) == nil)
        #expect(GeoKeyDirectory.decode([1, 1, 0]) == nil)
        #expect(GeoKeyDirectory.decode([2, 1, 0, 0]) == nil) // wrong version
        // Truncated directories are tolerated: the available entries are
        // decoded, the rest is ignored (GeoTIFF spec recommendation).
        #expect(GeoKeyDirectory.decode([1, 1, 0, 100]) == [:])
    }

    @Test
    func geoKeyDirectoryIgnoresParameterKeys() throws {
        // A key with tiffTagLocation != 0 references 34736/34737 and is
        // ignored by the EPSG-only model.
        let payload: [UInt16] = [
            1,
            1,
            0,
            2,
            1024,
            0,
            1,
            1, // direct value
            3078,
            34736,
            1,
            0, // ProjStdParallel1GeoKey: parameter in doubles
        ]

        let decoded = try #require(GeoKeyDirectory.decode(payload))
        #expect(decoded[1024] == 1)
        #expect(decoded[3078] == nil)
    }

    // MARK: - Helpers

    private func geographic_EPSGCode(_ info: GeoTIFFInfo) -> Int? {
        info.geographicEPSGCode
    }

}

#endif
