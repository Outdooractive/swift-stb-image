import CSTBImage
import Foundation

// MARK: - ImageReadError

/// Errors that can occur while reading PNG or JPG images.
public enum STBImageReadError: Error {

    /// The data is recognized as PNG/JPG but can not be decoded.
    case failedToReadImage

    /// The data is too large to be passed to the C decoder
    /// (which takes Int32 sizes).
    case dataTooLarge(bytes: Int)

}

/// Errors that can occur while writing PNG or JPG images.
public enum STBImageWriteError: Error {

    /// The encoder failed to write the image, e.g. for zero-sized images.
    case failedToWrite

    /// The pixel buffer does not provide a base address, i.e. it is empty.
    case unexpectedPointerError

}

/// The image format detected from a file signature.
public enum STBImageFormat {

    /// The format could not be detected.
    case unknown
    /// JPEG data.
    case jpg
    /// PNG data.
    case png
    /// WebP data.
    case webp

}

/// Supported export formats.
///
/// `STBExportFormat.png(compressionLevel:)` and `STBExportFormat.webp(...)`
/// can be constructed with defaults, e.g. `STBExportFormat.png(compressionLevel: 0)`.
public enum STBExportFormat {
    case jpg(quality: Int)
    case png
    case webp(WebPExportOptions)

    /// PNG with the specified compression level (0 = fastest, 9 = best
    /// compression). Defaults to level 6.
    public static func png(compressionLevel: Int = 6) -> STBExportFormat {
        .pngWithCompressionLevel(compressionLevel)
    }

    // Internal: carries the compression level of `png(compressionLevel:)`.
    // External switches over this enum need a default case.
    case pngWithCompressionLevel(Int)
}

/// Options for WebP export.
///
/// All values have sensible defaults; only `quality` is usually set.
public struct WebPExportOptions: Sendable {

    /// Between 0 (smallest file) and 100 (biggest). Quality 100 forces
    /// lossless encoding.
    public var quality: Int

    /// Quality/speed trade-off (0 = fast, 6 = slower-better).
    /// `nil` keeps the libwebp preset default.
    public var method: Int?

    /// If true, try to use multi-threaded encoding.
    public var useThreads: Bool

    /// If true, preserve the exact RGB values under transparent areas.
    /// Without it, invisible RGB information is discarded for better
    /// compression.
    public var exact: Bool

    /// Creates WebP export options.
    ///
    /// - Parameters:
    ///   - quality: Between 0 (smallest file) and 100 (biggest). Quality 100
    ///     forces lossless encoding.
    ///   - method: Quality/speed trade-off (0 = fast, 6 = slower-better).
    ///     `nil` keeps the libwebp preset default.
    ///   - useThreads: If true, try to use multi-threaded encoding.
    ///   - exact: If true, preserve the exact RGB values under transparent
    ///     areas. Without it, invisible RGB information is discarded for
    ///     better compression.
    public init(
        quality: Int = 85,
        method: Int? = nil,
        useThreads: Bool = false,
        exact: Bool = false
    ) {
        self.quality = quality
        self.method = method
        self.useThreads = useThreads
        self.exact = exact
    }

}

extension STBExportFormat {

    /// WebP with the specified options.
    public static func webp(
        quality: Int,
        method: Int? = nil,
        useThreads: Bool = false,
        exact: Bool = false
    ) -> STBExportFormat {
        .webp(WebPExportOptions(quality: quality, method: method, useThreads: useThreads, exact: exact))
    }

}

/// Reads and writes images in the PNG, JPG and WebP formats.
///
/// All functions are thread safe. PNG export uses zlib with adaptive
/// per-row filtering; the compression level is passed per call.
public enum STBImageCoder {

    private static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    private static let jpgSignature: [UInt8] = [0xFF, 0xD8, 0xFF]

    /// Detects the image format from the file signature.
    ///
    /// Recognizes PNG (8-byte signature), JPG (first 3 bytes) and
    /// WebP ("RIFF"/"WEBP" markers).
    ///
    /// - Parameter data: The encoded image data.
    /// - Returns: The detected format, or `.unknown` when the signature
    ///   is not recognized.
    public static func imageFormat(_ data: Data) -> STBImageFormat {
        guard data.count >= 3 else { return .unknown }

        if data.prefix(8).elementsEqual(Self.pngSignature) {
            return .png
        }
        else if data.prefix(3).elementsEqual(Self.jpgSignature) {
            return .jpg
        }
        else if data.count >= 12,
                data[0] == 0x52, data[1] == 0x49, data[2] == 0x46, data[3] == 0x46, // "RIFF"
                data[8] == 0x57, data[9] == 0x45, data[10] == 0x42, data[11] == 0x50 // "WEBP"
        {
            return .webp
        }

        return .unknown
    }

    /// Decodes an image from encoded PNG, JPG or WebP data.
    ///
    /// - Returns: `nil` when the data is not a recognized image format.
    /// - Throws: When the data is recognized but can not be decoded.
    ///
    /// - Parameter desiredChannels: Number of channels to convert the image
    ///   to, where 0 keeps the original channel count. Applies to PNG and JPG
    ///   only; WebP output is RGB or RGBA depending on the bitstream (use
    ///   `WebPDecoder` for explicit format control).
    public static func load(
        from data: Data,
        desiredChannels: Int = 0
    ) throws -> STBImageData? {
        precondition((0 ... 4).contains(desiredChannels), "desiredChannels must be in 0...4.")

        switch imageFormat(data) {
        // Check PNG, JPG
        case .jpg, .png:
            return try loadJpgPng(from: data, desiredChannels: desiredChannels)

        // Check WebP
        case .webp:
            return try loadWebP(from: data)

        case .unknown:
            return nil
        }
    }

    /// Encodes an image.
    ///
    /// - Parameters:
    ///   - pngCompressionLevel: PNG compression level, 0 = fastest to
    ///     9 = best compression. Defaults to 6.
    public static func export(
        imageData: STBImageData,
        format: STBExportFormat,
        pngCompressionLevel: Int = 6
    ) throws -> Data {
        switch format {
        case let .jpg(quality):
            return try exportJPG(from: imageData, quality: quality)
        case .png, .pngWithCompressionLevel:
            let level: Int
            if case let .pngWithCompressionLevel(requested) = format {
                level = requested
            }
            else {
                level = pngCompressionLevel
            }
            return try exportPNG(from: imageData, compressionLevel: level)
        case let .webp(options):
            return try exportWebP(
                from: imageData,
                quality: Float(options.quality),
                method: options.method,
                useThreads: options.useThreads,
                exact: options.exact)
        }
    }

    /// Converts encoded image data into another format.
    ///
    /// Data in the requested format is returned unchanged. Unrecognized or
    /// corrupt input, and failed conversions, throw instead of silently
    /// returning the original data.
    public static func converting(
        _ data: Data,
        to format: STBExportFormat
    ) throws -> Data {
        let originalFormat = STBImageCoder.imageFormat(data)
        // Don't convert the same format
        switch (originalFormat, format) {
        case (.jpg, .jpg), (.png, .png), (.webp, .webp):
            return data
        default:
            break
        }

        guard let imageData = try STBImageCoder.load(from: data) else {
            throw STBImageReadError.failedToReadImage
        }

        return try STBImageCoder.export(imageData: imageData, format: format)
    }

    /// Converts encoded image data into another format.
    ///
    /// Same as `converting(_:to:)`, but returns the original data unchanged
    /// when the input is unrecognized or corrupt, or the conversion fails.
    public static func convert(
        _ data: Data,
        to format: STBExportFormat
    ) -> Data {
        (try? converting(data, to: format)) ?? data
    }

}

// MARK: - Private implementation

extension STBImageCoder {

    // WebP

    @inlinable
    static func loadWebP(
        from data: Data
    ) throws -> STBImageData {
        let decoder = WebPDecoder()
        let options = WebPDecoderOptions()
        let imageLayout = try decoder.requiredOutputLayout(for: data, options: options)

        var output = [UInt8](repeating: 0, count: imageLayout.byteCount)
        _ = try output.withUnsafeMutableBufferPointer { buffer in
            try decoder.decodeIntoBuffer(
                data,
                output: buffer,
                layout: imageLayout,
                options: options,
                format: imageLayout.bytesPerPixel == 3 ? .rgb : .rgba)
        }

        return STBImageData(
            width: imageLayout.width,
            height: imageLayout.height,
            bpp: imageLayout.bytesPerPixel,
            data: output)
    }

    @inlinable
    static func exportWebP(
        from imageData: STBImageData,
        quality: Float = 85,
        method: Int? = nil,
        useThreads: Bool = false,
        exact: Bool = false
    ) throws -> Data {
        let encoder = WebPEncoder()
        let stride = imageData.width * imageData.bpp

        var config = WebPEncoderConfig.preset(.picture, quality: quality)
        if quality >= 100 {
            config.lossless = 1
        }
        if let method {
            config.method = method
        }
        if useThreads {
            config.threadLevel = 1
        }
        if exact {
            config.exact = 1
        }

        return try encoder.encode(
            imageData.data,
            format: imageData.bpp == 3 ? .rgb : .rgba,
            config: config,
            originWidth: imageData.width,
            originHeight: imageData.height,
            stride: stride)
    }

    // JPG/PNG

    @inlinable
    static func loadJpgPng(
        from data: Data,
        desiredChannels: Int = 0
    ) throws -> STBImageData {
        // The C API takes Int32 sizes, guard against overflow traps.
        guard data.count <= Int32.max else {
            throw STBImageReadError.dataTooLarge(bytes: data.count)
        }
        let dataLength = Int32(data.count)
        var width: Int32 = 0
        var height: Int32 = 0
        var bpp: Int32 = 0

        let pixels = try data.withUnsafeBytes { (p: UnsafeRawBufferPointer) -> UnsafeMutablePointer<UInt8> in
            let uc = p.baseAddress!.assumingMemoryBound(to: UInt8.self)
            guard let pixels = load_image_from_memory(uc, dataLength, &width, &height, &bpp, Int32(desiredChannels)) else {
                throw STBImageReadError.failedToReadImage
            }
            return pixels
        }
        defer { free_image(pixels) }

        // stb reports the number of channels in the file, even when the
        // pixels were converted to `desiredChannels`
        let effectiveBpp = desiredChannels == 0 ? Int(bpp) : desiredChannels
        let data = [UInt8](UnsafeBufferPointer(start: pixels, count: Int(width * height * Int32(effectiveBpp))))

        return STBImageData(
            width: Int(width),
            height: Int(height),
            bpp: effectiveBpp,
            data: data)
    }

    @inlinable
    static func exportPNG(
        from imageData: STBImageData,
        compressionLevel: Int = 6,
    ) throws -> Data {
        guard imageData.width > 0, imageData.height > 0 else {
            throw STBImageWriteError.failedToWrite
        }
        let width = Int32(imageData.width)
        let height = Int32(imageData.height)
        let bpp = Int32(imageData.bpp)
        let compressionLevel = Int32(max(0, min(9, compressionLevel)))

        let content = ContentBox()

        let code = try imageData.data.withUnsafeBufferPointer {
            guard let baseAddress = $0.baseAddress else {
                throw STBImageWriteError.unexpectedPointerError
            }

            return write_image_png_to_func(storeContent, Unmanaged.passUnretained(content).toOpaque(), width, height, bpp, baseAddress, compressionLevel)
        }

        guard code != 0 else {
            throw STBImageWriteError.failedToWrite
        }

        return content.data
    }

    @inlinable
    static func exportJPG(
        from imageData: STBImageData,
        quality: Int = 85
    ) throws -> Data {
        guard imageData.width > 0, imageData.height > 0 else {
            throw STBImageWriteError.failedToWrite
        }
        let width = Int32(imageData.width)
        let height = Int32(imageData.height)
        let bpp = Int32(imageData.bpp)

        let content = ContentBox()

        let code = try imageData.data.withUnsafeBufferPointer {
            guard let baseAddress = $0.baseAddress else {
                throw STBImageWriteError.unexpectedPointerError
            }

            return write_image_jpg_to_func(storeContent, Unmanaged.passUnretained(content).toOpaque(), width, height, bpp, baseAddress, Int32(quality))
        }

        guard code != 0 else {
            throw STBImageWriteError.failedToWrite
        }

        return content.data
    }

}

/// Reference box that receives the encoded image data from the C export
/// functions.
///
/// The context pointer passed to `stbi_write_*_to_func` must point to stable
/// memory that outlives the whole export call. Passing `&someData` would form
/// an `UnsafeMutableRawPointer` to a `Data` struct, which is undefined
/// behavior because `Data` may contain an object reference.
@usableFromInline
final class ContentBox {

    @usableFromInline
    var data = Data()

    @inlinable
    init() {}

}

@inlinable
func storeContent(
    context: UnsafeMutableRawPointer?,
    data: UnsafeMutableRawPointer?,
    size: Int32
) {
    guard let data,
          let context,
          size > 0
    else { return }

    let chunk = Data(bytes: data, count: Int(size))
    let content = Unmanaged<ContentBox>.fromOpaque(context).takeUnretainedValue()
    content.data.append(chunk)
}
