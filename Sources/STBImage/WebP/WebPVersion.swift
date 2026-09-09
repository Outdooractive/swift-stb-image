import Foundation
import CWebP

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
        major = Int((value >> 16) & 0xFF)
        minor = Int((value >> 8) & 0xFF)
        patch = Int(value & 0xFF)
    }

    /// The version as "major.minor.patch", i.e. "1.3.2".
    public var description: String {
        "\(major).\(minor).\(patch)"
    }

}

public extension WebPEncoder {

    /// The libwebp version that the encoder was linked against.
    static var libwebpVersion: WebPVersion {
        WebPVersion(rawValue: WebPGetEncoderVersion())
    }

}

public extension WebPDecoder {

    /// The libwebp version that the decoder was linked against.
    static var libwebpVersion: WebPVersion {
        WebPVersion(rawValue: WebPGetDecoderVersion())
    }

}
