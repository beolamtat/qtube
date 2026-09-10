import XCTest
@testable import QTube

final class ProgressAccumulatorTests: XCTestCase {
    func testAggregatesVideoAndAudioAgainstMetadataTotal() {
        let accumulator = ProgressAccumulator()
        let metadata = """
        [
          {"filesize": 400000000, "filesize_approx": 399000000},
          {"filesize": 25000000, "filesize_approx": 24000000}
        ]
        """
        XCTAssertEqual(accumulator.consumeMetadataJSON(metadata), 425_000_000)

        let video = """
        {"filename":"video.f399.mp4","downloaded_bytes":200000000,
         "total_bytes":400000000,"speed":5000000,"eta":40,"_percent":50}
        """
        let first = accumulator.consumeProgressJSON(video)
        XCTAssertEqual(first?.downloadedBytes, 200_000_000)
        XCTAssertEqual(first?.totalBytes, 425_000_000)
        XCTAssertEqual(first?.fraction ?? 0, 200.0 / 425.0, accuracy: 0.0001)
        XCTAssertEqual(first?.etaSeconds, 45)

        let audio = """
        {"filename":"audio.f251.webm","downloaded_bytes":5000000,
         "total_bytes":25000000,"speed":2500000,"eta":8,"_percent":20}
        """
        let second = accumulator.consumeProgressJSON(audio)
        XCTAssertEqual(second?.downloadedBytes, 205_000_000)
        XCTAssertEqual(second?.totalBytes, 425_000_000)
        XCTAssertEqual(second?.fraction ?? 0, 205.0 / 425.0, accuracy: 0.0001)
    }

    func testFallsBackToReportedPercentWhenTotalIsUnknown() {
        let accumulator = ProgressAccumulator()
        let progress = """
        {"filename":"stream","downloaded_bytes":1024,"speed":null,
         "eta":null,"_percent":12.5}
        """

        let snapshot = accumulator.consumeProgressJSON(progress)

        XCTAssertEqual(snapshot?.fraction, 0.125)
        XCTAssertNil(snapshot?.totalBytes)
        XCTAssertNil(snapshot?.etaSeconds)
    }

    func testRejectsMalformedJSON() {
        let accumulator = ProgressAccumulator()
        XCTAssertNil(accumulator.consumeMetadataJSON("not-json"))
        XCTAssertNil(accumulator.consumeProgressJSON("not-json"))
    }
}
