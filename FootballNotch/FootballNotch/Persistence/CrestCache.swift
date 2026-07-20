import AppKit

actor CrestCache {
    static let shared = CrestCache(cacheDirectory: FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("FootballNotchCrests", isDirectory: true))

    private let cacheDirectory: URL
    private var memoryCache: [URL: NSImage] = [:]

    init(cacheDirectory: URL) {
        self.cacheDirectory = cacheDirectory
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func image(for url: URL) async -> NSImage? {
        if let cached = memoryCache[url] { return cached }

        let diskPath = cacheDirectory.appendingPathComponent(url.lastPathComponent)
        if let diskData = try? Data(contentsOf: diskPath), let image = NSImage(data: diskData) {
            memoryCache[url] = image
            return image
        }

        guard let (data, _) = try? await URLSession.shared.data(from: url), let image = NSImage(data: data) else {
            return nil
        }
        try? data.write(to: diskPath)
        memoryCache[url] = image
        return image
    }
}
