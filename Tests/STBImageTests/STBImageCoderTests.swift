import Foundation
@testable import STBImage
import Testing

struct STBImageCoderTests {

    // MARK: - Format detection

    @Test
    func imageFormatDetection() throws {
        let png = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.png"))
        let jpg = try #require(ImageLoader.loadFile(named: "usgs_16_13672_24858.jpeg"))

        #expect(STBImageCoder.imageFormat(png) == .png)
        #expect(STBImageCoder.imageFormat(jpg) == .jpg)
        #if EnableWebP
        let webp = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.webp"))
        #expect(STBImageCoder.imageFormat(webp) == .webp)
        #endif
    }

    @Test
    func imageFormatUnknownData() {
        #expect(STBImageCoder.imageFormat(Data([1, 2, 3, 4, 5])) == .unknown)
        #expect(STBImageCoder.imageFormat(Data()) == .unknown)
        #expect(STBImageCoder.imageFormat(Data([0x89])) == .unknown)
        #expect(STBImageCoder.imageFormat(Data([0x89, 0x50])) == .unknown)
    }

    /// RIFF header without the WEBP tag at offset 8
    @Test
    func imageFormatRiffWithoutWebPTag() {
        var data = Data("RIFF".utf8)
        data.append(Data(repeating: 0, count: 4))
        data.append(Data("WAVE".utf8))

        #expect(STBImageCoder.imageFormat(data) == .unknown)
    }

    /// WEBP tag at offset 8 but no RIFF signature
    @Test
    func imageFormatWebPWithoutRiff() {
        var data = Data([0x00, 0x00, 0x00, 0x00])
        data.append(Data("WEBP".utf8))

        #expect(STBImageCoder.imageFormat(data) == .unknown)
    }

    #if EnableWebP
    @Test
    func imageFormatMinimalWebP() {
        var data = Data("RIFF".utf8)
        data.append(Data(repeating: 0, count: 4))
        data.append(Data("WEBP".utf8))

        #expect(STBImageCoder.imageFormat(data) == .webp)
    }
    #endif

    // MARK: - Load errors

    @Test
    func loadUnknownFormat() throws {
        let result = try STBImageCoder.load(from: Data([1, 2, 3, 4]))
        #expect(result == nil)
    }

    @Test
    func loadCorruptPNG() throws {
        var data = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.png"))
        // Keep the signature, corrupt the rest
        data.replaceSubrange(8..., with: Data(repeating: 0xFF, count: 32))

        #expect(throws: STBImageReadError.self) {
            try STBImageCoder.load(from: data)
        }
        #expect(STBImage(data: data) == nil)
    }

    @Test
    func loadCorruptJPG() throws {
        var data = try #require(ImageLoader.loadFile(named: "usgs_16_13672_24858.jpeg"))
        data.replaceSubrange(3..., with: Data(repeating: 0x00, count: 32))

        #expect(throws: STBImageReadError.self) {
            try STBImageCoder.load(from: data)
        }
        #expect(STBImage(data: data) == nil)
    }

    #if EnableWebP
    @Test
    func loadTruncatedWebP() throws {
        var data = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.webp"))
        data = data.prefix(16)

        #expect {
            try STBImageCoder.load(from: data)
        } throws: { error in
            error is WebPError
        }
        #expect(STBImage(data: data) == nil)
    }
    #endif

    // MARK: - Grayscale loading

    /// A grayscale PNG loads as a 1 channel STBImageData,
    /// but can not be converted into an STBImage
    @Test
    func loadGrayscalePNG() throws {
        let data = try #require(ImageLoader.loadFile(named: "gray_2x2.png"))
        let imageData = try #require(try STBImageCoder.load(from: data))

        #expect(imageData.width == 2)
        #expect(imageData.height == 2)
        #expect(imageData.channels == 1)
        #expect(imageData.data == [10, 20, 30, 40])
        #expect(STBImage(imageData: imageData) == nil)
        #expect(STBImage(data: data) == nil)
    }

    /// A gray+alpha PNG loads as a 2 channel STBImageData,
    /// but can not be converted into an STBImage
    @Test
    func loadGrayAlphaPNG() throws {
        let data = try #require(ImageLoader.loadFile(named: "gray_alpha_2x2.png"))
        let imageData = try #require(try STBImageCoder.load(from: data))

        #expect(imageData.width == 2)
        #expect(imageData.height == 2)
        #expect(imageData.channels == 2)
        #expect(imageData.data == [11, 255, 22, 128, 33, 64, 44, 0])
        #expect(STBImage(imageData: imageData) == nil)
    }

    // MARK: - Desired channels

    /// Grayscale images can be converted to RGB/RGBA while loading
    @Test
    func loadGrayscaleWithDesiredChannels() throws {
        let data = try #require(ImageLoader.loadFile(named: "gray_2x2.png"))

        let rgb = try #require(try STBImageCoder.load(from: data, desiredChannels: 3))
        #expect(rgb.channels == 3)
        #expect(rgb.data == [10, 10, 10, 20, 20, 20, 30, 30, 30, 40, 40, 40])

        let rgba = try #require(try STBImageCoder.load(from: data, desiredChannels: 4))
        #expect(rgba.channels == 4)
        #expect(rgba.data == [
            10,
            10,
            10,
            255,
            20,
            20,
            20,
            255,
            30,
            30,
            30,
            255,
            40,
            40,
            40,
            255,
        ])

        let image = try #require(STBImage(data: data, desiredChannels: 3))
        #expect(image.channels == 3)
        #expect(image[1, 1, .red] == 40)
    }

    @Test
    func loadGrayAlphaWithDesiredChannels() throws {
        let data = try #require(ImageLoader.loadFile(named: "gray_alpha_2x2.png"))

        let rgb = try #require(try STBImageCoder.load(from: data, desiredChannels: 3))
        #expect(rgb.channels == 3)
        #expect(rgb.data == [11, 11, 11, 22, 22, 22, 33, 33, 33, 44, 44, 44])

        let rgba = try #require(try STBImageCoder.load(from: data, desiredChannels: 4))
        #expect(rgba.channels == 4)
        #expect(rgba.data == [
            11,
            11,
            11,
            255,
            22,
            22,
            22,
            128,
            33,
            33,
            33,
            64,
            44,
            44,
            44,
            0,
        ])
    }

    /// An RGBA image can be loaded without its alpha channel
    @Test
    func loadRGBADesiredChannels3() throws {
        let data = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.png"))

        let image = try #require(STBImage(data: data, desiredChannels: 3))
        #expect(image.channels == 3)
        #expect(image.hasAlpha == false)
        #expect(image.isTransparent == false)
    }

    #if EnableWebP
    /// desiredChannels does not apply to WebP
    @Test
    func desiredChannelsIgnoredForWebP() throws {
        let data = try #require(ImageLoader.loadFile(named: "osm_topo_11_1077_720.webp"))

        let plain = try #require(STBImage(data: data))
        let withDesired = try #require(STBImage(data: data, desiredChannels: 4))

        #expect(plain.channels == 3)
        #expect(withDesired.channels == 3)
    }
    #endif

    // MARK: - PNG export

    /// PNG export is lossless, so a roundtrip must be pixel-exact
    @Test
    func exportPNGRoundtrip() throws {
        let fileData = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.png"))
        let original = try #require(STBImage(data: fileData))

        let exported = try original.export(.png)
        #expect(STBImageCoder.imageFormat(exported) == .png)

        let reloaded = try #require(STBImage(data: exported))
        #expect(reloaded == original)
    }

    // MARK: - JPG export

    @Test
    func exportJPGRoundtrip() throws {
        let fileData = try #require(ImageLoader.loadFile(named: "avk_11_1078_719.png"))
        let original = try #require(STBImage(data: fileData))

        let exported = try original.export(.jpg(quality: 85))
        #expect(STBImageCoder.imageFormat(exported) == .jpg)

        let reloaded = try #require(STBImage(data: exported))
        #expect(reloaded.width == original.width)
        #expect(reloaded.height == original.height)
        #expect(reloaded.channels == original.channels)
        // JPG is lossy, pixels will not be identical
        #expect(reloaded.data.count == original.data.count)
    }

    /// Exporting an RGBA image as JPG drops the alpha channel
    @Test
    func exportRGBAAsJPG() throws {
        let fileData = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.png"))
        let original = try #require(STBImage(data: fileData))
        #expect(original.hasAlpha)

        let exported = try original.export(.jpg(quality: 85))
        let reloaded = try #require(STBImage(data: exported))

        #expect(reloaded.width == original.width)
        #expect(reloaded.height == original.height)
        #expect(reloaded.channels == 3)
        #expect(reloaded.hasAlpha == false)
    }

    @Test
    func exportJPGQualityVariants() throws {
        let fileData = try #require(ImageLoader.loadFile(named: "avk_11_1078_719.png"))
        let original = try #require(STBImage(data: fileData))

        for quality in [1, 50, 100] {
            let exported = try original.export(.jpg(quality: quality))
            let reloaded = try #require(STBImage(data: exported))
            #expect(reloaded.width == original.width)
            #expect(reloaded.height == original.height)
        }
    }

    // MARK: - WebP export

    // Quality 100 forces lossless WebP. Note: libwebp still discards the RGB
    // values of fully transparent pixels (WebPEncoderConfig.exact defaults
    // to 0), so only the alpha channel and opaque pixels must survive
    // a lossless roundtrip.
    #if EnableWebP
    @Test
    func exportWebPRoundtripLossless() throws {
        let fileData = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.webp"))
        let original = try #require(STBImage(data: fileData))

        let exported = try original.export(.webp(quality: 100))
        #expect(STBImageCoder.imageFormat(exported) == .webp)

        let reloaded = try #require(STBImage(data: exported))
        #expect(reloaded.width == original.width)
        #expect(reloaded.height == original.height)
        #expect(reloaded.channels == original.channels)
        #expect(reloaded.data.count == original.data.count)

        var alphaMatches = true
        var opaqueRGBMatches = true
        var hasTransparentPixels = false

        for i in stride(from: 0, to: original.data.count, by: 4) {
            alphaMatches = alphaMatches && reloaded.data[i + 3] == original.data[i + 3]
            if original.data[i + 3] == 255 {
                opaqueRGBMatches = opaqueRGBMatches
                    && reloaded.data[i] == original.data[i]
                    && reloaded.data[i + 1] == original.data[i + 1]
                    && reloaded.data[i + 2] == original.data[i + 2]
            }
            else {
                hasTransparentPixels = true
            }
        }

        #expect(hasTransparentPixels)
        #expect(alphaMatches)
        #expect(opaqueRGBMatches)
    }

    @Test
    func exportWebPLossy() throws {
        let fileData = try #require(ImageLoader.loadFile(named: "osm_topo_11_1077_720.png"))
        let original = try #require(STBImage(data: fileData))

        let exported = try original.export(.webp(quality: 75))
        let reloaded = try #require(STBImage(data: exported))

        #expect(reloaded.width == original.width)
        #expect(reloaded.height == original.height)
        // WebP decodes without alpha as RGB, the source PNG is RGBA
        #expect(reloaded.channels == 3)
    }

    @Test
    func exportRGBWebPRoundtrip() throws {
        let fileData = try #require(ImageLoader.loadFile(named: "avk_11_1078_719.png"))
        let original = try #require(STBImage(data: fileData))

        let exported = try original.export(.webp(quality: 100))
        let reloaded = try #require(STBImage(data: exported))

        #expect(reloaded.channels == 3)
        #expect(reloaded == original)
    }
    #endif

    // MARK: - Export errors

    @Test
    func exportEmptyImage() {
        let imageData = STBImageData(width: 0, height: 0, channels: 3, data: [])

        #expect(throws: STBImageWriteError.self) {
            try STBImageCoder.export(imageData: imageData, format: .png)
        }
        #expect(throws: STBImageWriteError.self) {
            try STBImageCoder.export(imageData: imageData, format: .jpg(quality: 85))
        }
        #if EnableWebP
        #expect(throws: (any Error).self) {
            try STBImageCoder.export(imageData: imageData, format: .webp(quality: 85))
        }
        #endif
    }

    // MARK: - Convert

    @Test
    func convertSameFormatReturnsOriginalData() throws {
        let png = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.png"))
        let jpg = try #require(ImageLoader.loadFile(named: "usgs_16_13672_24858.jpeg"))

        #expect(STBImageCoder.convert(png, to: .png) == png)
        #expect(STBImageCoder.convert(jpg, to: .jpg(quality: 50)) == jpg)
        #if EnableWebP
        let webp = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.webp"))
        #expect(STBImageCoder.convert(webp, to: .webp(quality: 50)) == webp)
        #endif
    }

    @Test
    func convertCrossFormat() throws {
        let png = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.png"))

        #if EnableWebP
        let webp = STBImageCoder.convert(png, to: .webp(quality: 85))
        #expect(STBImageCoder.imageFormat(webp) == .webp)
        #expect(webp != png)

        let pngAgain = STBImageCoder.convert(webp, to: .png)
        #expect(STBImageCoder.imageFormat(pngAgain) == .png)
        #endif

        let jpg = STBImageCoder.convert(png, to: .jpg(quality: 85))
        #expect(STBImageCoder.imageFormat(jpg) == .jpg)
    }

    @Test
    func convertUnknownDataReturnsOriginal() {
        let garbage = Data([1, 2, 3, 4, 5])
        #expect(STBImageCoder.convert(garbage, to: .png) == garbage)
    }

    @Test
    func convertCorruptDataReturnsOriginal() throws {
        var data = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.png"))
        data.replaceSubrange(8..., with: Data(repeating: 0xFF, count: 32))

        #if EnableWebP
        #expect(STBImageCoder.convert(data, to: .webp(quality: 85)) == data)
        #endif
    }

    // MARK: - Grayscale export

    /// Grayscale (1 channel) STBImageData can be exported as PNG
    @Test
    func exportGrayscalePNG() throws {
        let gray = STBImageData(width: 2, height: 2, channels: 1, data: [10, 20, 30, 40])

        let exported = try STBImageCoder.export(imageData: gray, format: .png)
        #expect(STBImageCoder.imageFormat(exported) == .png)

        let reloaded = try #require(try STBImageCoder.load(from: exported))
        #expect(reloaded.width == 2)
        #expect(reloaded.height == 2)
        #expect(reloaded.channels == 1)
        #expect(reloaded.data == [10, 20, 30, 40])
    }

    /// Gray+alpha (2 channel) STBImageData can be exported as PNG
    @Test
    func exportGrayAlphaPNG() throws {
        let grayAlpha = STBImageData(width: 2, height: 2, channels: 2, data: [11, 255, 22, 128, 33, 64, 44, 0])

        let exported = try STBImageCoder.export(imageData: grayAlpha, format: .png)
        #expect(STBImageCoder.imageFormat(exported) == .png)

        let reloaded = try #require(try STBImageCoder.load(from: exported))
        #expect(reloaded.width == 2)
        #expect(reloaded.height == 2)
        #expect(reloaded.channels == 2)
        #expect(reloaded.data == [11, 255, 22, 128, 33, 64, 44, 0])
    }

    // MARK: - PNG compression levels

    @Test
    func pngCompressionLevelAffectsSize() throws {
        let fileData = try #require(ImageLoader.loadFile(named: "avk_11_1078_719.png"))
        let image = try #require(STBImage(data: fileData))

        let fast = try image.export(.png(compressionLevel: 0))
        let best = try image.export(.png(compressionLevel: 9))

        #expect(fast.count > best.count)

        // PNG is lossless regardless of the compression level
        #expect(STBImage(data: fast) == image)
        #expect(STBImage(data: best) == image)
    }

    @Test
    func pngDefaultCompressionLevelIs6() throws {
        let fileData = try #require(ImageLoader.loadFile(named: "avk_11_1078_719.png"))
        let image = try #require(STBImage(data: fileData))

        let defaultLevel = try image.export(.png)
        let level6 = try image.export(.png(compressionLevel: 6))

        #expect(defaultLevel == level6)
    }

    // MARK: - Throwing convert

    @Test
    func convertingSameFormatReturnsOriginalData() throws {
        let png = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.png"))
        let jpg = try #require(ImageLoader.loadFile(named: "usgs_16_13672_24858.jpeg"))

        #expect(try STBImageCoder.converting(png, to: .png) == png)
        #expect(try STBImageCoder.converting(jpg, to: .jpg(quality: 50)) == jpg)
        #if EnableWebP
        let webp = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.webp"))
        #expect(try STBImageCoder.converting(webp, to: .webp(quality: 50)) == webp)
        #endif
    }

    @Test
    func convertingCrossFormat() throws {
        let png = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.png"))

        #if EnableWebP
        let webp = try STBImageCoder.converting(png, to: .webp(quality: 85))
        #expect(STBImageCoder.imageFormat(webp) == .webp)
        #endif

        let jpg = try STBImageCoder.converting(png, to: .jpg(quality: 85))
        #expect(STBImageCoder.imageFormat(jpg) == .jpg)
    }

    @Test
    func convertingUnknownDataThrows() {
        #expect(throws: STBImageReadError.self) {
            try STBImageCoder.converting(Data([1, 2, 3, 4, 5]), to: .png)
        }
    }

    @Test
    func convertingCorruptDataThrows() throws {
        var data = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.png"))
        data.replaceSubrange(8..., with: Data(repeating: 0xFF, count: 32))

        #if EnableWebP
        #expect(throws: STBImageReadError.self) {
            try STBImageCoder.converting(data, to: .webp(quality: 85))
        }
        #endif
    }

    // MARK: - WebP export options

    #if EnableWebP
    /// exact = true preserves the RGB values of transparent pixels,
    /// making lossless roundtrips pixel-exact
    @Test
    func exportWebPExactOption() throws {
        var image = STBImage(width: 4, height: 4, red: 0, green: 0, blue: 0, alpha: 255)
        image.mapPixels { pixel in
            var pixel = pixel
            pixel.red = UInt8(pixel.x * 50 + pixel.y * 10)
            pixel.green = UInt8(pixel.x * 20 + 100)
            pixel.blue = UInt8(pixel.y * 30 + 7)
            pixel.alpha = (pixel.x + pixel.y) % 2 == 0 ? 0 : 255
            return pixel
        }

        let exported = try image.export(.webp(quality: 100, exact: true))
        let reloaded = try #require(STBImage(data: exported))

        #expect(reloaded == image)
    }

    @Test
    func exportWebPOptions() throws {
        let fileData = try #require(ImageLoader.loadFile(named: "avk_11_1078_719.png"))
        let image = try #require(STBImage(data: fileData))

        let threaded = try image.export(.webp(quality: 85, useThreads: true))
        let threadedImage = try #require(STBImage(data: threaded))
        #expect(threadedImage.width == image.width)
        #expect(threadedImage.height == image.height)

        let fastMethod = try image.export(.webp(quality: 85, method: 0))
        let fastImage = try #require(STBImage(data: fastMethod))
        #expect(fastImage.width == image.width)
        #expect(fastImage.height == image.height)
    }
    #endif

    // MARK: - 16-bit images

    @Test
    func load16BitPNG() throws {
        let pngData = try #require(ImageLoader.loadFile(named: "gray16.png"))
        let imageData = try #require(try STBImageCoder.load(from: pngData))

        #expect(imageData.width == 64)
        #expect(imageData.height == 64)
        #expect(imageData.channels == 1)
        #expect(imageData.bitDepth == .sixteen)
        #expect(imageData.bytesPerPixel == 2)
        #expect(imageData.data.count == 64 * 64 * 2)

        // Fixture values: (y*300 + x*7) % 65536, big-endian in the file,
        // normalized to little-endian in memory. First pixel is 0, second
        // is 7.
        let second = UInt16(imageData.data[2]) | (UInt16(imageData.data[3]) << 8)
        #expect(second == 7)
    }

    @Test
    func roundtrip16BitPNG() throws {
        let pngData = try #require(ImageLoader.loadFile(named: "gray16.png"))
        let original = try #require(try STBImageCoder.load(from: pngData))

        let exported = try STBImageCoder.export(imageData: original, format: .png())
        let reloaded = try #require(try STBImageCoder.load(from: exported))

        #expect(reloaded.bitDepth == .sixteen)
        #expect(reloaded.data == original.data)
    }

    @Test
    func convertedBitDepthRoundtrip() throws {
        let pngData = try #require(ImageLoader.loadFile(named: "gray16.png"))
        let gray16 = try #require(try STBImageCoder.load(from: pngData))

        // 16 → 8: values (v + 128) / 257
        let gray8 = gray16.convertedBitDepth(to: .eight)
        #expect(gray8.bitDepth == .eight)
        #expect(gray8.channels == 1)
        #expect(gray8.data.count == 64 * 64)

        // Value 0 → 0, value 7 → 0
        #expect(gray8.data[0] == 0)

        // 8 → 16: value * 257, then down again restores the 8-bit value
        let backTo8 = gray8.convertedBitDepth(to: .sixteen).convertedBitDepth(to: .eight)
        #expect(backTo8.data == gray8.data)
    }

    @Test
    func convertedBitDepthIdentity() {
        let image = STBImageData(width: 2, height: 2, channels: 3, data: [UInt8](repeating: 9, count: 12))

        #expect(image.convertedBitDepth(to: .eight) == image)
        // Multi-channel images can not be up-converted to 16 bits
        #expect(image.convertedBitDepth(to: .sixteen) == image)
    }

    @Test
    func export16BitJPGThrows() throws {
        let pngData = try #require(ImageLoader.loadFile(named: "gray16.png"))
        let gray16 = try #require(try STBImageCoder.load(from: pngData))

        #expect {
            try STBImageCoder.export(imageData: gray16, format: .jpg(quality: 85))
        } throws: { error in
            if case STBImageWriteError.unsupportedBitDepth = error {
                return true
            }
            return false
        }
    }

    #if EnableWebP
    @Test
    func export16BitWebPThrows() throws {
        let pngData = try #require(ImageLoader.loadFile(named: "gray16.png"))
        let gray16 = try #require(try STBImageCoder.load(from: pngData))

        #expect {
            try STBImageCoder.export(imageData: gray16, format: .webp(quality: 85))
        } throws: { error in
            if case STBImageWriteError.unsupportedBitDepth = error {
                return true
            }
            return false
        }
    }
    #endif

    @Test
    func downconvertThenExport() throws {
        let pngData = try #require(ImageLoader.loadFile(named: "gray16.png"))
        let gray16 = try #require(try STBImageCoder.load(from: pngData))

        let gray8 = gray16.convertedBitDepth(to: .eight)
        let jpg = try STBImageCoder.export(imageData: gray8, format: .jpg(quality: 85))
        #expect(STBImageCoder.imageFormat(jpg) == .jpg)
    }

    @Test
    func load16BitPNGWithDesiredChannels() throws {
        let pngData = try #require(ImageLoader.loadFile(named: "gray16.png"))
        // Channel conversion does not apply to 16-bit images
        let imageData = try #require(try STBImageCoder.load(from: pngData, desiredChannels: 3))
        #expect(imageData.bitDepth == .sixteen)
        #expect(imageData.channels == 1)
    }

    @Test
    func stbImageInitRejects16Bit() throws {
        let pngData = try #require(ImageLoader.loadFile(named: "gray16.png"))
        #expect(STBImage(data: pngData) == nil)
    }

    @Test
    func sample16Subscript() throws {
        let pngData = try #require(ImageLoader.loadFile(named: "gray16.png"))
        let image = try #require(try STBImageCoder.load(from: pngData))

        // Fixture values: (y*300 + x*7) % 65536
        #expect(image[0, 0] == 0)
        #expect(image[1, 0] == 7)
        #expect(image[0, 1] == 300)
        #expect(image[63, 63] == (63 * 300 + 63 * 7) % 65536)

        // Same value through the flat index
        #expect(image[data16: 1] == image[1, 0])
    }

    @Test
    func sample16SubscriptWrites() throws {
        let pngData = try #require(ImageLoader.loadFile(named: "gray16.png"))
        var image = try #require(try STBImageCoder.load(from: pngData))

        // Writing updates the underlying little-endian byte pairs
        image[3, 2] = 0xBEEF
        #expect(image[3, 2] == 0xBEEF)
        // Low byte first (little-endian)
        let offset = (2 * 64 + 3) * 2
        #expect(image.data[offset] == 0xEF)
        #expect(image.data[offset + 1] == 0xBE)

        image[data16: 0] = 0x1234
        #expect(image[data16: 0] == 0x1234)

        // The modified image roundtrips through TIFF/PNG encoding
        let encoded = try STBImageCoder.export(imageData: image, format: .png())
        let reloaded = try #require(try STBImageCoder.load(from: encoded))
        #expect(reloaded[3, 2] == 0xBEEF)
        #expect(reloaded[data16: 0] == 0x1234)
    }

    @Test
    func samples16View() throws {
        let pngData = try #require(ImageLoader.loadFile(named: "gray16.png"))
        let image = try #require(try STBImageCoder.load(from: pngData))

        let samples = image.samples16
        #expect(samples.count == 64 * 64)
        #expect(samples[0] == 0)
        #expect(samples[1] == 7)
        #expect(samples[64] == 300)
        #expect(samples[63 * 64 + 63] == (63 * 300 + 63 * 7) % 65536)

        // Roundtrip: samples → image property → samples
        var copy = image
        copy.samples16 = samples
        #expect(copy == image)

        // Mutating through the view
        var modified = image
        var newSamples = samples
        newSamples[10] = 42000
        modified.samples16 = newSamples
        #expect(modified[10 % 64, 10 / 64] == 42000)
        #expect(modified.samples16[10] == 42000)
    }

}
