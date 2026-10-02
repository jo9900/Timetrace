# Timetrace 1.0.0

Native iPhone photo stories built with SwiftUI, local JSON/JPEG persistence, and AVFoundation. Requires iOS 17 or later. Supports Simplified Chinese, Traditional Chinese, Japanese, and English throughout the interface and exported captions.

The `release` branch is the production and default branch; `dev` is the development branch.

## Run

Open `Timetrace.xcodeproj`, select the Timetrace scheme and an iPhone simulator, then Run. Automatic signing is configured for the individual developer account team `54BTJHJKUU` and bundle identifier `com.yuanzheng.timetrace`. Camera capture requires a physical device.

## Structure

- `Sources/App`: application entry, language selection, and localization
- `Sources/Models`: story and photo records
- `Sources/Services`: atomic persistence and image processing
- `Sources/Features/Library`: photo journal, creation, theme/language settings, and app information
- `Sources/Features/Timeline`: chronological records and notes
- `Sources/Features/Camera`: capture session, alignment reference, and review
- `Sources/Features/Compare`: two-photo reveal comparison
- `Sources/Features/Export`: video rendering, preview, Photos save, and sharing
- `Sources/Shared`: reusable styling and photo presentation
- `Sources/Resources`: four language bundles, permission descriptions, privacy manifest, and app icon
- `Tests`, `UITests`: persistence, video output, localization, and navigation checks

The checked-in Xcode project has no third-party runtime dependencies. `Scripts/generate_project.rb` regenerates it using the development-only `xcodeproj` Ruby gem if files are added outside Xcode.

The default palette is Soft Graphite, with warm off-white paper, graphite controls, and subtle desaturated paper grain. Serif branding, layered photo prints, translucent tape, and thumbnail strips preserve the scrapbook composition. Settings also offers Clay, Moss, Ink Blue, Forest, and Plum. Existing saved choices are preserved. The choice applies immediately, persists through relaunch, and supports light and dark appearance. Photos keep their original colors. Visual tokens are defined in `Sources/Shared/Theme.swift`. The selected Instant Memory icon (photography-round concept 02) is included in the AppIcon asset catalog. TestFlight 1.0.0 (1) still uses the previous Growth Trace icon.

Chinese serif fonts are bundled so typography does not depend on optional iOS downloads. The four regional Noto Serif font files add about 39.55 MB; their license and upstream sources are in `Sources/Resources/Fonts`. Japanese uses native Hiragino Mincho and English uses Baskerville. The paper texture is included in `Sources/Resources/Assets.xcassets/PaperTexture.imageset`.

Language defaults to the first supported system preference, with Simplified Chinese as the fallback. Settings offers Follow system and explicit language choices; switching updates the interface immediately and persists through relaunch. Export captures the selected language when rendering starts. Native permission and sharing dialogs use the language managed by iOS.

## Verify

```sh
xcodebuild -project Timetrace.xcodeproj -scheme Timetrace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test CODE_SIGNING_ALLOWED=NO
```

Tests use temporary libraries. The `--ui-testing` launch argument only exists in Debug and resets its own temporary test directory. Adding `--reset-theme` or `--reset-language` resets the corresponding preference for tests; ordinary launches preserve both.

## Data and sharing

The library lives in Application Support/Timetrace. Metadata changes are atomic; photo deletion happens only after metadata is committed. A damaged manifest blocks writes rather than overwriting existing files. Photos are normalized to JPEG at a maximum 2560-pixel dimension. Thumbnails are downsampled and cached.

Exports are 1080 x 1440 H.264 MP4, with dates, day numbers, localized brand marks, and a closing card. Photos remain on the device. The share sheet exposes installed compatible apps; saving to Photos also allows manual posting to Xiaohongshu. No private share URL or third-party SDK is used.

## Release checklist

- Confirm the uploaded build has finished processing in TestFlight before device testing.
- Verify camera permissions, front/rear orientation, interruptions, and photo alignment on a real iPhone.
- Verify Photos saving and sharing with installed target apps on a real iPhone.
- Supply App Store screenshots, support/privacy policy URLs, age rating, and privacy disclosures.

Run these commands from this directory to archive and upload version 1.0.0, build 1. `ExportOptions.plist` uses automatic signing, team `54BTJHJKUU`, the App Store Connect export method, and the upload destination.

```sh
xcodebuild -project Timetrace.xcodeproj -scheme Timetrace \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/archives/Timetrace-1.0.0-1.xcarchive \
  -allowProvisioningUpdates archive

xcodebuild -exportArchive \
  -archivePath build/archives/Timetrace-1.0.0-1.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/testflight \
  -allowProvisioningUpdates
```

The locally exported App Store package is `build/testflight-package/Timetrace.ipa`. Check [TestFlight](https://appstoreconnect.apple.com/apps/6818212918/testflight) for build availability after upload. Increment `CURRENT_PROJECT_VERSION` in `Scripts/generate_project.rb` and regenerate the project before a later build.

There is no cloud synchronization, historical photo import, per-story reminder schedule, AI, or community. App deletion removes the local library.

## Verified baseline

On October 2, 2026, all 18 tests passed after removing the empty-state headline and story-creation helper text. The device Release archive at `build/archives/Timetrace-1.0.0-1.xcarchive` and App Store export to `build/testflight-package/Timetrace.ipa` succeeded for version 1.0.0, build 1. The package is signed for the personal team `54BTJHJKUU` and bundle identifier `com.yuanzheng.timetrace`. Upload and Apple processing completed for App Store Connect app `6818212918`. TestFlight shows build 1.0.0 (1) as Testing in the Personal Testing internal group, with only the account holder invited. Automatic distribution is disabled. Physical camera testing remains pending on the user's iPhone.

On October 1, 2026, the Soft Graphite update passed the six-palette light/dark contrast test and the theme selection/persistence UI test. The updated app was installed and opened in the iPhone 17 Pro simulator with Graphite selected.

On September 30, 2026, Xcode 26.3 and the iPhone 17 Pro iOS 26.2 simulator passed all 18 tests: 6 persistence checks, 2 video export checks, 1 palette contrast check, 3 localization checks, 1 bundled-font check, and 5 UI checks. The export test decodes actual frames and verifies photo orientation/content, output dimensions, duration, cancellation, and missing-photo errors. Localization checks cover system preference ordering, Chinese scripts/regions, unsupported-language fallback, and matching keys/format arguments across all four bundles. The font check verifies registration, Chinese glyph coverage, and bundled license files. UI checks cover all four system languages, fallback, manual switching, language/theme persistence, return to system language, the single empty-state creation action, story creation, unavailable-camera recovery, and creation at the largest accessibility text size. Palette checks cover text and primary buttons in all six themes under light and dark appearance. After the final paper-texture and thumbnail-spacing adjustments, the palette check and all 5 UI checks passed again.

The earlier Clay home screens in all four languages, populated light/dark library, theme settings, empty library at the largest accessibility text size, and populated accessibility header were visually inspected. Historical preview images are not included in this repository. Hardware camera capture and target-app sharing remain release checks.
