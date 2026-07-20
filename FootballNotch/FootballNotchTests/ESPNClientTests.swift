import XCTest
@testable import FootballNotch

final class MockURLProtocol: URLProtocol {
    static var responseData: Data = Data()
    static var statusCode: Int = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class ESPNClientTests: XCTestCase {
    func test_fetchMatches_decodesEmptyEventsWithoutThrowing() async throws {
        MockURLProtocol.responseData = #"{"events":[]}"#.data(using: .utf8)!
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = ESPNClient(session: URLSession(configuration: config))

        let matches = try await client.fetchMatches(competitionSlug: "eng.1", competitionName: "Premier League")
        XCTAssertEqual(matches, [])
    }
}
