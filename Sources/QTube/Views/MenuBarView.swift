import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var queue: DownloadQueueViewModel
    @EnvironmentObject private var updater: UpdateChecker
    @ObservedObject private var clipboardMonitor = ClipboardMonitor.shared

    @State private var quickURL: String = ""

    private var activeItems: [DownloadItem] {
        queue.items.filter { $0.status.isActive || $0.status == .waiting }
    }

    private var recentCompletedItems: [DownloadItem] {
        Array(queue.items.filter { $0.status == .completed }.suffix(3).reversed())
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            quickDownloadInput
            Divider()
            contentList
            Divider()
            footerSettings
        }
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("QTube")
                    .font(.headline.weight(.semibold))

                if queue.activeCount > 0 {
                    Text("Đang tải \(queue.activeCount) video…")
                        .font(.caption)
                        .foregroundStyle(.blue)
                } else {
                    Text("Sẵn sàng tải")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                openMainWindow()
            } label: {
                Label("Mở app", systemImage: "macwindow")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Mở cửa sổ chính của QTube")

            Button {
                queue.openDownloadsFolder()
            } label: {
                Image(systemName: "folder")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Mở thư mục tải về trong Finder")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var quickDownloadInput: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Dán link YouTube để tải nhanh…", text: $quickURL)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .onSubmit {
                        submitQuickDownload()
                    }
                if !quickURL.isEmpty {
                    Button {
                        quickURL = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.18)))

            Button("Tải ngay") {
                submitQuickDownload()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(quickURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
    }

    private var contentList: some View {
        ScrollView {
            VStack(spacing: 8) {
                if activeItems.isEmpty && recentCompletedItems.isEmpty {
                    emptyStateView
                } else {
                    if !activeItems.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ĐANG TẢI (\(activeItems.count))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.top, 8)

                            ForEach(activeItems) { item in
                                activeItemRow(item)
                            }
                        }
                    }

                    if !recentCompletedItems.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ĐÃ TẢI XONG GẦN ĐÂY")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.top, 6)

                            ForEach(recentCompletedItems) { item in
                                completedItemRow(item)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .frame(maxHeight: 260)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
                .padding(.top, 20)

            Text("Hàng đợi trống")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Dán link YouTube ở trên hoặc copy trên trình duyệt để bắt đầu tải.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
    }

    private func activeItemRow(_ item: DownloadItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(item.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                Spacer()

                Button {
                    queue.cancel(itemID: item.id)
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Hủy tải video này")
            }

            ProgressView(value: max(item.progress, 0.02))
                .progressViewStyle(.linear)

            HStack {
                Text("\(Int(item.progress * 100))%")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)

                if let speed = item.formattedSpeed {
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(speed)
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if let eta = item.formattedETA {
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(eta)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 10)
    }

    private func completedItemRow(_ item: DownloadItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)

            Text(item.title)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            if let path = item.outputPath {
                Button("Mở file") {
                    let url = URL(fileURLWithPath: path)
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("Xem file trong Finder")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }

    private var footerSettings: some View {
        VStack(spacing: 8) {
            HStack {
                Toggle(isOn: $clipboardMonitor.isEnabled) {
                    Label("Tự động nhận link khi Copy", systemImage: "doc.on.clipboard")
                        .font(.caption)
                }
                .toggleStyle(.checkbox)
                .help("Tự động thêm vào danh sách tải khi bạn copy link YouTube trên trình duyệt")

                Spacer()
            }

            Divider()

            HStack {
                if queue.hasResumableItems {
                    Button("Tiếp tục tải") {
                        queue.resumeAll()
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                } else if queue.hasPendingOrActiveItems {
                    Button("Tạm dừng tất cả") {
                        queue.pauseAll()
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }

                Spacer()

                Button("Thoát QTube") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private func submitQuickDownload() {
        let trimmed = quickURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        queue.quickDownload(urlString: trimmed)
        quickURL = ""
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Reopen window if closed
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}
