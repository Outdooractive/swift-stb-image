import Foundation
@testable import STBImage
import Testing

struct StressMemoryTests {

    /// Repeated encode/decode cycles to surface memory leaks in the
    /// WebP encoder/decoder and PNG export paths.
    @Test
    func repeatedCyclesDoNotGrowMemory() throws {
        let fileData = try #require(ImageLoader.loadFile(named: "osm_topo_11_1077_720.png"))
        let base = try #require(STBImage(data: fileData))

        func currentRSSKB() -> Int {
            #if os(Linux)
            // /proc/self/statm: size resident shared text data library dt
            if let statm = try? String(contentsOfFile: "/proc/self/statm", encoding: .utf8) {
                let fields = statm.split(separator: " ")
                if fields.count >= 2, let pages = Int(fields[1]) {
                    return pages * 4096 / 1024
                }
            }
            return 0
            #elseif canImport(Darwin)
            var info = task_basic_info_data_t()
            var count = mach_msg_type_number_t(MemoryLayout<task_basic_info_data_t>.size) / 4
            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), $0, &count)
                }
            }
            return result == KERN_SUCCESS ? Int(info.resident_size) / 1024 : 0
            #else
            return 0
            #endif
        }

        func loadAndExport(_ image: STBImage) {
            #if EnableWebP
            let webp = try? image.export(.webp(quality: 85))
            let png = try? image.export(.png)
            _ = webp.flatMap { STBImage(data: $0) }
            _ = png.flatMap { STBImage(data: $0) }
            #else
            let png = try? image.export(.png)
            _ = png.flatMap { STBImage(data: $0) }
            #endif
        }

        // Warm up allocators
        for _ in 0 ..< 20 {
            loadAndExport(base)
        }

        let rssBefore = currentRSSKB()

        for _ in 0 ..< 100 {
            var image = base
            loadAndExport(image)
            image.blendWith(base)
            image.dropAlpha()
            loadAndExport(image)
        }

        let rssAfter = currentRSSKB()
        let growthKB = rssAfter - rssBefore
        print("RSS before: \(rssBefore) KB, after: \(rssAfter) KB, growth: \(growthKB) KB")

        // Skip the threshold when the platform can not report RSS
        guard rssBefore > 0, rssAfter > 0 else { return }

        // Tolerate allocator noise, but a systematic leak of the
        // 256x256x4 buffers (256 KB each) would show up as multiple MB
        #expect(growthKB < 4096, "Memory grew by \(growthKB) KB over the stress cycles")
    }

}
