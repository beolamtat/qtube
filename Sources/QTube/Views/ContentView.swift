import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var queue: DownloadQueueViewModel
    @EnvironmentObject private var updater: UpdateChecker
    @State private var previousLinkInputText = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            if let update = updater.updateAvailable, !updater.hasDismissedBanner {
                updateBanner(for: update)
            }
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    linkInput
                    settings
                    queueSection
                }
                .padding(20)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await updater.checkForUpdates(isManual: false)
        }
        .sheet(isPresented: $updater.showUpdateDialog) {
            if let release = updater.updateAvailable {
                UpdateDialogView(release: release, updater: updater)
            }
        }
        .sheet(item: $queue.activePlaylist) { playlist in
            PlaylistInspectorView(
                playlist: Binding(
                    get: { queue.activePlaylist ?? playlist },
                    set: { queue.activePlaylist = $0 }
                ),
                queue: queue,
                baseDirectory: queue.outputDirectory,
                onConfirm: { numberFiles, targetDir in
                    queue.importSelectedPlaylist(numberFiles: numberFiles, targetDirectory: targetDir)
                },
                onCancel: {
                    queue.cancelPlaylistInspection()
                    queue.activePlaylist = nil
                }
            )
        }
        .confirmationDialog(
            queue.isPromptingMix ? "Phát hiện YouTube Mix (Danh sách gợi ý tự động)" : "Phát hiện Danh sách phát (Playlist)",
            isPresented: Binding(
                get: { queue.playlistPromptURL != nil },
                set: { if !$0 { queue.playlistPromptURL = nil } }
            ),
            titleVisibility: .visible
        ) {
            if queue.isPromptingMix {
                Button("Chỉ tải video này (Khuyên dùng)") {
                    queue.declinePlaylistPromptToSingleVideo()
                }
                Button("Xem & Tải toàn bộ danh sách Mix (~80 bài)") {
                    queue.acceptPlaylistPrompt()
                }
            } else {
                Button("Xem & Tải trọn bộ Playlist") {
                    queue.acceptPlaylistPrompt()
                }
                Button("Chỉ tải video này") {
                    queue.declinePlaylistPromptToSingleVideo()
                }
            }
            Button("Hủy", role: .cancel) {
                queue.cancelPlaylistPrompt()
            }
        } message: {
            if queue.isPromptingMix {
                Text("Đường dẫn này đi kèm một đài phát YouTube Mix (tự động gợi ý thêm hàng chục bài hát của các ca sĩ liên quan). Bạn nên chọn chỉ tải video này, hoặc mở toàn bộ để tự chọn.")
            } else {
                Text("Đường dẫn này nằm trong một danh sách phát. Bạn muốn tải toàn bộ danh sách phát hay chỉ tải video này?")
            }
        }
        .alert(updater.infoAlertMessage ?? "", isPresented: Binding(
            get: { updater.infoAlertMessage != nil },
            set: { if !$0 { updater.infoAlertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        }
        .alert("Thông báo cập nhật", isPresented: Binding(
            get: { updater.errorMessage != nil && !updater.showUpdateDialog },
            set: { if !$0 { updater.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(updater.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 30))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("QTube")
                    .font(.title2.weight(.semibold))
                Text("Tải Video, Playlist & Âm thanh YouTube chất lượng cao")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let update = updater.updateAvailable {
                Button {
                    updater.showUpdateDialog = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                        Text("Có bản mới \(update.tagName)")
                            .fontWeight(.semibold)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue, in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Bấm để xem nội dung cập nhật và cài đặt")
            } else {
                Text("v\(appVersion)")
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.1), in: Capsule())
            }
            if queue.hasPendingOrActiveItems {
                ProgressView()
                    .controlSize(.small)
                Text("Đang chạy \(queue.activeCount)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func updateBanner(for update: AppUpdateInfo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: updater.isReadyToRelaunch ? "checkmark.circle.fill" : "sparkles")
                .foregroundStyle(updater.isReadyToRelaunch ? .green : .blue)
                .font(.headline)
            VStack(alignment: .leading, spacing: 2) {
                Text(updater.isReadyToRelaunch ? "Bản cập nhật \(update.displayTitle) đã sẵn sàng!" : "Đã có phiên bản mới: \(update.displayTitle)")
                    .font(.callout.weight(.semibold))
                Text(updater.isReadyToRelaunch ? "Khởi động lại ngay để hoàn tất cài đặt bản mới." : (update.body?.components(separatedBy: .newlines).first ?? "Bản cập nhật tối ưu hiệu năng và sửa lỗi."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()

            if updater.isReadyToRelaunch {
                Button("Khởi động lại ngay") {
                    updater.applyUpdateAndRelaunch()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)
            } else {
                Button("Xem nội dung & Cập nhật") {
                    updater.showUpdateDialog = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Button {
                updater.hasDismissedBanner = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Đóng thông báo")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background((updater.isReadyToRelaunch ? Color.green : Color.blue).opacity(0.08))
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Dev"
    }

    private var linkInput: some View {
        GroupBox {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    TextField("Dán link Video, Playlist hoặc Kênh YouTube…", text: $queue.linkInputText)
                        .textFieldStyle(.plain)
                        .font(.body.monospaced())
                        .onSubmit { queue.addCurrentInput() }
                        .onChange(of: queue.linkInputText) { newValue in
                            handleLinkInputChange(newValue)
                        }

                    Button("Thêm") { queue.addCurrentInput() }
                        .disabled(queue.linkInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        queue.pasteLinks()
                    } label: {
                        Label("Dán từ clipboard", systemImage: "doc.on.clipboard")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.2)))

                if queue.linkDrafts.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "link.badge.plus")
                            .foregroundStyle(.secondary)
                        Text("Hỗ trợ tải video đơn, hàng loạt, trọn bộ Playlist hoặc toàn bộ Kênh.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(minHeight: 42)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 7) {
                            ForEach($queue.linkDrafts) { $draft in
                                LinkTagRow(
                                    draft: $draft,
                                    isValid: queue.url(for: draft) != nil,
                                    isDuplicate: queue.isDuplicate(draft),
                                    onRemove: { queue.removeLinkDraft(id: draft.id) }
                                )
                            }
                        }
                        .padding(.vertical, 1)
                    }
                    .frame(maxHeight: 170)
                }

                HStack {
                    Label("Tìm thấy \(queue.detectedLinkCount) link hợp lệ", systemImage: "link")
                        .font(.callout)
                        .foregroundStyle(queue.detectedLinkCount > 0 ? Color.green : Color.secondary)
                    Spacer()
                    Button("Xóa tất cả") { queue.removeAllLinkDrafts() }
                        .disabled(queue.linkDrafts.isEmpty && queue.linkInputText.isEmpty)
                }
            }
            .padding(8)
        } label: {
            Text("Danh sách link")
                .font(.headline)
        }
    }

    private func handleLinkInputChange(_ newValue: String) {
        let previousValue = previousLinkInputText
        previousLinkInputText = newValue

        let insertedCharacterCount = newValue.count - previousValue.count
        guard insertedCharacterCount > 1,
              !LinkExtractor.youtubeURLs(from: newValue).isEmpty
        else { return }

        queue.addCurrentInput()
        previousLinkInputText = ""
    }

    private var settings: some View {
        GroupBox {
            VStack(spacing: 14) {
                HStack(spacing: 16) {
                    Picker("", selection: $queue.selectedMode) {
                        Label("Video (MP4)", systemImage: "film").tag(DownloadMode.video)
                        Label("Chỉ âm thanh", systemImage: "music.note").tag(DownloadMode.audio)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                    .disabled(queue.hasPendingOrActiveItems)

                    if queue.selectedMode == .video {
                        Picker("Độ phân giải:", selection: $queue.selectedQuality) {
                            ForEach(VideoQuality.allCases) { quality in
                                Text(quality.rawValue).tag(quality)
                            }
                        }
                        .frame(maxWidth: 240)
                        .disabled(queue.hasPendingOrActiveItems)

                        Toggle(isOn: $queue.downloadSubtitles) {
                            HStack(spacing: 4) {
                                Image(systemName: "captions.bubble")
                                Text("Phụ đề .srt")
                            }
                        }
                        .toggleStyle(.checkbox)
                        .help("Tự động tải phụ đề tiếng Việt / tiếng Anh (.srt)")
                        .disabled(queue.hasPendingOrActiveItems)
                    } else {
                        Picker("Định dạng audio:", selection: $queue.selectedAudioFormat) {
                            ForEach(AudioFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .frame(maxWidth: 240)
                        .disabled(queue.hasPendingOrActiveItems)

                        HStack(spacing: 4) {
                            Image(systemName: "photo.artframe")
                                .foregroundStyle(.blue)
                            Text("Tự động nhúng Cover Art & ID3")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Stepper("Đồng thời: \(queue.maxConcurrentDownloads)", value: $queue.maxConcurrentDownloads, in: 1...4)
                        .fixedSize()
                        .disabled(queue.hasPendingOrActiveItems)
                }

                Divider()

                HStack(spacing: 10) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Thư mục lưu")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(queue.outputDirectory.path)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(queue.outputDirectory.path)
                    }
                    Spacer()
                    Button("Mở") { queue.openOutputDirectory() }
                    Button("Chọn thư mục…") { queue.chooseOutputDirectory() }
                        .disabled(queue.hasPendingOrActiveItems)
                }

                if let error = queue.generalError {
                    HStack {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.callout)
                        Spacer()
                    }
                }

                HStack {
                    Text("Chỉ tải nội dung bạn sở hữu hoặc được phép sử dụng. Playlist được tự động lưu vào thư mục riêng.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        queue.addLinksAndStart()
                    } label: {
                        Label("Tải tất cả", systemImage: "arrow.down.to.line")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(queue.detectedLinkCount == 0)
                    .keyboardShortcut(.return, modifiers: [.command])
                }
            }
            .padding(8)
        } label: {
            Text("Tùy chọn tải")
                .font(.headline)
        }
    }


    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Text("Hàng đợi tải")
                        .font(.headline)
                    if !queue.items.isEmpty {
                        Text("\(queue.completedCount)/\(queue.items.count) hoàn tất")
                            .font(.caption.monospacedDigit())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()

                HStack(spacing: 8) {
                    if queue.hasPendingOrActiveItems {
                        Button {
                            queue.stopAllDownloads()
                        } label: {
                            Label("Dừng tất cả", systemImage: "stop.fill")
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .controlSize(.small)
                        .help("Dừng toàn bộ các video đang tải và đang chờ")
                    } else if queue.hasResumableItems {
                        Button {
                            queue.resumeAllDownloads()
                        } label: {
                            Label("Tải lại tất cả", systemImage: "arrow.clockwise")
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        .controlSize(.small)
                        .help("Tải lại các video đã hủy hoặc bị lỗi")
                    }

                    if queue.completedCount > 0 {
                        Button {
                            queue.removeFinished()
                        } label: {
                            Label("Dọn mục đã xong", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Xóa các video đã tải xong khỏi danh sách")
                    }

                    if !queue.items.isEmpty {
                        Button {
                            queue.clearAllQueue()
                        } label: {
                            Label("Xóa tất cả", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Hủy toàn bộ và xóa sạch danh sách hàng đợi")
                    }
                }
            }

            if queue.items.isEmpty {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.08))
                            .frame(width: 72, height: 72)
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 38))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.blue)
                    }
                    VStack(spacing: 4) {
                        Text("Hàng đợi tải đang trống")
                            .font(.headline.weight(.semibold))
                        Text("Dán link Video đơn, Playlist hoặc Kênh YouTube vào ô phía trên để bắt đầu tải.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Button {
                        queue.pasteLinks()
                    } label: {
                        Label("Dán link từ Clipboard", systemImage: "doc.on.clipboard")
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .padding(.vertical, 24)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(queue.items) { item in
                        DownloadRow(item: item)
                    }
                }
            }
        }
    }
}

private struct LinkTagRow: View {
    @Binding var draft: LinkDraft
    let isValid: Bool
    let isDuplicate: Bool
    let onRemove: () -> Void

    private var hasError: Bool { !isValid || isDuplicate }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: hasError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(hasError ? Color.red : Color.green)

            if let thumb = draft.thumbnailURL {
                AsyncImage(url: thumb) { phase in
                    if let img = phase.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.secondary.opacity(0.12)
                    }
                }
                .frame(width: 42, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            VStack(alignment: .leading, spacing: 2) {
                if let title = draft.title {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }
                TextField("Link YouTube", text: $draft.text)
                    .textFieldStyle(.plain)
                    .font(draft.title != nil ? .caption.monospaced() : .callout.monospaced())
                    .foregroundStyle(draft.title != nil ? .secondary : .primary)
            }

            Spacer(minLength: 4)

            if isDuplicate {
                Text("Trùng")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if !isValid {
                Text("Không hợp lệ")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Xóa link này")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(hasError ? Color.red.opacity(0.65) : Color.secondary.opacity(0.16))
        }
    }
}

private struct DownloadRow: View {
    @EnvironmentObject private var queue: DownloadQueueViewModel
    let item: DownloadItem
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            thumbnailView

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    if let author = item.authorName, !author.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "play.rectangle.fill")
                                .foregroundStyle(.red)
                                .font(.system(size: 10))
                            Text(author)
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Text(item.url.host ?? "YouTube")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let badge = item.formatBadge {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(badgeColor(for: badge))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(badgeColor(for: badge).opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                    }

                    if item.hasSubtitles {
                        Text("CC")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                    }
                }

                if item.status == .downloading {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: item.progress)
                            .progressViewStyle(.linear)

                        HStack {
                            Text(byteProgressText)
                            if let speed = item.speedBytesPerSecond, speed > 0 {
                                Text("• \(formatBytes(Int64(speed)))/s")
                            }
                            if let eta = item.etaSeconds, eta > 0 {
                                Text("• Còn ~\(formatDuration(TimeInterval(eta)))")
                            }
                            Spacer()
                            Text(item.progress, format: .percent.precision(.fractionLength(0)))
                                .fontWeight(.semibold)
                        }
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                } else if item.status == .preparing || item.status == .processing {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(item.status.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                } else if case .failed(let message) = item.status {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                } else if item.status == .completed {
                    HStack(spacing: 8) {
                        Label("Đã tải xong", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                        if let finalSize = item.finalFileSize {
                            Text("• \(formatBytes(finalSize))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let duration = finishedDuration {
                            Text("• Tải trong \(formatDuration(duration))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if item.status == .waiting {
                    Label("Đang chờ trong hàng đợi…", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if item.status == .cancelled {
                    Label("Đã hủy", systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            actionButtons
                .padding(.top, 2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovered ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var thumbnailView: some View {
        ZStack(alignment: .bottomTrailing) {
            if let thumbURL = item.thumbnailURL {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 68)
                            .clipped()
                    case .failure:
                        placeholderThumb
                    case .empty:
                        ZStack {
                            placeholderThumb
                            ProgressView().controlSize(.small)
                        }
                    @unknown default:
                        placeholderThumb
                    }
                }
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                placeholderThumb
            }

            VStack {
                HStack {
                    statusOverlayBadge
                    Spacer()
                }
                .padding(4)

                Spacer()

                HStack(spacing: 3) {
                    Spacer()
                    if item.hasSubtitles {
                        Text("CC")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 3))
                    }
                    if let badge = item.formatBadge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(badgeBackgroundColor(for: badge), in: RoundedRectangle(cornerRadius: 3))
                    }
                }
                .padding(4)
            }
        }
        .frame(width: 120, height: 68)
    }

    private func badgeColor(for badge: String) -> Color {
        switch badge {
        case "4K": return .purple
        case "2K": return .indigo
        case "1080p": return .blue
        case "MP3", "M4A": return .orange
        default: return .secondary
        }
    }

    private func badgeBackgroundColor(for badge: String) -> Color {
        switch badge {
        case "4K": return Color.purple.opacity(0.85)
        case "2K": return Color.indigo.opacity(0.85)
        case "1080p": return Color.blue.opacity(0.85)
        case "MP3", "M4A": return Color.orange.opacity(0.85)
        default: return Color.black.opacity(0.75)
        }
    }

    private var placeholderThumb: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
            Image(systemName: "play.rectangle")
                .font(.system(size: 24))
                .foregroundStyle(.secondary.opacity(0.6))
        }
        .frame(width: 120, height: 68)
    }

    @ViewBuilder
    private var statusOverlayBadge: some View {
        switch item.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .background(Circle().fill(Color.green))
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .background(Circle().fill(Color.red))
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 6) {
            if item.status == .completed {
                Button {
                    queue.reveal(itemID: item.id)
                } label: {
                    Label("Mở file", systemImage: "folder.fill")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Mở file đã tải trong Finder")

                Button {
                    queue.removeItem(itemID: item.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Xóa khỏi danh sách")
            } else if item.requiresBrowserCookies {
                Menu("Xác minh & thử lại") {
                    ForEach(BrowserCookieSource.browsers) { source in
                        Button("Dùng \(source.displayName)") {
                            queue.retryVerificationFailures(using: source)
                        }
                    }
                }
                .controlSize(.small)
            } else if item.status.isActive || item.status == .waiting {
                Button {
                    queue.cancel(itemID: item.id)
                } label: {
                    Label("Dừng tải", systemImage: "stop.circle.fill")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
                .help("Dừng tiến trình tải video này")
            } else if item.status == .cancelled || isFailed {
                Button {
                    queue.retry(itemID: item.id)
                } label: {
                    Label("Tải lại", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .controlSize(.small)
                .help("Bắt đầu tải lại video này")

                Button {
                    queue.removeItem(itemID: item.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Xóa video này khỏi hàng đợi")
            }
        }
    }

    private var isFailed: Bool {
        if case .failed = item.status { return true }
        return false
    }

    private var byteProgressText: String {
        let downloaded = formatBytes(item.downloadedBytes)
        if let total = item.totalBytes {
            return "\(downloaded) / \(formatBytes(total))"
        }
        return downloaded
    }

    private var finishedDuration: TimeInterval? {
        guard let startedAt = item.startedAt, let finishedAt = item.finishedAt else { return nil }
        return max(finishedAt.timeIntervalSince(startedAt), 0)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(bytes, 0), countStyle: .file)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(Int(interval.rounded()), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 { return "\(hours)g \(minutes)p" }
        if minutes > 0 { return "\(minutes)p \(seconds)s" }
        return "\(seconds)s"
    }
}
