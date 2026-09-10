import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dismiss any lingering NSPanel / popover left over from previous runs
        for window in NSApp.windows where window is NSPanel {
            window.close()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep the app running in the background & Menu Bar when user closes the window
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where !(window is NSPanel) {
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }
                window.makeKeyAndOrderFront(nil)
                return true
            }
        }
        return true
    }
}

@main
struct QTubeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var downloadQueue = DownloadQueueViewModel()
    @StateObject private var updater = UpdateChecker()
    @Environment(\.openWindow) private var openWindow

    private static let menuBarAppIcon: NSImage = {
        let size = NSSize(width: 18, height: 18)
        var iconPaths: [String] = []
        if let bundlePath = Bundle.main.url(forResource: "AppIcon", withExtension: "png")?.path {
            iconPaths.append(bundlePath)
        }
        iconPaths.append(Bundle.main.bundlePath + "/Contents/Resources/AppIcon.png")
        iconPaths.append(FileManager.default.currentDirectoryPath + "/Resources/AppIcon.png")
        if let menuPath = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png")?.path {
            iconPaths.append(menuPath)
        }
        iconPaths.append(Bundle.main.bundlePath + "/Contents/Resources/MenuBarIcon.png")
        iconPaths.append(FileManager.default.currentDirectoryPath + "/Resources/MenuBarIcon.png")

        for path in iconPaths {
            if let baseImage = NSImage(contentsOfFile: path) {
                let scaled = NSImage(size: size, flipped: false) { rect in
                    NSGraphicsContext.current?.imageInterpolation = .high
                    baseImage.draw(in: rect, from: NSRect(origin: .zero, size: baseImage.size), operation: .sourceOver, fraction: 1.0)
                    return true
                }
                scaled.isTemplate = false // Keep vivid app logo colors
                return scaled
            }
        }

        if let appIcon = NSApp.applicationIconImage {
            let scaled = NSImage(size: size, flipped: false) { rect in
                NSGraphicsContext.current?.imageInterpolation = .high
                appIcon.draw(in: rect, from: NSRect(origin: .zero, size: appIcon.size), operation: .sourceOver, fraction: 1.0)
                return true
            }
            scaled.isTemplate = false
            return scaled
        }

        let fallback = NSImage(systemSymbolName: "play.rectangle.fill", accessibilityDescription: "QTube") ?? NSImage()
        fallback.size = size
        return fallback
    }()

    private func activateAndOpen() {
        for window in NSApp.windows where window is NSPanel {
            window.close()
        }
        NSApp.activate(ignoringOtherApps: true)
        if let existing = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeKey }) {
            if existing.isMiniaturized {
                existing.deminiaturize(nil)
            }
            existing.makeKeyAndOrderFront(nil)
            existing.orderFrontRegardless()
            return
        }
        openWindow(id: "main")
    }

    var body: some Scene {
        Window("QTube", id: "main") {
            ContentView()
                .environmentObject(downloadQueue)
                .environmentObject(updater)
                .frame(minWidth: 900, minHeight: 640)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .appInfo) {
                Button("Kiểm tra cập nhật…") {
                    updater.checkForUpdatesManually()
                }
                .keyboardShortcut("u", modifiers: [.command])
            }
        }

        MenuBarExtra {
            let activeItems = downloadQueue.items.filter { $0.status.isActive }
            let waitingItems = downloadQueue.items.filter { $0.status == .waiting }
            let total = activeItems.count + waitingItems.count

            if total == 0 {
                Text("✓ Không có video nào đang tải")
            } else {
                Text("Đang xử lý \(total) video:")
                    .font(.caption)

                ForEach(activeItems) { item in
                    let name = item.title.isEmpty ? "Video YouTube" : (item.title.count > 32 ? String(item.title.prefix(30)) + "…" : item.title)
                    let pct = Int(item.progress * 100)
                    Button {
                        activateAndOpen()
                    } label: {
                        Text("⚡ \(name) (\(pct)%)")
                    }
                }

                ForEach(waitingItems.prefix(3)) { item in
                    let name = item.title.isEmpty ? "Video YouTube" : (item.title.count > 32 ? String(item.title.prefix(30)) + "…" : item.title)
                    Button {
                        activateAndOpen()
                    } label: {
                        Text("⏳ \(name) (Chờ)")
                    }
                }
            }

            Divider()

            Button("Mở QTube") {
                activateAndOpen()
            }
            .keyboardShortcut("o")

            Button("Mở thư mục tải về") {
                downloadQueue.openDownloadsFolder()
            }

            Divider()

            Button("Thoát QTube") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            let active = downloadQueue.activeCount
            let waiting = downloadQueue.items.filter { $0.status == .waiting }.count
            let total = active + waiting

            HStack(spacing: 3) {
                Image(nsImage: Self.menuBarAppIcon)
                if total > 0 {
                    Text("\(total)")
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                }
            }
        }
    }
}
