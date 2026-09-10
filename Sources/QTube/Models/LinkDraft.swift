import Foundation

struct LinkDraft: Identifiable, Equatable {
    let id: UUID
    var text: String
    var title: String?
    var thumbnailURL: URL?

    init(id: UUID = UUID(), text: String, title: String? = nil, thumbnailURL: URL? = nil) {
        self.id = id
        self.text = text
        self.title = title
        self.thumbnailURL = thumbnailURL
    }
}
