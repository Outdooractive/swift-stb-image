#if EnableWebP
import CWebP
import Foundation

/// A customized error that describes the pattern of error causes.
/// However, the error is unlikely to happen normally but it's still better to handle with throw-catch than fatal error.
public enum WebPEncoderError: Error, Sendable {

    /// The encoder configuration or a parameter is invalid.
    case invalidParameter

    /// The picture import step failed.
    case versionMismatched

}

/// The mapped error codes that `CWebP.WebPEncode` returns.
public enum WebPEncodeStatusCode: Int, Error, Sendable {

    /// No error.
    case ok = 0
    /// Memory error allocating objects.
    case outOfMemory
    /// Memory error while flushing bits.
    case bitstreamOutOfMemory
    /// A pointer parameter is NULL.
    case nullParameter
    /// The configuration is invalid.
    case invalidConfiguration
    /// The picture has invalid width/height.
    case badDimension
    /// The partition is bigger than 512k.
    case partition0Overflow
    /// The partition is bigger than 16M.
    case partitionOverflow
    /// Error while flushing bytes.
    case badWrite
    /// The file is bigger than 4G.
    case fileTooBig
    /// Abort request by user.
    case userAbort
    /// List terminator. Always last.
    case last
    /// A status code outside of the documented libwebp range.
    case unknownError = 9999

    init(libwebpRawValue: Int) {
        self = WebPEncodeStatusCode(rawValue: libwebpRawValue) ?? .unknownError
    }

}

/// The pixel format of the encoder's input buffer.
///
/// The buffer must contain `stride * height` bytes, with `stride` being the
/// number of bytes per row (i.e. `width * bytesPerPixel`).
public enum WebPEncodePixelFormat: Sendable {

    /// RGB, 3 bytes per pixel.
    case rgb
    /// RGBA, 4 bytes per pixel.
    case rgba
    /// RGBX, 4 bytes per pixel with an ignored fourth byte.
    case rgbx
    /// BGR, 3 bytes per pixel.
    case bgr
    /// BGRA, 4 bytes per pixel.
    case bgra
    /// BGRX, 4 bytes per pixel with an ignored fourth byte.
    case bgrx

}

/// Encodes pixel data into WebP.
public struct WebPEncoder: Sendable {

    typealias WebPPictureImporter = (UnsafeMutablePointer<WebPPicture>, UnsafeMutablePointer<UInt8>, Int32) -> Int32

    /// Creates an encoder.
    public init() {}

    /// Encodes pixel data into WebP.
    ///
    /// - Parameters:
    ///   - webPData: The raw pixel data, at least `stride * originHeight`
    ///     bytes.
    ///   - format: The pixel format of the input buffer.
    ///   - config: The encoder configuration.
    ///   - originWidth: The width of the input image in pixels.
    ///   - originHeight: The height of the input image in pixels.
    ///   - stride: The number of bytes per input row.
    ///   - resizeWidth: When set together with `resizeHeight`, the picture
    ///     is rescaled to this width as part of the encoding.
    ///   - resizeHeight: When set together with `resizeWidth`, the picture
    ///     is rescaled to this height as part of the encoding.
    /// - Returns: The encoded WebP data.
    /// - Throws: ``WebPEncoderError/invalidParameter`` for invalid
    ///   configurations, and ``WebPEncodeStatusCode`` for encode failures.
    public func encode(
        _ webPData: [UInt8],
        format: WebPEncodePixelFormat,
        config: WebPEncoderConfig,
        originWidth: Int,
        originHeight: Int,
        stride: Int,
        resizeWidth: Int = 0,
        resizeHeight: Int = 0
    ) throws -> Data {
        try webPData.withUnsafeBufferPointer {
            try encode(
                $0,
                format: format,
                config: config,
                originWidth: originWidth,
                originHeight: originHeight,
                stride: stride,
                resizeWidth: resizeWidth,
                resizeHeight: resizeHeight)
        }
    }

    /// Encodes pixel data into WebP.
    ///
    /// - Parameters:
    ///   - data: The raw pixel data, at least `stride * originHeight` bytes.
    ///   - format: The pixel format of the input buffer.
    ///   - config: The encoder configuration.
    ///   - originWidth: The width of the input image in pixels.
    ///   - originHeight: The height of the input image in pixels.
    ///   - stride: The number of bytes per input row.
    ///   - resizeWidth: When set together with `resizeHeight`, the picture
    ///     is rescaled to this width as part of the encoding.
    ///   - resizeHeight: When set together with `resizeWidth`, the picture
    ///     is rescaled to this height as part of the encoding.
    /// - Returns: The encoded WebP data.
    /// - Throws: ``WebPEncoderError/invalidParameter`` for invalid
    ///   configurations, and ``WebPEncodeStatusCode`` for encode failures.
    public func encode(
        _ data: UnsafeBufferPointer<UInt8>,
        format: WebPEncodePixelFormat,
        config: WebPEncoderConfig,
        originWidth: Int,
        originHeight: Int,
        stride: Int,
        resizeWidth: Int = 0,
        resizeHeight: Int = 0
    ) throws -> Data {
        // libwebp reads originHeight rows of `stride` bytes, anything shorter
        // would be read out of bounds.
        precondition(data.count >= stride * originHeight, "Data is smaller than the specified image dimensions.")
        guard let baseAddress = data.baseAddress else {
            throw WebPError.unexpectedPointerError
        }

        let importer = importer(for: format)
        return try encode(
            UnsafeMutablePointer(mutating: baseAddress),
            importer: importer,
            config: config,
            originWidth: originWidth,
            originHeight: originHeight,
            stride: stride,
            resizeWidth: resizeWidth,
            resizeHeight: resizeHeight)
    }

    private func importer(for format: WebPEncodePixelFormat) -> WebPPictureImporter {
        switch format {
        case .rgb:
            { picturePtr, data, stride in
                WebPPictureImportRGB(picturePtr, data, stride)
            }

        case .rgba:
            { picturePtr, data, stride in
                WebPPictureImportRGBA(picturePtr, data, stride)
            }

        case .rgbx:
            { picturePtr, data, stride in
                WebPPictureImportRGBX(picturePtr, data, stride)
            }

        case .bgr:
            { picturePtr, data, stride in
                WebPPictureImportBGR(picturePtr, data, stride)
            }

        case .bgra:
            { picturePtr, data, stride in
                WebPPictureImportBGRA(picturePtr, data, stride)
            }

        case .bgrx:
            { picturePtr, data, stride in
                WebPPictureImportBGRX(picturePtr, data, stride)
            }
        }
    }

    private func encode(
        _ dataPtr: UnsafeMutablePointer<UInt8>,
        importer: WebPPictureImporter,
        config: WebPEncoderConfig,
        originWidth: Int,
        originHeight: Int,
        stride: Int,
        resizeWidth: Int = 0,
        resizeHeight: Int = 0
    ) throws -> Data {
        var config = config.rawValue
        if WebPValidateConfig(&config) == 0 {
            throw WebPEncoderError.invalidParameter
        }

        var picture = WebPPicture()
        if WebPPictureInit(&picture) == 0 {
            throw WebPEncoderError.invalidParameter
        }
        defer {
            WebPPictureFree(&picture)
        }

        picture.use_argb = config.lossless == 0 ? 0 : 1
        picture.width = Int32(originWidth)
        picture.height = Int32(originHeight)

        let ok = importer(&picture, dataPtr, Int32(stride))
        if ok == 0 {
            throw WebPEncoderError.versionMismatched
        }

        if resizeHeight > 0, resizeWidth > 0 {
            if WebPPictureRescale(&picture, Int32(resizeWidth), Int32(resizeHeight)) == 0 {
                throw WebPEncodeStatusCode.outOfMemory
            }
        }

        var buffer = WebPMemoryWriter()
        WebPMemoryWriterInit(&buffer)
        // The writer owns its `mem` buffer until ownership is handed over to
        // the returned `Data`. Clear it on every error path to prevent leaks.
        var ownsBuffer = false
        defer {
            if ownsBuffer == false {
                WebPMemoryWriterClear(&buffer)
            }
        }
        let writeWebP: @convention(c) (UnsafePointer<UInt8>?, Int, UnsafePointer<WebPPicture>?)
            -> Int32 = { data, size, picture -> Int32 in
                WebPMemoryWrite(data, size, picture)
            }
        picture.writer = writeWebP

        try withUnsafeMutableBytes(of: &buffer) { ptr in
            picture.custom_ptr = ptr.baseAddress

            if WebPEncode(&config, &picture) == 0 {
                throw WebPEncodeStatusCode(libwebpRawValue: Int(picture.error_code.rawValue))
            }
        }
        ownsBuffer = true

        guard let pointer = buffer.mem else {
            return Data()
        }

        return Data(bytesNoCopy: pointer, count: buffer.size, deallocator: .custom { rawPointer, _ in
            WebPFree(rawPointer)
        })
    }

}
#endif
