#if EnableTIFF
import Foundation

/// TIFF compression methods.
public enum TIFFCompression: Sendable, Hashable {

    /// No compression (baseline).
    case none

    /// CCITT Group 3 fax encoding (recognized but not supported for
    /// decoding pixel data here).
    case ccittFax3

    /// CCITT Group 4 fax encoding (recognized but not supported for
    /// decoding pixel data here).
    case ccittFax4

    /// Lempel-Ziv & Welch.
    case lzw

    /// Old-style JPEG-in-TIFF (not supported for decoding pixel data
    /// here).
    case jpeg

    /// Deflate (zlib), the legacy tag value 32946.
    case deflateLegacy

    /// Deflate (zlib), as recognized by Adobe (tag value 8).
    case deflate

    /// Macintosh RLE (PackBits).
    case packBits

    /// A compression method not modeled above.
    case unknown(Int)

    /// Creates the enum from a raw tag value.
    public init(raw: Int) {
        switch raw {
        case 1: self = .none
        case 3: self = .ccittFax3
        case 4: self = .ccittFax4
        case 5: self = .lzw
        case 7: self = .jpeg
        case 32946: self = .deflateLegacy
        case 8: self = .deflate
        case 32773: self = .packBits
        default: self = .unknown(raw)
        }
    }

    /// The raw TIFF compression tag value.
    public var rawValueForEncoding: Int {
        switch self {
        case .none: return 1
        case .ccittFax3: return 3
        case .ccittFax4: return 4
        case .lzw: return 5
        case .jpeg: return 7
        case .deflateLegacy: return 32946
        case .deflate: return 8
        case .packBits: return 32773
        case let .unknown(raw): return raw
        }
    }

    /// True when this compression method is supported by the decoder.
    public var isSupportedForDecoding: Bool {
        switch self {
        case .deflate, .deflateLegacy, .lzw, .none, .packBits: return true
        default: return false
        }
    }

    /// True when this compression method is supported by the encoder.
    public var isSupportedForEncoding: Bool {
        switch self {
        case .deflate, .lzw, .none, .packBits: return true
        default: return false
        }
    }

}

#endif
