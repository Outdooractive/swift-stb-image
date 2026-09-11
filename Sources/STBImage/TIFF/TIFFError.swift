#if EnableTIFF
import Foundation

/// Errors that can occur while reading TIFF images.
public enum TIFFError: Error, Sendable {

    /// The data is not TIFF (never thrown by the TIFF decoders themselves,
    /// which only see recognized signatures).
    case notATIFF

    /// The data is recognized as TIFF but can not be decoded.
    case decodingFailed(message: String)

    /// The TIFF contains a variant that is not supported, e.g. paletted
    /// images, CMYK photometric interpretations, planar storage or float
    /// samples.
    case unsupported(message: String)

    /// The TIFF data is too large to be processed
    /// (an `Int32`/`Int` overflow or a size limit was hit).
    case dataTooLarge(bytes: Int)

    /// The decoder produced less data than expected (truncated image).
    case unexpectedDataSize(expected: Int, actual: Int)

}

/// Errors that can occur while writing TIFF images.
public enum TIFFWriteError: Error, Sendable {

    /// The encoder failed to write the image, e.g. for zero-sized images.
    case failedToWrite(message: String)

    /// The pixel buffer does not provide a base address, i.e. it is empty.
    case unexpectedPointerError

}

#endif
