import SwiftUI

/// A user's profile with their uploads.
struct ProfileScreen: View {
    @Environment(Session.self) private var session
    let name: String
    @State private var uploads: FeedModel
    @State private var profile: Profile?
    @State private var error: Error?

    init(name: String) {
        self.name = name
        _uploads = State(initialValue: FeedModel(query: FeedQuery(stream: .new, user: name)))
    }

    var body: some View {
        FeedGrid(model: uploads) {
            VStack(alignment: .leading, spacing: 18) {
                ProfileHeader(name: name, profile: profile, error: error)
                Text("Hochlads").pr0SectionHeader()
            }
            .padding(16)
        }
        .navigationTitle(name)
        .task(id: session.flags) { await load() }
    }

    private func load() async {
        do {
            profile = try await APIClient.shared.profile(name, flags: session.flags)
            error = nil
        } catch is CancellationError {
        } catch {
            self.error = error
        }
    }
}

private struct ProfileHeader: View {
    let name: String
    let profile: Profile?
    let error: Error?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Avatar(name: name, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(name).font(.system(size: 24, weight: .semibold)).lineLimit(1)
                        if let profile { MarkDot(mark: profile.user.mark, size: 10) }
                    }
                    if let profile {
                        Text("\(profile.user.score.formatted()) Benis")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.pr0Secondary)
                        if profile.user.banned == 1 {
                            Text("gesperrt").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.pr0Orange)
                        }
                    }
                }
            }

            if let profile {
                HStack(spacing: 28) {
                    if let count = profile.uploadCount { stat(count, "Hochlads") }
                    if let count = profile.commentCount { stat(count, "Kommentare") }
                    if let count = profile.tagCount { stat(count, "Tags") }
                }

                Text("Dabei seit \(profile.user.registeredAt.formatted(date: .long, time: .omitted))")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.pr0Secondary)

                if let badges = profile.badges, !badges.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(badges, id: \.self) { badge in
                            AsyncImage(url: badge.imageURL) { $0.resizable().scaledToFit() } placeholder: { Color.clear }
                                .frame(width: 32, height: 32)
                                .help(badge.description ?? "")
                                .accessibilityLabel(badge.description ?? "Abzeichen")
                        }
                    }
                }
            } else if let error {
                Text(error.localizedDescription).foregroundStyle(Color.pr0Secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .number).font(.system(size: 17, weight: .semibold)).monospacedDigit()
            Text(label).font(.system(size: 12)).foregroundStyle(Color.pr0Secondary)
        }
    }
}
