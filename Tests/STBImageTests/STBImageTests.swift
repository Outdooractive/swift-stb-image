import Foundation
@testable import STBImage
import Testing

struct STBImageTests {

    // PNG RGBA image with some transparent pixels
    @Test
    func transparentPNGImages() throws {
        let data = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.png"))
        let image = try #require(STBImage(data: data))

        #expect(image.width == 256)
        #expect(image.height == 256)
        #expect(image.channels == 4)
        #expect(image.hasAlpha)
        #expect(image.data.count == 256 * 256 * STBImage.RGBA.channels)
        #expect(image.isTransparent)
    }

    // WebP RGBA image with some transparent pixels
    @Test
    func transparentWebPImages() throws {
        let data = try #require(ImageLoader.loadFile(named: "avk_11_1077_720.webp"))
        let image = try #require(STBImage(data: data))

        #expect(image.width == 256)
        #expect(image.height == 256)
        #expect(image.channels == 4)
        #expect(image.hasAlpha)
        #expect(image.data.count == 256 * 256 * STBImage.RGBA.channels)
        #expect(image.isTransparent)

        let webP = try WebPImageInspector.inspect(data)
        #expect(webP.width == 256)
        #expect(webP.height == 256)
        #expect(webP.hasAlpha)
    }

    // PNG RGBA image without transparency
    @Test
    func notTransparentPNGImages() throws {
        let data = try #require(ImageLoader.loadFile(named: "osm_topo_11_1077_720.png"))
        let image = try #require(STBImage(data: data))

        #expect(image.width == 256)
        #expect(image.height == 256)
        #expect(image.channels == 4)
        #expect(image.hasAlpha)
        #expect(image.data.count == 256 * 256 * STBImage.RGBA.channels)
        #expect(!image.isTransparent)
    }

    // WebP RGBA image without transparency
    // Note: Image is loaded as RGB
    @Test
    func notTransparentWebPImages() throws {
        let data = try #require(ImageLoader.loadFile(named: "osm_topo_11_1077_720.webp"))
        let image = try #require(STBImage(data: data))

        #expect(image.width == 256)
        #expect(image.height == 256)
        #expect(image.channels == 3)
        #expect(!image.hasAlpha)
        #expect(image.data.count == 256 * 256 * STBImage.RGB.channels)
        #expect(!image.isTransparent)

        let webP = try WebPImageInspector.inspect(data)
        #expect(webP.width == 256)
        #expect(webP.height == 256)
        #expect(!webP.hasAlpha)
    }

    // PNG RGB image without alpha and transparency
    @Test
    func noAlphaPNG() throws {
        let data = try #require(ImageLoader.loadFile(named: "avk_11_1078_719.png"))
        let image = try #require(STBImage(data: data))

        #expect(image.width == 256)
        #expect(image.height == 256)
        #expect(image.channels == 3)
        #expect(!image.hasAlpha)
        #expect(image.data.count == 256 * 256 * STBImage.RGB.channels)
        #expect(!image.isTransparent)
    }

    // WebP RGB image without alpha and transparency
    @Test
    func noAlphaWebP() throws {
        let data = try #require(ImageLoader.loadFile(named: "avk_11_1078_719.webp"))
        let image = try #require(STBImage(data: data))

        #expect(image.width == 256)
        #expect(image.height == 256)
        #expect(image.channels == 3)
        #expect(!image.hasAlpha)
        #expect(image.data.count == 256 * 256 * STBImage.RGB.channels)
        #expect(!image.isTransparent)

        let webP = try WebPImageInspector.inspect(data)
        #expect(webP.width == 256)
        #expect(webP.height == 256)
        #expect(!webP.hasAlpha)
    }

    // Blending two PNG RGBA images
    @Test
    func blendingAlphaPNG() throws {
        let image1 = try #require(STBImage(url: ImageLoader.url(forResourceNamed: "osm_topo_11_1077_720.png")))
        let image2 = try #require(STBImage(url: ImageLoader.url(forResourceNamed: "avk_11_1077_720.png")))

        let expected = try #require(STBImage(url: ImageLoader.url(forResourceNamed: "avk_osm_11_1077_720.png")))
        let blended = try #require(STBImage.blend(images: [image1, image2]))
        #expect(blended == expected)

//        blended.write(to: URL(fileURLWithPath: "/Users/trasch/Desktop/blended.png"))
    }

    // Blending two WebP images, one with, one without alpha channel
    @Test
    func blendingAlphaWebP() throws {
        let image1 = try #require(STBImage(url: ImageLoader.url(forResourceNamed: "osm_topo_11_1077_720.webp")))
        let image2 = try #require(STBImage(url: ImageLoader.url(forResourceNamed: "avk_11_1077_720.webp")))

        let expected = try #require(STBImage(url: ImageLoader.url(forResourceNamed: "avk_osm_11_1077_720.webp")))
        let blended = try #require(STBImage.blend(images: [image1, image2]))
        #expect(blended == expected)

//        try STBImageCoder
//            .exportWebP(from: blended.imageData, quality: 100)
//            .write(to: URL(fileURLWithPath: "/Users/trasch/Desktop/blended.webp"))
    }

    // Blend one RGBA and one RGB image, the latter wins
    // Result will have an alpha channel
    @Test
    func blendingNoAlphaPNG() throws {
        let image1 = try #require(STBImage(url: ImageLoader.url(forResourceNamed: "osm_topo_11_1078_719.png")))
        let image2 = try #require(STBImage(url: ImageLoader.url(forResourceNamed: "avk_11_1078_719.png")))

        var blended = try #require(STBImage.blend(images: [image1, image2]))
        blended.dropAlpha()
        #expect(blended == image2)

//        blended.write(to: URL(fileURLWithPath: "/Users/trasch/Desktop/blended.png"))
    }

    // Blend one RGBA and one RGB image, the latter wins
    // Result will have an alpha channel
    @Test
    func blendingNoAlphaWebP() throws {
        let image1 = try #require(STBImage(url: ImageLoader.url(forResourceNamed: "osm_topo_11_1078_719.webp")))
        let image2 = try #require(STBImage(url: ImageLoader.url(forResourceNamed: "avk_11_1078_719.webp")))

        var blended = try #require(STBImage.blend(images: [image1, image2]))
        blended.dropAlpha()
        #expect(blended == image2)

        //        blended.write(to: URL(fileURLWithPath: "/Users/trasch/Desktop/blended.png"))
    }

    // Draw an RGBA image in top of an RGB image, RGBA image wins
    // ... but the result won't have an alpha channel
    @Test
    func blendingNoAlphaSource2PNG() throws {
        var image1 = try #require(STBImage(url: ImageLoader.url(forResourceNamed: "avk_11_1078_719.png")))
        var image2 = try #require(STBImage(url: ImageLoader.url(forResourceNamed: "osm_topo_11_1078_719.png")))

        image1.blendWith(image2)
        image2.dropAlpha()
        #expect(image1 == image2)

//        image1.write(to: URL(fileURLWithPath: "/Users/trasch/Desktop/blended.png"))
    }

    // Draw an RGBA image in top of an RGB image, RGBA image wins
    // ... but the result won't have an alpha channel
    @Test
    func blendingNoAlphaSource2WebP() throws {
        var image1 = try #require(STBImage(url: ImageLoader.url(forResourceNamed: "avk_11_1078_719.webp")))
        var image2 = try #require(STBImage(url: ImageLoader.url(forResourceNamed: "osm_topo_11_1078_719.webp")))

        image1.blendWith(image2)
        image2.dropAlpha()
        #expect(image1 == image2)

        //        image1.write(to: URL(fileURLWithPath: "/Users/trasch/Desktop/blended.png"))
    }

    @Test
    func loadJpeg() throws {
        let data = try #require(ImageLoader.loadFile(named: "usgs_16_13672_24858.jpeg"))
        let image = try #require(STBImage(data: data))

        #expect(image.width == 256)
        #expect(image.height == 256)
        #expect(image.channels == 3)
        #expect(!image.hasAlpha)
        #expect(image.data.count == 256 * 256 * STBImage.RGB.channels)
        #expect(!image.isTransparent)
    }

}
