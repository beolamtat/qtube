import Foundation

struct VideoMetadata: Equatable {
    let title: String
    let authorName: String?
    let thumbnailURL: URL?
    let durationSeconds: Int?
}

actor VideoMetadataService {
    static let shared = VideoMetadataService()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 8
        return URLSession(configuration: config)
    }()

    private var cache: [String: VideoMetadata] = [:]

    func fetchMetadata(for url: URL) async -> VideoMetadata? {
        let key = url.absoluteString
        if let cached = cache[key] {
            return cached
        }

        guard let videoID = Self.extractYouTubeID(from: url) else {
            return nil
        }

        let oembedURLString = "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=\(videoID)&format=json"
        guard let oembedURL = URL(string: oembedURLString) else {
            return fallbackMetadata(videoID: videoID, originalURL: url)
        }

        var request = URLRequest(url: oembedURL)
        request.setValue("QTube-macOS", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return fallbackMetadata(videoID: videoID, originalURL: url)
            }

            struct OEmbedResponse: Decodable {
                let title: String
                let author_name: String?
                let thumbnail_url: String?
            }

            let decoded = try JSONDecoder().decode(OEmbedResponse.self, from: data)
            let thumbURL = decoded.thumbnail_url.flatMap { URL(string: $0) }
                ?? URL(string: "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg")

            let meta = VideoMetadata(
                title: decoded.title,
                authorName: decoded.author_name,
                thumbnailURL: thumbURL,
                durationSeconds: nil
            )

            cache[key] = meta
            return meta
        } catch {
            return fallbackMetadata(videoID: videoID, originalURL: url)
        }
    }

    private func fallbackMetadata(videoID: String, originalURL: URL) -> VideoMetadata {
        let thumbURL = URL(string: "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg")
        let meta = VideoMetadata(
            title: originalURL.host ?? "YouTube Video",
            authorName: "YouTube",
            thumbnailURL: thumbURL,
            durationSeconds: nil
        )
        cache[originalURL.absoluteString] = meta
        return meta
    }

    nonisolated static func extractYouTubeID(from url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        let path = url.path

        if host.contains("youtu.be") {
            let id = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return id.isEmpty ? nil : id
        }

        if path.contains("/shorts/") {
            let components = path.components(separatedBy: "/shorts/")
            if let last = components.last?.split(separator: "?").first {
                return String(last).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }
        }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            if let vItem = queryItems.first(where: { $0.name == "v" })?.value, !vItem.isEmpty {
                return vItem
            }
        }

        if path.contains("/embed/") {
            let components = path.components(separatedBy: "/embed/")
            if let last = components.last?.split(separator: "?").first {
                return String(last).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }
        }

        return nil
    }
}
