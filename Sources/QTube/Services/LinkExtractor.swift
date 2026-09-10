import Foundation

enum LinkExtractor {
    private static let acceptedHosts = [
        "youtube.com",
        "www.youtube.com",
        "m.youtube.com",
        "music.youtube.com",
        "youtu.be"
    ]

    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func youtubeURLs(from text: String) -> [URL] {
        guard !text.isEmpty else { return [] }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = detector?.matches(in: text, options: [], range: range) ?? []
        var seen = Set<String>()

        return matches.compactMap { match in
            guard let url = match.url, isYouTubeURL(url) else { return nil }

            let normalized = url.absoluteString
            guard seen.insert(normalized).inserted else { return nil }
            return url
        }
    }

    static func youtubeURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains(where: { $0.isWhitespace }),
              let url = URL(string: trimmed),
              isYouTubeURL(url)
        else { return nil }
        return url
    }

    static func playlistID(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return nil }
        guard let item = queryItems.first(where: { $0.name.lowercased() == "list" }),
              let value = item.value, !value.isEmpty else { return nil }
        return value
    }

    static func isPlaylistURL(_ url: URL) -> Bool {
        guard isYouTubeURL(url) else { return false }
        if playlistID(from: url) != nil {
            return true
        }
        let path = url.path.lowercased()
        return path.hasPrefix("/@") || path.hasPrefix("/channel/") || path.hasPrefix("/c/") || path.hasPrefix("/user/")
    }

    static func isYouTubeMix(listID: String) -> Bool {
        listID.hasPrefix("RD") || listID.hasPrefix("UL") || listID.hasPrefix("PU")
    }

    static func isYouTubeMixURL(_ url: URL) -> Bool {
        guard let listID = playlistID(from: url) else { return false }
        return isYouTubeMix(listID: listID)
    }

    static func isWatchVideoWithPlaylistURL(_ url: URL) -> Bool {
        guard isYouTubeURL(url), let listID = playlistID(from: url), !listID.isEmpty else { return false }
        let path = url.path.lowercased()
        return path.contains("/watch") || url.host?.lowercased() == "youtu.be"
    }

    static func cleanVideoURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.queryItems = components.queryItems?.filter { item in
            let name = item.name.lowercased()
            return name != "list" && name != "index" && name != "start_radio"
        }
        return components.url ?? url
    }

    static func playlistURL(from listID: String) -> URL? {
        URL(string: "https://www.youtube.com/playlist?list=\(listID)")
    }

    private static func isYouTubeURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host?.lowercased()
        else { return false }

        return acceptedHosts.contains(host) || host.hasSuffix(".youtube.com")
    }
}
