import AVKit
import SwiftUI

struct DownloadsScreen: View {
    @Environment(DownloadStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            if store.downloads.isEmpty {
                ContentUnavailableView("Keine Downloads", systemImage: "arrow.down.circle",
                                       description: Text("Tippe bei einem Post auf ↓, um ihn offline zu speichern."))
                    .padding(.top, 120)
            } else {
                LazyVGrid(columns: ThumbnailView.thumbnailColumns(compact: sizeClass == .compact), spacing: ThumbnailView.spacing) {
                    ForEach(store.downloads) { download in
                        NavigationLink(value: Route.download(download.id)) {
                            ThumbnailView(item: download.item)
                                .overlay(alignment: .bottomTrailing) {
                                    if download.item.isVideo {
                                        Image(systemName: "play.fill")
                                            .font(.caption2)
                                            .padding(5)
                                            .background(.black.opacity(0.55), in: .circle)
                                            .padding(4)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .contextMenu { DownloadActions(download: download) }
                    }
                }
            }
        }
        .background(Color.pr0Background)
    }
}

struct DownloadActions: View {
    @Environment(DownloadStore.self) private var store
    let download: Download
    var onDelete: () -> Void = {}

    var body: some View {
        ShareLink(item: store.fileURL(for: download)) {
            Label("Teilen", systemImage: "square.and.arrow.up")
        }
        Button("In Fotos sichern", systemImage: "photo.badge.arrow.down") {
            Task { await store.saveToPhotos(download) }
        }
        Button("Löschen", systemImage: "trash", role: .destructive) {
            store.delete(download)
            onDelete()
        }
    }
}

struct DownloadViewer: View {
    @Environment(DownloadStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let id: Int
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let download = store.download(for: id) {
                let url = store.fileURL(for: download)
                Group {
                    if download.item.isVideo {
                        VideoPlayer(player: player)
                            .onAppear {
                                player = AVPlayer(url: url)
                                player?.play()
                            }
                            .onDisappear { player?.pause() }
                    } else if let image = UIImage(contentsOfFile: url.path()) {
                        Image(uiImage: image).resizable().scaledToFit()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(download.item.user)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            DownloadActions(download: download) { dismiss() }
                            NavigationLink(value: Route.item(download.id)) {
                                Label("Post öffnen", systemImage: "arrow.up.forward.app")
                            }
                        } label: {
                            Label("Aktionen", systemImage: "ellipsis")
                        }
                    }
                }
            } else {
                ContentUnavailableView("Download nicht gefunden", systemImage: "questionmark.folder")
            }
        }
        .background(Color.black)
    }
}

struct DownloadButton: View {
    @Environment(DownloadStore.self) private var store
    let item: FeedItem

    var body: some View {
        let state = store.state(for: item.id)
        let isSaved = state == .saved
        let isLoading = state == .loading
        Button {
            Task { await store.save(item) }
        } label: {
            if isLoading {
                ProgressView()
                    .padding(.horizontal, 30)
                    .frame(height: 38)
                    .background(Color.pr0Pill, in: .capsule)
            } else {
                ActionPillLabel(title: isSaved ? "Gespeichert" : "Laden",
                                symbol: isSaved ? "checkmark" : "arrow.down",
                                tint: isSaved ? .upvoteGreen : .pr0Text)
            }
        }
        .buttonStyle(.plain)
        .disabled(isSaved || isLoading)
    }
}
