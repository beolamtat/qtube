import SwiftUI

struct UpdateDialogView: View {
    let release: AppUpdateInfo
    @ObservedObject var updater: UpdateChecker

    var body: some View {
        VStack(spacing: 16) {
            header
            Divider()
            if updater.isReadyToRelaunch {
                readyToRelaunchNotice
            }
            changelogSection
            if updater.isDownloading {
                downloadProgressSection
            }
            if let error = updater.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                }
            }
            Divider()
            footerActions
        }
        .padding(24)
        .frame(width: 520, height: updater.isReadyToRelaunch ? 460 : 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 14) {
            if updater.isReadyToRelaunch {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(updater.isReadyToRelaunch ? "Cập nhật đã sẵn sàng!" : "Đã có bản cập nhật mới!")
                    .font(.title3.weight(.bold))
                HStack(spacing: 6) {
                    Text(release.displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("(Hiện tại: v\(updater.currentVersion))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private var readyToRelaunchNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Đã tải xong bản cập nhật")
                    .font(.callout.weight(.semibold))
                Text("Nhấn \"Khởi động lại ngay\" để ứng dụng tự động áp dụng bản mới và mở lại.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.3)))
    }

    private var changelogSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Nội dung cập nhật:", systemImage: "doc.text")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)

            ScrollView {
                Text(releaseNotesText)
                    .font(.body)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
        }
    }

    private var releaseNotesText: String {
        let raw = release.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "Bản cập nhật tối ưu hiệu năng và cải thiện độ ổn định." : raw
    }

    private var downloadProgressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(updater.statusMessage ?? "Đang tải…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(updater.downloadProgress, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit().weight(.semibold))
            }
            ProgressView(value: updater.downloadProgress)
            if updater.totalBytes > 0 {
                HStack {
                    Text("\(formatBytes(updater.downloadedBytes)) / \(formatBytes(updater.totalBytes))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var footerActions: some View {
        HStack {
            if updater.isDownloading {
                Button("Hủy tải") {
                    updater.cancelDownload()
                }
                Spacer()
            } else if updater.isReadyToRelaunch {
                Button("Để sau") {
                    updater.dismissUntilNextLaunch()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    updater.applyUpdateAndRelaunch()
                } label: {
                    Label("Khởi động lại ngay", systemImage: "arrow.clockwise.circle.fill")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Để sau") {
                    updater.dismissUntilNextLaunch()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    updater.startDownload(for: release)
                } label: {
                    Label("Cập nhật ngay", systemImage: "arrow.down.circle.fill")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(bytes, 0), countStyle: .file)
    }
}
