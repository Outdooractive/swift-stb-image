[![][image-1]][1]
[![][image-2]][2]
[![](https://img.shields.io/github/license/Outdooractive/swift-stb-image)](https://github.com/Outdooractive/swift-stb-image/blob/main/LICENSE)
[![](https://img.shields.io/github/v/release/Outdooractive/swift-stb-image?sort=semver&display_name=tag)](https://github.com/Outdooractive/swift-stb-image/releases) [![](https://img.shields.io/github/release-date/Outdooractive/swift-stb-image?display_date=published_at
)](https://github.com/Outdooractive/swift-stb-image/releases)
[![](https://img.shields.io/github/issues/Outdooractive/swift-stb-image
)](https://github.com/Outdooractive/swift-stb-image/issues) [![](https://img.shields.io/github/issues-pr/Outdooractive/swift-stb-image
)](https://github.com/Outdooractive/swift-stb-image/pulls)
[![](https://img.shields.io/github/check-runs/Outdooractive/swift-stb-image/main)](https://github.com/Outdooractive/swift-stb-image/actions)

# STBImage
A Swift wrapper around the image reader and writer from the [stb package][2] and [libwebp][3], for reading and writing PNG, JPG and WebP images.

## Table of Contents

- [STBImage](#stbimage)
  - [Features](#features)
  - [Notes](#notes)
  - [Requirements](#requirements)
  - [Installation with Swift Package Manager](#installation-with-swift-package-manager)
  - [Quick start](#quick-start)
- [Loading images](#loading-images)
  - [STBImage](#stbimage-1)
  - [STBImageData](#stbimagedata)
  - [STBImageCoder](#stbimagecoder)
  - [Grayscale images](#grayscale-images)
- [Pixel access](#pixel-access)
  - [Subscripts](#subscripts)
  - [Pixel iteration](#pixel-iteration)
  - [unsafePixelwiseConvert](#unsafepixelwiseconvert)
- [Alpha](#alpha)
- [Blending and compositing](#blending-and-compositing)
- [Transformations](#transformations)
  - [Rotation and flipping](#rotation-and-flipping)
  - [Rescaling](#rescaling)
  - [Extraction](#extraction)
- [Export and conversion](#export-and-conversion)
  - [PNG compression levels](#png-compression-levels)
  - [WebP export options](#webp-export-options)
  - [convert and converting](#convert-and-converting)
- [WebP decoding](#webp-decoding)
- [WebP encoding](#webp-encoding)
- [Error handling](#error-handling)
- [Thread safety](#thread-safety)
- [Acknowledgments](#acknowledgments)
- [Related packages](#related-packages)
- [Contributing](#contributing)
- [License](#license)
- [Authors](#authors)

## Features

- Reads PNG and JPG via [stb_image][2], WebP via [libwebp][3]
- Writes PNG and JPG via [stb_image_write][2] and WebP via [libwebp][3], including lossless WebP
- Format auto-detection (`imageFormat`) for PNG, JPG and WebP, based on the file signature
- RGB (3 channels) and RGBA (4 channels) images as simple `Sendable`/`Hashable` value types
- Grayscale (1 channel) and gray+alpha (2 channels) images can be loaded with automatic channel conversion
- Fast pixel access through subscripts, plus a safe pixel iterator (`forEachPixel`/`mapPixels`) and an unsafe fast path (`unsafePixelwiseConvert`)
- Alpha compositing ("over" blending) of equally sized images, and compositing at an arbitrary offset with clipping
- Transformations: 90° rotations, horizontal/vertical flipping, bilinear rescaling, and region extraction
- PNG export with adaptive per-row filtering and configurable compression level (default 6, range 0–9)
- WebP export with quality, method, multi-threading and `exact` options
- Lossless WebP roundtrips (quality 100 with `exact`)
- In-memory only: everything works on `Data`, `[UInt8]` and `URL` convenience
- Pure Swift wrapper without external Swift dependencies; requires the system libwebp

## Notes

This package intentionally provides the smallest common denominator of the involved C libraries. Some things to be aware of:

- `STBImage` supports RGB and RGBA images only. Grayscale images (1 or 2 channels in the file) are loaded as `STBImageData` with `bpp` 1 or 2, and can be converted to RGB/RGBA while loading with `desiredChannels` (see [Grayscale images](#grayscale-images)).
- `STBImageCoder.load` returns `nil` for unrecognized formats and throws for recognized but corrupt/undecodable data. The failable `STBImage` initializers swallow both cases and return `nil`.
- PNG, JPG and lossless WebP roundtrips are pixel-exact for fully opaque images. Lossless WebP still discards the RGB values of fully transparent pixels unless the `exact` option is enabled (see [WebP export options](#webp-export-options)).
- Alpha values are straight (not premultiplied). Bilinear rescaling interpolates channels independently, which can produce halos around hard transparency edges.
- JPG export ignores the alpha channel (a limitation of stb_image_write), and produces baseline JPEG only.
- WebP animations can be inspected (`hasAnimation`) but not decoded — only the first frame of an animated WebP would be decoded, which is why animated WebP input is rejected.

## Requirements

This package requires Swift 6.3 or higher, and compiles on macOS (\>= macOS 15) and Linux. Two system libraries are required: libwebp (WebP support, `brew install webp` on macOS, `apt install libwebp-dev` on Debian/Ubuntu, resolved through `pkg-config`) and zlib (PNG export; ships with macOS, install `zlib1g-dev` on Debian/Ubuntu).

## Installation with Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/Outdooractive/swift-stb-image", from: "1.0.0"),
],
targets: [
    .target(name: "MyTarget", dependencies: [
        .product(name: "STBImage", package: "swift-stb-image"),
    ]),
]
```

## Quick start

```swift
import STBImage

// Load an image (PNG, JPG or WebP is detected automatically)
guard let image = STBImage(url: url) else { ... }
print(image.description) // Image<RGBA>(width: 256, height: 256)

// Read and write pixels
let red = image[x, y, .red]
image[x, y, .alpha] = 128

// Pixel-wise processing
image.mapPixels { pixel in
    var pixel = pixel
    pixel.red = 255 - pixel.red
    return pixel
}

// Blend another image on top
var base = image
base.blendWith(overlay, at: 16, y: 16)

// Transform
let rotated = image.rotated(quarterTurns: 1)
let smaller = image.resized(width: 128, height: 128)
let tile = image.extract(x: 0, y: 0, width: 64, height: 64)

// Export
let png = try image.export(.png)
let jpg = try image.export(.jpg(quality: 85))
let webp = try image.export(.webp(quality: 85))
let lossless = try image.export(.webp(quality: 100, exact: true))
```

See the [tests for more examples][4].

# Loading images

## STBImage
[Implementation][5]

`STBImage` is the central value type: an RGB or RGBA image with its pixel data in a single `[UInt8]` buffer, row by row, top to bottom, interleaved per pixel (R, G, B, A):
```swift
/// The image's width in pixels.
public let width: Int
/// The image's height in pixels.
public let height: Int
/// The number of channels: 3 (RGB) or 4 (RGBA).
public private(set) var channels: Int
/// True when the image has an alpha channel.
public var hasAlpha: Bool { get }

/// True when the image has at least one pixel with an alpha value below 255.
public var isTransparent: Bool { get }

/// Create an image from raw pixel data.
public init(width: Int, height: Int, channels: Int, data: [UInt8])

/// Create an RGBA image filled with a single value.
public init(width: Int, height: Int, value: UInt8)

/// Create an image filled with a single color. Without `alpha`,
/// the image has three (RGB) channels, otherwise four (RGBA).
public init(width: Int, height: Int, red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8? = nil)

/// Convert an `STBImageData` (requires `bpp` 3 or 4).
public init?(imageData: STBImageData)

/// Load from encoded PNG/JPG/WebP data.
public init?(data: Data)

/// Load from encoded data, converting to the desired channel count.
public init?(data: Data, desiredChannels: Int)

/// Load from a file.
public init?(url: URL)

/// Load from a file, converting to the desired channel count.
public init?(url: URL, desiredChannels: Int)
```

Example:
```swift
let image = STBImage(width: 256, height: 256, red: 0, green: 0, blue: 0, alpha: 255)
print(image.description) // Image<RGBA>(width: 256, height: 256)

let photo = STBImage(url: URL(fileURLWithPath: "photo.jpg"))!
print(photo.hasAlpha) // false

let grayAsRGB = STBImage(data: grayPngData, desiredChannels: 3)!
print(grayAsRGB.channels) // 3
```

## STBImageData
[Implementation][6]

`STBImageData` is the raw image representation without the RGB/RGBA restriction — it is what the decoders return and what the encoders accept:
```swift
/// The image's width in pixels.
public let width: Int
/// The image's height in pixels.
public let height: Int
/// Bytes per pixel: 1 (gray), 2 (gray+alpha), 3 (RGB) or 4 (RGBA).
public let bpp: Int
/// The raw pixel data.
public let data: [UInt8]
```

`STBImageCoder.load` returns an `STBImageData`, which can be exported directly, or converted into an `STBImage` when `bpp` is 3 or 4:
```swift
let imageData = try STBImageCoder.load(from: data)
let image = imageData.flatMap(STBImage.init(imageData:)) // nil for gray images
```

## STBImageCoder
[Implementation][7]

`STBImageCoder` contains the generic load/export/convert machinery:
```swift
/// Detect the image format from the file signature.
public static func imageFormat(_ data: Data) -> STBImageFormat

/// Decode PNG, JPG or WebP data.
///
/// - Returns: `nil` when the data is not a recognized image format.
/// - Throws: When the data is recognized but can not be decoded.
///
/// - Parameter desiredChannels: Number of channels to convert the image
///   to, where 0 keeps the original channel count. Applies to PNG and JPG
///   only; WebP output is RGB or RGBA depending on the bitstream (use
///   `WebPDecoder` for explicit format control).
public static func load(from data: Data, desiredChannels: Int = 0) throws -> STBImageData?

/// Encode an image.
///
/// - Parameter pngCompressionLevel: PNG compression level, 0 = fastest
///   to 9 = best compression. Defaults to 6.
public static func export(imageData: STBImageData, format: STBExportFormat, pngCompressionLevel: Int = 6) throws -> Data

/// Convert encoded image data into another format, throwing on failure.
public static func converting(_ data: Data, to format: STBExportFormat) throws -> Data

/// Convert encoded image data into another format, returning the original
/// data when the input is unrecognized or corrupt, or the conversion fails.
public static func convert(_ data: Data, to format: STBExportFormat) -> Data
```

Example:
```swift
// Format detection
let format = STBImageCoder.imageFormat(data) // .png, .jpg, .webp or .unknown

// Load with error handling
do {
    let imageData = try STBImageCoder.load(from: data)
    // imageData is nil for unknown formats, thrown errors are decode failures
}
catch {
    print("Couldn't decode the image: \(error)")
}

// Convert between formats
let webpData = STBImageCoder.convert(pngData, to: .webp(quality: 85))
```

## Grayscale images

stb_image reports grayscale (1 channel) and gray+alpha (2 channels) images with their original `bpp`. Such images can not be turned into an `STBImage` directly, but `desiredChannels` converts them while loading — and because `desiredChannels` also applies to RGB(A) sources, it can be used to drop or add an alpha channel at load time as well:

```swift
let gray = try #require(STBImageCoder.load(from: grayPngData))
print(gray.bpp) // 1

let asRGB = try STBImageCoder.load(from: grayPngData, desiredChannels: 3)!
print(asRGB.bpp) // 3, gray values are replicated into all channels

let asRGBA = try STBImageCoder.load(from: grayPngData, desiredChannels: 4)!
// gray values replicated, alpha = 255

let withoutAlpha = try STBImageCoder.load(from: rgbaPngData, desiredChannels: 3)!
// alpha channel dropped

// Convenience on STBImage:
let image = STBImage(data: grayPngData, desiredChannels: 3)!
```

# Pixel access

## Subscripts
[Implementation][5]

```swift
/// Read/write a single byte of the pixel buffer.
public subscript(data index: Int) -> UInt8 { get set }

/// Read/write a pixel channel by coordinates.
public subscript(x: Int, y: Int, c: Int) -> UInt8 { get set }

/// Read/write a pixel channel by coordinates, using the RGBA enum.
public subscript(x: Int, y: Int, c: STBImage.RGBA) -> UInt8 { get set }

/// Get the buffer index of a pixel/channel.
public func dataIndex(x: Int, y: Int, c: Int = 0) -> Int

/// Get the buffer index of a pixel/channel for arbitrary image dimensions.
public static func dataIndex(x: Int, y: Int, c: Int = 0, width: Int, height: Int, channels: Int) -> Int
```

The `STBImage.RGBA` (and `STBImage.RGB`) enums describe the channels:
```swift
public enum RGBA: Int, CaseIterable {
    case red = 0
    case green = 1
    case blue = 2
    case alpha = 3
}
```

Example:
```swift
var image = STBImage(width: 2, height: 2, value: 0)

image[0, 0, .red] = 200
image[0, 0, 1] = 100 // same as .green

// Index arithmetic for manual loops
let index = image.dataIndex(x: 1, y: 1, c: 3) // alpha of the bottom right pixel
image.data[index] = 128
```

Out-of-bounds access traps with a precondition failure — these are programming errors, not recoverable conditions.

## Pixel iteration
[Implementation][8]

For safe pixel-wise processing there are two iterator methods and a `Pixel` value type:
```swift
/// A single pixel value with its position.
/// `alpha` is `nil` when the image has no alpha channel.
public struct Pixel {
    public let x: Int
    public let y: Int
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var alpha: UInt8?
}

/// Iterate over all pixels of the image (read-only).
public func forEachPixel(_ body: (Pixel) -> Void)

/// Transform all pixels of the image. On images without an alpha channel
/// the returned `alpha` value is ignored. When `alpha` is `nil`, the
/// existing alpha value is kept.
public mutating func mapPixels(_ transform: (Pixel) -> Pixel)
```

Example:
```swift
// Convert to grayscale
image.mapPixels { pixel in
    var pixel = pixel
    let gray = UInt8((Int(pixel.red) + Int(pixel.green) + Int(pixel.blue)) / 3)
    pixel.red = gray
    pixel.green = gray
    pixel.blue = gray
    return pixel
}

// Or collect something from every pixel
var brightnessSum = 0
image.forEachPixel { pixel in
    brightnessSum += Int(pixel.red) + Int(pixel.green) + Int(pixel.blue)
}
```

## unsafePixelwiseConvert
[Implementation][5]

`mapPixels`/`forEachPixel` copy channel values in and out of a `Pixel` struct. For maximum performance, `unsafePixelwiseConvert` gives direct buffer access through an `UnsafePixelRef`:
```swift
/// Convert pixels.
/// - Note: `UnsafePixelRef` contains an `UnsafeMutableBufferPointer`.
/// So it's unsafe to bring it outside the closure.
public mutating func unsafePixelwiseConvert(_ body: (UnsafePixelRef) -> Void)

/// Convert pixels in the specified range.
public mutating func unsafePixelwiseConvert(
    _ xRange: Range<Int>,
    _ yRange: Range<Int>,
    _ body: (UnsafePixelRef) -> Void)
```

The pixel ref provides `x`, `y`, `channels` and an unchecked channel subscript:
```swift
var image = STBImage(width: 4, height: 4, value: 0)
image.unsafePixelwiseConvert { ref in
    ref[0] = UInt8(ref.x * 10 + ref.y)
}

// Only the center 2x2 pixels
image.unsafePixelwiseConvert(1 ..< 3, 1 ..< 3) { ref in
    ref[3] = 255 // channel 3 = alpha
}
```

As the note says: the `UnsafePixelRef` is only valid inside the closure, and reading the image through its own subscripts inside the closure would be an exclusivity violation.

# Alpha

[Implementation][5]

```swift
/// True when the image has at least one pixel with an alpha value below 255.
public var isTransparent: Bool { get }

/// Removes the alpha channel by dropping every fourth byte (RGB -> RGBA).
public mutating func dropAlpha()
```

Example:
```swift
if overlay.isTransparent {
    // contains see-through pixels
}

var image = STBImage(data: rgbaPngData)!
image.dropAlpha()
print(image.channels) // 3
```

`dropAlpha` requires that the buffer size matches `width * height * 4` and traps otherwise.

# Blending and compositing

[Implementation][5]

The blend functions implement standard "over" alpha compositing. Pixel values are assumed to be in range [0, 255]:
```swift
/// Draw image with alpha blending. Both images must have the same dimensions.
public mutating func blendWith(_ other: STBImage)

/// Draw image at the specified position with alpha blending. The image is
/// placed with its top left corner at `(x, y)`. Negative positions and
/// overhang beyond the image bounds are allowed and get clipped.
public mutating func blendWith(_ other: STBImage, at x: Int, y: Int)

/// Draw images with alpha blending, stacked in order.
/// All images must match the dimensions of the image.
public mutating func blendWith(images: [STBImage])

/// Blend images into a new image (returns the first image when the
/// array contains less than two elements, nil for an empty array).
public static func blend(images: [STBImage]) -> STBImage?
```

Example:
```swift
// Stack a photo over a background image
var base = STBImage(url: backgroundUrl)!
let overlay = STBImage(url: overlayUrl)!

base.blendWith(overlay)

// Or draw it at an offset, e.g. a 64x64 thumbnail on a 256x256 canvas
var canvas = STBImage(width: 256, height: 256, red: 255, green: 255, blue: 255, alpha: 255)
let thumbnail = overlay.resized(width: 64, height: 64)!
canvas.blendWith(thumbnail, at: 96, y: 96)

// Static variant
let blended = STBImage.blend(images: [background, overlay1, overlay2])
```

A fully transparent overlay pixel leaves the base pixel unchanged, a fully opaque overlay pixel replaces it, everything in between is alpha blended.

# Transformations

## Rotation and flipping
[Implementation][9]

All transformations return new images, the original is never modified:
```swift
/// Returns a copy of the image rotated by `quarterTurns * 90°`.
/// Positive values rotate clockwise.
public func rotated(quarterTurns: Int) -> STBImage

/// Returns a copy of the image, mirrored along the vertical axis.
public func flippedHorizontally() -> STBImage

/// Returns a copy of the image, mirrored along the horizontal axis.
public func flippedVertically() -> STBImage
```

Example:
```swift
let rotated = image.rotated(quarterTurns: 1)  // 90° clockwise
let rotated = image.rotated(quarterTurns: -1) // 90° counter-clockwise
let upsideDown = image.rotated(quarterTurns: 2)
let mirrored = image.flippedHorizontally()
```

## Rescaling
[Implementation][9]

```swift
/// Returns a bilinearly rescaled copy of the image, or `nil` for
/// invalid dimensions.
public func resized(width: Int, height: Int) -> STBImage?
```

Rescaling uses bilinear interpolation on the center of each destination pixel. Channels are interpolated independently and alpha is treated as straight (not premultiplied), which can produce halos around hard transparency edges. Very large downscale factors will alias — for WebP sources, prefer the decoder's scaling options (see [WebP decoding](#webp-decoding)) which use libwebp's high-quality rescaler:

```swift
let thumbnail = image.resized(width: 64, height: 64)!
let sameSize = image.resized(width: image.width, height: image.height)! // returns self
```

## Extraction
[Implementation][5]

```swift
/// Returns a copy of the specified region, or `nil` when the region
/// is not fully contained in the image.
public func extract(x: Int, y: Int, width: Int, height: Int) -> STBImage?
```

Example:
```swift
let tile = image.extract(x: 0, y: 0, width: 64, height: 64)!
let subRegion = image.extract(x: 16, y: 16, width: 32, height: 32)!
```

# Export and conversion

## PNG compression levels
[Implementation][7]

PNG export uses zlib with adaptive per-row filtering (all 5 PNG filter types are scored per row, the best is used — the same heuristic libpng applies). PNG export defaults to compression level 6. Level 0 is roughly twice as fast with somewhat larger files, level 9 compresses best but is considerably slower:
```swift
// Default (level 6)
let png = try image.export(.png)

// Explicit level
let fast = try image.export(.png(compressionLevel: 0))
let best = try image.export(.png(compressionLevel: 9))

// Or as a parameter
let png = try image.export(.png, pngCompressionLevel: 9)

// The level is clamped to 0...9
let png = try image.export(.png(compressionLevel: 42)) // level 9
```

PNG export is lossless regardless of the compression level.

## WebP export options
[Implementation][7] / [WebP encoder implementation][10]

`STBExportFormat.webp` carries a `WebPExportOptions` value, constructed with defaults:
```swift
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
}

extension STBExportFormat {
    /// WebP with the specified options.
    public static func webp(
        quality: Int,
        method: Int? = nil,
        useThreads: Bool = false,
        exact: Bool = false) -> STBExportFormat
}
```

Quality 100 forces lossless encoding. Note that libwebp discards the RGB values of fully transparent pixels unless `exact` is enabled:
```swift
// Lossy
let webp = try image.export(.webp(quality: 85))

// Fast lossy encoding
let webp = try image.export(.webp(quality: 85, method: 0))

// Lossless, pixel-exact roundtrip (see the note above)
let webp = try image.export(.webp(quality: 100, exact: true))
```

JPG export takes a quality between 1 and 100 (values outside the range are clamped by stb_image_write), and drops the alpha channel:
```swift
let jpg = try image.export(.jpg(quality: 85))
```

## convert and converting
[Implementation][7]

`converting` throws when the input can not be decoded or the conversion fails, `convert` falls back to the original data in all failure cases (including "input is already in the requested format"):
```swift
// Returns the original data when it is already a PNG
let png = STBImageCoder.convert(pngData, to: .png)

// Cross-format conversion, silently falling back to the input
let webp = STBImageCoder.convert(jpgData, to: .webp(quality: 85))

// The throwing variant
let webp = try STBImageCoder.converting(jpgData, to: .webp(quality: 85))
```

# WebP decoding
[Implementation][11] / [WebP test cases][12]

The `WebPDecoder` allows explicit control over the output format and supports libwebp's crop and scale options:
```swift
public struct WebPDecoder: Sendable {
    public init()

    /// Inspect the bitstream and calculate the output dimensions.
    public func requiredOutputLayout(
        for webPData: Data,
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat? = nil) throws -> OutputLayout

    /// Calculate the required output buffer size.
    public func requiredOutputByteCount(
        for webPData: Data,
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat = .rgba) throws -> Int

    /// Decode into a caller-provided buffer.
    @discardableResult
    public func decode(
        _ webPData: Data,
        into output: inout [UInt8],
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat = .rgba) throws -> Int

    /// Decode into a new `Data`.
    public func decode(
        _ webPData: Data,
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat = .rgba) throws -> Data
}

public struct OutputLayout {
    public let width: Int
    public let height: Int
    public let bytesPerPixel: Int
    public let stride: Int
    public let byteCount: Int
}
```

The supported output formats are `rgb`, `rgba`, `bgr`, `bgra`, `argb`, `rgba4444`, `rgb565` and the pre-multiplied variants (`rgbA`, `bgrA`, `Argb`, `rgbA4444`). YUV output (`.yuv`/`.yuva`) is not supported through this API. `rgb565` and the 4444 formats produce 2 bytes per pixel.

Decoding options mirror libwebp's `WebPDecoderOptions`:
```swift
public struct WebPDecoderOptions: Sendable {
    public var bypassFiltering: Int
    public var noFancyUpsampling: Int
    public var useCropping: Bool
    public var cropLeft: Int      // snapped to even values by libwebp
    public var cropTop: Int
    public var cropWidth: Int
    public var cropHeight: Int
    public var useScaling: Bool
    public var scaledWidth: Int
    public var scaledHeight: Int
    public var useThreads: Bool
    public var ditheringStrength: Int
    public var alphaDitheringStrength: Int
    public var flip: Int
}
```

Example:
```swift
let decoder = WebPDecoder()

// Simple decode to RGBA (or RGB when the bitstream has no alpha)
let rgba = try decoder.decode(webpData, options: WebPDecoderOptions())

// Scaled decoding
var options = WebPDecoderOptions()
options.useScaling = true
options.scaledWidth = 128
options.scaledHeight = 128
let thumbnail = try decoder.decode(webpData, options: options)

// Cropped decoding
var cropOptions = WebPDecoderOptions()
cropOptions.useCropping = true
cropOptions.cropLeft = 10
cropOptions.cropTop = 20
cropOptions.cropWidth = 100
cropOptions.cropHeight = 60
let cropped = try decoder.decode(webpData, options: cropOptions)

// Into an existing buffer
var buffer = [UInt8](repeating: 0, count: 256 * 256 * 4)
let written = try decoder.decode(webpData, into: &buffer, options: WebPDecoderOptions())

// Bitstream inspection without decoding
let features = try WebPImageInspector.inspect(webpData)
print(features.width, features.height, features.hasAlpha, features.hasAnimation, features.format)

// The linked libwebp version
print(WebPDecoder.libwebpVersion.description) // e.g. "1.3.2"
```

# WebP encoding
[Implementation][13] / [WebP test cases][12]

`STBImageCoder.export` covers the common cases; the `WebPEncoder` provides the full libwebp interface for everything else (buffer sources, rescaling during encode):
```swift
public struct WebPEncoder: Sendable {
    public init()

    /// Encode pixel data into WebP.
    public func encode(
        _ webPData: [UInt8],
        format: WebPEncodePixelFormat,
        config: WebPEncoderConfig,
        originWidth: Int,
        originHeight: Int,
        stride: Int,
        resizeWidth: Int = 0,
        resizeHeight: Int = 0) throws -> Data

    /// Same as above with an unsafe buffer pointer source.
    public func encode(
        _ data: UnsafeBufferPointer<UInt8>,
        ...) throws -> Data
}
```

The pixel `format` selects the importer (`rgb`, `rgba`, `rgbx`, `bgr`, `bgra`, `bgrx`), and the buffer must contain at least `stride * originHeight` bytes. `resizeWidth`/`resizeHeight` rescale the picture with libwebp's rescaler as part of the encoding.

The `WebPEncoderConfig` exposes all libwebp encoder parameters:
```swift
public struct WebPEncoderConfig: Sendable {
    /// A preset with sensible defaults for the image type.
    public static func preset(_ preset: Preset, quality: Float) -> WebPEncoderConfig

    /// The libwebp lossless preset levels [0...9].
    public static func losslessPreset(level: Int) throws -> WebPEncoderConfig

    /// Validate config fields against libwebp's supported ranges.
    public func validate() -> Bool

    public var lossless: Int
    public var quality: Float
    public var method: Int
    public var imageHint: WebPImageHint
    // ... and many more, see the implementation
}

public enum Preset: Sendable {
    case `default`, picture, photo, drawing, icon, text
}
```

Example:
```swift
let image = STBImage(width: 256, height: 256, value: 128)

// Preset-based config
var config = WebPEncoderConfig.preset(.picture, quality: 90)

// Lossless with exact RGB values under transparent pixels
var lossless = WebPEncoderConfig.preset(.picture, quality: 100)
lossless.lossless = 1
lossless.exact = 1

// Fast lossless encoding
let fastLossless = try WebPEncoderConfig.losslessPreset(level: 0)

// Encode with rescaling
let data = try WebPEncoder().encode(
    image.data,
    format: .rgba,
    config: config,
    originWidth: image.width,
    originHeight: image.height,
    stride: image.width * 4,
    resizeWidth: 128,
    resizeHeight: 128)
```

# Error handling

```swift
public enum STBImageReadError: Error {
    case failedToReadImage
    case dataTooLarge(bytes: Int)
}

public enum STBImageWriteError: Error {
    case failedToWrite
    case unexpectedPointerError
}

public enum WebPError: Error, Sendable {
    case unexpectedPointerError
    case unexpectedError(withMessage: String)
    case decoderConfigInitializationFailed
    case unsupportedColorspaceMode
    case invalidWebPConfig
    case unsupportedDecodeFormat
    case outputBufferTooSmall(required: Int, actual: Int)
}

public enum WebPDecodingError: UInt32, Error, Sendable {
    case outOfMemory, invalidParam, bitstreamError, unsupportedFeature,
         suspended, userAbort, notEnoughData, unknownError
}

public enum WebPEncoderError: Error, Sendable {
    case invalidParameter
    case versionMismatched
}

public enum WebPEncodeStatusCode: Int, Error, Sendable {
    case outOfMemory, bitstreamOutOfMemory, nullParameter, invalidConfiguration,
         badDimension, partition0Overflow, partitionOverflow, badWrite,
         fileTooBig, userAbort, last, unknownError
}
```

# Thread safety

All loading, decoding, blending and export functions are thread safe. PNG export uses zlib with adaptive per-row filtering, and the compression level is passed per call. `STBImage` is a `Sendable` value type and can be shared across concurrency domains freely.

# Acknowledgments

This package is MIT licensed and builds on third-party components with compatible licenses:

| Component | License | How it is used |
| --------- | ------- | -------------- |
| [stb_image][17] / [stb_image_write][17] | Public domain or MIT (dual) | Vendored in `Sources/CSTBImage`, PNG/JPG reading and JPG writing |
| [zlib][18] | zlib license | External system dependency, not bundled — PNG export (deflate + CRC32) |
| [libwebp][3] | BSD-3-Clause | External system dependency (`pkg-config`), not bundled — WebP decoding and encoding |
| [Swift-WebP][19] | MIT | The WebP Swift wrapper was initially ported from this project |

# Related packages
- [gis-tools][16]: GIS tools for Swift, including a GeoJSON implementation and many algorithms
- [mvt-tools][14]: Vector tiles reader/writer for Swift

# Contributing
Please [create an issue](https://github.com/Outdooractive/swift-stb-image/issues) or [open a pull request](https://github.com/Outdooractive/swift-stb-image/pulls) with a fix or enhancement.

# License
MIT

# Authors
Thomas Rasch, Outdooractive

[2]: https://github.com/nothings/stb "stb"
[3]: https://github.com/webmproject/libwebp "libwebp"
[4]: https://github.com/Outdooractive/swift-stb-image/tree/main/Tests/STBImageTests "Tests"
[5]: https://github.com/Outdooractive/swift-stb-image/blob/main/Sources/STBImage/STBImage.swift "STBImage.swift"
[6]: https://github.com/Outdooractive/swift-stb-image/blob/main/Sources/STBImage/STBImageData.swift "STBImageData.swift"
[7]: https://github.com/Outdooractive/swift-stb-image/blob/main/Sources/STBImage/STBImageCoder.swift "STBImageCoder.swift"
[8]: https://github.com/Outdooractive/swift-stb-image/blob/main/Sources/STBImage/Extensions/Pixel.swift "Pixel.swift"
[9]: https://github.com/Outdooractive/swift-stb-image/blob/main/Sources/STBImage/Extensions/Transforms.swift "Transforms.swift"
[10]: https://github.com/Outdooractive/swift-stb-image/blob/main/Sources/STBImage/WebP/WebPEncoderConfig.swift "WebPEncoderConfig.swift"
[11]: https://github.com/Outdooractive/swift-stb-image/blob/main/Sources/STBImage/WebP/WebPDecoder.swift "WebPDecoder.swift"
[12]: https://github.com/Outdooractive/swift-stb-image/blob/main/Tests/STBImageTests/WebPTests.swift "WebPTests.swift"
[13]: https://github.com/Outdooractive/swift-stb-image/blob/main/Sources/STBImage/WebP/WebPEncoder.swift "WebPEncoder.swift"
[14]: https://github.com/Outdooractive/mvt-tools "mvt-tools"
[15]: https://github.com/Outdooractive/mvt-postgis "mvt-postgis"
[16]: https://github.com/Outdooractive/gis-tools "gis-tools"
[17]: https://github.com/nothings/stb "stb"
[18]: https://zlib.net "zlib"
[19]: https://github.com/ainame/Swift-WebP "Swift-WebP"

[1]:	https://swiftpackageindex.com/Outdooractive/swift-stb-image
[2]:	https://swiftpackageindex.com/Outdooractive/swift-stb-image

[image-1]:	https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FOutdooractive%2Fswift-stb-image%2Fbadge%3Ftype%3Dswift-versions
[image-2]:	https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FOutdooractive%2Fswift-stb-image%2Fbadge%3Ftype%3Dplatforms
