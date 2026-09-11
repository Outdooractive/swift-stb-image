#if EnableTIFF
import CTIFF
import Foundation

/// Inspects TIFF data without decoding the pixel buffer.
public enum TIFFImageInspector {

    /// Inspects the TIFF data and returns a summary of the first page.
    ///
    /// - Parameter data: The encoded TIFF data.
    /// - Returns: The image info.
    /// - Throws: `TIFFError` when the data is corrupt or contains an
    ///   unsupported variant.
    public static func inspect(_ data: Data) throws -> TIFFImageInfo {
        let image = try TIFFDecoder.inspectLayout(data)
        return image.info
    }

    /// Returns the libtiff version string, e.g.
    /// `"LIBTIFF, Version 4.5.1\nCopyright ..."`.
    public static var libtiffVersion: String {
        ctiff_version_string().asString() ?? ""
    }

}

extension UnsafePointer where Pointee == CChar {

    /// Converts a NUL-terminated C string into a Swift `String`.
    func asString() -> String? {
        String(cString: self)
    }

}

#endif
