#if EnableTIFF
import Foundation

/// Encoding and decoding of the GeoTIFF `GeoKeyDirectoryTag` (tag 34735).
///
/// The tag is an array of 16-bit unsigned values:
/// - Header: `[keyDirectoryVersion, keyRevision, minorRevision, numberOfKeys]`
/// - Then `numberOfKeys` entries of four values each:
///   `[keyID, tiffTagLocation, count, valueOffset]`
///
/// When `tiffTagLocation` is 0, `valueOffset` carries the value itself
/// (a single SHORT). Otherwise it is the offset into the tag referenced by
/// `tiffTagLocation` (34736/34737 for double/ASCII parameters).
enum GeoKeyDirectory {

    /// GeoKey IDs.
    enum KeyID {

        /// `GTModelTypeGeoKey`: 1 = projected, 2 = geographic.
        static let modelType: UInt16 = 1024

        /// `GTRasterTypeGeoKey`: 1 = pixelIsArea, 2 = pixelIsPoint.
        static let rasterType: UInt16 = 1025

        /// `GeodeticCRSGeoKey`: EPSG code of the geographic CRS.
        static let geographicCRS: UInt16 = 2048

        /// `ProjectedCRSGeoKey`: EPSG code of the projected CRS.
        static let projectedCRS: UInt16 = 3072

    }

    /// The header size in 16-bit values.
    static let headerSize = 4

    /// The number of values per key entry.
    static let entrySize = 4

    // MARK: - Decoding

    /// Decodes a `GeoKeyDirectoryTag` payload.
    ///
    /// - Returns: The decoded key/value dictionary, or `nil` when the
    ///   payload is malformed (too short, truncated).
    static func decode(_ values: [UInt16]) -> [UInt16: UInt16]? {
        guard values.count >= headerSize else { return nil }

        let keyDirectoryVersion = values[0]
        let numberOfKeys = Int(values[3])
        // Accept both GeoTIFF 1.0 (1.1.0) and 1.1 (1.1.1) directories.
        guard keyDirectoryVersion == 1, numberOfKeys >= 0 else { return nil }

        // Truncated directories are tolerated, entries beyond the payload
        // are ignored (as recommended by the GeoTIFF spec).
        let availableKeys = min(numberOfKeys, (values.count - headerSize) / entrySize)

        var result: [UInt16: UInt16] = [:]
        result.reserveCapacity(availableKeys)

        for index in 0 ..< availableKeys {
            let offset = headerSize + index * entrySize
            let keyID = values[offset]
            let tiffTagLocation = values[offset + 1]
            let count = values[offset + 2]
            let valueOffset = values[offset + 3]

            // Only direct SHORT values (tiffTagLocation == 0, count == 1)
            // are handled here; parameters stored in 34736/34737 are out
            // of scope for the EPSG-only model.
            guard tiffTagLocation == 0, count == 1 else { continue }

            result[keyID] = valueOffset
        }

        return result
    }

    // MARK: - Encoding

    /// Encodes key/value pairs into a `GeoKeyDirectoryTag` payload.
    ///
    /// Keys are written sorted by ID for deterministic output.
    static func encode(_ keys: [UInt16: UInt16]) -> [UInt16] {
        var payload: [UInt16] = [1, 1, 0, UInt16(keys.count)]

        for (keyID, value) in keys.sorted(by: { $0.key < $1.key }) {
            payload.append(keyID)
            payload.append(0) // tiffTagLocation: direct value
            payload.append(1) // count
            payload.append(value)
        }

        return payload
    }

}

extension GeoTIFFInfo {

    /// Creates georeferencing information from a `GeoKeyDirectoryTag`
    /// payload and the associated scale/tiepoint values.
    ///
    /// - Parameters:
    ///   - keyDirectory: The raw GeoKeyDirectory values (may be empty).
    ///   - pixelScale: The `ModelPixelScaleTag` values (3 or more), when
    ///     present.
    ///   - tiepoint: The `ModelTiepointTag` values (6 or more), when
    ///     present.
    static func from(
        keyDirectory: [UInt16],
        pixelScale: [Double],
        tiepoint: [Double]
    ) -> GeoTIFFInfo {
        let keys = GeoKeyDirectory.decode(keyDirectory) ?? [:]

        var scale: GeoTIFFScale?
        if pixelScale.count >= 2 {
            scale = GeoTIFFScale(x: pixelScale[0], y: pixelScale[1])
        }

        var point: GeoTIFFTiepoint?
        if tiepoint.count >= 6 {
            point = GeoTIFFTiepoint(
                raster: GeoTIFFRasterPoint(i: tiepoint[0], j: tiepoint[1]),
                world: GeoTIFFWorldPoint(x: tiepoint[3], y: tiepoint[4]))
        }

        var rasterType: RasterType?
        if let rawRasterType = keys[GeoKeyDirectory.KeyID.rasterType],
           let type = RasterType(rawValue: Int(rawRasterType))
        {
            rasterType = type
        }

        var geographicEPSGCode: Int?
        if let geographic = keys[GeoKeyDirectory.KeyID.geographicCRS], geographic > 0, geographic != 32767 {
            geographicEPSGCode = Int(geographic)
        }

        var epsgCode: Int?
        if let projected = keys[GeoKeyDirectory.KeyID.projectedCRS], projected > 0, projected != 32767 {
            // 32767 marks a user-defined PCS (parameters in other keys),
            // which is out of scope here.
            epsgCode = Int(projected)
        }
        else if let geographic = geographicEPSGCode {
            // Geographic-only files (e.g. plain EPSG:4326 rasters) carry
            // no projected CRS; report the geographic code as the file's
            // EPSG identity.
            epsgCode = geographic
        }

        return GeoTIFFInfo(
            epsgCode: epsgCode,
            geographicEPSGCode: geographicEPSGCode,
            rasterType: rasterType,
            pixelScale: scale,
            tiepoint: point)
    }

    /// The GeoKeyDirectory payload encoding this information.
    var keyDirectory: [UInt16] {
        var keys: [UInt16: UInt16] = [:]
        if let epsgCode {
            keys[GeoKeyDirectory.KeyID.modelType] = 1 // projected
            keys[GeoKeyDirectory.KeyID.projectedCRS] = UInt16(epsgCode)
        }
        else if let geographicEPSGCode {
            keys[GeoKeyDirectory.KeyID.modelType] = 2 // geographic
            keys[GeoKeyDirectory.KeyID.geographicCRS] = UInt16(geographicEPSGCode)
        }
        if let rasterType {
            keys[GeoKeyDirectory.KeyID.rasterType] = UInt16(rasterType.rawValue)
        }
        return GeoKeyDirectory.encode(keys)
    }

}

#endif
