import Foundation

struct PlaylistEntry: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    var title: String
    let url: URL
    let durationSeconds: Double?
    let durationText: String?
    let thumbnailURL: URL?
    let author: String?
    var isSelected: Bool

    init(
        id: String,
        title: String,
        url: URL,
        durationSeconds: Double? = nil,
        durationText: String? = nil,
        thumbnailURL: URL? = nil,
        author: String? = nil,
        isSelected: Bool = true
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.durationSeconds = durationSeconds
        self.durationText = durationText
        self.thumbnailURL = thumbnailURL
        self.author = author
        self.isSelected = isSelected
    }
}

struct PlaylistInfo: Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    var uploader: String?
    let webpageURL: URL
    var entries: [PlaylistEntry]

    var selectedCount: Int {
        entries.filter(\.isSelected).count
    }

    var totalCount: Int {
        entries.count
    }

    var areAllSelected: Bool {
        !entries.isEmpty && entries.allSatisfy(\.isSelected)
    }

    var isMix: Bool {
        id.hasPrefix("RD") || id.hasPrefix("UL") || id.hasPrefix("PU") || title.hasPrefix("Mix - ") || title.hasPrefix("Danh sách kết hợp - ")
    }

    var primaryArtist: String? {
        if title.hasPrefix("Mix - ") {
            let artist = String(title.dropFirst("Mix - ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !artist.isEmpty { return artist }
        }
        if title.hasPrefix("Danh sách kết hợp - ") {
            let artist = String(title.dropFirst("Danh sách kết hợp - ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !artist.isEmpty { return artist }
        }
        if let uploader, !uploader.isEmpty {
            return uploader
        }
        return entries.first?.author
    }

    mutating func selectOnly(author artist: String) {
        let needle = artist.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return }
        for i in entries.indices {
            let matchesAuthor = entries[i].author?.lowercased().contains(needle) == true
            let matchesTitle = entries[i].title.lowercased().contains(needle)
            entries[i].isSelected = matchesAuthor || matchesTitle
        }
    }
}
