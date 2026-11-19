import SwiftUI

struct ProfileScreen<Extras: View>: View {
    @Environment(Session.self) private var session
    @Environment(\.bookPages) private var bookPages
    let name: String
    /// Shown between the header and the uploads, e.g. the settings on your own profile.
    @ViewBuilder let extras: Extras
    @State private var uploads: FeedModel
    @State private var profile: Profile?
    @State private var error: Error?

    init(name: String, @ViewBuilder extras: () -> Extras) {
        self.name = name
        self.extras = extras()
        _uploads = State(initialValue: FeedModel(query: FeedQuery(stream: .new, user: name)))
    }

    var body: some View {
        Group {
            if bookPages != nil, #available(iOS 27.1, visionOS 27.1, *) {
                // Book Mode: who it is on one page, what they uploaded on the other.
                ArrangementView {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            ProfileHeader(name: name, profile: profile, error: error)
                            extras
                        }
                        .padding(16)
                    }
                    .background(Color.pr0Background)
                } secondary: {
                    FeedGrid(model: uploads) {
                        Text("Hochlads").pr0SectionHeader().padding(16)
                    }
                }
                .arrangementViewStyle(.split)
            } else {
                FeedGrid(model: uploads) {
                    VStack(alignment: .leading, spacing: 18) {
                        ProfileHeader(name: name, profile: profile, error: error)
                        extras
                        Text("Hochlads").pr0SectionHeader()
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle(name)
        .task(id: session.flags) { await load() }
    }

    private func load() async {
        do {
            profile = try await APIClient.shared.profile(name, flags: session.flags)
            error = nil
        } catch where error.isCancellation {
        } catch {
            self.error = error
        }
    }
}

extension ProfileScreen where Extras == EmptyView {
    init(name: String) {
        self.init(name: name) { EmptyView() }
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
                    Text(name).font(.title2.bold()).lineLimit(1)
                    if let profile {
                        HStack(spacing: 6) {
                            MarkDot(mark: profile.user.mark, size: 8)
                            Text(UserMark.name(profile.user.mark))
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.mark(profile.user.mark))
                        if profile.user.banned == 1 {
                            Text("gesperrt").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.pr0Orange)
                        }
                    }
                }
            }

            if let profile {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.user.score, format: .number)
                        .font(.system(size: 44, weight: .bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("Benis").font(.caption).foregroundStyle(Color.pr0Secondary)
                }
                .accessibilityElement(children: .combine)

                HStack(spacing: 26) {
                    if let count = profile.uploadCount { stat(count, "Hochlads") }
                    if let count = profile.commentCount { stat(count, "Kommentare") }
                    if let count = profile.tagCount { stat(count, "Tags") }
                }

                Text("Dabei seit \(profile.user.registeredAt.formatted(date: .long, time: .omitted))")
                    .font(.footnote)
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
            Text(value, format: .number).font(.title3.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(Color.pr0Secondary)
        }
    }
}
