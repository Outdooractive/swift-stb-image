#if EnableTIFF
import CTIFF
import Foundation

/// Decodes TIFF data.
///
/// Supported variants are 8-bit gray/gray+alpha/RGB/RGBA images and
/// single-channel 16-bit images, in strip or tile organization, with
/// none/LZW/Deflate/PackBits compression. Anything else throws
/// `TIFFError.unsupported` instead of mis-decoding.
///
/// Decoding operates on the first page only (multi-page files are
/// treated as their first image).
public enum TIFFDecoder {

    // MARK: - Public API

    /// Decodes TIFF data.
    ///
    /// - Parameters:
    ///   - data: The encoded TIFF data.
    ///   - desiredChannels: Number of channels to convert 8-bit images
    ///     to, where 0 keeps the original channel count (gray 1/2/3/4
    ///     channels are supported). 16-bit images are unaffected.
    /// - Returns: The decoded image, or `nil` when the data is not a
    ///   recognized TIFF.
    /// - Throws: `TIFFError` when the data is recognized but can not be
    ///   decoded.
    public static func load(
        from data: Data,
        desiredChannels: Int = 0
    ) throws -> STBImageData? {
        precondition((0 ... 4).contains(desiredChannels), "desiredChannels must be in 0...4.")

        guard isTIFFSignature(data) else { return nil }

        return try decode(data, desiredChannels: desiredChannels)
    }

    /// Inspects the layout of TIFF data.
    ///
    /// - Parameter data: The encoded TIFF data.
    /// - Returns: The layout description.
    /// - Throws: `TIFFError` when the data is corrupt or contains an
    ///   unsupported variant.
    static func inspectLayout(_ data: Data) throws -> Layout {
        guard isTIFFSignature(data) else {
            throw TIFFError.notATIFF
        }

        let tif = try open(data)
        defer { ctiff_close_check_error(tif) }

        return try readLayout(tif)
    }

    // MARK: - Layout

    /// The TIFF file layout as read from the tags.
    struct Layout {

        let width: Int
        let height: Int
        let bitsPerSample: Int
        let samplesPerPixel: Int
        let photometric: Int
        let planarConfig: Int
        let sampleFormat: Int
        let compression: TIFFCompression
        let extrasamples: [UInt16]
        let isTiled: Bool
        let geoTIFFInfo: GeoTIFFInfo?

        /// The sample bit depth.
        var bitDepth: STBImageBitDepth {
            bitsPerSample == 16 ? .sixteen : .eight
        }

        var info: TIFFImageInfo {
            TIFFImageInfo(
                width: width,
                height: height,
                channels: samplesPerPixel,
                bitDepth: bitsPerSample == 16 ? .sixteen : .eight,
                isTiled: isTiled,
                compression: compression,
                geoTIFFInfo: geoTIFFInfo)
        }

    }

    // MARK: - Private implementation

    static func isTIFFSignature(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }

        let bytes: [UInt8] = [data[data.startIndex], data[data.index(after: data.startIndex)], data[data.index(data.startIndex, offsetBy: 2)], data[data.index(data.startIndex, offsetBy: 3)]]

        // Classic TIFF: II*\0 (little endian), MM\0* (big endian)
        // BigTIFF: II+\0, MM\0+
        let littleEndianClassic: [UInt8] = [0x49, 0x49, 0x2A, 0x00]
        let bigEndianClassic: [UInt8] = [0x4D, 0x4D, 0x00, 0x2A]
        let littleEndianBig: [UInt8] = [0x49, 0x49, 0x2B, 0x00]
        let bigEndianBig: [UInt8] = [0x4D, 0x4D, 0x00, 0x2B]

        return bytes == littleEndianClassic || bytes == bigEndianClassic
            || bytes == littleEndianBig || bytes == bigEndianBig
    }

    private static func open(_ data: Data) throws -> OpaquePointer {
        guard data.count <= Int(Int32.max) else {
            throw TIFFError.dataTooLarge(bytes: data.count)
        }

        let tif = data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> OpaquePointer? in
            guard let base = buffer.baseAddress else { return nil }

            return ctiff_open_read(base.assumingMemoryBound(to: UInt8.self), data.count)
        }

        guard let tif else {
            throw TIFFError.decodingFailed(message: lastErrorMessage(nil, default: "failed to open TIFF data"))
        }

        return tif
    }

    private static func readLayout(_ tif: OpaquePointer) throws -> Layout {
        var bitsPerSample: UInt16 = 1
        if ctiff_get_short_scalar_defaulted(tif, 258, &bitsPerSample) == 0 {
            bitsPerSample = 1
        }

        var samplesPerPixel: UInt16 = 1
        if ctiff_get_short_scalar_defaulted(tif, 277, &samplesPerPixel) == 0 {
            samplesPerPixel = 1
        }

        var photometric: UInt16 = 0
        if ctiff_get_short_scalar(tif, 262, &photometric) == 0 {
            photometric = 0
        }

        var planarConfig: UInt16 = 1
        if ctiff_get_short_scalar_defaulted(tif, 284, &planarConfig) == 0 {
            planarConfig = 1
        }

        var sampleFormat: UInt16 = 1
        if ctiff_get_short_scalar_defaulted(tif, 339, &sampleFormat) == 0 {
            sampleFormat = 1
        }

        var compressionRaw: UInt16 = 1
        if ctiff_get_short_scalar_defaulted(tif, 259, &compressionRaw) == 0 {
            compressionRaw = 1
        }

        var extrasamplesPointer: UnsafeMutablePointer<UInt16>?
        var extrasamplesCount: UInt16 = 0
        var extrasamples: [UInt16] = []
        if ctiff_get_extrasamples(tif, &extrasamplesPointer, &extrasamplesCount) != 0,
           let extrasamplesPointer, extrasamplesCount > 0
        {
            extrasamples = Array(
                UnsafeBufferPointer(start: extrasamplesPointer, count: Int(extrasamplesCount)))
        }

        // GeoTIFF tags
        var geoTIFFInfo: GeoTIFFInfo?
        if let geo = readGeoTIFFInfo(tif) {
            geoTIFFInfo = geo
        }

        return Layout(
            width: Int(ctiff_image_width(tif)),
            height: Int(ctiff_image_height(tif)),
            bitsPerSample: Int(bitsPerSample),
            samplesPerPixel: Int(samplesPerPixel),
            photometric: Int(photometric),
            planarConfig: Int(planarConfig),
            sampleFormat: Int(sampleFormat),
            compression: TIFFCompression(raw: Int(compressionRaw)),
            extrasamples: extrasamples,
            isTiled: ctiff_is_tiled(tif) != 0,
            geoTIFFInfo: geoTIFFInfo)
    }

    private static func readGeoTIFFInfo(_ tif: OpaquePointer) -> GeoTIFFInfo? {
        var keyDirectoryPointer: UnsafeMutablePointer<UInt16>?
        var keyDirectoryCount: UInt32 = 0
        var keyDirectory: [UInt16] = []
        if ctiff_get_short_array(tif, 34735, &keyDirectoryPointer, &keyDirectoryCount) != 0,
           let keyDirectoryPointer, keyDirectoryCount > 0
        {
            keyDirectory = Array(
                UnsafeBufferPointer(start: keyDirectoryPointer, count: Int(keyDirectoryCount)))
        }

        var scalePointer: UnsafeMutablePointer<Double>?
        var scaleCount: UInt32 = 0
        var pixelScale: [Double] = []
        if ctiff_get_double_array(tif, 33550, &scalePointer, &scaleCount) != 0,
           let scalePointer, scaleCount > 0
        {
            pixelScale = Array(UnsafeBufferPointer(start: scalePointer, count: Int(scaleCount)))
        }

        var tiepointPointer: UnsafeMutablePointer<Double>?
        var tiepointCount: UInt32 = 0
        var tiepoint: [Double] = []
        if ctiff_get_double_array(tif, 33922, &tiepointPointer, &tiepointCount) != 0,
           let tiepointPointer, tiepointCount > 0
        {
            tiepoint = Array(
                UnsafeBufferPointer(start: tiepointPointer, count: Int(tiepointCount)))
        }

        let info = GeoTIFFInfo.from(
            keyDirectory: keyDirectory,
            pixelScale: pixelScale,
            tiepoint: tiepoint)
        return info.isEmpty ? nil : info
    }

    private static func decode(
        _ data: Data,
        desiredChannels: Int
    ) throws -> STBImageData {
        let tif = try open(data)
        defer { ctiff_close_check_error(tif) }

        let layout = try readLayout(tif)
        try validateLayout(layout)

        // libtiff returns 16-bit sample data in the file's byte order;
        // big-endian (MM) files must be swapped to the package-wide
        // little-endian convention.
        let fileIsBigEndian = isBigEndianSignature(data)
        let needs16BitSwap = layout.bitDepth == .sixteen && fileIsBigEndian

        // Resolve the channel count to load.
        var effectiveChannels = layout.samplesPerPixel
        if desiredChannels > 0, layout.bitDepth == .eight {
            effectiveChannels = desiredChannels
        }

        if layout.bitDepth == .sixteen {
            // 16-bit images are always single-channel in this decoder.
            effectiveChannels = 1
        }

        let byteCount = layout.width * layout.height * effectiveChannels * layout.bitDepth.bytesPerSample
        guard byteCount > 0, byteCount <= Int(Int32.max) else {
            throw TIFFError.dataTooLarge(bytes: byteCount)
        }

        // The raw data is always loaded with the file's channel count,
        // then converted when `desiredChannels` differs (matching the
        // stb_image behavior).
        let rawData: [UInt8]
        if layout.bitDepth == .sixteen {
            let data16 = try decode16Bit(tif, layout: layout)
            rawData = needs16BitSwap ? Self.swap16BitPairs(data16) : data16
        }
        else {
            rawData = try decode8Bit(tif, layout: layout)
        }

        var imageData = STBImageData(
            width: layout.width,
            height: layout.height,
            channels: layout.samplesPerPixel,
            bitDepth: layout.bitDepth,
            data: rawData)

        if layout.bitDepth == .eight, effectiveChannels != layout.samplesPerPixel {
            imageData = imageData.convertedChannels(to: effectiveChannels)
        }

        return imageData
    }

    /// Detects the big-endian (MM) signature.
    static func isBigEndianSignature(_ data: Data) -> Bool {
        guard data.count >= 2 else { return false }

        return data[data.startIndex] == 0x4D && data[data.index(after: data.startIndex)] == 0x4D
    }

    /// Swaps every adjacent byte pair (16-bit little-endian ↔ big-endian).
    static func swap16BitPairs(_ input: [UInt8]) -> [UInt8] {
        var output = input
        guard output.count % 2 == 0 else { return output }

        let count = output.count
        output.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
            guard let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }

            for index in stride(from: 0, to: count, by: 2) {
                let temp = base[index]
                base[index] = base[index + 1]
                base[index + 1] = temp
            }
        }
        return output
    }

    private static func validateLayout(_ layout: Layout) throws {
        guard layout.width > 0, layout.height > 0 else {
            throw TIFFError.decodingFailed(
                message: "invalid dimensions \(layout.width)x\(layout.height)")
        }
        guard layout.compression.isSupportedForDecoding else {
            throw TIFFError.unsupported(
                message: "compression \(layout.compression) is not supported")
        }

        switch layout.bitsPerSample {
        case 8:
            switch layout.photometric {
            case 1: // MINISBLACK
                guard layout.samplesPerPixel == 1 || layout.samplesPerPixel == 2 else {
                    throw TIFFError.unsupported(
                        message: "grayscale image with \(layout.samplesPerPixel) channels is not supported")
                }

            case 2: // RGB
                guard layout.samplesPerPixel == 3 || layout.samplesPerPixel == 4 else {
                    throw TIFFError.unsupported(
                        message: "RGB image with \(layout.samplesPerPixel) channels is not supported")
                }

            case 3: // PALETTE
                throw TIFFError.unsupported(message: "paletted images are not supported")

            case 5: // CMYK
                throw TIFFError.unsupported(message: "CMYK images are not supported")

            case 6: // YCbCr
                throw TIFFError.unsupported(message: "YCbCr images are not supported")

            default:
                throw TIFFError.unsupported(
                    message: "photometric interpretation \(layout.photometric) is not supported")
            }

        case 16:
            guard layout.samplesPerPixel == 1 else {
                throw TIFFError.unsupported(
                    message: "16-bit images with \(layout.samplesPerPixel) channels are not supported (only single-channel)")
            }
            guard layout.photometric == 1 else {
                throw TIFFError.unsupported(
                    message: "16-bit images with photometric interpretation \(layout.photometric) are not supported")
            }

        default:
            throw TIFFError.unsupported(
                message: "\(layout.bitsPerSample)-bit samples are not supported")
        }

        guard layout.planarConfig == 1 else {
            throw TIFFError.unsupported(message: "planar configuration is not supported")
        }
        guard layout.sampleFormat == 1 else { // SAMPLEFORMAT_UINT
            let name = layout.sampleFormat == 3 ? "floating point" : "signed integer"
            throw TIFFError.unsupported(message: "\(name) samples are not supported")
        }
        guard layout.extrasamples.count <= 1 else {
            throw TIFFError.unsupported(
                message: "multiple extra samples are not supported")
        }
    }

    private static func decode8Bit(
        _ tif: OpaquePointer,
        layout: Layout
    ) throws -> [UInt8] {
        let bytesPerRow = layout.width * layout.samplesPerPixel
        let totalBytes = layout.height * bytesPerRow

        var data = [UInt8](repeating: 0, count: totalBytes)

        if layout.isTiled {
            let tileWidth = Int(ctiff_tile_width(tif))
            let tileHeight = Int(ctiff_tile_height(tif))
            guard tileWidth > 0, tileHeight > 0 else {
                throw TIFFError.decodingFailed(message: "invalid tile dimensions")
            }

            let tileSize = Int(ctiff_tile_size(tif))
            guard tileSize > 0 else {
                throw TIFFError.decodingFailed(message: "invalid tile size")
            }

            var tileBuffer = [UInt8](repeating: 0, count: tileSize)
            let tilesAcross = (layout.width + tileWidth - 1) / tileWidth
            let tilesDown = (layout.height + tileHeight - 1) / tileHeight
            let numberOfTiles = ctiff_number_of_tiles(tif)
            guard Int(numberOfTiles) == tilesAcross * tilesDown else {
                throw TIFFError.decodingFailed(
                    message: "tile count mismatch: expected \(tilesAcross * tilesDown), got \(numberOfTiles)")
            }

            try data.withUnsafeMutableBytes { (outputBuffer: UnsafeMutableRawBufferPointer) in
                guard let outputBase = outputBuffer.baseAddress else {
                    throw TIFFError.decodingFailed(message: "output buffer has no base address")
                }

                try tileBuffer.withUnsafeMutableBytes { (tileRawBuffer: UnsafeMutableRawBufferPointer) in
                    guard let tileBase = tileRawBuffer.baseAddress else {
                        throw TIFFError.decodingFailed(message: "output buffer has no base address")
                    }

                    for tileRow in 0 ..< tilesDown {
                        for tileColumn in 0 ..< tilesAcross {
                            let tileIndex = tileRow * tilesAcross + tileColumn
                            let read = ctiff_read_encoded_tile(
                                tif,
                                UInt32(tileIndex),
                                tileBase,
                                Int64(tileSize))
                            guard read == tileSize else {
                                throw TIFFError.decodingFailed(
                                    message: "failed to read tile \(tileIndex)")
                            }

                            // Copy the valid pixel region of the tile
                            // into the output.
                            let yStart = tileRow * tileHeight
                            let xStart = tileColumn * tileWidth
                            for y in 0 ..< tileHeight {
                                let outputY = yStart + y
                                guard outputY < layout.height else { break }

                                let columnsToCopy = min(tileWidth, layout.width - xStart)
                                let tileOffset = y * tileWidth * layout.samplesPerPixel
                                let outputOffset = (outputY * layout.width + xStart)
                                    * layout.samplesPerPixel

                                memcpy(
                                    outputBase + outputOffset,
                                    tileBase + tileOffset,
                                    columnsToCopy * layout.samplesPerPixel)
                            }
                        }
                    }
                }
            }
        }
        else {
            let stripSize = Int(ctiff_strip_size(tif))
            guard stripSize > 0 else {
                throw TIFFError.decodingFailed(message: "invalid strip size")
            }

            let rowsPerStrip = Int(ctiff_rows_per_strip(tif))
            guard rowsPerStrip > 0 else {
                throw TIFFError.decodingFailed(message: "invalid rows per strip")
            }

            var stripBuffer = [UInt8](repeating: 0, count: stripSize)
            let numberOfStrips = Int(ctiff_number_of_strips(tif))
            let stripsPerImage = (layout.height + rowsPerStrip - 1) / rowsPerStrip
            guard numberOfStrips == stripsPerImage else {
                throw TIFFError.decodingFailed(
                    message: "strip count mismatch: expected \(stripsPerImage), got \(numberOfStrips)")
            }

            try data.withUnsafeMutableBytes { (outputBuffer: UnsafeMutableRawBufferPointer) in
                guard let outputBase = outputBuffer.baseAddress else {
                    throw TIFFError.decodingFailed(message: "output buffer has no base address")
                }

                try stripBuffer.withUnsafeMutableBytes { (stripRawBuffer: UnsafeMutableRawBufferPointer) in
                    guard let stripBase = stripRawBuffer.baseAddress else {
                        throw TIFFError.decodingFailed(message: "output buffer has no base address")
                    }

                    for stripIndex in 0 ..< numberOfStrips {
                        let read = ctiff_read_encoded_strip(
                            tif,
                            UInt32(stripIndex),
                            stripBase,
                            Int64(stripSize))
                        guard read > 0 else {
                            throw TIFFError.decodingFailed(
                                message: "failed to read strip \(stripIndex)")
                        }

                        let yStart = stripIndex * rowsPerStrip
                        let rowsInStrip = min(rowsPerStrip, layout.height - yStart)
                        let bytesToCopy = rowsInStrip * bytesPerRow
                        guard Int(read) >= bytesToCopy else {
                            throw TIFFError.decodingFailed(
                                message: "strip \(stripIndex) is truncated: expected \(bytesToCopy) bytes, got \(read)")
                        }

                        memcpy(outputBase + yStart * bytesPerRow, stripBase, bytesToCopy)
                    }
                }
            }
        }

        return data
    }

    private static func decode16Bit(
        _ tif: OpaquePointer,
        layout: Layout
    ) throws -> [UInt8] {
        let bytesPerRow = layout.width * 2
        let totalBytes = layout.height * bytesPerRow

        var data = [UInt8](repeating: 0, count: totalBytes)

        if layout.isTiled {
            let tileWidth = Int(ctiff_tile_width(tif))
            let tileHeight = Int(ctiff_tile_height(tif))
            guard tileWidth > 0, tileHeight > 0 else {
                throw TIFFError.decodingFailed(message: "invalid tile dimensions")
            }

            let tileSize = Int(ctiff_tile_size(tif))
            guard tileSize > 0 else {
                throw TIFFError.decodingFailed(message: "invalid tile size")
            }

            var tileBuffer = [UInt8](repeating: 0, count: tileSize)
            let tilesAcross = (layout.width + tileWidth - 1) / tileWidth
            let tilesDown = (layout.height + tileHeight - 1) / tileHeight
            let numberOfTiles = Int(ctiff_number_of_tiles(tif))
            guard numberOfTiles == tilesAcross * tilesDown else {
                throw TIFFError.decodingFailed(
                    message: "tile count mismatch: expected \(tilesAcross * tilesDown), got \(numberOfTiles)")
            }

            try data.withUnsafeMutableBytes { (outputBuffer: UnsafeMutableRawBufferPointer) in
                guard let outputBase = outputBuffer.baseAddress else {
                    throw TIFFError.decodingFailed(message: "output buffer has no base address")
                }

                try tileBuffer.withUnsafeMutableBytes { (tileRawBuffer: UnsafeMutableRawBufferPointer) in
                    guard let tileBase = tileRawBuffer.baseAddress else {
                        throw TIFFError.decodingFailed(message: "output buffer has no base address")
                    }

                    for tileRow in 0 ..< tilesDown {
                        for tileColumn in 0 ..< tilesAcross {
                            let tileIndex = tileRow * tilesAcross + tileColumn
                            let read = ctiff_read_encoded_tile(
                                tif,
                                UInt32(tileIndex),
                                tileBase,
                                Int64(tileSize))
                            guard read == tileSize else {
                                throw TIFFError.decodingFailed(
                                    message: "failed to read tile \(tileIndex)")
                            }

                            let yStart = tileRow * tileHeight
                            let xStart = tileColumn * tileWidth
                            for y in 0 ..< tileHeight {
                                let outputY = yStart + y
                                guard outputY < layout.height else { break }

                                let columnsToCopy = min(tileWidth, layout.width - xStart)
                                let tileOffset = y * tileWidth * 2
                                let outputOffset = (outputY * layout.width + xStart) * 2

                                memcpy(outputBase + outputOffset, tileBase + tileOffset, columnsToCopy * 2)
                            }
                        }
                    }
                }
            }
        }
        else {
            let stripSize = Int(ctiff_strip_size(tif))
            guard stripSize > 0 else {
                throw TIFFError.decodingFailed(message: "invalid strip size")
            }

            let rowsPerStrip = Int(ctiff_rows_per_strip(tif))
            guard rowsPerStrip > 0 else {
                throw TIFFError.decodingFailed(message: "invalid rows per strip")
            }

            var stripBuffer = [UInt8](repeating: 0, count: stripSize)
            let numberOfStrips = Int(ctiff_number_of_strips(tif))
            let stripsPerImage = (layout.height + rowsPerStrip - 1) / rowsPerStrip
            guard numberOfStrips == stripsPerImage else {
                throw TIFFError.decodingFailed(
                    message: "strip count mismatch: expected \(stripsPerImage), got \(numberOfStrips)")
            }

            try data.withUnsafeMutableBytes { (outputBuffer: UnsafeMutableRawBufferPointer) in
                guard let outputBase = outputBuffer.baseAddress else {
                    throw TIFFError.decodingFailed(message: "output buffer has no base address")
                }

                try stripBuffer.withUnsafeMutableBytes { (stripRawBuffer: UnsafeMutableRawBufferPointer) in
                    guard let stripBase = stripRawBuffer.baseAddress else {
                        throw TIFFError.decodingFailed(message: "output buffer has no base address")
                    }

                    for stripIndex in 0 ..< numberOfStrips {
                        let read = ctiff_read_encoded_strip(
                            tif,
                            UInt32(stripIndex),
                            stripBase,
                            Int64(stripSize))
                        guard read > 0 else {
                            throw TIFFError.decodingFailed(
                                message: "failed to read strip \(stripIndex)")
                        }

                        let yStart = stripIndex * rowsPerStrip
                        let rowsInStrip = min(rowsPerStrip, layout.height - yStart)
                        let bytesToCopy = rowsInStrip * bytesPerRow
                        guard Int(read) >= bytesToCopy else {
                            throw TIFFError.decodingFailed(
                                message: "strip \(stripIndex) is truncated: expected \(bytesToCopy) bytes, got \(read)")
                        }

                        memcpy(outputBase + yStart * bytesPerRow, stripBase, bytesToCopy)
                    }
                }
            }
        }

        return data
    }

    private static func lastErrorMessage(
        _ tif: OpaquePointer?,
        default message: String
    ) -> String {
        if let tif, ctiff_has_error(tif) != 0,
           let error = ctiff_last_error(tif).asString(), error.isEmpty == false
        {
            return error
        }
        return message
    }

}

#endif
