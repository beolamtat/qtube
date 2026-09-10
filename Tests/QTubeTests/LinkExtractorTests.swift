import XCTest
@testable import QTube

final class LinkExtractorTests: XCTestCase {
    func testExtractsMultipleSupportedLinksFromMixedText() {
        let input = """
        Video đầu: https://www.youtube.com/watch?v=abc123
        và https://youtu.be/xyz789?t=12
        """

        let urls = LinkExtractor.youtubeURLs(from: input)

        XCTAssertEqual(urls.map(\.absoluteString), [
            "https://www.youtube.com/watch?v=abc123",
            "https://youtu.be/xyz789?t=12"
        ])
    }

    func testRemovesExactDuplicatesWhileKeepingOrder() {
        let input = """
        https://youtu.be/abc123
        https://youtu.be/abc123
        https://youtube.com/watch?v=other
        """

        let urls = LinkExtractor.youtubeURLs(from: input)

        XCTAssertEqual(urls.map(\.absoluteString), [
            "https://youtu.be/abc123",
            "https://youtube.com/watch?v=other"
        ])
    }

    func testRejectsLookalikeAndNonHTTPLinks() {
        let input = """
        https://youtube.com.example.org/watch?v=bad
        ftp://youtube.com/watch?v=bad
        https://example.com/?next=https://youtube.com/watch?v=hidden
        """

        XCTAssertTrue(LinkExtractor.youtubeURLs(from: input).isEmpty)
    }

    func testValidatesAnEditableTagAsOneCompleteURL() {
        XCTAssertEqual(
            LinkExtractor.youtubeURL(from: "  https://www.youtube.com/watch?v=abc123  ")?.absoluteString,
            "https://www.youtube.com/watch?v=abc123"
        )
        XCTAssertNil(LinkExtractor.youtubeURL(from: "xem https://youtu.be/abc123"))
        XCTAssertNil(LinkExtractor.youtubeURL(from: "https://youtube.com.example.org/watch?v=bad"))
    }
}
