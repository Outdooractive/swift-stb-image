import Foundation

struct ImageLoader {

    static func loadFile(named name: String) -> Data? {
        try? Data(contentsOf: url(forResourceNamed: name))
    }

    static func url(forResourceNamed name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Images")
            .appendingPathComponent(name)
    }

}
