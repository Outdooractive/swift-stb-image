#if EnableTIFF
import CTIFF
import Foundation

/// Encodes TIFF data.
///
/// The encoder always writes strip-based, north-up files with one strip of
/// `height` rows unless the image is larger than 8 KB per row (libtiff's
/// defaults apply then). 8-bit gray/gray+alpha/RGB/RGBA and 16-bit
/// single-channel images are supported.
public enum TIFFEncoder {

    /// Encodes an image into TIFF data.
    ///
    /// - Parameters:
    ///   - image: The image to encode.
    ///   - options: Export options (compression, GeoTIFF info).
    /// - Returns: The encoded TIFF data.
    /// - Throws: `TIFFWriteError` when encoding fails or the options
    ///   contain an unsupported compression method.
    public static func export(
        image: STBImageData,
        options: TIFFExportOptions = TIFFExportOptions()
    ) throws -> Data {
        guard options.compression.isSupportedForEncoding else {
            throw TIFFWriteError.failedToWrite(
                message: "compression \(options.compression) is not supported for encoding")
        }
        guard image.width > 0, image.height > 0 else {
            throw TIFFWriteError.failedToWrite(
                message: "invalid dimensions \(image.width)x\(image.height)")
        }
        guard image.width <= Int(UInt32.max), image.height <= Int(UInt32.max) else {
            throw TIFFError.dataTooLarge(bytes: image.width * image.height)
        }
        guard image.data.count == image.width * image.height * image.bytesPerPixel
        else {
            throw TIFFWriteError.failedToWrite(
                message: "data size mismatch: expected \(image.width * image.height * image.bytesPerPixel) bytes, got \(image.data.count)")
        }

        if let geoTIFFInfo = options.geoTIFFInfo, geoTIFFInfo.isEmpty == false {
            guard let epsgCode = geoTIFFInfo.epsgCode ?? geoTIFFInfo.geographicEPSGCode,
                  epsgCode > 0, epsgCode <= Int(UInt16.max)
            else {
                throw TIFFWriteError.failedToWrite(
                    message: "GeoTIFFInfo requires an EPSG code in 1...65535")
            }
        }

        var sink: UnsafeMutableRawPointer?
        guard let tif = ctiff_open_write(&sink) else {
            throw TIFFWriteError.failedToWrite(message: "failed to create TIFF encoder")
        }

        do {
            try write(image: image, options: options, tif: tif)
        }
        catch {
            ctiff_close_check_error(tif)
            var size = 0
            if let buffer = ctiff_sink_finish(&sink, &size) {
                ctiff_free(buffer)
            }
            throw error
        }

        let closeFailed = ctiff_close_check_error(tif) != 0
        var size = 0
        let buffer = ctiff_sink_finish(&sink, &size)

        if closeFailed {
            ctiff_free(buffer)
            throw TIFFWriteError.failedToWrite(message: lastErrorMessage(tif))
        }

        guard let buffer else {
            throw TIFFWriteError.failedToWrite(message: lastErrorMessage(tif, default: "encoder produced no data"))
        }

        let data = Data(bytes: buffer, count: size)
        ctiff_free(buffer)
        return data
    }

    // MARK: - Private implementation

    private static func write(
        image: STBImageData,
        options: TIFFExportOptions,
        tif: OpaquePointer
    ) throws {
        ctiff_set_scalar(tif, 256, UInt32(image.width)) // IMAGEWIDTH
        ctiff_set_scalar(tif, 257, UInt32(image.height)) // IMAGELENGTH
        ctiff_set_short_scalar(tif, 258, UInt16(image.bitDepth.rawValue)) // BITSPERSAMPLE
        ctiff_set_short_scalar(tif, 277, UInt16(image.channels)) // SAMPLESPERPIXEL
        ctiff_set_short_scalar(tif, 284, 1) // PLANARCONFIG_CONTIG
        ctiff_set_short_scalar(tif, 259, UInt16(options.compression.rawValueForEncoding)) // COMPRESSION

        switch image.channels {
        case 1:
            ctiff_set_short_scalar(tif, 262, 1) // PHOTOMETRIC_MINISBLACK
        case 2:
            ctiff_set_short_scalar(tif, 262, 1) // PHOTOMETRIC_MINISBLACK
            ctiff_set_extrasamples(tif, 2) // EXTRASAMPLE_UNASSALPHA
        case 3:
            ctiff_set_short_scalar(tif, 262, 2) // PHOTOMETRIC_RGB
        case 4:
            ctiff_set_short_scalar(tif, 262, 2) // PHOTOMETRIC_RGB
            ctiff_set_extrasamples(tif, 2) // EXTRASAMPLE_UNASSALPHA
        default:
            throw TIFFWriteError.failedToWrite(message: "unsupported channel count \(image.channels)")
        }

        // One strip for the whole image (ROWSPERSTRIP = height keeps the
        // strip bookkeeping trivial and matches what libtiff produces for
        // small rasters).
        ctiff_set_scalar(tif, 278, UInt32(image.height)) // ROWSPERSTRIP

        if let geoTIFFInfo = options.geoTIFFInfo, geoTIFFInfo.isEmpty == false {
            writeGeoTIFFInfo(geoTIFFInfo, tif: tif)
        }

        try image.data.withUnsafeBufferPointer { (buffer: UnsafeBufferPointer<UInt8>) throws in
            guard let base = buffer.baseAddress else {
                throw TIFFWriteError.unexpectedPointerError
            }

            let ok = ctiff_write_encoded_strip(
                tif,
                0,
                UnsafeMutableRawPointer(mutating: base),
                Int64(image.data.count))
            guard ok != 0 else {
                throw TIFFWriteError.failedToWrite(
                    message: lastErrorMessage(tif, default: "failed to write image data"))
            }
        }
    }

    private static func writeGeoTIFFInfo(
        _ info: GeoTIFFInfo,
        tif: OpaquePointer
    ) {
        if let pixelScale = info.pixelScale {
            var scale: [Double] = [pixelScale.x, pixelScale.y, 0.0]
            ctiff_set_double_array(tif, 33550, &scale, 3)
        }

        if let tiepoint = info.tiepoint {
            var tie: [Double] = [
                tiepoint.raster.i,
                tiepoint.raster.j,
                0.0,
                tiepoint.world.x,
                tiepoint.world.y,
                0.0,
            ]
            ctiff_set_double_array(tif, 33922, &tie, 6)
        }

        let keyDirectory = info.keyDirectory
        if keyDirectory.count > 4 {
            ctiff_set_short_array(tif, 34735, keyDirectory, UInt32(keyDirectory.count))
        }
    }

    private static func lastErrorMessage(
        _ tif: OpaquePointer?,
        default message: String = "failed to write TIFF"
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
