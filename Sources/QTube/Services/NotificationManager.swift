import Foundation
import UserNotifications
import AppKit

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private var isAvailable: Bool {
        guard let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty else { return false }
        return Bundle.main.bundlePath.hasSuffix(".app")
    }

    override private init() {
        super.init()
        if isAvailable {
            UNUserNotificationCenter.current().delegate = self
        }
    }

    func requestAuthorization() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func sendDownloadCompletedNotification(title: String, filePath: String?) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = "Tải video hoàn tất"
        content.body = title
        content.sound = .default
        if let filePath = filePath {
            content.userInfo = ["filePath": filePath]
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendDownloadFailedNotification(title: String, errorMessage: String) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = "Tải video thất bại"
        content.body = "\(title): \(errorMessage)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let filePath = userInfo["filePath"] as? String {
            let url = URL(fileURLWithPath: filePath)
            if FileManager.default.fileExists(atPath: filePath) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
