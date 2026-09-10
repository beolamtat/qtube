import SwiftUI

struct PlaylistInspectorView: View {
    @Binding var playlist: PlaylistInfo
    @ObservedObject var queue: DownloadQueueViewModel
    let baseDirectory: URL
    let onConfirm: (_ numberFiles: Bool, _ targetDirectory: URL) -> Void
    let onCancel: () -> Void

    @State private var numberFiles = true
    @State private var createSubfolder = true
    @State private var chosenBaseDirectory: URL? = nil
    @State private var searchText = ""

    private var currentBaseDirectory: URL {
        chosenBaseDirectory ?? baseDirectory
    }

    private var destinationDirectory: URL {
        if createSubfolder {
            let titleToUse: String
            if !playlist.title.isEmpty && playlist.title != "Đang phân tích danh sách…" {
                titleToUse = playlist.title
            } else if let t = queue.inspectingPlaylistTitle, !t.isEmpty, t != "Đang phân tích Danh sách phát…" {
                titleToUse = t
            } else {
                titleToUse = "Playlist"
            }
            let folderName = DownloadQueueViewModel.sanitizeFilename(titleToUse)
            return currentBaseDirectory.appendingPathComponent(folderName, isDirectory: true)
        } else {
            return currentBaseDirectory
        }
    }

    private var filteredEntriesWithIndex: [(index: Int, entry: PlaylistEntry)] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = Array(playlist.entries.enumerated())
        if trimmed.isEmpty {
            return all.map { ($0.offset, $0.element) }
        }
        return all.compactMap { offset, element in
            element.title.lowercased().contains(trimmed) ? (offset, element) : nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            if playlist.entries.isEmpty {
                loadingStateView
            } else {
                filterBar
                if playlist.isMix {
                    mixNoticeBar
                }
                if queue.isInspectingPlaylist {
                    streamingProgressBar
                }
                Divider()
                entriesList
                Divider()
                destinationBar
                Divider()
                footerView
            }
        }
        .frame(minWidth: 660, idealWidth: 720, minHeight: 520, idealHeight: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeInOut(duration: 0.25), value: playlist.entries.isEmpty)
    }

    private var headerView: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "list.bullet.rectangle.portrait.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                let displayTitle: String = {
                    if !playlist.title.isEmpty && playlist.title != "Đang phân tích danh sách…" {
                        return playlist.title
                    }
                    if let t = queue.inspectingPlaylistTitle, !t.isEmpty && t != "Đang phân tích Danh sách phát…" {
                        return t
                    }
                    return "Đang phân tích danh sách…"
                }()

                HStack(spacing: 8) {
                    Text(displayTitle)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)

                    if playlist.isMix {
                        Text("YouTube Mix")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.12), in: Capsule())
                            .foregroundStyle(.purple)
                            .help("Danh sách bài hát gợi ý tự động do thuật toán YouTube tạo ra")
                    }
                }

                HStack(spacing: 8) {
                    let author = playlist.uploader ?? queue.inspectingPlaylistUploader
                    if let author, !author.isEmpty {
                        Text(author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("•")
                            .foregroundStyle(.tertiary)
                    } else if playlist.isMix {
                        Text("Radio gợi ý tự động")
                            .font(.subheadline)
                            .foregroundStyle(.purple)
                        Text("•")
                            .foregroundStyle(.tertiary)
                    }

                    if playlist.entries.isEmpty {
                        HStack(spacing: 5) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Đang kết nối YouTube…")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    } else if queue.isInspectingPlaylist {
                        HStack(spacing: 5) {
                            ProgressView()
                                .controlSize(.small)
                            if let total = queue.inspectingTotalCount, total > 0 {
                                Text("Đang nạp \(playlist.entries.count) / \(total) video…")
                            } else {
                                Text("Đang nạp \(playlist.entries.count) video…")
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    } else {
                        Text("\(playlist.totalCount) video")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Đóng cửa sổ")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var loadingStateView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Đang kết nối và lấy thông tin video từ YouTube…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.04))

            Divider()

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(0..<6, id: \.self) { _ in
                        PlaylistSkeletonRow()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }

            Divider()

            HStack {
                Text("Vui lòng đợi trong giây lát…")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Hủy", action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Tìm kiếm video trong danh sách…", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.18)))

            Spacer(minLength: 4)

            if playlist.isMix, let artist = playlist.primaryArtist, !artist.isEmpty {
                Button {
                    playlist.selectOnly(author: artist)
                } label: {
                    Label("Chỉ chọn bài của \"\(artist)\"", systemImage: "person.crop.circle.badge.checkmark")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.purple)
                .disabled(playlist.entries.isEmpty)
                .help("Tự động chọn các bài hát của \(artist) và bỏ chọn các bài hát gợi ý khác")
            }

            Button(playlist.areAllSelected ? "Bỏ chọn tất cả" : "Chọn tất cả") {
                let newState = !playlist.areAllSelected
                for idx in playlist.entries.indices {
                    playlist.entries[idx].isSelected = newState
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(playlist.entries.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }

    private var mixNoticeBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
                .font(.caption)

            Text("Đây là danh sách YouTube Mix tự động do thuật toán đề xuất thêm các ca sĩ khác.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let artist = playlist.primaryArtist, !artist.isEmpty {
                Button("Chỉ chọn bài của \"\(artist)\"") {
                    playlist.selectOnly(author: artist)
                }
                .buttonStyle(.borderless)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.purple)
                .help("Chọn bài của \(artist)")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(Color.purple.opacity(0.06))
    }

    private var streamingProgressBar: some View {
        VStack(spacing: 4) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    if let total = queue.inspectingTotalCount, total > 0 {
                        let percent = Int(queue.inspectingProgressFraction * 100)
                        Text("Đang nạp: **\(playlist.entries.count)** / **\(total)** video (\(percent)%)")
                            .font(.caption)
                    } else {
                        Text("Đang nạp: **\(playlist.entries.count)** video…")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)

                Spacer()

                Button("Dừng nạp") {
                    queue.cancelPlaylistInspection()
                }
                .buttonStyle(.borderless)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .help("Dừng quét thêm và giữ lại các video đã nạp")
            }

            if let total = queue.inspectingTotalCount, total > 0 {
                ProgressView(value: queue.inspectingProgressFraction)
                    .progressViewStyle(.linear)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.05))
    }

    private var entriesList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if playlist.entries.isEmpty {
                    ForEach(0..<6, id: \.self) { _ in
                        PlaylistSkeletonRow()
                    }
                } else {
                    ForEach(filteredEntriesWithIndex, id: \.entry.id) { item in
                        entryRow(index: item.index, entry: item.entry)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    private func entryRow(index: Int, entry: PlaylistEntry) -> some View {
        let isSelected = (index < playlist.entries.count && playlist.entries[index].id == entry.id)
            ? playlist.entries[index].isSelected
            : entry.isSelected

        return HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { newValue in
                    if index < playlist.entries.count && playlist.entries[index].id == entry.id {
                        playlist.entries[index].isSelected = newValue
                    } else if let realIdx = playlist.entries.firstIndex(where: { $0.id == entry.id }) {
                        playlist.entries[realIdx].isSelected = newValue
                    }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            Text(String(format: "%02d", index + 1))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)

            ZStack(alignment: .bottomTrailing) {
                if let thumb = entry.thumbnailURL {
                    AsyncImage(url: thumb) { phase in
                        if let img = phase.image {
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.secondary.opacity(0.10)
                        }
                    }
                    .frame(width: 80, height: 45)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.10))
                        .frame(width: 80, height: 45)
                }

                if let duration = entry.durationText {
                    Text(duration)
                        .font(.system(size: 9, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 3))
                        .padding(2)
                }
            }
            .frame(width: 80, height: 45)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                if let author = entry.author, !author.isEmpty {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if index < playlist.entries.count && playlist.entries[index].id == entry.id {
                playlist.entries[index].isSelected.toggle()
            } else if let realIdx = playlist.entries.firstIndex(where: { $0.id == entry.id }) {
                playlist.entries[realIdx].isSelected.toggle()
            }
        }
    }

    private var destinationBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.blue)
                    .font(.body)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Thư mục lưu")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(destinationDirectory.path)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(destinationDirectory.path)
                }

                Spacer()

                Button("Đổi thư mục…") {
                    chooseFolder()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 20) {
                Toggle(isOn: $createSubfolder) {
                    Text("Tạo thư mục riêng theo tên Playlist")
                        .font(.callout)
                }
                .toggleStyle(.checkbox)
                .help("Tự động gom toàn bộ video của Playlist này vào thư mục riêng")

                Toggle(isOn: $numberFiles) {
                    Text("Đánh số thứ tự file (01, 02…)")
                        .font(.callout)
                }
                .toggleStyle(.checkbox)
                .help("Thêm tiền tố 01, 02... vào tên file để sắp xếp đúng thứ tự trong Finder")

                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Chọn thư mục lưu cho Playlist"
        panel.message = "Chọn thư mục bạn muốn lưu các video từ Playlist này."
        panel.prompt = "Chọn thư mục"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = currentBaseDirectory

        if panel.runModal() == .OK, let selected = panel.url {
            chosenBaseDirectory = selected
        }
    }

    private var footerView: some View {
        HStack {
            Text("Đã chọn: **\(playlist.selectedCount)** / \(playlist.totalCount) video")
                .font(.callout)
                .foregroundStyle(playlist.selectedCount > 0 ? Color.primary : Color.secondary)

            Spacer()

            Button("Hủy", action: onCancel)
                .keyboardShortcut(.cancelAction)

            Button {
                onConfirm(numberFiles, destinationDirectory)
            } label: {
                Text(playlist.selectedCount > 0 ? "Tải \(playlist.selectedCount) video đã chọn" : "Tải đã chọn")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(playlist.selectedCount == 0)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

struct PlaylistSkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 16, height: 16)

            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 22, height: 12)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 80, height: 45)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 240, height: 13)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 140, height: 11)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}
