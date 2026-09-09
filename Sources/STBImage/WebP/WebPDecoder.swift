import Foundation
import CWebP

/// There's no definition of WebPDecodingError in libwebp.
/// We map VP8StatusCode enum as WebPDecodingError instead.
public enum WebPDecodingError: UInt32, Error, Sendable {

    /// The decode succeeded. Shouldn't be used as an error.
    case ok = 0
    /// Memory allocation failed.
    case outOfMemory
    /// A parameter was invalid.
    case invalidParam
    /// The bitstream is corrupt or undecodable.
    case bitstreamError
    /// The bitstream uses an unsupported feature.
    case unsupportedFeature
    /// The decode was suspended.
    case suspended
    /// The decode was aborted by the user.
    case userAbort
    /// Not enough data was provided to decode the image.
    case notEnoughData
    /// An internal error outside of the documented libwebp status codes.
    case unknownError = 9999

    init(vp8StatusCodeRawValue: UInt32) {
        self = WebPDecodingError(rawValue: vp8StatusCodeRawValue) ?? .unknownError
    }

}

/// The pixel format of the decoder's output buffer.
///
/// The non-capital names (e.g. `rgbA`) relate to pre-multiplied RGB channels.
/// `rgba4444` and `rgb565` produce 2 bytes per pixel, the RGB variants
/// 3 bytes, everything else 4 bytes per pixel.
public enum WebPDecodePixelFormat: Sendable {

    /// RGB, 3 bytes per pixel.
    case rgb
    /// RGBA, 4 bytes per pixel.
    case rgba
    /// BGR, 3 bytes per pixel.
    case bgr
    /// BGRA, 4 bytes per pixel.
    case bgra
    /// ARGB, 4 bytes per pixel.
    case argb
    /// Packed RGBA4444, 2 bytes per pixel.
    case rgba4444
    /// Packed RGB565, 2 bytes per pixel.
    case rgb565
    /// Premultiplied RGBA, 4 bytes per pixel.
    case rgbA
    /// Premultiplied BGRA, 4 bytes per pixel.
    case bgrA
    /// Premultiplied ARGB, 4 bytes per pixel.
    case Argb
    /// Premultiplied packed RGBA4444, 2 bytes per pixel.
    case rgbA4444
    /// YUV, not supported through the RGB-oriented decode API.
    case yuv
    /// YUVA, not supported through the RGB-oriented decode API.
    case yuva

    var colorspace: ColorspaceMode {
        switch self {
        case .rgb:
                .RGB
        case .rgba:
                .RGBA
        case .bgr:
                .BGR
        case .bgra:
                .BGRA
        case .argb:
                .ARGB
        case .rgba4444:
                .RGBA4444
        case .rgb565:
                .RGB565
        case .rgbA:
                .rgbA
        case .bgrA:
                .bgrA
        case .Argb:
                .Argb
        case .rgbA4444:
                .rgbA4444
        case .yuv:
                .YUV
        case .yuva:
                .YUVA
        }
    }

}

/// Decodes WebP bitstreams into RGB-style pixel buffers.
public struct WebPDecoder: Sendable {

    /// Creates a decoder.
    public init() {}

    /// Calculates the required output buffer size for the given options
    /// and format, without decoding.
    ///
    /// - Parameters:
    ///   - webPData: The encoded WebP data.
    ///   - options: The decoding options, i.e. crop and scale settings.
    ///   - format: The pixel format of the output buffer.
    /// - Returns: The required buffer size in bytes.
    /// - Throws: ``WebPError`` when the bitstream can not be inspected.
    public func requiredOutputByteCount(
        for webPData: Data,
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat = .rgba
    ) throws -> Int {
        try requiredOutputLayout(
            for: webPData,
            options: options,
            format: format)
        .byteCount
    }

    private func decodeIntoBuffer(
        _ webPData: Data,
        output: UnsafeMutableBufferPointer<UInt8>,
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat
    ) throws -> Int {
        let layout = try requiredOutputLayout(for: webPData, options: options, format: format)
        return try decodeIntoBuffer(
            webPData,
            output: output,
            layout: layout,
            options: options,
            format: format)
    }

    /// Decodes into a caller-provided buffer using a precomputed output layout.
    ///
    /// - Note: `layout` must have been obtained from `requiredOutputLayout`
    ///   with the same `options` and `format`, otherwise the output is undefined.
    @usableFromInline
    func decodeIntoBuffer(
        _ webPData: Data,
        output: UnsafeMutableBufferPointer<UInt8>,
        layout: OutputLayout,
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat
    ) throws -> Int {
        guard format.colorspace.isRGBMode else {
            throw WebPError.unsupportedDecodeFormat
        }
        guard output.count >= layout.byteCount else {
            throw WebPError.outputBufferTooSmall(required: layout.byteCount, actual: output.count)
        }
        guard let base = output.baseAddress else {
            throw WebPError.outputBufferTooSmall(required: layout.byteCount, actual: output.count)
        }

        var config = try makeConfig(options, format.colorspace)
        config.output.externalMemoryMode = .externalMemory
        config.output.width = layout.width
        config.output.height = layout.height
        let rgbaBuffer = WebPRGBABuffer(
            rgba: base,
            stride: Int32(layout.stride),
            size: layout.byteCount
        )
        config.output.u = .RGBA(rgbaBuffer)
        try webPData.withUnsafeBytes { rawPtr in
            let span = Span<UInt8>(_unsafeBytes: rawPtr)
            try decode(span, config: &config)
        }
        return layout.byteCount
    }

    /// Decodes a WebP bitstream into a caller-provided buffer.
    ///
    /// - Parameters:
    ///   - webPData: The encoded WebP data.
    ///   - output: The output buffer, at least
    ///     `requiredOutputByteCount(for:options:format:)` bytes large.
    ///   - options: The decoding options, i.e. crop and scale settings.
    ///   - format: The pixel format of the output buffer.
    /// - Returns: The number of bytes written into the output buffer.
    /// - Throws: ``WebPError/outputBufferTooSmall(required:actual:)`` when
    ///   the buffer is too small, ``WebPError/unsupportedDecodeFormat`` for
    ///   YUV formats, and ``WebPDecodingError`` for undecodable bitstreams.
    @discardableResult
    public func decode(
        _ webPData: Data,
        into output: inout [UInt8],
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat = .rgba
    ) throws -> Int {
        try output.withUnsafeMutableBufferPointer { buffer in
            try decodeIntoBuffer(webPData, output: buffer, options: options, format: format)
        }
    }

    /// Decodes a WebP bitstream into a new `Data` value.
    ///
    /// - Parameters:
    ///   - webPData: The encoded WebP data.
    ///   - options: The decoding options, i.e. crop and scale settings.
    ///   - format: The pixel format of the output.
    /// - Returns: The decoded pixel data.
    /// - Throws: ``WebPError/unsupportedDecodeFormat`` for YUV formats,
    ///   and ``WebPDecodingError`` for undecodable bitstreams.
    public func decode(
        _ webPData: Data,
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat = .rgba
    ) throws -> Data {
        guard format.colorspace.isRGBMode else {
            throw WebPError.unsupportedDecodeFormat
        }
        let layout = try requiredOutputLayout(
            for: webPData,
            options: options,
            format: format
        )
        var output = Data(count: layout.byteCount)
        let written = try output.withUnsafeMutableBytes { rawPtr -> Int in
            guard let baseAddress = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw WebPError.outputBufferTooSmall(required: layout.byteCount, actual: 0)
            }
            let buffer = UnsafeMutableBufferPointer(start: baseAddress, count: rawPtr.count)
            return try decodeIntoBuffer(
                webPData,
                output: buffer,
                layout: layout,
                options: options,
                format: format)
        }
        if written == output.count {
            return output
        }
        return output.prefix(written)
    }

    private func decode(
        _ webPData: borrowing Span<UInt8>,
        config: inout WebPDecoderConfig
    ) throws {
        var rawConfig: CWebP.WebPDecoderConfig = config.rawValue

        try webPData.withUnsafeBytes { rawPtr in
            guard let basePointer = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw WebPDecodingError.unknownError
            }

            let status = WebPDecode(basePointer, webPData.count, &rawConfig)
            if status != VP8_STATUS_OK {
                throw WebPDecodingError(vp8StatusCodeRawValue: status.rawValue)
            }
        }

        switch config.output.u {
        case .RGBA:
            config.output.u = WebPDecBuffer.Colorspace.RGBA(rawConfig.output.u.RGBA)
        case .YUVA:
            config.output.u = WebPDecBuffer.Colorspace.YUVA(rawConfig.output.u.YUVA)
        }
    }

    private func makeConfig(
        _ options: WebPDecoderOptions,
        _ colorspace: ColorspaceMode
    ) throws -> WebPDecoderConfig {
        var config = try WebPDecoderConfig()
        config.options = options
        config.output.colorspace = colorspace
        return config
    }

    /// Inspects the WebP bitstream and calculates the output dimensions for
    /// the given options, without decoding.
    ///
    /// When `format` is `nil`, the pixel format is chosen automatically:
    /// RGBA when the bitstream contains an alpha channel, RGB otherwise.
    ///
    /// - Parameters:
    ///   - webPData: The encoded WebP data.
    ///   - options: The decoding options. Crop and scale settings modify the
    ///     reported dimensions.
    ///   - format: The pixel format of the output buffer, or `nil` to pick
    ///     RGB/RGBA based on the bitstream's alpha channel.
    /// - Returns: The output layout with dimensions and buffer size.
    /// - Throws: ``WebPError`` when the bitstream can not be inspected.
    public func requiredOutputLayout(
        for webPData: Data,
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat? = nil
    ) throws -> OutputLayout {
        let feature = try WebPImageInspector.inspect(webPData)
        var width = feature.width
        var height = feature.height

        if options.useCropping {
            if options.cropWidth > 0 {
                width = options.cropWidth
            }
            if options.cropHeight > 0 {
                height = options.cropHeight
            }
        }
        if options.useScaling {
            if options.scaledWidth > 0 {
                width = options.scaledWidth
            }
            if options.scaledHeight > 0 {
                height = options.scaledHeight
            }
        }

        let format: WebPDecodePixelFormat = if let format {
            format
        }
        else if feature.hasAlpha {
            .rgba
        }
        else {
            .rgb
        }

        let bytesPerPixel = format.bytesPerPixel
        let stride = width * bytesPerPixel
        let byteCount = stride * height
        return OutputLayout(
            width: width,
            height: height,
            bytesPerPixel: bytesPerPixel,
            stride: stride,
            byteCount: byteCount
        )
    }

}

/// The dimensions and buffer size required for a WebP decode.
public struct OutputLayout {

    /// The output's width in pixels.
    public let width: Int

    /// The output's height in pixels.
    public let height: Int

    /// Bytes per pixel of the output: 2, 3 or 4, depending on the format.
    public let bytesPerPixel: Int

    /// The number of bytes per output row.
    public let stride: Int

    /// The total output buffer size in bytes.
    public let byteCount: Int

}

private extension WebPDecodePixelFormat {

    var bytesPerPixel: Int {
        switch self {
        case .rgb, .bgr:
            3
        case .rgba4444, .rgb565, .rgbA4444:
            2
        default:
            4
        }
    }

}
