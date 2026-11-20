# Interactive Bot UI

Interactive animated bot avatar for native Android (Jetpack Compose) and iOS (SwiftUI), drawn natively. No web view. Colour and mood change at runtime.

## Android (Jetpack Compose)

Module `android/botui`. Demo: `android/app`.

```kotlin
BotView(
    state = BotState.Happy,            // see States below
    modifier = Modifier.size(260.dp),
    style = BotStyle(
        color = Color(0xFFF5292A),
        brightness = 1.1f, furLength = 2.6f, furDensity = 0.75f,
        face = BotFace.EyesAndMouth,   // or Eyes
        feather = featherBitmap,         // optional ImageBitmap
    ),
)
```

Build: `cd android && ./gradlew :app:assembleDebug`. Tests: `:botui:testDebugUnitTest`.

## iOS (SwiftUI)

Swift package `ios/BotUI` (iOS 16+). Demo: `ios/Demo` (`xcodegen generate`, then open the project).

```swift
BotView(
    state: .happy,                       // see States below
    style: BotStyle(color: Color(red: 0.96, green: 0.16, blue: 0.16),
                      brightness: 1.1, furLength: 2.6, face: .eyesAndMouth,
                      feather: UIImage(named: "feather")))
    .frame(width: 260, height: 260)
```

Tests: `cd ios/BotUI && swift test`.

## States

17 presets, same names on both ports (Swift uses lowerCamel):

Neutral, Happy, Working, Sleeping, Thinking, Idea, Love, Sad, Surprised, Angry, Confused, Excited,
Listening, Speaking, Success, Error, Giggle.

Each state is a face preset (`BotFaceSpec`) plus a body motion (hop, shake, nod, heartbeat, tilt,
giggle wiggle). Changing state crossfades the old face into the new one over about 0.22s. No face
uses eyebrows. Sad and Angry tilt the eyes instead (`eyeTilt`).

Thinking shows a thought bubble with pulsing dots, and Idea shows the system light bulb emoji with
pulsing rays, both floating beside the head.

## Touch

Tap the bot to make it giggle (1.6s), press and hold for love (2.4s). Then it returns to the state you set.

```kotlin
BotView(state, touchReactions = true, onTouch = { reacted -> /* Giggle or Love */ })
```

```swift
BotView(state: state, touchReactions: true, onTouch: { reacted in /* .giggle or .love */ })
```

Pass `touchReactions = false` to turn it off.

## Body shape

```kotlin
style = BotStyle(shape = BotShape.Round)          // Teardrop (default), Round, Egg, Blob, Blossom, Squircle
style = BotStyle(shape = BotShape.svg("M20 40C20 10 80 10 80 40C95 55 85 95 50 95C15 95 5 55 20 40Z"))
```

```swift
BotStyle(shape: .round)
BotStyle(shape: .svg("M20 40C20 10 80 10 80 40C95 55 85 95 50 95C15 95 5 55 20 40Z"))
```

`svg` takes the first sub-path of any SVG path string (`M L H V C S Q Z`, absolute or relative, any
units, no arcs). It is scaled to fit and stands on the ground. A bad path falls back to the teardrop.
Fur, shading and the feather pin follow the shape.

## Custom face

Build any state by passing your own face through the style. A custom face replaces the state's face
(motion still follows `state`).

```kotlin
style = BotStyle(customFace = BotFaceSpec(
    eyes = BotEyes.Star, mouth = BotMouth.Open, eyeScale = 1.2f, eyeTilt = -0.4f))
```

```swift
BotStyle(customFace: BotFaceSpec(
    eyes: .star, mouth: .open, eyeScale: 1.2, eyeTilt: -0.4))
```

Eyes: Oval, ArcUp, ArcDown, Heart, Star, Cross, Slit. Mouth: None, Smile, Grin, Open, O, Flat, Frown,
Wavy, Dot, Talk (Swift spells the empty mouth `.none`). `eyeTilt` runs -1 (angry) to 1 (sad) and turns
oval and slit eyes. Also: `eyeScaleRight`, `lookX`, `lookY`, `mouthScale`, `mouthShift`.

## Parity

Both ports share the same sim constants (seeded mulberry32, hop, blink, gaze, feather spring), body path and
shading. Fur is a close approximation of the web version, not a pixel match. Animation stops when the system
reduces motion. Leave room above the head for the feather.
