import XCTest
@testable import QTube

final class YTDLPServiceTests: XCTestCase {
    func testArgumentsForceProgressAndIgnoreExternalPlugins() {
        let service = YTDLPService()
        let request = DownloadRequest(
            url: URL(string: "https://youtu.be/example")!,
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            mode: .video,
            quality: .p1080,
            browserCookieSource: .none
        )

        let arguments = service.arguments(
            for: request,
            ffmpeg: URL(fileURLWithPath: "/app/Tools/ffmpeg"),
            deno: URL(fileURLWithPath: "/app/Tools/deno")
        )

        XCTAssertTrue(arguments.contains("--progress"))
        XCTAssertTrue(arguments.contains("--no-plugin-dirs"))
        XCTAssertEqual(value(after: "--progress-delta", in: arguments), "0.5")
        XCTAssertEqual(value(after: "--progress-template", in: arguments), "download:[BT_PROGRESS]%(progress)j")
        XCTAssertEqual(value(after: "--js-runtimes", in: arguments), "deno:/app/Tools/deno")
        XCTAssertFalse(arguments.contains("--cookies-from-browser"))
    }

    func testArgumentsPreferQuickJSOverDeno() {
        let service = YTDLPService()
        let request = DownloadRequest(
            url: URL(string: "https://youtu.be/example")!,
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            mode: .video,
            quality: .best,
            browserCookieSource: .none
        )

        let arguments = service.arguments(
            for: request,
            ffmpeg: URL(fileURLWithPath: "/app/Tools/ffmpeg"),
            deno: URL(fileURLWithPath: "/app/Tools/deno"),
            quickjs: URL(fileURLWithPath: "/app/Tools/quickjs")
        )

        XCTAssertEqual(value(after: "--js-runtimes", in: arguments), "quickjs:/app/Tools/quickjs")
    }

    func testArgumentsUseSelectedBrowserCookies() {
        let service = YTDLPService()
        let request = DownloadRequest(
            url: URL(string: "https://youtu.be/example")!,
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            mode: .video,
            quality: .p720,
            browserCookieSource: .chrome
        )

        let arguments = service.arguments(
            for: request,
            ffmpeg: URL(fileURLWithPath: "/app/Tools/ffmpeg"),
            deno: nil
        )

        XCTAssertEqual(value(after: "--cookies-from-browser", in: arguments), "chrome")
    }

    func testArgumentsIncludePlayerClientAndAntiThrottlingOptions() {
        let service = YTDLPService()
        let request = DownloadRequest(
            url: URL(string: "https://youtu.be/example")!,
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            mode: .video,
            quality: .best,
            browserCookieSource: .auto
        )

        let arguments = service.arguments(
            for: request,
            ffmpeg: URL(fileURLWithPath: "/app/Tools/ffmpeg"),
            deno: nil
        )

        XCTAssertEqual(value(after: "--extractor-args", in: arguments), "youtube:player_client=ios,mweb,web")
        XCTAssertEqual(value(after: "--retries", in: arguments), "10")
        XCTAssertEqual(value(after: "--fragment-retries", in: arguments), "10")
        XCTAssertEqual(value(after: "--sleep-requests", in: arguments), "1.0")
        XCTAssertTrue(arguments.contains("--user-agent"))
        XCTAssertFalse(arguments.contains("--cookies-from-browser"))
    }

    func testArgumentsSupportCustomPlayerClientFallback() {
        let service = YTDLPService()
        let request = DownloadRequest(
            url: URL(string: "https://youtu.be/example")!,
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            mode: .audio,
            quality: .best,
            browserCookieSource: .auto
        )

        let arguments = service.arguments(
            for: request,
            ffmpeg: URL(fileURLWithPath: "/app/Tools/ffmpeg"),
            deno: nil,
            playerClients: "mweb,tv_embedded,ios"
        )

        XCTAssertEqual(value(after: "--extractor-args", in: arguments), "youtube:player_client=mweb,tv_embedded,ios")
    }

    func testArgumentsExtractAudioWithCoverArtAndMetadata() {
        let service = YTDLPService()
        let requestMP3 = DownloadRequest(
            url: URL(string: "https://youtu.be/example")!,
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            mode: .audio,
            quality: .best,
            audioFormat: .mp3,
            browserCookieSource: .none
        )

        let argsMP3 = service.arguments(
            for: requestMP3,
            ffmpeg: URL(fileURLWithPath: "/app/Tools/ffmpeg"),
            deno: nil
        )

        XCTAssertTrue(argsMP3.contains("--extract-audio"))
        XCTAssertEqual(value(after: "--audio-format", in: argsMP3), "mp3")
        XCTAssertEqual(value(after: "--audio-quality", in: argsMP3), "0")
        XCTAssertTrue(argsMP3.contains("--embed-thumbnail"))
        XCTAssertTrue(argsMP3.contains("--add-metadata"))

        let requestM4A = DownloadRequest(
            url: URL(string: "https://youtu.be/example")!,
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            mode: .audio,
            quality: .best,
            audioFormat: .m4a,
            browserCookieSource: .none
        )

        let argsM4A = service.arguments(
            for: requestM4A,
            ffmpeg: URL(fileURLWithPath: "/app/Tools/ffmpeg"),
            deno: nil
        )

        XCTAssertEqual(value(after: "--audio-format", in: argsM4A), "m4a")
        XCTAssertTrue(argsM4A.contains("--embed-thumbnail"))
    }

    func testArgumentsIncludeSubtitlesWhenRequested() {
        let service = YTDLPService()
        let requestWithSubs = DownloadRequest(
            url: URL(string: "https://youtu.be/example")!,
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            mode: .video,
            quality: .p1080,
            downloadSubtitles: true,
            browserCookieSource: .none
        )

        let args = service.arguments(
            for: requestWithSubs,
            ffmpeg: URL(fileURLWithPath: "/app/Tools/ffmpeg"),
            deno: nil
        )

        XCTAssertTrue(args.contains("--write-sub"))
        XCTAssertTrue(args.contains("--write-auto-sub"))
        XCTAssertEqual(value(after: "--sub-lang", in: args), "vi,en")
        XCTAssertEqual(value(after: "--convert-subs", in: args), "srt")

        let requestWithoutSubs = DownloadRequest(
            url: URL(string: "https://youtu.be/example")!,
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            mode: .video,
            quality: .p1080,
            downloadSubtitles: false,
            browserCookieSource: .none
        )

        let argsNoSubs = service.arguments(
            for: requestWithoutSubs,
            ffmpeg: URL(fileURLWithPath: "/app/Tools/ffmpeg"),
            deno: nil
        )

        XCTAssertFalse(argsNoSubs.contains("--write-sub"))
        XCTAssertFalse(argsNoSubs.contains("--write-auto-sub"))
    }

    func testArgumentsLimitResolutionFor4KAndFullHD() {
        let service = YTDLPService()

        let request4K = DownloadRequest(
            url: URL(string: "https://youtu.be/example")!,
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            mode: .video,
            quality: .p2160,
            browserCookieSource: .none
        )
        let args4K = service.arguments(
            for: request4K,
            ffmpeg: URL(fileURLWithPath: "/app/Tools/ffmpeg"),
            deno: nil
        )
        XCTAssertEqual(value(after: "--format", in: args4K), "bv*[height<=2160]+ba/b[height<=2160]")

        let request1080 = DownloadRequest(
            url: URL(string: "https://youtu.be/example")!,
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            mode: .video,
            quality: .p1080,
            browserCookieSource: .none
        )
        let args1080 = service.arguments(
            for: request1080,
            ffmpeg: URL(fileURLWithPath: "/app/Tools/ffmpeg"),
            deno: nil
        )
        XCTAssertEqual(value(after: "--format", in: args1080), "bv*[height<=1080]+ba/b[height<=1080]")
    }

    func testArgumentsUseCustomFilenameWhenProvided() {
        let service = YTDLPService()
        let request = DownloadRequest(
            url: URL(string: "https://youtu.be/example")!,
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            mode: .video,
            quality: .p1080,
            customFilename: "01. Bài 1 - Nhập môn",
            browserCookieSource: .none
        )

        let args = service.arguments(
            for: request,
            ffmpeg: URL(fileURLWithPath: "/app/Tools/ffmpeg"),
            deno: nil
        )

        XCTAssertEqual(value(after: "--output", in: args), "01. Bài 1 - Nhập môn [%(id)s].%(ext)s")
    }

    private func value(after option: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: option), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}
