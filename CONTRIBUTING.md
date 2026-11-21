# Contributing

Thanks for helping. Bug reports, new faces and shapes, docs fixes and tests are all welcome.

## Ground rules

- **Keep Android and iOS in step.** A feature lands on both platforms with the same names (Swift uses
  lowerCamel) and the same constants, or the PR explains why not.
- **No new runtime dependencies.** Android uses only AndroidX Compose, iOS only SwiftUI.
- **Keep the sim deterministic.** The animation uses a seeded generator, so the same seed gives the same motion.

## Run the tests

```bash
swift test                                             # iOS package, repo root
cd android && ./gradlew :botui:testDebugUnitTest       # Android library
cd android && ./gradlew :app:assembleDebug             # demo app builds
```

## Run the demos

- Android: open `android/` in Android Studio and run `app`.
- iOS: `cd ios/Demo && xcodegen generate`, then open `BotUIDemo.xcodeproj`.

## Good first issues

Look for the `good first issue` label. Easy wins: a new eye or mouth style, a new built-in body shape,
or a test for an existing state.

## Pull requests

Small and focused is best. Describe what changed and why, and tick the checklist in the PR template.
By contributing you agree your work is released under the MIT license.
