import XCTest
@testable import QTube

final class PlaylistTests: XCTestCase {
    func testPlaylistIDDetection() {
        let playlistURL = URL(string: "https://www.youtube.com/playlist?list=PLr6-GrHUlVf_ZD46RQD_Z1Obe74zH8m8b")!
        XCTAssertEqual(LinkExtractor.playlistID(from: playlistURL), "PLr6-GrHUlVf_ZD46RQD_Z1Obe74zH8m8b")
        XCTAssertTrue(LinkExtractor.isPlaylistURL(playlistURL))
        XCTAssertFalse(LinkExtractor.isWatchVideoWithPlaylistURL(playlistURL))

        let watchWithListURL = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLr6-GrHUlVf_ZD46RQD_Z1Obe74zH8m8b&index=3")!
        XCTAssertEqual(LinkExtractor.playlistID(from: watchWithListURL), "PLr6-GrHUlVf_ZD46RQD_Z1Obe74zH8m8b")
        XCTAssertTrue(LinkExtractor.isPlaylistURL(watchWithListURL))
        XCTAssertTrue(LinkExtractor.isWatchVideoWithPlaylistURL(watchWithListURL))

        let clean = LinkExtractor.cleanVideoURL(from: watchWithListURL)
        XCTAssertEqual(clean.absoluteString, "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        XCTAssertFalse(LinkExtractor.isWatchVideoWithPlaylistURL(clean))
        XCTAssertNil(LinkExtractor.playlistID(from: clean))
    }

    func testChannelURLDetection() {
        let channelURL = URL(string: "https://www.youtube.com/@apple")!
        XCTAssertTrue(LinkExtractor.isPlaylistURL(channelURL))

        let customChannelURL = URL(string: "https://www.youtube.com/c/SwiftCommunity")!
        XCTAssertTrue(LinkExtractor.isPlaylistURL(customChannelURL))

        let plainVideo = URL(string: "https://youtu.be/dQw4w9WgXcQ")!
        XCTAssertFalse(LinkExtractor.isPlaylistURL(plainVideo))
    }

    func testFormatDuration() {
        XCTAssertEqual(PlaylistService.formatDuration(45), "00:45")
        XCTAssertEqual(PlaylistService.formatDuration(125), "02:05")
        XCTAssertEqual(PlaylistService.formatDuration(3665), "1:01:05")
    }

    func testPlaylistInfoSelectionHelpers() {
        let entries = [
            PlaylistEntry(id: "1", title: "Video 1", url: URL(string: "https://youtu.be/1")!, isSelected: true),
            PlaylistEntry(id: "2", title: "Video 2", url: URL(string: "https://youtu.be/2")!, isSelected: false),
            PlaylistEntry(id: "3", title: "Video 3", url: URL(string: "https://youtu.be/3")!, isSelected: true)
        ]

        var playlist = PlaylistInfo(
            id: "PL123",
            title: "Khóa học Swift",
            uploader: "Dev Channel",
            webpageURL: URL(string: "https://youtube.com/playlist?list=PL123")!,
            entries: entries
        )

        XCTAssertEqual(playlist.totalCount, 3)
        XCTAssertEqual(playlist.selectedCount, 2)
        XCTAssertFalse(playlist.areAllSelected)

        playlist.entries[1].isSelected = true
        XCTAssertTrue(playlist.areAllSelected)
        XCTAssertEqual(playlist.selectedCount, 3)
    }

    func testSanitizeFilename() {
        let dirty = "Mix - Đen: Mùa hè 26 / Pink Frog (M/V)? *awesome*"
        let clean = DownloadQueueViewModel.sanitizeFilename(dirty)
        XCTAssertFalse(clean.contains("/"))
        XCTAssertFalse(clean.contains(":"))
        XCTAssertFalse(clean.contains("*"))
        XCTAssertFalse(clean.contains("?"))
        XCTAssertTrue(clean.contains("Đen"))
    }

    func testYouTubeMixDetectionAndFiltering() {
        let mixURL = URL(string: "https://www.youtube.com/watch?v=abc&list=RDabc")!
        XCTAssertTrue(LinkExtractor.isYouTubeMixURL(mixURL))
        XCTAssertTrue(LinkExtractor.isYouTubeMix(listID: "RDabc"))
        XCTAssertFalse(LinkExtractor.isYouTubeMix(listID: "PLr6-GrHUlVf_ZD46RQD_Z1Obe74zH8m8b"))

        let entries = [
            PlaylistEntry(id: "1", title: "Dangrangto - Love is", url: URL(string: "https://youtu.be/1")!, author: "Dangrangto", isSelected: true),
            PlaylistEntry(id: "2", title: "Dangrangto - Xương Rồng", url: URL(string: "https://youtu.be/2")!, author: "Dangrangto", isSelected: true),
            PlaylistEntry(id: "3", title: "Không Thời Gian", url: URL(string: "https://youtu.be/3")!, author: "Dương Domic", isSelected: true),
            PlaylistEntry(id: "4", title: "Như Anh Mơ", url: URL(string: "https://youtu.be/4")!, author: "PC FeelingSoundz", isSelected: true)
        ]

        var mixInfo = PlaylistInfo(
            id: "RDabc",
            title: "Mix - Dangrangto",
            uploader: "YouTube",
            webpageURL: mixURL,
            entries: entries
        )

        XCTAssertTrue(mixInfo.isMix)
        XCTAssertEqual(mixInfo.primaryArtist, "Dangrangto")

        // Filter to Dangrangto only
        mixInfo.selectOnly(author: "Dangrangto")
        XCTAssertEqual(mixInfo.selectedCount, 2)
        XCTAssertTrue(mixInfo.entries[0].isSelected)
        XCTAssertTrue(mixInfo.entries[1].isSelected)
        XCTAssertFalse(mixInfo.entries[2].isSelected)
        XCTAssertFalse(mixInfo.entries[3].isSelected)
    }
}
