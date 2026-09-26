# pr0gramm

An unofficial native SwiftUI client for [pr0gramm.com](https://pr0gramm.com) on iPhone, iPad and
Apple Vision Pro. The app's interface is in German, like the site.

> This project is not affiliated with or endorsed by pr0gramm.com. It talks to the site's
> undocumented web API, which can change at any time.

## Features

- Browse the beliebt, neu, müll and Abos streams, or a home screen with today's top posts
- Full-screen, swipeable Reels feed with content filters
- Tag search with the site's extended options (minimum Benis, videos or images only, excluded tags)
- Posts with zoomable images, videos, tags and threaded comments
- Log in to vote, comment and see NSFW/NSFL/POL content. Votes cast on the website sync back to the app
- User profiles, offline downloads and saving to Photos
- A configurable tab bar
- On visionOS, open a post in its own window and place it in the room

## Requirements

- Xcode 27 with the iOS 26 and visionOS 26 SDKs (Swift 6)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build

The Xcode project isn't checked in. XcodeGen generates it from `project.yml`:

```bash
xcodegen generate
open Pr0gramm.xcodeproj
```

To run on a device, set your signing team before generating the project. `project.yml` reads it
from the environment, so it never ends up in git:

```bash
export DEVELOPMENT_TEAM=ABCDE12345
xcodegen generate
```

If you build under your own team, change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` to an
identifier you own.

## Install on a device

Sign in to Xcode with your Apple ID once (Settings › Accounts), then:

```bash
scripts/install-phone.sh --dry-run    # find the connected iPhone, print the commands
scripts/install-phone.sh              # archive, export (development) and install
scripts/install-vision.sh --dry-run   # same for a paired Vision Pro over Wi-Fi
scripts/install-vision.sh
```

Pass a device name or identifier if more than one device is connected. Keep the Vision Pro awake,
unlocked and on the same Wi-Fi. Logs, archives and IPAs land in `build/`, which git ignores. With a
free Apple developer account the app stops opening after 7 days; run the script again to reinstall.

## Project layout

```
Pr0gramm/
  API/        API client, models, session (login, votes, sync)
  App/        app entry point, tabs, navigation
  Features/   one folder per screen (Feed, Item, Reels, Search, Profile, ...)
  Shared/     theme and reusable views
scripts/      device install scripts and the icon generator
```

## License

[MIT](LICENSE)
