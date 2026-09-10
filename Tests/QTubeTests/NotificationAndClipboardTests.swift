import XCTest
@testable import QTube

final class NotificationAndClipboardTests: XCTestCase {
    func testClipboardMonitorToggle() {
        let monitor = ClipboardMonitor.shared
        let originalState = monitor.isEnabled

        monitor.isEnabled = true
        XCTAssertTrue(monitor.isEnabled)

        monitor.isEnabled = false
        XCTAssertFalse(monitor.isEnabled)

        // Restore original state
        monitor.isEnabled = originalState
    }

    func testNotificationManagerSingleton() {
        let manager = NotificationManager.shared
        XCTAssertNotNil(manager)
        // Ensure calling notification methods doesn't crash
        manager.sendDownloadCompletedNotification(title: "Test Video", filePath: nil)
        manager.sendDownloadFailedNotification(title: "Test Video", errorMessage: "Error description")
    }

    @MainActor
    func testQuickDownloadDraftCreation() {
        let queue = DownloadQueueViewModel()
        XCTAssertEqual(queue.items.count, 0)

        queue.quickDownload(urlString: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        XCTAssertEqual(queue.items.count, 1)
        XCTAssertEqual(queue.items.first?.url.absoluteString, "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        if let id = queue.items.first?.id {
            queue.cancel(itemID: id)
        }
    }
}
