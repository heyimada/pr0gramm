# Untangle decision log (pr0gramm)

User chose: Comments + Tests. Repo has no tests at all → Tests addition = nothing to remove; report that.
Baseline: main @ 24f4030, builds for iPhone Duo sim.

## Fixes, each above the problems it solves

F1. One `TagQuery` value type for pr0gramm's tag syntax (`!` extended prefix, body, `-tag` exclusions). Every place that strips/adds `!` uses it.
  - `API/FeedSource.swift:220` CustomFeed.query adds "! " when a `-tag` appears.
  - `API/FeedSource.swift:31` CustomFeed.init(query:) strips "!" for the name.
  - `Settings/FeedSettingsView.swift:119` CustomFeedEditor.tagsAreEmpty strips "!" again.
  - `Reels/ReelsFilter.swift:17` strips "!" before merging feed tags.
  - `API/SearchOptions.swift:33` strips "!" (wasExtended).

F2. One list of switchable content filters on `ContentFlags` (flag, title, subtitle) + one toggle binding on Session; drop dead `badge`/`nsfp`.
  - `App/MainToolbar.swift:32` FilterMenu has its own (flag,title) list.
  - `Settings/FeedSettingsView.swift:97` ContentFlags.filters lives in a Settings view file.
  - `Settings/SettingsView.swift:32` four hand-written flagToggle calls.
  - `API/FeedSource.swift:18` isVisible has its own `switchable` set.
  - `MainToolbar.swift:75` and `SettingsView.swift:83` copy the same insert/remove binding.
  - `Models.swift:14` ContentFlags.badge is dead; `nsfp` only used by it.

F3. Feed selection resolved in one place: `AppState.query(for:)` non-optional (falls back to .top), `AppState.currentSource(picked:in:)`; a `FeedPager` view owns the paging ScrollView + FeedPaging used by Feed tab and Reels.
  - `Feed/FeedScreen.swift:175`, `Home/HomeScreen.swift:24`, `Reels/ReelsScreen.swift:19` each re-implement `selection ?? default`, `contains ? : .top`.
  - `app.query(for:) ?? .top` at 4 call sites + defaultQuery.
  - `FeedScreen.swift:184` and `ReelsScreen.swift:28` duplicate GeometryReader+horizontal paging HStack+FeedPaging.

F4. One `VoteButton` primitive (login gate, toggle-to-0, haptic, a11y, failure alert) used by all vote UIs; Session stores votes as `[VoteTarget: [Int: Int]]` (same persisted format).
  - `Shared/Components.swift:110`, `Item/ItemDetailView.swift:316`, `Item/TagsSection.swift:66`, `Reels/ReelsScreen.swift:418` each gate login, toggle, and handle errors differently (two alert, two swallow).
  - `API/Session.swift:113,140,168,185` four switches over item/comment/tag dictionaries.

F5. An observable `ItemDetails` model per post (load, error, posted comments) and `CommentsSection` owns the composer; ItemInfo tags ranked once.
  - Item info fetched 4 ways: `HomeScreen.swift:139`, `ItemDetailView.swift:122`, `ReelsScreen.swift:283`, `ReelsScreen.swift:459` (reels sheet spins forever on failure).
  - Posted-comments merge duplicated (`ItemDetailView.swift:114`, `ReelsScreen.swift:463`) and inconsistent (reload vs nothing).
  - ReplyTarget vs replyTarget/composes: two ways to open CommentComposer; onComment/onReply params only exist to open it.
  - Tags sorted by confidence 3x (`HomeScreen.swift:115`, `TagsSection.swift:10`, `ReelsScreen.swift:342`).

F6. Site URLs in one place (`API/Site.swift`): origin, api base, post link, user link, badge, media hosts.
  - `https://pr0gramm.com` literal in APIClient, Session (2x), Models badge, CommentText, ItemInfoBar, ReelPage.
  - Post share link duplicated `ItemDetailView.swift:212`, `ReelsScreen.swift:395`.

F7. `Route.tag(String)` resolved by RouteDestination with the default stream.
  - `TagsSection.swift:41` and `ReelsScreen.swift:345` both build FeedQuery(stream: app.defaultStream, tags:).

F8. Persisted settings persist themselves (didSet) via one UserDefaults Codable helper; ReelsFilter moves onto AppState.
  - `ReelsScreen.swift:63` must remember `.onChange(of: filter) { filter.save() }` (call-order convention).
  - encode/decode boilerplate in AppState x4, Session votes, ReelsFilter load/save.
  - onFilter(String, Bool) closure threaded ReelsScreen→ReelsFeed→ReelPage only to reach the filter.
  - Tag-filter reset duplicated (`ReelsFilter.swift:81`, `ReelsScreen.swift:122`).

F9. Download state in one place: `DownloadStore.state(for:)`.
  - `DownloadsScreen.swift:118` and `ReelsScreen.swift:478` both derive isSaved/isLoading.

F10. Colocation / dependency direction: move app-domain types out of API/, shared primitives out of feature files, split FeedScreen.swift.
  - CustomFeed/FeedSource, SearchOptions, Session live in API/ but are app state.
  - glassCircle/glassCapsule defined in ReelsScreen.swift, used by FeedScreen.
  - LoopingPlayer, RemoteImage in Item/MediaView.swift, used by Home, Reels, MediaWindow.
  - ActionPillLabel in ItemDetailView, used by Downloads.
  - FeedScreen.swift holds 7 types (screen, grid, streams tab, pager, collapse, cache).
  - FeedGrid and ReelsFeed duplicate the empty/error/loading state; FeedGrid and DownloadsScreen duplicate grid columns.

F11. Surplus: delete pass-throughs, never-varied injection, dead fields.
  - `Session.captcha()` wraps api.captcha(); `AppState.open` / `router` wrap push (1 caller).
  - `api:`/`defaults:` init params never varied (Session, FeedModel).
  - `FeedResponse.atStart`, `refreshFromCookie` public, `isSyncing` observable but unread.
  - `APIError.server` thrown for non-server messages (Photos, missing post) → `.message`.

F12. Caller-specific parameters / special cases.
  - `FilterMenu.plain` exists only for Reels → FilterMenu takes its label.
  - ItemPagerView/SingleItemScreen measure pageSize for ItemDetailView → it measures itself.
  - ReelsFeed `.task(id: "\(tags)-\(stream)-\(flags)")` + `if model.query != query { rebuild }` → identity by `.id(query)`.
  - TabStack `tab.stream!` force unwrap.

## Kept on purpose (system needs them)
  - FeedModel.loadMore swallows paging errors (next scroll retries).
  - Session.logout `try?` (local logout must succeed offline).
  - CustomFeed custom decoder (old saved data), `tabOrder.v2`, NavigationSettings shownID/hiddenID (SwiftUI identity quirk).
  - SingleItemScreen loads via `.new` + `around` (API quirk).
  - FeedGrid.showsBackground, SegmentCapsule.glassNamespace (glass morph needs ID on the inner glass).
  - Video prefs on Session: small, leave.

## Verification
  - Pin: `scripts/verify/` equivalence harness of pure logic (tag queries, routes, comment threading, vote log, feed visibility), baseline recorded before any change.
  - Build iOS + visionOS.
  - E2E smoke on iPhone Duo simulator, screenshots before/after.
