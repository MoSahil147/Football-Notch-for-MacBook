import XCTest
@testable import FootballNotch

final class CrestCacheTests: XCTestCase {
    func test_image_returnsNilForUnreachableHost_withoutThrowing() async {
        let cache = CrestCache(cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let url = URL(string: "https://invalid.invalid/doesnotexist.png")!
        let image = await cache.image(for: url)
        XCTAssertNil(image)
    }
}
