import Foundation
@testable import STBImage
import Testing

struct STBImageTransformTests {

    // 2x3 test image, red channel encodes the pixel as y * 10 + x
    private var testImage: STBImage {
        var image = STBImage(width: 2, height: 3, red: 0, green: 0, blue: 0, alpha: 255)
        image.mapPixels { pixel in
            var pixel = pixel
            pixel.red = UInt8(pixel.y * 10 + pixel.x)
            return pixel
        }
        return image
    }

    // MARK: - Color fill init

    @Test
    func initWithoutAlpha() {
        let image = STBImage(width: 2, height: 2, red: 1, green: 2, blue: 3)

        #expect(image.channels == 3)
        #expect(!image.hasAlpha)
        #expect(image.data.count == 12)
        for y in 0 ..< 2 {
            for x in 0 ..< 2 {
                #expect(image[x, y, .red] == 1)
                #expect(image[x, y, .green] == 2)
                #expect(image[x, y, .blue] == 3)
            }
        }
    }

    @Test
    func initWithAlpha() {
        let image = STBImage(width: 2, height: 2, red: 1, green: 2, blue: 3, alpha: 4)

        #expect(image.channels == 4)
        #expect(image.hasAlpha)
        #expect(image.data == [1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4])
    }

    // MARK: - Extraction

    @Test
    func extractFullImage() throws {
        let image = testImage
        let extractedImage = image.extract(x: 0, y: 0, width: image.width, height: image.height)
        let extracted = try #require(extractedImage)

        #expect(extracted == image)
    }

    @Test
    func extractSubRegion() throws {
        let image = testImage
        // Bottom right 1x2 region
        let extractedImage = image.extract(x: 1, y: 1, width: 1, height: 2)
        let extracted = try #require(extractedImage)

        #expect(extracted.width == 1)
        #expect(extracted.height == 2)
        #expect(extracted.channels == image.channels)
        #expect(extracted[0, 0, .red] == image[1, 1, .red])
        #expect(extracted[0, 1, .red] == image[1, 2, .red])
    }

    @Test
    func extractInvalidRegions() {
        let image = testImage

        #expect(image.extract(x: 0, y: 0, width: 0, height: 1) == nil)
        #expect(image.extract(x: 0, y: 0, width: 1, height: 0) == nil)
        #expect(image.extract(x: -1, y: 0, width: 1, height: 1) == nil)
        #expect(image.extract(x: 0, y: -1, width: 1, height: 1) == nil)
        #expect(image.extract(x: 0, y: 0, width: 3, height: 1) == nil)
        #expect(image.extract(x: 0, y: 0, width: 1, height: 4) == nil)
    }

    // MARK: - Rescaling

    @Test
    func resizedToSameSize() throws {
        let image = testImage
        let resizedImage = image.resized(width: image.width, height: image.height)
        let resized = try #require(resizedImage)

        #expect(resized == image)
    }

    // 2x2 image with black and white columns, downscaled to 1x1
    // results in the average 128
    @Test
    func resizedDownscale() throws {
        var image = STBImage(width: 2, height: 2, red: 0, green: 0, blue: 0, alpha: 255)
        for y in 0 ..< 2 {
            image[1, y, .red] = 255
            image[1, y, .green] = 255
            image[1, y, .blue] = 255
        }

        let resizedImage = image.resized(width: 1, height: 1)
        let resized = try #require(resizedImage)

        #expect(resized[0, 0, .red] == 128)
        #expect(resized[0, 0, .green] == 128)
        #expect(resized[0, 0, .blue] == 128)
        #expect(resized[0, 0, .alpha] == 255)
    }

    @Test
    func resizedUpscale() throws {
        var image = STBImage(width: 2, height: 2, red: 0, green: 0, blue: 0, alpha: 255)
        for y in 0 ..< 2 {
            image[1, y, .red] = 255
            image[1, y, .green] = 255
            image[1, y, .blue] = 255
        }

        let resizedImage = image.resized(width: 4, height: 4)
        let resized = try #require(resizedImage)

        #expect(resized.width == 4)
        #expect(resized.height == 4)

        // Center pixel of the 2x2 gradient
        #expect(resized[1, 1, .red] == 64)
        // Corner pixel, biased towards the white column
        #expect(resized[0, 0, .red] == 191)
    }

    @Test
    func resizedInvalidDimensions() {
        let image = testImage

        #expect(image.resized(width: 0, height: 1) == nil)
        #expect(image.resized(width: 1, height: 0) == nil)
        #expect(image.resized(width: -1, height: 1) == nil)
    }

    @Test
    func resizedKeepsChannelsAndAlpha() throws {
        var image = STBImage(width: 4, height: 4, value: 100)
        image[0, 0, .alpha] = 0

        let resizedImage = image.resized(width: 2, height: 2)
        let resized = try #require(resizedImage)

        #expect(resized.channels == 4)
        #expect(resized.isTransparent)
    }

    // MARK: - Rotation

    // 2x3 image, red encodes y * 10 + x:
    // row 0: [0, 1], row 1: [10, 11], row 2: [20, 21]
    @Test
    func rotated90Clockwise() {
        let rotated = testImage.rotated(quarterTurns: 1)

        #expect(rotated.width == 3)
        #expect(rotated.height == 2)

        #expect(rotated[0, 0, .red] == 20)
        #expect(rotated[1, 0, .red] == 10)
        #expect(rotated[2, 0, .red] == 0)
        #expect(rotated[0, 1, .red] == 21)
        #expect(rotated[1, 1, .red] == 11)
        #expect(rotated[2, 1, .red] == 1)
    }

    @Test
    func rotated180() {
        let rotated = testImage.rotated(quarterTurns: 2)

        #expect(rotated.width == 2)
        #expect(rotated.height == 3)

        #expect(rotated[0, 0, .red] == 21)
        #expect(rotated[1, 0, .red] == 20)
        #expect(rotated[0, 1, .red] == 11)
        #expect(rotated[1, 1, .red] == 10)
        #expect(rotated[0, 2, .red] == 1)
        #expect(rotated[1, 2, .red] == 0)
    }

    @Test
    func rotated90CounterClockwise() {
        let rotated = testImage.rotated(quarterTurns: 3)

        #expect(rotated.width == 3)
        #expect(rotated.height == 2)

        #expect(rotated[0, 0, .red] == 1)
        #expect(rotated[1, 0, .red] == 11)
        #expect(rotated[2, 0, .red] == 21)
        #expect(rotated[0, 1, .red] == 0)
        #expect(rotated[1, 1, .red] == 10)
        #expect(rotated[2, 1, .red] == 20)
    }

    @Test
    func rotatedFullTurns() {
        let image = testImage

        #expect(image.rotated(quarterTurns: 0) == image)
        #expect(image.rotated(quarterTurns: 4) == image)
        #expect(image.rotated(quarterTurns: -4) == image)
        #expect(image.rotated(quarterTurns: -1) == image.rotated(quarterTurns: 3))
        #expect(image.rotated(quarterTurns: 5) == image.rotated(quarterTurns: 1))

        let rotated180 = image.rotated(quarterTurns: 2)
        #expect(rotated180.rotated(quarterTurns: 2) == image)
    }

    // MARK: - Flipping

    @Test
    func flippedHorizontally() {
        let flipped = testImage.flippedHorizontally()

        #expect(flipped.width == 2)
        #expect(flipped.height == 3)

        #expect(flipped[0, 0, .red] == 1)
        #expect(flipped[1, 0, .red] == 0)
        #expect(flipped[0, 2, .red] == 21)
        #expect(flipped[1, 2, .red] == 20)

        // Flipping twice restores the image
        #expect(flipped.flippedHorizontally() == testImage)
    }

    @Test
    func flippedVertically() {
        let flipped = testImage.flippedVertically()

        #expect(flipped.width == 2)
        #expect(flipped.height == 3)

        #expect(flipped[0, 0, .red] == 20)
        #expect(flipped[1, 0, .red] == 21)
        #expect(flipped[0, 2, .red] == 0)
        #expect(flipped[1, 2, .red] == 1)

        #expect(flipped.flippedVertically() == testImage)
    }

    // MARK: - Offset blending

    @Test
    func blendAtOriginEqualsFullBlend() {
        var base = STBImage(width: 3, height: 3, red: 10, green: 10, blue: 10)
        let overlay = STBImage(width: 3, height: 3, red: 200, green: 0, blue: 0, alpha: 255)

        var expected = base
        expected.blendWith(overlay)

        base.blendWith(overlay, at: 0, y: 0)

        #expect(base == expected)
    }

    @Test
    func blendAtOffset() {
        var base = STBImage(width: 3, height: 3, red: 10, green: 10, blue: 10)
        let overlay = STBImage(width: 2, height: 2, red: 200, green: 0, blue: 0, alpha: 255)

        base.blendWith(overlay, at: 1, y: 1)

        // Only the overlapping bottom right 2x2 region changed
        #expect(base[0, 0, .red] == 10)
        #expect(base[2, 0, .red] == 10)
        #expect(base[0, 2, .red] == 10)
        for y in 1 ..< 3 {
            for x in 1 ..< 3 {
                #expect(base[x, y, .red] == 200)
            }
        }
    }

    @Test
    func blendAtNegativeOffset() {
        var base = STBImage(width: 3, height: 3, red: 10, green: 10, blue: 10)
        var overlay = STBImage(width: 2, height: 2, red: 200, green: 0, blue: 0, alpha: 255)
        // Bottom right pixel of the overlay differs
        overlay[1, 1, .red] = 50

        base.blendWith(overlay, at: -1, y: -1)

        // Only overlay pixel (1, 1) lands on base pixel (0, 0)
        #expect(base[0, 0, .red] == 50)
        #expect(base[1, 0, .red] == 10)
        #expect(base[0, 1, .red] == 10)
    }

    @Test
    func blendWithOverhang() {
        var base = STBImage(width: 3, height: 3, red: 10, green: 10, blue: 10)
        var overlay = STBImage(width: 3, height: 3, red: 200, green: 0, blue: 0, alpha: 255)
        overlay[0, 0, .red] = 50

        base.blendWith(overlay, at: 2, y: 2)

        #expect(base[2, 2, .red] == 50)
        #expect(base[1, 1, .red] == 10)
    }

    @Test
    func blendOutsideBounds() {
        var base = STBImage(width: 2, height: 2, red: 10, green: 10, blue: 10)
        let overlay = STBImage(width: 2, height: 2, red: 200, green: 0, blue: 0, alpha: 255)

        base.blendWith(overlay, at: 10, y: 10)
        base.blendWith(overlay, at: -10, y: -10)

        #expect(base == STBImage(width: 2, height: 2, red: 10, green: 10, blue: 10))
    }

    // MARK: - Pixel iteration

    @Test
    func forEachPixelVisitsAllPixels() {
        let image = testImage

        var count = 0
        image.forEachPixel { pixel in
            #expect(pixel.red == UInt8(pixel.y * 10 + pixel.x))
            count += 1
        }

        #expect(count == 6)
    }

    @Test
    func forEachPixelAlphaNilForRGB() {
        let image = STBImage(width: 2, height: 2, red: 1, green: 2, blue: 3)

        image.forEachPixel { pixel in
            #expect(pixel.alpha == nil)
        }
    }

    @Test
    func mapPixelsInverts() {
        var image = STBImage(width: 2, height: 2, red: 10, green: 20, blue: 30, alpha: 255)

        image.mapPixels { pixel in
            var pixel = pixel
            pixel.red = 255 - pixel.red
            pixel.green = 255 - pixel.green
            pixel.blue = 255 - pixel.blue
            return pixel
        }

        #expect(image[0, 0, .red] == 245)
        #expect(image[0, 0, .green] == 235)
        #expect(image[0, 0, .blue] == 225)
    }

    @Test
    func mapPixelsKeepsAlphaWhenNil() {
        var image = STBImage(width: 1, height: 1, red: 0, green: 0, blue: 0, alpha: 77)

        image.mapPixels { pixel in
            var pixel = pixel
            pixel.red = 100
            // alpha stays nil -> existing value is kept
            return pixel
        }

        #expect(image[0, 0, .red] == 100)
        #expect(image[0, 0, .alpha] == 77)
    }

    @Test
    func mapPixelsIgnoresAlphaForRGB() {
        var image = STBImage(width: 1, height: 1, red: 0, green: 0, blue: 0)

        image.mapPixels { pixel in
            var pixel = pixel
            pixel.alpha = 123 // ignored, image has no alpha channel
            return pixel
        }

        #expect(image.channels == 3)
        #expect(!image.hasAlpha)
    }

    // MARK: - Hashable & Sendable

    @Test
    func hashable() {
        let image = STBImage(width: 2, height: 2, value: 5)
        let same = STBImage(width: 2, height: 2, value: 5)
        let other = STBImage(width: 2, height: 2, value: 6)

        var set = Set<STBImage>()
        set.insert(image)
        set.insert(same)

        #expect(set.count == 1)
        #expect(set.contains(image))

        set.insert(other)
        #expect(set.count == 2)
    }

    @Test
    func sendable() {
        let image = STBImage(width: 2, height: 2, value: 5)

        func acceptsSendable<T: Sendable>(_ value: T) -> Bool {
            _ = value
            return true
        }

        #expect(acceptsSendable(image))
    }

}
