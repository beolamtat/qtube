import Foundation
import AppKit

final class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()

    private let userDefaultsKey = "qtube.clipboard_monitor_enabled"
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: userDefaultsKey)
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var lastDetectedURL: String? = nil

    var onURLDetected: ((URL) -> Void)?

    init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: userDefaultsKey)
        self.lastChangeCount = NSPasteboard.general.changeCount
        if self.isEnabled {
            startMonitoring()
        }
    }

    func startMonitoring() {
        stopMonitoring()
        lastChangeCount = NSPasteboard.general.changeCount
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func checkClipboard() {
        let currentChangeCount = NSPasteboard.general.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        guard let text = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }

        let extracted = LinkExtractor.youtubeURLs(from: text)
        guard let first = extracted.first else { return }

        let urlString = first.absoluteString
        guard urlString != lastDetectedURL else { return }
        lastDetectedURL = urlString

        DispatchQueue.main.async { [weak self] in
            self?.onURLDetected?(first)
        }
    }
}
