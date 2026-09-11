#if EnableWebP
import Foundation

/// Errors that can occur during WebP processing.
public enum WebPError: Error, Sendable {

    /// Something related to pointer operations went wrong.
    case unexpectedPointerError
    /// An unexpected internal error, with a description.
    case unexpectedError(withMessage: String)
    /// The WebP decoder configuration could not be initialized.
    case decoderConfigInitializationFailed
    /// The colorspace mode is not supported for this operation.
    case unsupportedColorspaceMode
    /// The WebP encoder configuration is invalid.
    case invalidWebPConfig
    /// The decode output format is not supported through this API
    /// (YUV output is RGB-oriented only).
    case unsupportedDecodeFormat
    /// The output buffer is too small for the decoded image.
    case outputBufferTooSmall(required: Int, actual: Int)

}
#endif
