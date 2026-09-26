import Foundation
import Observation
import Photos

struct Download: Codable, Identifiable {
    let item: FeedItem
    let fileName: String
    let date: Date
    var id: Int { item.id }
}

/// Posts saved for offline viewing in `Documents/Downloads`, with a JSON index next to them.
@Observable
final class DownloadStore {
    private(set) var downloads: [Download] = []
    private(set) var inProgress: Set<Int> = []

    private let directory: URL
    private var indexURL: URL { directory.appending(path: "index.json") }

    init() {
        directory = URL.documentsDirectory.appending(path: "Downloads", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: indexURL),
           let stored = try? JSONDecoder().decode([Download].self, from: data) {
            downloads = stored.filter { FileManager.default.fileExists(atPath: fileURL(for: $0).path()) }
        }
    }

    func download(for id: Int) -> Download? {
        downloads.first { $0.id == id }
    }

    func fileURL(for download: Download) -> URL {
        directory.appending(path: download.fileName)
    }

    var totalBytes: Int64 {
        downloads.reduce(0) { total, download in
            let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL(for: download).path())
            return total + ((attributes?[.size] as? NSNumber)?.int64Value ?? 0)
        }
    }

    /// Downloads the best available file (fullsize image or H.264 video).
    func save(_ item: FeedItem) async throws {
        guard download(for: item.id) == nil, !inProgress.contains(item.id) else { return }
        inProgress.insert(item.id)
        defer { inProgress.remove(item.id) }

        let source = item.fullsizeURL ?? item.mediaURL
        let (temporary, response) = try await URLSession.shared.download(from: source)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.http(http.statusCode)
        }
        let fileName = "\(item.id).\(source.pathExtension.isEmpty ? "bin" : source.pathExtension)"
        let destination = directory.appending(path: fileName)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)

        downloads.insert(Download(item: item, fileName: fileName, date: .now), at: 0)
        persist()
    }

    func delete(_ download: Download) {
        try? FileManager.default.removeItem(at: fileURL(for: download))
        downloads.removeAll { $0.id == download.id }
        persist()
    }

    func deleteAll() {
        downloads.forEach { try? FileManager.default.removeItem(at: fileURL(for: $0)) }
        downloads = []
        persist()
    }

    /// Copies a download into the photo library (asks for add-only access).
    func saveToPhotos(_ download: Download) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw APIError.server("Kein Zugriff auf die Fotos. Erlaube ihn in den Einstellungen.")
        }
        let url = fileURL(for: download)
        let isVideo = download.item.isVideo
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: isVideo ? .video : .photo, fileURL: url, options: nil)
        }
    }

    private func persist() {
        try? JSONEncoder().encode(downloads).write(to: indexURL, options: .atomic)
    }
}
