import SwiftUI

struct PlaylistLoadingView: View {
    @ObservedObject var queue: DownloadQueueViewModel
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: "list.bullet.rectangle.portrait.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(queue.inspectingPlaylistTitle ?? "Đang phân tích Danh sách phát…")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)

                    if let uploader = queue.inspectingPlaylistUploader, !uploader.isEmpty {
                        Text(uploader)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Đang kết nối tới YouTube…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            VStack(spacing: 8) {
                if let total = queue.inspectingTotalCount, total > 0 {
                    ProgressView(value: queue.inspectingProgressFraction)
                        .progressViewStyle(.linear)

                    HStack {
                        Text("Đã nạp \(queue.inspectingCurrentIndex) / \(total) video")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(queue.inspectingProgressFraction, format: .percent.precision(.fractionLength(0)))
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(.blue)
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)

                    HStack {
                        if queue.inspectingCurrentIndex > 0 {
                            Text("Đã nạp \(queue.inspectingCurrentIndex) video…")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Đang quét danh sách video…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                if let currentTitle = queue.inspectingCurrentVideoTitle, !currentTitle.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(currentTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.12), lineWidth: 1))

            HStack {
                Spacer()
                Button("Hủy", action: onCancel)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            }
        }
        .padding(22)
        .frame(width: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
