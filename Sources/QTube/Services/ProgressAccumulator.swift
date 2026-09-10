import Foundation

struct DownloadProgressSnapshot: Equatable {
    let fraction: Double
    let downloadedBytes: Int64
    let totalBytes: Int64?
    let speedBytesPerSecond: Double?
    let etaSeconds: Int?
}

final class ProgressAccumulator {
    private struct FormatInfo: Decodable {
        let filesize: Int64?
        let filesizeApprox: Int64?

        enum CodingKeys: String, CodingKey {
            case filesize
            case filesizeApprox = "filesize_approx"
        }
    }

    private struct Payload: Decodable {
        let downloadedBytes: Int64?
        let totalBytes: Int64?
        let totalBytesEstimate: Int64?
        let filename: String?
        let speed: Double?
        let eta: Double?
        let percent: Double?

        enum CodingKeys: String, CodingKey {
            case downloadedBytes = "downloaded_bytes"
            case totalBytes = "total_bytes"
            case totalBytesEstimate = "total_bytes_estimate"
            case filename
            case speed
            case eta
            case percent = "_percent"
        }
    }

    private struct TransferState {
        var downloadedBytes: Int64
        var totalBytes: Int64?
    }

    private var expectedTotalBytes: Int64?
    private var transfers: [String: TransferState] = [:]
    private let jsonDecoder = JSONDecoder()

    @discardableResult
    func consumeMetadataJSON(_ json: String) -> Int64? {
        guard let data = json.data(using: .utf8),
              let formats = try? jsonDecoder.decode([FormatInfo].self, from: data)
        else { return nil }

        let total = formats.reduce(Int64(0)) { partial, format in
            partial + (format.filesize ?? format.filesizeApprox ?? 0)
        }
        expectedTotalBytes = total > 0 ? total : nil
        return expectedTotalBytes
    }

    func consumeProgressJSON(_ json: String) -> DownloadProgressSnapshot? {
        guard let data = json.data(using: .utf8),
              let payload = try? jsonDecoder.decode(Payload.self, from: data)
        else { return nil }

        let key = payload.filename ?? "default"
        let previous = transfers[key]
        let downloaded = max(previous?.downloadedBytes ?? 0, payload.downloadedBytes ?? 0)
        let reportedTotal = payload.totalBytes ?? payload.totalBytesEstimate
        let preservedTotal: Int64?
        if let previousTotal = previous?.totalBytes, let reportedTotal {
            preservedTotal = max(previousTotal, reportedTotal)
        } else {
            preservedTotal = previous?.totalBytes ?? reportedTotal
        }
        transfers[key] = TransferState(downloadedBytes: downloaded, totalBytes: preservedTotal)

        let aggregateDownloaded = transfers.values.reduce(Int64(0)) { $0 + $1.downloadedBytes }
        let knownTotal = transfers.values.reduce(Int64(0)) { $0 + ($1.totalBytes ?? 0) }
        let aggregateTotal: Int64? = {
            let total = max(expectedTotalBytes ?? 0, knownTotal)
            return total > 0 ? total : nil
        }()

        let fraction: Double
        if let aggregateTotal, aggregateTotal > 0 {
            fraction = Double(aggregateDownloaded) / Double(aggregateTotal)
        } else {
            fraction = (payload.percent ?? 0) / 100
        }

        let eta: Int?
        if let aggregateTotal,
           let speed = payload.speed,
           speed > 0,
           aggregateTotal > aggregateDownloaded {
            eta = Int(Double(aggregateTotal - aggregateDownloaded) / speed)
        } else if let reportedETA = payload.eta {
            eta = Int(reportedETA)
        } else {
            eta = nil
        }

        return DownloadProgressSnapshot(
            fraction: min(max(fraction, 0), 1),
            downloadedBytes: aggregateDownloaded,
            totalBytes: aggregateTotal,
            speedBytesPerSecond: payload.speed,
            etaSeconds: eta
        )
    }
}
