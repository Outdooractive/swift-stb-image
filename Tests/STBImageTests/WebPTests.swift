#if EnableWebP
import Foundation
@testable import STBImage
import Testing

struct WebPTests {

    // 256x256 RGBA test image with transparency
    private let rgbaData = ImageLoader.loadFile(named: "avk_11_1077_720.webp")

    // 256x256 RGB test image without transparency
    private let rgbData = ImageLoader.loadFile(named: "avk_11_1078_719.webp")

    // MARK: - Versions

    @Test
    func libwebpVersions() {
        let encoderVersion = WebPEncoder.libwebpVersion.description
        let decoderVersion = WebPDecoder.libwebpVersion.description

        #expect(encoderVersion == decoderVersion)
        #expect(!encoderVersion.isEmpty)
        #expect(encoderVersion.split(separator: ".").count == 3)
        for component in encoderVersion.split(separator: ".") {
            #expect(Int(component) != nil)
        }
    }

    // MARK: - Inspection

    @Test
    func inspect() throws {
        let features = try WebPImageInspector.inspect(try #require(rgbaData))

        #expect(features.width == 256)
        #expect(features.height == 256)
        #expect(features.hasAlpha)
        #expect(!features.hasAnimation)
    }

    @Test
    func inspectRGBImage() throws {
        let features = try WebPImageInspector.inspect(try #require(rgbData))

        #expect(features.width == 256)
        #expect(features.height == 256)
        #expect(!features.hasAlpha)
    }

    @Test
    func inspectCorruptData() throws {
        var data = try #require(rgbaData)
        data.replaceSubrange(12..., with: Data(repeating: 0xFF, count: 32))

        #expect {
            try WebPImageInspector.inspect(data)
        } throws: { error in
            error is WebPError
        }
    }

    @Test
    func inspectTruncatedData() throws {
        let data = try #require(rgbaData).prefix(16)

        #expect(throws: WebPError.self) {
            try WebPImageInspector.inspect(data)
        }
    }

    // MARK: - Output layout

    @Test
    func requiredOutputLayoutDefault() throws {
        let layout = try WebPDecoder().requiredOutputLayout(
            for: try #require(rgbaData),
            options: WebPDecoderOptions())

        #expect(layout.width == 256)
        #expect(layout.height == 256)
        #expect(layout.bytesPerPixel == 4)
        #expect(layout.stride == 256 * 4)
        #expect(layout.byteCount == 256 * 256 * 4)
    }

    @Test
    func requiredOutputLayoutRGB() throws {
        let layout = try WebPDecoder().requiredOutputLayout(
            for: try #require(rgbData),
            options: WebPDecoderOptions())

        #expect(layout.bytesPerPixel == 3)
        #expect(layout.byteCount == 256 * 256 * 3)
    }

    @Test
    func requiredOutputLayoutCropping() throws {
        var options = WebPDecoderOptions()
        options.useCropping = true
        options.cropLeft = 10
        options.cropTop = 20
        options.cropWidth = 100
        options.cropHeight = 60

        let layout = try WebPDecoder().requiredOutputLayout(
            for: try #require(rgbaData),
            options: options)

        #expect(layout.width == 100)
        #expect(layout.height == 60)
        #expect(layout.byteCount == 100 * 60 * 4)
    }

    @Test
    func requiredOutputLayoutScaling() throws {
        var options = WebPDecoderOptions()
        options.useScaling = true
        options.scaledWidth = 128
        options.scaledHeight = 64

        let layout = try WebPDecoder().requiredOutputLayout(
            for: try #require(rgbaData),
            options: options)

        #expect(layout.width == 128)
        #expect(layout.height == 64)
        #expect(layout.byteCount == 128 * 64 * 4)
    }

    // MARK: - Decoding

    @Test
    func decodeIntoBuffer() throws {
        let data = try #require(rgbaData)
        let decoder = WebPDecoder()
        let options = WebPDecoderOptions()

        var output = [UInt8](repeating: 0, count: 256 * 256 * 4)
        let written = try decoder.decode(data, into: &output, options: options)

        #expect(written == output.count)
        #expect(output.contains { $0 != 0 })
    }

    @Test
    func decodeIntoTooSmallBuffer() throws {
        let data = try #require(rgbaData)
        var output = [UInt8](repeating: 0, count: 256 * 256 * 4 - 1)

        #expect {
            try WebPDecoder().decode(data, into: &output, options: WebPDecoderOptions())
        } throws: { error in
            error is WebPError
        }
    }

    @Test
    func decodeIntoOversizedBuffer() throws {
        let data = try #require(rgbaData)
        var output = [UInt8](repeating: 0, count: 256 * 256 * 4 + 16)

        let written = try WebPDecoder().decode(data, into: &output, options: WebPDecoderOptions())

        #expect(written == 256 * 256 * 4)
    }

    @Test
    func decodeToData() throws {
        let output = try WebPDecoder().decode(
            try #require(rgbaData),
            options: WebPDecoderOptions())

        #expect(output.count == 256 * 256 * 4)
    }

    @Test
    func decodeRGBFormat() throws {
        let output = try WebPDecoder().decode(
            try #require(rgbData),
            options: WebPDecoderOptions(),
            format: .rgb)

        #expect(output.count == 256 * 256 * 3)
    }

    // 2 bytes per pixel
    @Test
    func decodeRGB565Format() throws {
        let output = try WebPDecoder().decode(
            try #require(rgbData),
            options: WebPDecoderOptions(),
            format: .rgb565)

        #expect(output.count == 256 * 256 * 2)
    }

    @Test
    func decodeCropped() throws {
        var options = WebPDecoderOptions()
        options.useCropping = true
        options.cropLeft = 10
        options.cropTop = 20
        options.cropWidth = 100
        options.cropHeight = 60

        let output = try WebPDecoder().decode(try #require(rgbaData), options: options)

        #expect(output.count == 100 * 60 * 4)
    }

    @Test
    func decodeScaled() throws {
        var options = WebPDecoderOptions()
        options.useScaling = true
        options.scaledWidth = 128
        options.scaledHeight = 64

        let output = try WebPDecoder().decode(try #require(rgbaData), options: options)

        #expect(output.count == 128 * 64 * 4)

        // Scaling down must produce roughly the same average brightness
        // as the original image
        let averageScaled = output.reduce(0) { $0 + Int($1) } / output.count
        let original = try WebPDecoder().decode(try #require(rgbaData), options: WebPDecoderOptions())
        let averageOriginal = original.reduce(0) { $0 + Int($1) } / original.count

        #expect(abs(averageScaled - averageOriginal) < 16)
    }

    // YUV output is not supported through the RGB-oriented decode API
    @Test
    func decodeYUVThrows() throws {
        let data = try #require(rgbaData)

        #expect(throws: WebPError.self) {
            try WebPDecoder().decode(data, options: WebPDecoderOptions(), format: .yuv)
        }

        var output = [UInt8](repeating: 0, count: 256 * 256 * 3)
        #expect(throws: WebPError.self) {
            try WebPDecoder().decode(data, into: &output, options: WebPDecoderOptions(), format: .yuva)
        }
    }

    @Test
    func decodeCorruptData() throws {
        var data = try #require(rgbaData)
        data.replaceSubrange(12..., with: Data(repeating: 0xFF, count: 32))

        // The bitstream inspection fails first for corrupt data
        #expect(throws: WebPError.self) {
            try WebPDecoder().decode(data, options: WebPDecoderOptions())
        }
    }

    // MARK: - Encoding

    // Lossless encode/decode roundtrip must be pixel-exact.
    // `exact = 1` preserves the RGB values of transparent pixels,
    // which libwebp would otherwise discard.
    @Test
    func encodeLosslessRoundtrip() throws {
        var image = STBImage(width: 8, height: 8, value: 0)
        for y in 0 ..< 8 {
            for x in 0 ..< 8 {
                image[x, y, .red] = UInt8(x * 30)
                image[x, y, .green] = UInt8(y * 30)
                image[x, y, .blue] = UInt8((x + y) * 15)
                image[x, y, .alpha] = UInt8(255 - x * 20)
            }
        }

        var config = WebPEncoderConfig.preset(.picture, quality: 100)
        config.lossless = 1
        config.exact = 1

        let data = try WebPEncoder().encode(
            image.data,
            format: .rgba,
            config: config,
            originWidth: image.width,
            originHeight: image.height,
            stride: image.width * 4)

        #expect(STBImageCoder.imageFormat(data) == .webp)

        let decoded = try WebPDecoder().decode(data, options: WebPDecoderOptions())
        #expect(Array(decoded) == image.data)
    }

    @Test
    func encodeResized() throws {
        let image = STBImage(width: 32, height: 32, value: 100)

        let data = try WebPEncoder().encode(
            image.data,
            format: .rgba,
            config: WebPEncoderConfig.preset(.default, quality: 90),
            originWidth: image.width,
            originHeight: image.height,
            stride: image.width * 4,
            resizeWidth: 16,
            resizeHeight: 16)

        let decoded = try WebPDecoder().decode(data, options: WebPDecoderOptions())
        #expect(decoded.count == 16 * 16 * 4)
    }

    @Test
    func encodeInvalidConfig() throws {
        let image = STBImage(width: 2, height: 2, value: 0)
        var config = WebPEncoderConfig.preset(.default, quality: 90)
        config.quality = 101 // valid range is 0...100

        #expect(!config.validate())
        #expect(throws: WebPEncoderError.self) {
            try WebPEncoder().encode(
                image.data,
                format: .rgba,
                config: config,
                originWidth: image.width,
                originHeight: image.height,
                stride: image.width * 4)
        }
    }

    // Encoding a zero-sized image fails because there is no data to encode.
    // (An empty Swift array may still hand out a non-nil base address,
    // so libwebp's import step fails rather than the pointer guard.)
    @Test
    func encodeEmptyBuffer() {
        #expect(throws: (any Error).self) {
            try WebPEncoder().encode(
                [],
                format: .rgba,
                config: WebPEncoderConfig.preset(.default, quality: 90),
                originWidth: 0,
                originHeight: 0,
                stride: 0)
        }
    }

    @Test
    func encoderConfigValidation() {
        #expect(WebPEncoderConfig.preset(.photo, quality: 85).validate())

        var config = WebPEncoderConfig.preset(.default, quality: 85)
        config.lossless = 1
        #expect(config.validate())
    }

    @Test
    func losslessPreset() throws {
        let config = try WebPEncoderConfig.losslessPreset(level: 6)
        #expect(config.lossless == 1)
        #expect(config.validate())

        #expect(throws: WebPError.self) {
            try WebPEncoderConfig.losslessPreset(level: 10)
        }
    }

    @Test
    func encodeDecodeRGBRoundtrip() throws {
        let image = STBImage(width: 8, height: 8, channels: 3, data: [UInt8](repeating: 66, count: 8 * 8 * 3))

        let data = try WebPEncoder().encode(
            image.data,
            format: .rgb,
            config: WebPEncoderConfig.preset(.picture, quality: 100),
            originWidth: image.width,
            originHeight: image.height,
            stride: image.width * 3)

        let decoded = try WebPDecoder().decode(
            data,
            options: WebPDecoderOptions(),
            format: .rgb)

        #expect(Array(decoded) == image.data)
    }

    // MARK: - Colorspace helpers

    @Test
    func colorspaceModeProperties() {
        #expect(ColorspaceMode.RGBA.isAlphaMode)
        #expect(ColorspaceMode.BGRA.isAlphaMode)
        #expect(ColorspaceMode.ARGB.isAlphaMode)
        #expect(ColorspaceMode.YUVA.isAlphaMode)
        #expect(!ColorspaceMode.RGB.isAlphaMode)
        #expect(!ColorspaceMode.YUV.isAlphaMode)

        #expect(ColorspaceMode.rgbA.isPremultipliedMode)
        #expect(ColorspaceMode.bgrA.isPremultipliedMode)
        #expect(ColorspaceMode.Argb.isPremultipliedMode)
        #expect(ColorspaceMode.rgbA4444.isPremultipliedMode)
        #expect(!ColorspaceMode.RGBA.isPremultipliedMode)

        #expect(ColorspaceMode.RGB.isRGBMode)
        #expect(ColorspaceMode.RGBA4444.isRGBMode)
        #expect(!ColorspaceMode.YUV.isRGBMode)
        #expect(!ColorspaceMode.YUVA.isRGBMode)
    }

}
#endif
