import Foundation

struct ReleaseAsset: Decodable, Equatable {
    let name: String
    let browserDownloadURL: URL
    let size: Int64

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
    }
}

struct AppUpdateInfo: Identifiable, Decodable, Equatable {
    let id: Int
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let assets: [ReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case assets
    }

    var cleanVersion: String {
        var v = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.lowercased().hasPrefix("v") {
            v.removeFirst()
        }
        return v
    }

    var displayTitle: String {
        name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? name! : "QTube \(tagName)"
    }

    func assetForCurrentArchitecture() -> ReleaseAsset? {
        #if arch(arm64)
        let keywords = ["applesilicon", "arm64", "m1"]
        #else
        let keywords = ["intel", "x86_64"]
        #endif

        for asset in assets {
            let lower = asset.name.lowercased()
            if lower.hasSuffix(".dmg") && keywords.contains(where: { lower.contains($0) }) {
                return asset
            }
        }
        return assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }) ?? assets.first
    }
}
