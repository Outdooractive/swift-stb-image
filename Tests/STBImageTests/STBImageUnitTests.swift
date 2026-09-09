import Foundation
@testable import STBImage
import Testing

struct STBImageUnitTests {

    // MARK: - Init

    @Test
    func initWithValue() {
        let image = STBImage(width: 3, height: 2, value: 77)

        #expect(image.width == 3)
        #expect(image.height == 2)
        #expect(image.channels == 4)
        #expect(image.hasAlpha)
        #expect(image.data.count == 3 * 2 * STBImage.RGBA.channels)
        #expect(image.data.allSatisfy { $0 == 77 })
    }

    @Test
    func initWithImageData() {
        let rgb = STBImageData(width: 2, height: 2, bpp: 3, data: [UInt8](repeating: 1, count: 12))
        let rgba = STBImageData(width: 2, height: 2, bpp: 4, data: [UInt8](repeating: 1, count: 16))

        #expect(STBImage(imageData: rgb) != nil)
        #expect(STBImage(imageData: rgba) != nil)
        #expect(STBImage(imageData: rgb)?.channels == 3)
        #expect(STBImage(imageData: rgba)?.channels == 4)
    }

    @Test
    func initWithInvalidImageData() {
        let gray = STBImageData(width: 2, height: 2, bpp: 1, data: [UInt8](repeating: 1, count: 4))
        let grayAlpha = STBImageData(width: 2, height: 2, bpp: 2, data: [UInt8](repeating: 1, count: 8))

        #expect(STBImage(imageData: gray) == nil)
        #expect(STBImage(imageData: grayAlpha) == nil)
    }

    @Test
    func initWithInvalidData() {
        #expect(STBImage(data: Data([1, 2, 3, 4, 5])) == nil)
        #expect(STBImage(data: Data()) == nil)
        #expect(STBImage(url: URL(fileURLWithPath: "/nonexistent/image.png")) == nil)
    }

    // MARK: - Data index

    @Test
    func dataIndex() {
        #expect(STBImage.dataIndex(x: 0, y: 0, width: 4, height: 3, channels: 4) == 0)
        #expect(STBImage.dataIndex(x: 1, y: 0, c: 2, width: 4, height: 3, channels: 4) == 6)
        #expect(STBImage.dataIndex(x: 2, y: 2, c: 1, width: 4, height: 3, channels: 4) == 41)
        #expect(STBImage.dataIndex(x: 3, y: 2, c: 3, width: 4, height: 3, channels: 4) == 47)
    }

    @Test
    func dataIndexInstance() {
        let image = STBImage(width: 4, height: 3, channels: 3, data: [UInt8](repeating: 0, count: 36))

        #expect(image.dataIndex(x: 0, y: 0) == 0)
        #expect(image.dataIndex(x: 2, y: 1, c: 2) == 20)
        #expect(image.dataIndex(x: 3, y: 2) == 33)
    }

    // MARK: - Subscripts

    @Test
    func subscriptAccess() {
        var image = STBImage(width: 2, height: 2, value: 0)

        image[0, 0, 0] = 10
        image[1, 0, 1] = 20
        image[0, 1, 2] = 30
        image[1, 1, 3] = 40

        #expect(image[0, 0, 0] == 10)
        #expect(image[1, 0, 1] == 20)
        #expect(image[0, 1, 2] == 30)
        #expect(image[1, 1, 3] == 40)

        image[0, 0, .red] = 100
        image[1, 1, .alpha] = 200

        #expect(image[0, 0, .red] == 100)
        #expect(image[1, 1, .alpha] == 200)

        #expect(image[data: 0] == 100)
        image[data: 5] = 33
        #expect(image[data: 5] == 33)
    }

    // MARK: - Alpha

    @Test
    func isTransparent() {
        var image = STBImage(width: 2, height: 2, value: 255)
        #expect(!image.isTransparent)

        image[1, 1, .alpha] = 128
        #expect(image.isTransparent)

        image[1, 1, .alpha] = 0
        #expect(image.isTransparent)

        let opaque = STBImage(
            width: 2,
            height: 2,
            channels: 3,
            data: [UInt8](repeating: 255, count: 12))
        #expect(!opaque.isTransparent)
    }

    @Test
    func isTransparentChecksAllPixels() {
        var image = STBImage(width: 16, height: 16, value: 255)
        image[15, 15, .alpha] = 254
        #expect(image.isTransparent)
    }

    @Test
    func dropAlpha() {
        var image = STBImage(width: 2, height: 2, value: 0)
        image[0, 0, .red] = 1
        image[0, 0, .green] = 2
        image[0, 0, .blue] = 3
        image[1, 1, .red] = 4
        image[1, 1, .green] = 5
        image[1, 1, .blue] = 6
        image[1, 1, .alpha] = 9

        image.dropAlpha()

        #expect(image.channels == 3)
        #expect(!image.hasAlpha)
        #expect(image.data.count == 2 * 2 * 3)
        #expect(image.data == [1, 2, 3, 0, 0, 0, 0, 0, 0, 4, 5, 6])
    }

    @Test
    func dropAlphaOnLargeImage() {
        var image = STBImage(width: 64, height: 64, value: 12)
        image[63, 63, .alpha] = 1

        let expected = image.data.enumerated()
            .filter { $0.offset % 4 != 3 }
            .map(\.element)

        image.dropAlpha()

        #expect(image.data == expected)
    }

    @Test
    func dropAlphaOnRGBImage() {
        let image = STBImage(
            width: 2,
            height: 2,
            channels: 3,
            data: [UInt8](repeating: 7, count: 12))

        var copy = image
        copy.dropAlpha()

        #expect(copy == image)
        #expect(copy.channels == 3)
    }

    // MARK: - Equality & description

    @Test
    func equality() {
        let image1 = STBImage(width: 2, height: 2, value: 5)
        let image2 = STBImage(width: 2, height: 2, value: 5)
        let image3 = STBImage(width: 2, height: 2, value: 6)
        let image4 = STBImage(width: 3, height: 2, value: 5)

        #expect(image1 == image2)
        #expect(image1 != image3)
        #expect(image1 != image4)

        let rgb = STBImage(width: 2, height: 2, channels: 3, data: [UInt8](repeating: 5, count: 12))
        #expect(image1 != rgb)
    }

    @Test
    func description() {
        let rgba = STBImage(width: 2, height: 3, value: 0)
        #expect(rgba.description == "Image<RGBA>(width: 2, height: 3)")

        let rgb = STBImage(width: 4, height: 5, channels: 3, data: [UInt8](repeating: 0, count: 60))
        #expect(rgb.description == "Image<RGB>(width: 4, height: 5)")
    }

    // MARK: - Pixelwise conversion

    @Test
    func pixelwiseConvert() {
        var image = STBImage(width: 2, height: 2, value: 0)
        image[0, 0, .red] = 10
        image[1, 1, .blue] = 20

        image.unsafePixelwiseConvert { ref in
            for c in 0 ..< ref.channels {
                ref[c] = ref[c] + 1
            }
        }

        #expect(image[0, 0, .red] == 11)
        #expect(image[0, 0, .alpha] == 1)
        #expect(image[1, 1, .blue] == 21)
        #expect(image[0, 1, .alpha] == 1)
    }

    @Test
    func pixelwiseConvertSubRange() {
        var image = STBImage(width: 3, height: 3, value: 0)

        image.unsafePixelwiseConvert(1 ..< 2, 1 ..< 3) { ref in
            ref[0] = 9
        }

        #expect(image[1, 1, 0] == 9)
        #expect(image[1, 2, 0] == 9)
        #expect(image[0, 0, 0] == 0)
        #expect(image[2, 2, 0] == 0)
        #expect(image[1, 0, 0] == 0)
        #expect(image[0, 1, 0] == 0)
    }

    @Test
    func pixelwiseConvertPixelCoordinates() {
        var image = STBImage(width: 2, height: 2, value: 0)

        image.unsafePixelwiseConvert { ref in
            ref[0] = UInt8(ref.x * 10 + ref.y)
        }

        #expect(image[1, 1, 0] == 11)
        #expect(image[0, 1, 0] == 1)
        #expect(image[1, 0, 0] == 10)
    }

    // MARK: - Blending

    // A fully transparent overlay leaves the base image unchanged
    @Test
    func blendWithTransparentOverlay() {
        var base = STBImage(width: 2, height: 2, value: 50)
        var overlay = STBImage(width: 2, height: 2, value: 200)
        overlay.unsafePixelwiseConvert { ref in
            ref[STBImage.RGBA.alphaIndex] = 0
        }

        base.blendWith(overlay)

        #expect(base == STBImage(width: 2, height: 2, value: 50))
    }

    // A fully opaque overlay replaces the base image
    @Test
    func blendWithOpaqueOverlay() {
        var base = STBImage(width: 2, height: 2, value: 50)
        var overlay = STBImage(width: 2, height: 2, value: 200)
        overlay.unsafePixelwiseConvert { ref in
            ref[STBImage.RGBA.alphaIndex] = 255
        }

        base.blendWith(overlay)

        #expect(base == overlay)
    }

    // Blend math for a known 50% alpha overlay
    // base = (100, 100, 100, 255), overlay = (200, 0, 0, 128)
    // factor = (255 - 128) * 255 = 32385
    // blendAlpha255 = 255 * 128 + 32385 = 65025
    // red = (100 * 32385 + 255 * 128 * 200) / 65025 = 150
    // green = blue = (100 * 32385 + 255 * 128 * 0) / 65025 = 49
    // alpha = 65025 / 255 = 255
    @Test
    func blendWithHalfTransparentOverlay() {
        var base = STBImage(width: 1, height: 1, value: 100)
        base[0, 0, .alpha] = 255
        var overlay = STBImage(width: 1, height: 1, value: 0)
        overlay[0, 0, .red] = 200
        overlay[0, 0, .alpha] = 128

        base.blendWith(overlay)

        #expect(base[0, 0, .red] == 150)
        #expect(base[0, 0, .green] == 49)
        #expect(base[0, 0, .blue] == 49)
        #expect(base[0, 0, .alpha] == 255)
    }

    // An RGB overlay on an RGBA base wins completely
    @Test
    func blendWithRGBOverlayOnRGBABase() {
        var base = STBImage(width: 1, height: 1, value: 50)
        let overlay = STBImage(width: 1, height: 1, channels: 3, data: [10, 20, 30])

        base.blendWith(overlay)

        #expect(base[0, 0, .red] == 10)
        #expect(base[0, 0, .green] == 20)
        #expect(base[0, 0, .blue] == 30)
        #expect(base[0, 0, .alpha] == 255)
    }

    // An RGB base has no alpha to blend
    @Test
    func blendWithRGBBase() {
        var base = STBImage(width: 1, height: 1, channels: 3, data: [100, 100, 100])
        var overlay = STBImage(width: 1, height: 1, value: 0)
        overlay[0, 0, .red] = 200
        overlay[0, 0, .alpha] = 128

        base.blendWith(overlay)

        #expect(base[0, 0, .red] == 150)
        #expect(base[0, 0, .green] == 49)
        #expect(base[0, 0, .blue] == 49)
        #expect(base.channels == 3)
    }

    @Test
    func blendWithMultipleImages() {
        var base = STBImage(width: 1, height: 1, value: 0)
        let first = STBImage(width: 1, height: 1, channels: 3, data: [10, 10, 10])
        let second = STBImage(width: 1, height: 1, channels: 3, data: [20, 20, 20])

        base.blendWith(images: [first, second])

        #expect(base[0, 0, .red] == 20)
    }

    @Test
    func blendWithEmptyImagesList() {
        let base = STBImage(width: 2, height: 2, value: 50)
        var copy = base

        copy.blendWith(images: [])

        #expect(copy == base)
    }

    @Test
    func blendImages() throws {
        var image = STBImage(width: 2, height: 2, value: 5)
        image.unsafePixelwiseConvert { ref in
            ref[STBImage.RGBA.alphaIndex] = 255
        }

        #expect(STBImage.blend(images: []) == nil)
        #expect(STBImage.blend(images: [image]) == image)

        let blended = try #require(STBImage.blend(images: [image, image, image]))
        #expect(blended == image)
    }

    @Test
    func blendRGBImages() throws {
        let first = STBImage(width: 1, height: 1, channels: 3, data: [10, 10, 10])
        let second = STBImage(width: 1, height: 1, channels: 3, data: [20, 20, 20])

        let blended = try #require(STBImage.blend(images: [first, second]))

        #expect(blended.channels == 3)
        #expect(blended == second)
    }

}
