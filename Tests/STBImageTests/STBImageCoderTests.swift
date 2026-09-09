import Foundation
@testable import STBImage
import Testing

struct STBImageCoderTests {

    // MARK: - Format detection

    @Test
    func imageFormatDetection() throws {
        let png = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.png"))
        let jpg = try #require(ImageLoader.loadFile(named: "usgs_16_13672_24858.jpeg"))
        let webp = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.webp"))

        #expect(STBImageCoder.imageFormat(png) == .png)
        #expect(STBImageCoder.imageFormat(jpg) == .jpg)
        #expect(STBImageCoder.imageFormat(webp) == .webp)
    }

    @Test
    func imageFormatUnknownData() {
        #expect(STBImageCoder.imageFormat(Data([1, 2, 3, 4, 5])) == .unknown)
        #expect(STBImageCoder.imageFormat(Data()) == .unknown)
        #expect(STBImageCoder.imageFormat(Data([0x89])) == .unknown)
        #expect(STBImageCoder.imageFormat(Data([0x89, 0x50])) == .unknown)
    }

    // RIFF header without the WEBP tag at offset 8
    @Test
    func imageFormatRiffWithoutWebPTag() {
        var data = Data("RIFF".utf8)
        data.append(Data(repeating: 0, count: 4))
        data.append(Data("WAVE".utf8))

        #expect(STBImageCoder.imageFormat(data) == .unknown)
    }

    // WEBP tag at offset 8 but no RIFF signature
    @Test
    func imageFormatWebPWithoutRiff() {
        var data = Data([0x00, 0x00, 0x00, 0x00])
        data.append(Data("WEBP".utf8))

        #expect(STBImageCoder.imageFormat(data) == .unknown)
    }

    @Test
    func imageFormatMinimalWebP() {
        var data = Data("RIFF".utf8)
        data.append(Data(repeating: 0, count: 4))
        data.append(Data("WEBP".utf8))

        #expect(STBImageCoder.imageFormat(data) == .webp)
    }

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

    // MARK: - Grayscale loading

    // A grayscale PNG loads as a 1 channel STBImageData,
    // but can not be converted into an STBImage
    @Test
    func loadGrayscalePNG() throws {
        let data = try #require(ImageLoader.loadFile(named: "gray_2x2.png"))
        let imageData = try #require(try STBImageCoder.load(from: data))

        #expect(imageData.width == 2)
        #expect(imageData.height == 2)
        #expect(imageData.bpp == 1)
        #expect(imageData.data == [10, 20, 30, 40])
        #expect(STBImage(imageData: imageData) == nil)
        #expect(STBImage(data: data) == nil)
    }

    // A gray+alpha PNG loads as a 2 channel STBImageData,
    // but can not be converted into an STBImage
    @Test
    func loadGrayAlphaPNG() throws {
        let data = try #require(ImageLoader.loadFile(named: "gray_alpha_2x2.png"))
        let imageData = try #require(try STBImageCoder.load(from: data))

        #expect(imageData.width == 2)
        #expect(imageData.height == 2)
        #expect(imageData.bpp == 2)
        #expect(imageData.data == [11, 255, 22, 128, 33, 64, 44, 0])
        #expect(STBImage(imageData: imageData) == nil)
    }

    // MARK: - Desired channels

    // Grayscale images can be converted to RGB/RGBA while loading
    @Test
    func loadGrayscaleWithDesiredChannels() throws {
        let data = try #require(ImageLoader.loadFile(named: "gray_2x2.png"))

        let rgb = try #require(try STBImageCoder.load(from: data, desiredChannels: 3))
        #expect(rgb.bpp == 3)
        #expect(rgb.data == [10, 10, 10, 20, 20, 20, 30, 30, 30, 40, 40, 40])

        let rgba = try #require(try STBImageCoder.load(from: data, desiredChannels: 4))
        #expect(rgba.bpp == 4)
        #expect(rgba.data == [
            10, 10, 10, 255,
            20, 20, 20, 255,
            30, 30, 30, 255,
            40, 40, 40, 255,
        ])

        let image = try #require(STBImage(data: data, desiredChannels: 3))
        #expect(image.channels == 3)
        #expect(image[1, 1, .red] == 40)
    }

    @Test
    func loadGrayAlphaWithDesiredChannels() throws {
        let data = try #require(ImageLoader.loadFile(named: "gray_alpha_2x2.png"))

        let rgb = try #require(try STBImageCoder.load(from: data, desiredChannels: 3))
        #expect(rgb.bpp == 3)
        #expect(rgb.data == [11, 11, 11, 22, 22, 22, 33, 33, 33, 44, 44, 44])

        let rgba = try #require(try STBImageCoder.load(from: data, desiredChannels: 4))
        #expect(rgba.bpp == 4)
        #expect(rgba.data == [
            11, 11, 11, 255,
            22, 22, 22, 128,
            33, 33, 33, 64,
            44, 44, 44, 0,
        ])
    }

    // An RGBA image can be loaded without its alpha channel
    @Test
    func loadRGBADesiredChannels3() throws {
        let data = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.png"))

        let image = try #require(STBImage(data: data, desiredChannels: 3))
        #expect(image.channels == 3)
        #expect(!image.hasAlpha)
        #expect(image.isTransparent == false)
    }

    // desiredChannels does not apply to WebP
    @Test
    func desiredChannelsIgnoredForWebP() throws {
        let data = try #require(ImageLoader.loadFile(named: "osm_topo_11_1077_720.webp"))

        let plain = try #require(STBImage(data: data))
        let withDesired = try #require(STBImage(data: data, desiredChannels: 4))

        #expect(plain.channels == 3)
        #expect(withDesired.channels == 3)
    }

    // MARK: - PNG export

    // PNG export is lossless, so a roundtrip must be pixel-exact
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

    // Exporting an RGBA image as JPG drops the alpha channel
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
        #expect(!reloaded.hasAlpha)
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

    // MARK: - Export errors

    @Test
    func exportEmptyImage() {
        let imageData = STBImageData(width: 0, height: 0, bpp: 3, data: [])

        #expect(throws: STBImageWriteError.self) {
            try STBImageCoder.export(imageData: imageData, format: .png)
        }
        #expect(throws: STBImageWriteError.self) {
            try STBImageCoder.export(imageData: imageData, format: .jpg(quality: 85))
        }
        #expect(throws: (any Error).self) {
            try STBImageCoder.export(imageData: imageData, format: .webp(quality: 85))
        }
    }

    // MARK: - Convert

    @Test
    func convertSameFormatReturnsOriginalData() throws {
        let png = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.png"))
        let jpg = try #require(ImageLoader.loadFile(named: "usgs_16_13672_24858.jpeg"))
        let webp = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.webp"))

        #expect(STBImageCoder.convert(png, to: .png) == png)
        #expect(STBImageCoder.convert(jpg, to: .jpg(quality: 50)) == jpg)
        #expect(STBImageCoder.convert(webp, to: .webp(quality: 50)) == webp)
    }

    @Test
    func convertCrossFormat() throws {
        let png = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.png"))

        let webp = STBImageCoder.convert(png, to: .webp(quality: 85))
        #expect(STBImageCoder.imageFormat(webp) == .webp)
        #expect(webp != png)

        let pngAgain = STBImageCoder.convert(webp, to: .png)
        #expect(STBImageCoder.imageFormat(pngAgain) == .png)

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

        #expect(STBImageCoder.convert(data, to: .webp(quality: 85)) == data)
    }

    // MARK: - Grayscale export

    // Grayscale (1 channel) STBImageData can be exported as PNG
    @Test
    func exportGrayscalePNG() throws {
        let gray = STBImageData(width: 2, height: 2, bpp: 1, data: [10, 20, 30, 40])

        let exported = try STBImageCoder.export(imageData: gray, format: .png)
        #expect(STBImageCoder.imageFormat(exported) == .png)

        let reloaded = try #require(try STBImageCoder.load(from: exported))
        #expect(reloaded.width == 2)
        #expect(reloaded.height == 2)
        #expect(reloaded.bpp == 1)
        #expect(reloaded.data == [10, 20, 30, 40])
    }

    // Gray+alpha (2 channel) STBImageData can be exported as PNG
    @Test
    func exportGrayAlphaPNG() throws {
        let grayAlpha = STBImageData(width: 2, height: 2, bpp: 2, data: [11, 255, 22, 128, 33, 64, 44, 0])

        let exported = try STBImageCoder.export(imageData: grayAlpha, format: .png)
        #expect(STBImageCoder.imageFormat(exported) == .png)

        let reloaded = try #require(try STBImageCoder.load(from: exported))
        #expect(reloaded.width == 2)
        #expect(reloaded.height == 2)
        #expect(reloaded.bpp == 2)
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
        let webp = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.webp"))

        #expect(try STBImageCoder.converting(png, to: .png) == png)
        #expect(try STBImageCoder.converting(jpg, to: .jpg(quality: 50)) == jpg)
        #expect(try STBImageCoder.converting(webp, to: .webp(quality: 50)) == webp)
    }

    @Test
    func convertingCrossFormat() throws {
        let png = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.png"))

        let webp = try STBImageCoder.converting(png, to: .webp(quality: 85))
        #expect(STBImageCoder.imageFormat(webp) == .webp)

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

        #expect(throws: STBImageReadError.self) {
            try STBImageCoder.converting(data, to: .webp(quality: 85))
        }
    }

    // MARK: - WebP export options

    // exact = true preserves the RGB values of transparent pixels,
    // making lossless roundtrips pixel-exact
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

}
