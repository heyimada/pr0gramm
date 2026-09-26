import AVKit
import SwiftUI

/// Downloads tab: grid of offline posts.
struct DownloadsScreen: View {
    @Environment(DownloadStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        sizeClass == .compact
            ? Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
            : [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 2)]
    }

    var body: some View {
        ScrollView {
            if store.downloads.isEmpty {
                ContentUnavailableView("Keine Downloads", systemImage: "arrow.down.circle",
                                       description: Text("Tippe bei einem Post auf ↓, um ihn offline zu speichern."))
                    .padding(.top, 120)
            } else {
                LazyVGrid(columns: columns, spacing: 2) {
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

/// Share, save to Photos and delete, used in context menus and the viewer's toolbar.
struct DownloadActions: View {
    @Environment(DownloadStore.self) private var store
    let download: Download
    var onDelete: () -> Void = {}

    var body: some View {
        ShareLink(item: store.fileURL(for: download)) {
            Label("Teilen", systemImage: "square.and.arrow.up")
        }
        Button("In Fotos sichern", systemImage: "photo.badge.arrow.down") {
            Task { try? await store.saveToPhotos(download) }
        }
        Button("Löschen", systemImage: "trash", role: .destructive) {
            store.delete(download)
            onDelete()
        }
    }
}

/// Plays or shows a downloaded file from disk.
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

/// "Laden" pill: downloads the post, shows progress, then "Gespeichert".
struct DownloadButton: View {
    @Environment(DownloadStore.self) private var store
    let item: FeedItem
    @State private var failed = false

    var body: some View {
        let isSaved = store.download(for: item.id) != nil
        let isLoading = store.inProgress.contains(item.id)
        Button {
            Task {
                do { try await store.save(item) } catch { failed = true }
            }
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
        .alert("Download fehlgeschlagen", isPresented: $failed) {}
    }
}
