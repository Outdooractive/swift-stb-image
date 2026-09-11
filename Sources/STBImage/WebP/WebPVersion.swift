#if EnableWebP
import CWebP
import Foundation

/// The linked libwebp version, i.e. `WebPDecoder.libwebpVersion`.
public struct WebPVersion: Equatable, CustomStringConvertible, Sendable {

    /// The major version component.
    public let major: Int

    /// The minor version component.
    public let minor: Int

    /// The patch version component.
    public let patch: Int

    init(rawValue: Int32) {
        let value = UInt32(bitPattern: rawValue)
        self.major = Int((value >> 16) & 0xFF)
        self.minor = Int((value >> 8) & 0xFF)
        self.patch = Int(value & 0xFF)
    }

    /// The version as "major.minor.patch", i.e. "1.3.2".
    public var description: String {
        "\(major).\(minor).\(patch)"
    }

}

extension WebPEncoder {

    /// The libwebp version that the encoder was linked against.
    public static var libwebpVersion: WebPVersion {
        WebPVersion(rawValue: WebPGetEncoderVersion())
    }

}

extension WebPDecoder {

    /// The libwebp version that the decoder was linked against.
    public static var libwebpVersion: WebPVersion {
        WebPVersion(rawValue: WebPGetDecoderVersion())
    }

}
#endif
