#if EnableTIFF
import Foundation
@testable import STBImage
import Testing

struct TIFFTests {

    /// 256x256 RGBA test image with transparency
    private let rgbaData = ImageLoader.loadFile(named: "avk_11_1077_720.webp")

    /// 256x256 RGB test image without transparency
    private let rgbData = ImageLoader.loadFile(named: "avk_11_1078_719.webp")

    // MARK: - Inspection

    @Test
    func inspectStripTIFF() throws {
        let image = try TIFFDecoder.load(from: #require(ImageLoader.loadFile(named: "rgba_strip.tif")))
        let info = try TIFFImageInspector.inspect(#require(ImageLoader.loadFile(named: "rgba_strip.tif")))

        #expect(info.width == 256)
        #expect(info.height == 256)
        #expect(info.channels == 4)
        #expect(info.bitDepth == .eight)
        #expect(info.isTiled == false)
        #expect(info.compression == .deflate)
        #expect(info.geoTIFFInfo == nil)
        #expect(image?.channels == 4)
    }

    @Test
    func inspectTiledTIFF() throws {
        let info = try TIFFImageInspector.inspect(#require(ImageLoader.loadFile(named: "rgba_tiled.tif")))

        #expect(info.width == 256)
        #expect(info.height == 256)
        #expect(info.channels == 4)
        #expect(info.isTiled)
        #expect(info.compression == .deflate)
    }

    // MARK: - Decoding

    @Test
    func decodeRGBATIFF() throws {
        let tiffData = try #require(ImageLoader.loadFile(named: "rgba_strip.tif"))
        let image = try #require(try TIFFDecoder.load(from: tiffData))

        #expect(image.width == 256)
        #expect(image.height == 256)
        #expect(image.channels == 4)
        #expect(image.bitDepth == .eight)

        // Compare against the WebP reference (the fixture was created
        // from it), only available with the EnableWebP trait
        #if EnableWebP
        let sourceData = try #require(rgbaData)
        let pngImage = try #require(STBImage(data: sourceData))
        #expect(image.data == pngImage.data)
        #endif
    }

    @Test
    func decodeRGBTIFF() throws {
        let tiffData = try #require(ImageLoader.loadFile(named: "rgb_strip.tif"))
        let image = try #require(try TIFFDecoder.load(from: tiffData))

        #expect(image.channels == 3)

        #if EnableWebP
        let sourceData = try #require(rgbData)
        let pngImage = try #require(STBImage(data: sourceData))
        #expect(image.data == pngImage.data)
        #endif
    }

    @Test
    func decodeGrayTIFF() throws {
        let tiffData = try #require(ImageLoader.loadFile(named: "gray8.tif"))
        let image = try #require(try TIFFDecoder.load(from: tiffData))

        #expect(image.width == 64)
        #expect(image.height == 64)
        #expect(image.channels == 1)
        #expect(image.bitDepth == .eight)

        // Pixel values written by the fixture generator: (y*4+x) % 256
        #expect(image.data[0] == 0)
        #expect(image.data[63] == 63)
    }

    @Test
    func decodeGrayAlphaTIFF() throws {
        let tiffData = try #require(ImageLoader.loadFile(named: "grayalpha.tif"))
        let image = try #require(try TIFFDecoder.load(from: tiffData))

        #expect(image.channels == 2)
    }

    @Test
    func decodeGrayAsRGB() throws {
        let tiffData = try #require(ImageLoader.loadFile(named: "gray8.tif"))
        let image = try #require(try TIFFDecoder.load(from: tiffData, desiredChannels: 3))

        #expect(image.channels == 3)
        // Gray replicated into all channels
        #expect(image.data[0] == image.data[1])
        #expect(image.data[1] == image.data[2])
    }

    @Test
    func decode16BitGrayTIFF() throws {
        let tiffData = try #require(ImageLoader.loadFile(named: "gray16.tif"))
        let image = try #require(try TIFFDecoder.load(from: tiffData))

        #expect(image.width == 256)
        #expect(image.height == 256)
        #expect(image.channels == 1)
        #expect(image.bitDepth == .sixteen)
        #expect(image.data.count == 256 * 256 * 2)
        #expect(image.bytesPerPixel == 2)

        // Value fidelity: little-endian 16-bit values (r*257+c*13) % 65536
        let first = UInt16(image.data[0]) | (UInt16(image.data[1]) << 8)
        #expect(first == 0)
        let second = UInt16(image.data[2]) | (UInt16(image.data[3]) << 8)
        #expect(second == 13)
    }

    @Test
    func decode16BitGrayAsSTBImageData() throws {
        let tiffData = try #require(ImageLoader.loadFile(named: "gray16.tif"))
        let imageData = try #require(try STBImageCoder.load(from: tiffData))

        #expect(imageData.bitDepth == .sixteen)
        #expect(imageData.channels == 1)
    }

    @Test
    func decodeTiledTIFF() throws {
        let tiffData = try #require(ImageLoader.loadFile(named: "rgba_tiled.tif"))
        let image = try #require(try TIFFDecoder.load(from: tiffData))

        // Same pixels as the strip version
        let stripData = try #require(ImageLoader.loadFile(named: "rgba_strip.tif"))
        let stripImage = try #require(try TIFFDecoder.load(from: stripData))
        #expect(image.data == stripImage.data)
    }

    @Test
    func decodeBigEndianTIFF() throws {
        let tiffData = try #require(ImageLoader.loadFile(named: "rgba_bigendian.tif"))
        let image = try #require(try TIFFDecoder.load(from: tiffData))

        #expect(image.width == 256)
        #expect(image.height == 256)
        #expect(image.channels == 4)

        let stripData = try #require(ImageLoader.loadFile(named: "rgba_strip.tif"))
        let stripImage = try #require(try TIFFDecoder.load(from: stripData))
        #expect(image.data == stripImage.data)
    }

    @Test
    func decodeCompressions() throws {
        for name in ["rgba_lzw.tif", "rgba_packbits.tif"] {
            let tiffData = try #require(ImageLoader.loadFile(named: name))
            let image = try #require(try TIFFDecoder.load(from: tiffData))
            #expect(image.channels == 4)
            #expect(image.width == 256)
        }
    }

    @Test
    func decodePalettedFails() throws {
        let tiffData = try #require(ImageLoader.loadFile(named: "paletted.tif"))

        #expect {
            try TIFFDecoder.load(from: tiffData)
        } throws: { error in
            if case TIFFError.unsupported = error {
                return true
            }
            return false
        }
    }

    @Test
    func decodeUnknownFormat() throws {
        let image = try TIFFDecoder.load(from: Data([0x00, 0x01, 0x02, 0x03]))
        #expect(image == nil)
    }

    @Test
    func decodeCorruptTIFF() throws {
        var data = try #require(ImageLoader.loadFile(named: "rgba_strip.tif"))
        data.replaceSubrange(100..., with: Data(repeating: 0xFF, count: 64))

        #expect {
            try TIFFDecoder.load(from: data)
        } throws: { error in
            error is TIFFError
        }
    }

    // MARK: - Encoding

    @Test
    func roundtripRGBA() throws {
        #if EnableWebP
        let sourceData = try #require(rgbaData)
        let pngImage = try #require(STBImage(data: sourceData))
        let imageData = pngImage.imageData
        #else
        // Without WebP support, generate an RGBA reference image
        var data = [UInt8]()
        for index in 0 ..< 64 * 64 {
            data.append(UInt8((index * 3) % 256))
            data.append(UInt8((index * 5) % 256))
            data.append(UInt8((index * 7) % 256))
            data.append(UInt8((index % 3 == 0) ? 0 : 255))
        }
        let imageData = STBImageData(width: 64, height: 64, channels: 4, data: data)
        #endif

        let encoded = try TIFFEncoder.export(image: imageData)
        let decoded = try #require(try TIFFDecoder.load(from: encoded))

        #expect(decoded.width == imageData.width)
        #expect(decoded.height == imageData.height)
        #expect(decoded.channels == 4)
        #expect(decoded.data == imageData.data)
    }

    @Test
    func roundtripRGB() throws {
        #if EnableWebP
        let sourceData = try #require(rgbData)
        let pngImage = try #require(STBImage(data: sourceData))
        let imageData = pngImage.imageData
        #else
        // Without WebP support, generate an RGB reference image
        var data = [UInt8]()
        for index in 0 ..< 64 * 64 {
            data.append(UInt8((index * 3) % 256))
            data.append(UInt8((index * 5) % 256))
            data.append(UInt8((index * 7) % 256))
        }
        let imageData = STBImageData(width: 64, height: 64, channels: 3, data: data)
        #endif

        let encoded = try TIFFEncoder.export(image: imageData)
        let decoded = try #require(try TIFFDecoder.load(from: encoded))

        #expect(decoded.channels == 3)
        #expect(decoded.data == imageData.data)
    }

    @Test
    func roundtripGray() throws {
        let image = STBImageData(
            width: 8,
            height: 8,
            channels: 1,
            data: [UInt8](0 ..< 64))

        let data = try TIFFEncoder.export(image: image)
        let decoded = try #require(try TIFFDecoder.load(from: data))

        #expect(decoded.channels == 1)
        #expect(decoded.data == image.data)
    }

    @Test
    func roundtripGrayAlpha() throws {
        var data = [UInt8]()
        for index in 0 ..< 16 * 16 {
            data.append(UInt8(index % 256))
            data.append(UInt8((index % 3 == 0) ? 0 : 255))
        }
        let image = STBImageData(width: 16, height: 16, channels: 2, data: data)

        let encoded = try TIFFEncoder.export(image: image)
        let decoded = try #require(try TIFFDecoder.load(from: encoded))

        #expect(decoded.channels == 2)
        #expect(decoded.data == image.data)
    }

    @Test
    func roundtrip16BitGray() throws {
        var data = [UInt8]()
        for index in 0 ..< 16 * 16 {
            let value = UInt16((index * 4096) % 65536)
            data.append(UInt8(value & 0xFF))
            data.append(UInt8(value >> 8))
        }
        let image = STBImageData(width: 16, height: 16, channels: 1, bitDepth: .sixteen, data: data)

        let encoded = try TIFFEncoder.export(image: image)
        let decoded = try #require(try TIFFDecoder.load(from: encoded))

        #expect(decoded.bitDepth == .sixteen)
        #expect(decoded.data == image.data)
    }

    @Test
    func compressions() throws {
        #if EnableWebP
        let sourceData = try #require(rgbaData)
        let pngImage = try #require(STBImage(data: sourceData))
        let imageData = pngImage.imageData
        #else
        var data = [UInt8]()
        for index in 0 ..< 64 * 64 {
            data.append(UInt8((index * 3) % 256))
            data.append(UInt8((index * 5) % 256))
            data.append(UInt8((index * 7) % 256))
            data.append(UInt8((index % 3 == 0) ? 0 : 255))
        }
        let imageData = STBImageData(width: 64, height: 64, channels: 4, data: data)
        #endif

        for compression in [TIFFCompression.none, .lzw, .deflate, .packBits] {
            let encoded = try TIFFEncoder.export(
                image: imageData,
                options: TIFFExportOptions(compression: compression))
            let decoded = try #require(try TIFFDecoder.load(from: encoded))
            #expect(decoded.data == imageData.data)
            #expect(decoded.channels == 4)
        }
    }

    @Test
    func unsupportedCompressionFails() throws {
        let image = STBImageData(width: 2, height: 2, channels: 3, data: [UInt8](repeating: 0, count: 12))

        #expect {
            try TIFFEncoder.export(image: image, options: TIFFExportOptions(compression: .jpeg))
        } throws: { error in
            error is TIFFWriteError
        }
    }

    @Test
    func emptyImageFails() throws {
        let image = STBImageData(width: 0, height: 0, channels: 3, data: [])

        #expect(throws: TIFFWriteError.self) {
            try TIFFEncoder.export(image: image)
        }
    }

    // MARK: - Integration with STBImageCoder

    @Test
    func imageFormatDetectsTIFF() throws {
        #expect(try STBImageCoder.imageFormat(#require(ImageLoader.loadFile(named: "rgba_strip.tif"))) == .tiff)
        #expect(try STBImageCoder.imageFormat(#require(ImageLoader.loadFile(named: "rgba_tiled.tif"))) == .tiff)
        #expect(try STBImageCoder.imageFormat(#require(ImageLoader.loadFile(named: "gray16.tif"))) == .tiff)
        #if EnableWebP
        #expect(try STBImageCoder.imageFormat(#require(rgbaData)) == .webp)
        #endif
        #expect(STBImageCoder.imageFormat(Data([0x00, 0x01, 0x02])) == .unknown)
    }

    @Test
    func loadTIFFThroughCoder() throws {
        let tiffData = try #require(ImageLoader.loadFile(named: "rgba_strip.tif"))
        let imageData = try #require(try STBImageCoder.load(from: tiffData))

        #expect(imageData.width == 256)
        #expect(imageData.height == 256)
        #expect(imageData.channels == 4)
    }

    @Test
    func loadTIFFWithDesiredChannels() throws {
        let tiffData = try #require(ImageLoader.loadFile(named: "grayalpha.tif"))
        let imageData = try #require(try STBImageCoder.load(from: tiffData, desiredChannels: 4))

        #expect(imageData.channels == 4)
    }

    @Test
    func exportTIFFThroughCoder() throws {
        #if EnableWebP
        let sourceData = try #require(rgbaData)
        let pngImage = try #require(STBImage(data: sourceData))
        let imageData = pngImage.imageData
        let originalData = pngImage.data
        #else
        var data = [UInt8]()
        for index in 0 ..< 64 * 64 {
            data.append(UInt8((index * 3) % 256))
            data.append(UInt8((index * 5) % 256))
            data.append(UInt8((index * 7) % 256))
            data.append(UInt8((index % 3 == 0) ? 0 : 255))
        }
        let imageData = STBImageData(width: 64, height: 64, channels: 4, data: data)
        let originalData = imageData.data
        #endif

        let encoded = try STBImageCoder.export(imageData: imageData, format: .tiff())
        #expect(STBImageCoder.imageFormat(encoded) == .tiff)

        let roundtrip = try #require(try STBImageCoder.load(from: encoded))
        #expect(roundtrip.data == originalData)
    }

    @Test
    func convertPNGToTIFF() throws {
        #if EnableWebP
        let pngData = try #require(rgbaData)

        let tiffData = try STBImageCoder.converting(pngData, to: .tiff())
        #expect(STBImageCoder.imageFormat(tiffData) == .tiff)

        let roundtrip = try #require(STBImage(data: tiffData))
        let original = try #require(STBImage(data: pngData))
        #expect(roundtrip.data == original.data)
        #endif
    }

    #if EnableWebP
    @Test
    func convertTIFFToWebP() throws {
        let tiffData = try STBImageCoder.converting(#require(ImageLoader.loadFile(named: "rgba_strip.tif")), to: .webp(quality: 95))
        #expect(STBImageCoder.imageFormat(tiffData) == .webp)
    }
    #endif

    @Test
    func convertingTiffToTiffIsIdentity() throws {
        let tiffData = try #require(ImageLoader.loadFile(named: "rgba_strip.tif"))
        let result = try STBImageCoder.converting(tiffData, to: .tiff())
        #expect(result == tiffData)
    }

    // MARK: - STBImage convenience

    @Test
    func stbImageExportTIFF() throws {
        #if EnableWebP
        let sourceData = try #require(rgbaData)
        let image = try #require(STBImage(data: sourceData))
        let originalData = image.data
        #else
        var data = [UInt8]()
        for index in 0 ..< 64 * 64 {
            data.append(UInt8((index * 3) % 256))
            data.append(UInt8((index * 5) % 256))
            data.append(UInt8((index * 7) % 256))
            data.append(UInt8((index % 3 == 0) ? 0 : 255))
        }
        let image = try #require(STBImage(imageData: STBImageData(width: 64, height: 64, channels: 4, data: data)))
        let originalData = image.data
        #endif

        let tiffData = try image.export(.tiff())
        #expect(STBImageCoder.imageFormat(tiffData) == .tiff)

        let reloaded = try #require(STBImage(data: tiffData))
        #expect(reloaded.data == originalData)
    }

    // MARK: - 16-bit integration

    @Test
    func load16BitThroughCoder() throws {
        let tiffData = try #require(ImageLoader.loadFile(named: "gray16.tif"))
        let imageData = try #require(try STBImageCoder.load(from: tiffData))

        #expect(imageData.bitDepth == .sixteen)
        #expect(imageData.channels == 1)
        #expect(imageData.bytesPerPixel == 2)
    }

    @Test
    func decode16BitBigEndianTIFF() throws {
        let tiffData = try #require(ImageLoader.loadFile(named: "gray16_bigendian.tif"))
        let image = try #require(try TIFFDecoder.load(from: tiffData))

        #expect(image.bitDepth == .sixteen)

        // The big-endian file must decode into the same little-endian
        // samples as the little-endian fixture.
        let littleData = try #require(ImageLoader.loadFile(named: "gray16.tif"))
        let littleImage = try #require(try TIFFDecoder.load(from: littleData))
        #expect(image.data == littleImage.data)
    }

    @Test
    func export16BitTIFFThroughCoder() throws {
        var data = [UInt8]()
        for index in 0 ..< 16 * 16 {
            let value = UInt16((index * 4096) % 65536)
            data.append(UInt8(value & 0xFF))
            data.append(UInt8(value >> 8))
        }
        let image = STBImageData(width: 16, height: 16, channels: 1, bitDepth: .sixteen, data: data)

        let encoded = try STBImageCoder.export(imageData: image, format: .tiff())
        #expect(STBImageCoder.imageFormat(encoded) == .tiff)

        let decoded = try #require(try STBImageCoder.load(from: encoded))
        #expect(decoded.bitDepth == .sixteen)
        #expect(decoded.data == data)
    }

    @Test
    func libtiffVersion() {
        let version = TIFFImageInspector.libtiffVersion
        #expect(version.contains("LIBTIFF"))
    }

}

#endif
