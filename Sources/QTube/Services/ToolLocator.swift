import Foundation

enum ToolLocator {
    static func ytDLP() -> URL? {
        locate(
            bundledName: "yt-dlp_macos",
            fallbacks: [
                "/opt/homebrew/bin/yt-dlp",
                "/usr/local/bin/yt-dlp"
            ]
        )
    }

    static func ffmpeg() -> URL? {
        locate(
            bundledName: "ffmpeg",
            fallbacks: [
                "/opt/homebrew/bin/ffmpeg",
                "/usr/local/bin/ffmpeg"
            ]
        )
    }

    static func quickjs() -> URL? {
        locate(
            bundledName: "quickjs",
            fallbacks: [
                "/opt/homebrew/bin/qjs",
                "/usr/local/bin/qjs",
                "/opt/homebrew/bin/quickjs",
                "/usr/local/bin/quickjs"
            ]
        )
    }

    static func deno() -> URL? {
        locate(
            bundledName: "deno",
            fallbacks: [
                "/opt/homebrew/bin/deno",
                "/usr/local/bin/deno"
            ]
        )
    }

    private static func locate(bundledName: String, fallbacks: [String]) -> URL? {
        if let resources = Bundle.main.resourceURL {
            let bundled = resources
                .appendingPathComponent("Tools", isDirectory: true)
                .appendingPathComponent(bundledName)
            if FileManager.default.isExecutableFile(atPath: bundled.path) {
                return bundled
            }
        }

        for path in fallbacks where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}
