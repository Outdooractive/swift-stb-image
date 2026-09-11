#if EnableWebP
import CWebP
import Foundation

/// The libwebp decoder configuration, mapping `CWebP.WebPDecoderConfig`.
public struct WebPDecoderConfig: InternalRawRepresentable {

    /// Immutable bitstream features (optional).
    public var input: WebPBitstreamFeatures?

    /// Output buffer (can point to external memory).
    public var output: WebPDecBuffer

    /// Decoding options.
    public var options: WebPDecoderOptions

    /// Initializes the configuration through libwebp's
    /// `WebPInitDecoderConfig`.
    ///
    /// - Throws: ``WebPError/decoderConfigInitializationFailed`` when
    ///   libwebp rejects the initialization (i.e. a version mismatch).
    public init() throws {
        var originConfig = CWebP.WebPDecoderConfig()
        if CWebP.WebPInitDecoderConfig(&originConfig) == 0 {
            throw WebPError.decoderConfigInitializationFailed
        }
        self = WebPDecoderConfig(rawValue: originConfig)
    }

    init(rawValue: CWebP.WebPDecoderConfig) {
        self.input = WebPBitstreamFeatures(rawValue: rawValue.input)
        self.output = WebPDecBuffer(rawValue: rawValue.output)
        self.options = WebPDecoderOptions(rawValue: rawValue.options)
    }

    var rawValue: CWebP.WebPDecoderConfig {
        let inputValue = input?.rawValue ?? CWebP.WebPBitstreamFeatures(
            width: 0,
            height: 0,
            has_alpha: 0,
            has_animation: 0,
            format: 0,
            pad: (0, 0, 0, 0, 0))
        return CWebP.WebPDecoderConfig(input: inputValue, output: output.rawValue, options: options.rawValue)
    }

}

/// Immutable features of a WebP bitstream, as read by
/// ``WebPImageInspector``.
public struct WebPBitstreamFeatures: InternalRawRepresentable, Sendable {

    /// The compression format of the bitstream.
    public enum Format: Int, Sendable {

        /// Undefined or mixed.
        case undefined = 0
        /// Lossy compression (VP8).
        case lossy
        /// Lossless compression (VP8L).
        case lossless

    }

    /// Width in pixels, as read from the bitstream.
    public var width: Int

    /// Height in pixels, as read from the bitstream.
    public var height: Int

    /// True if the bitstream contains an alpha channel.
    public var hasAlpha: Bool

    /// True if the bitstream is an animation.
    public var hasAnimation: Bool

    /// The bitstream's compression format.
    public var format: Format

    /// Padding for later use.
    public var pad: (Int, Int, Int, Int, Int)

    var rawValue: CWebP.WebPBitstreamFeatures {
        let has_alpha = hasAlpha ? 1 : 0
        let has_animation = hasAnimation ? 1 : 0

        return CWebP.WebPBitstreamFeatures(
            width: Int32(width),
            height: Int32(height),
            has_alpha: Int32(has_alpha),
            has_animation: Int32(has_animation),
            format: Int32(format.rawValue),
            pad: (UInt32(pad.0), UInt32(pad.1), UInt32(pad.2), UInt32(pad.3), UInt32(pad.4)))
    }

    init(rawValue: CWebP.WebPBitstreamFeatures) {
        self.width = Int(rawValue.width)
        self.height = Int(rawValue.height)
        self.hasAlpha = rawValue.has_alpha != 0
        self.hasAnimation = rawValue.has_animation != 0
        guard let format = Format(rawValue: Int(rawValue.format)) else {
            preconditionFailure("Unexpected WebP bitstream format value: \(rawValue.format)")
        }

        self.format = format
        self.pad = (Int(rawValue.pad.0), Int(rawValue.pad.1), Int(rawValue.pad.2), Int(rawValue.pad.3), Int(rawValue.pad.4))
    }

}

/// Colorspaces of the decoder's output.
///
/// Note: the naming describes the byte-ordering of packed samples in memory.
/// For instance, MODE_BGRA relates to samples ordered as B,G,R,A,B,G,R,A,...
/// Non-capital names (e.g.:MODE_Argb) relates to pre-multiplied RGB channels.
/// RGBA-4444 and RGB-565 colorspaces are represented by following byte-order:
/// RGBA-4444: [r3 r2 r1 r0 g3 g2 g1 g0], [b3 b2 b1 b0 a3 a2 a1 a0], ...
/// RGB-565: [r4 r3 r2 r1 r0 g5 g4 g3], [g2 g1 g0 b4 b3 b2 b1 b0], ...
/// In the case WEBP_SWAP_16BITS_CSP is defined, the bytes are swapped for
/// these two modes:
/// RGBA-4444: [b3 b2 b1 b0 a3 a2 a1 a0], [r3 r2 r1 r0 g3 g2 g1 g0], ...
/// RGB-565: [g2 g1 g0 b4 b3 b2 b1 b0], [r4 r3 r2 r1 r0 g5 g4 g3], ...
public enum ColorspaceMode: Int, Sendable {

    /// RGB, 3 bytes per pixel.
    case RGB = 0
    /// RGBA, 4 bytes per pixel.
    case RGBA = 1
    /// BGR, 3 bytes per pixel.
    case BGR = 2
    /// BGRA, 4 bytes per pixel.
    case BGRA = 3
    /// ARGB, 4 bytes per pixel.
    case ARGB = 4
    /// Packed RGBA4444, 2 bytes per pixel.
    case RGBA4444 = 5
    /// Packed RGB565, 2 bytes per pixel.
    case RGB565 = 6

    /// RGB-premultiplied transparent modes (alpha value is preserved)
    /// Premultiplied RGBA, 4 bytes per pixel.
    case rgbA = 7
    /// Premultiplied BGRA, 4 bytes per pixel.
    case bgrA = 8
    /// Premultiplied ARGB, 4 bytes per pixel.
    case Argb = 9
    /// Premultiplied packed RGBA4444, 2 bytes per pixel.
    case rgbA4444 = 10

    /// YUV modes must come after RGB ones.
    /// YUV.
    case YUV = 11
    /// YUVA.
    case YUVA = 12
    /// List terminator.
    case LAST = 13

    /// True when the colorspace uses premultiplied RGB channels.
    public var isPremultipliedMode: Bool {
        if self == .rgbA || self == .bgrA || self == .Argb || self == .rgbA4444 {
            return true
        }
        return false
    }

    /// True when the colorspace contains an alpha channel.
    public var isAlphaMode: Bool {
        if self == .RGBA || self == .BGRA || self == .ARGB
            || self == .RGBA4444 || self == .YUVA || isPremultipliedMode
        {
            return true
        }
        return false
    }

    /// True when the colorspace is one of the RGB-style formats
    /// (i.e. everything except YUV/YUVA).
    public var isRGBMode: Bool {
        rawValue < ColorspaceMode.YUV.rawValue
    }

}

/// The libwebp output buffer, mapping `CWebP.WebPDecBuffer`.
public struct WebPDecBuffer: InternalRawRepresentable {

    /// Whether the decode writes into libwebp-allocated memory or into
    /// caller-provided memory.
    public enum ExternalMemoryMode: Equatable, Sendable {

        /// libwebp allocates the output memory.
        case internalMemory
        /// The caller provides the output memory.
        case externalMemory
        /// The caller provides the output memory, using slower code paths.
        case externalMemorySlow

        var libwebpValue: Int32 {
            switch self {
            case .internalMemory:
                0
            case .externalMemory:
                1
            case .externalMemorySlow:
                2
            }
        }

        init(libwebpValue: Int32) {
            switch libwebpValue {
            case 0:
                self = .internalMemory
            case 1:
                self = .externalMemory
            default:
                self = .externalMemorySlow
            }
        }

    }

    /// The buffer contents, either RGBA- or YUVA-style.
    public enum Colorspace {

        /// An RGBA-style buffer.
        case RGBA(WebPRGBABuffer)
        /// A YUVA-style buffer.
        case YUVA(WebPYUVABuffer)

        var rgba: WebPRGBABuffer? {
            if case let .RGBA(buffer) = self {
                return buffer
            }
            return nil
        }

        var yuva: WebPYUVABuffer? {
            if case let .YUVA(buffer) = self {
                return buffer
            }
            return nil
        }

    }

    /// Colorspace.
    public var colorspace: ColorspaceMode

    /// The output's width in pixels.
    public var width: Int

    /// The output's height in pixels.
    public var height: Int

    /// Whether the output is written into internal or external memory.
    public var externalMemoryMode: ExternalMemoryMode

    /// The buffer contents, either RGBA- or YUVA-style.
    public var u: Colorspace

    /// Nameless union of buffer parameters.
    public var pad: (Int, Int, Int, Int)

    var privateMemory: UnsafeMutablePointer<UInt8>?

    var rawValue: CWebP.WebPDecBuffer {
        let originU =
            switch u {
            case let .RGBA(buffer):
                CWebP.WebPDecBuffer.__Unnamed_union_u(RGBA: buffer)
            case let .YUVA(buffer):
                CWebP.WebPDecBuffer.__Unnamed_union_u(YUVA: buffer)
            }
        // let u = colorspace.isRGBMode ? libwebp.WebPDecBuffer.__Unnamed_union_u(RGBA: u.RGBA) :
        // libwebp.WebPDecBuffer.__Unnamed_union_u(YUVA: u.YUVA)
        return CWebP.WebPDecBuffer(
            colorspace: WEBP_CSP_MODE(rawValue: UInt32(colorspace.rawValue)),
            width: Int32(width),
            height: Int32(height),
            is_external_memory: externalMemoryMode.libwebpValue,
            u: originU,
            pad: (UInt32(pad.0), UInt32(pad.1), UInt32(pad.2), UInt32(pad.3)),
            private_memory: privateMemory)
    }

    init(rawValue: CWebP.WebPDecBuffer) {
        guard let colorspace = ColorspaceMode(rawValue: Int(rawValue.colorspace.rawValue)) else {
            preconditionFailure("Unexpected WebP colorspace value: \(rawValue.colorspace.rawValue)")
        }

        self.colorspace = colorspace
        self.width = Int(rawValue.width)
        self.height = Int(rawValue.height)
        self.externalMemoryMode = ExternalMemoryMode(libwebpValue: rawValue.is_external_memory)
        self.u = colorspace.isRGBMode ? Colorspace.RGBA(rawValue.u.RGBA) : Colorspace.YUVA(rawValue.u.YUVA)
        self.pad = (Int(rawValue.pad.0), Int(rawValue.pad.1), Int(rawValue.pad.2), Int(rawValue.pad.3))
        self.privateMemory = rawValue.private_memory
    }

}

/// The libwebp decoding options, mapping `CWebP.WebPDecoderOptions`.
public struct WebPDecoderOptions: InternalRawRepresentable, Sendable {

    /// If true (1), skip the in-loop filtering.
    public var bypassFiltering: Int

    /// If true (1), use faster pointwise upsampling.
    public var noFancyUpsampling: Int

    /// If true, cropping is applied _first_.
    public var useCropping: Bool

    /// Top-left position for cropping. Will be snapped to even values
    /// by libwebp.
    public var cropLeft: Int

    /// Top-left position for cropping. Will be snapped to even values
    /// by libwebp.
    public var cropTop: Int

    /// Width of the cropping area.
    public var cropWidth: Int

    /// Height of the cropping area.
    public var cropHeight: Int

    /// If true, scaling is applied _afterward_.
    public var useScaling: Bool

    /// Final resolution width.
    public var scaledWidth: Int

    /// Final resolution height.
    public var scaledHeight: Int

    /// If true, use multi-threaded decoding.
    public var useThreads: Bool

    /// Dithering strength (0 = off, 100 = full).
    public var ditheringStrength: Int

    /// Alpha dithering strength in [0..100].
    public var alphaDitheringStrength: Int

    /// If true (1), flip the output vertically.
    public var flip: Int

    /// Padding for later use.
    public var pad: (Int, Int, Int, Int, Int)

    var rawValue: CWebP.WebPDecoderOptions {
        let useCropping = useCropping ? 1 : 0
        let useScaling = useScaling ? 1 : 0
        let useThreads = useThreads ? 1 : 0

        return CWebP.WebPDecoderOptions(
            bypass_filtering: Int32(bypassFiltering),
            no_fancy_upsampling: Int32(noFancyUpsampling),
            use_cropping: Int32(useCropping),
            crop_left: Int32(cropLeft),
            crop_top: Int32(cropTop),
            crop_width: Int32(cropWidth),
            crop_height: Int32(cropHeight),
            use_scaling: Int32(useScaling),
            scaled_width: Int32(scaledWidth),
            scaled_height: Int32(scaledHeight),
            use_threads: Int32(useThreads),
            dithering_strength: Int32(ditheringStrength),
            flip: Int32(flip),
            alpha_dithering_strength: Int32(alphaDitheringStrength),
            pad: (UInt32(pad.0), UInt32(pad.1), UInt32(pad.2), UInt32(pad.3), UInt32(pad.4)))
    }

    init(rawValue: CWebP.WebPDecoderOptions) {
        self.bypassFiltering = Int(rawValue.bypass_filtering)
        self.noFancyUpsampling = Int(rawValue.no_fancy_upsampling)
        self.useCropping = rawValue.use_cropping != 0
        self.cropLeft = Int(rawValue.crop_left)
        self.cropTop = Int(rawValue.crop_top)
        self.cropWidth = Int(rawValue.crop_width)
        self.cropHeight = Int(rawValue.crop_height)
        self.useScaling = rawValue.use_scaling != 0
        self.scaledWidth = Int(rawValue.scaled_width)
        self.scaledHeight = Int(rawValue.scaled_height)
        self.useThreads = rawValue.use_threads != 0
        self.ditheringStrength = Int(rawValue.dithering_strength)
        self.flip = Int(rawValue.flip)
        self.alphaDitheringStrength = Int(rawValue.alpha_dithering_strength)
        self.pad = (Int(rawValue.pad.0), Int(rawValue.pad.1), Int(rawValue.pad.2), Int(rawValue.pad.3), Int(rawValue.pad.4))
    }

    /// Creates options with libwebp's defaults (no filtering bypass,
    /// no cropping, no scaling, no threads, no dithering, no flip).
    public init() {
        self.bypassFiltering = 0
        self.noFancyUpsampling = 0
        self.useCropping = false
        self.cropLeft = 0
        self.cropTop = 0
        self.cropWidth = 0
        self.cropHeight = 0
        self.useScaling = false
        self.scaledWidth = 0
        self.scaledHeight = 0
        self.useThreads = false
        self.ditheringStrength = 0
        self.flip = 0
        self.alphaDitheringStrength = 0
        self.pad = (0, 0, 0, 0, 0)
    }

}
#endif
