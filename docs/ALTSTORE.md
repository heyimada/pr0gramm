# Distributing with AltStore PAL

AltStore PAL is an alternative app marketplace for iPhone and iPad users in the EU, Japan and
Brazil. Apps still go through Apple, but only through notarization (security and basic
functionality), not full App Review. The Vision Pro build can't be distributed this way.

Steps 1–5 are one-time setup; steps 6–9 repeat for every release.

## One-time setup

### 1. Accept Apple's EU terms

Request the Alternative Terms Addendum for Apps in the EU as the Account Holder:
https://developer.apple.com/contact/request/alternative-eu-terms-addendum/

This changes your account's fee terms for the EU. A free app without any revenue owes no Core
Technology Commission. Skip this step if you only want Japan.

### 2. Create the app record

If it doesn't exist yet (it's shared with TestFlight): App Store Connect › Apps › + › New App,
bundle ID `de.azula.pr0gramm`, primary language German.

### 3. Register with AltStore

1. In App Store Connect, click your name (top right) › **Edit Profile** and copy your
   **Developer ID**. That's a UUID, not your Team ID; registering with the Team ID fails silently.
2. Register it:

   ```bash
   curl --header "Content-Type: application/json" -X POST \
     --data '{"developerID": "<Developer ID>", "email": "<your email>"}' \
     https://api.altstore.io/register
   ```

3. The response contains a `token`. In App Store Connect go to **Users and Access › Integrations ›
   Marketplace**, click **+** and paste it.
4. Select pr0gramm as an app to distribute.
5. Choose **Yes, send notifications**, so AltStore processes every notarized build automatically.

### 4. Fill in the metadata notarization requires

Notarization needs most of the App Store metadata, in App Store Connect:

- **App Information:** category (e.g. Social Networking or Entertainment), content rights, age
  rating. Answer the age rating questions honestly: user-generated content and mature content.
- **Version page:** screenshots (iPhone and iPad), description, keywords, support URL (the GitHub
  issues page works), copyright.
- **App Privacy:** a privacy policy URL, and the data declaration. The app collects nothing
  itself; logins go straight to pr0gramm.com.
- Copy the app's **Apple ID** from App Information. The source file needs it as `marketplaceID`.

### 5. Create the source

A source is a JSON file at a public URL. The simplest option is `altstore/source.json` in this repo,
served from `https://raw.githubusercontent.com/heyimada/pr0gramm/main/altstore/source.json`.

```json
{
  "name": "pr0gramm",
  "subtitle": "Inoffizieller pr0gramm-Client",
  "description": "Nativer SwiftUI-Client für pr0gramm.com.",
  "iconURL": "https://raw.githubusercontent.com/heyimada/pr0gramm/main/Pr0gramm/Resources/Assets.xcassets/AppIcon.appiconset/icon.png",
  "website": "https://github.com/heyimada/pr0gramm",
  "tintColor": "#EE4D2E",
  "apps": [
    {
      "name": "pr0gramm",
      "bundleIdentifier": "de.azula.pr0gramm",
      "marketplaceID": "<Apple ID from App Information>",
      "developerName": "azula",
      "subtitle": "Inoffizieller pr0gramm-Client",
      "localizedDescription": "Streams, Reels, Suche, Kommentare und Votes – nativ auf iPhone und iPad.",
      "iconURL": "https://raw.githubusercontent.com/heyimada/pr0gramm/main/Pr0gramm/Resources/Assets.xcassets/AppIcon.appiconset/icon.png",
      "tintColor": "#EE4D2E",
      "category": "social",
      "screenshots": [],
      "appPermissions": {
        "entitlements": [],
        "privacy": {
          "NSPhotoLibraryAddUsageDescription": "Damit du heruntergeladene Posts in deinen Fotos sichern kannst."
        }
      },
      "versions": []
    }
  ],
  "news": []
}
```

Versions are added in step 9.

## Every release

### 6. Upload a build

```bash
scripts/testflight.sh ios
```

The same build serves TestFlight and AltStore PAL.

### 7. Submit for notarization

1. App Store Connect › pr0gramm › the iOS version (create one with **+** if needed).
2. Attach the build under **Build**.
3. Under **App Review Information › Review Type** click **Edit**, choose **Notarization**, save.
4. **Add for Review**, then **Submit to App Review**.

Notarization can take about a day.

### 8. Download the package and publish it

1. Once notarized: App Store Connect › pr0gramm › **History** › copy the **Alternative
   Distribution Package ID** next to the version.
2. Ask AltStore for it (it has usually processed it already thanks to the notifications):

   ```bash
   curl https://api.altstore.io/adps/<ADP ID>
   ```

   If there's no `downloadURL` yet, check `status` and try again later. If it was never processed,
   trigger it with
   `curl --header "Content-Type: application/json" -X POST --data '{"adpID": "<ADP ID>"}' https://api.altstore.io/adps`.
3. Download from `downloadURL` and unzip. The package contains `manifest.json`, a `signature` file
   and one or more `.ipa` variants. **Don't modify any of them**, not even to reformat
   `manifest.json`; the hashes must match.
4. From the unzipped folder, create a GitHub release with all files attached:

   ```bash
   gh release create v1.0 --title "pr0gramm 1.0" manifest.json signature $(find . -name '*.ipa')
   ```

### 9. Add the version to the source

Add a new entry at the **top** of `versions` in `altstore/source.json`. GitHub releases can't
preserve the package's folder layout, so list every file under `assetURLs`: keys are the file names
without extension.

```json
{
  "version": "1.0",
  "buildVersion": "20260927.1530",
  "date": "2026-09-27",
  "localizedDescription": "Erste Version.",
  "downloadURL": "https://github.com/heyimada/pr0gramm/releases/download/v1.0/manifest.json",
  "size": 12345678,
  "assetURLs": {
    "manifest": "https://github.com/heyimada/pr0gramm/releases/download/v1.0/manifest.json",
    "signature": "https://github.com/heyimada/pr0gramm/releases/download/v1.0/signature",
    "<variant UUID>": "https://github.com/heyimada/pr0gramm/releases/download/v1.0/<variant UUID>.ipa"
  },
  "minOSVersion": "26.0"
}
```

- `version` and `buildVersion` must match `CFBundleShortVersionString` and `CFBundleVersion`
  exactly (the build number `scripts/testflight.sh` printed).
- `size` is the byte size of any one `.ipa` variant (`stat -f %z <variant>.ipa`).

Commit and push. Users who added the source get the update automatically.

### Installing

Users in the EU, Japan or Brazil install AltStore PAL from https://altstore.io, then add the source
URL under Sources.

### Optional: make it discoverable

Add `"fediUsername": "<your fediverse handle>"` to the source, then:

```bash
curl --header "Content-Type: application/json" -X POST \
  --data '{"source": "https://raw.githubusercontent.com/heyimada/pr0gramm/main/altstore/source.json"}' \
  https://api.altstore.io/federate
```

The app then shows up on https://explore.alt.store.

## References

- [AltStore: Distribute with AltStore PAL](https://faq.altstore.io/developers/distribute-with-altstore-pal)
- [AltStore: Make a source](https://faq.altstore.io/developers/make-a-source)
- [AltStore: REST API](https://faq.altstore.io/developers/rest-api)
- [Apple: Submit for notarization](https://developer.apple.com/help/app-store-connect/distributing-apps-in-the-european-union/submit-for-notarization)
- [Apple: Get an alternative distribution package ID](https://developer.apple.com/help/app-store-connect/distributing-apps-in-the-european-union/get-an-alternative-distribution-package-id/)
