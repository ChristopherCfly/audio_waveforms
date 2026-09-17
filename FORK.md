# Fork of `SimformSolutionsPvtLtd/audio_waveforms`

This repository is a fork of [SimformSolutionsPvtLtd/audio_waveforms](https://github.com/SimformSolutionsPvtLtd/audio_waveforms) (MIT License, Copyright (c) 2022 Simform Solutions). The original `LICENSE` and copyright notice are preserved unchanged.

**Why this fork exists:** the published package (2.0.2) pins `compileSdk 34`, Java `1.8`, Kotlin `1.8.20`, an AGP `8.1.0` classpath, a Gradle `8.0` wrapper, an iOS `8.0` podspec floor, and — most consequentially — the retired pre-Media3 ExoPlayer artifact for playback. The Cinefly app (cinefly/cinefly_app_flutter_v2, issue #885) must reach compileSdk 37 / AGP 9 (#883) and Swift Package Manager, none of which the published package can satisfy. Upstream is comparatively healthy (last push 2026-07-01) but not keeping pace; `main` was identical to the published version in every respect that matters at fork time, so there was no unreleased fix to pull.

Consumed by the app as a **direct dependency** pinned to a full commit SHA (unlike the sibling `video_thumbnail` fork, no `dependency_overrides` gymnastics are needed).

## Changes vs upstream 2.0.2

### Android (`android/`)

| Property | Upstream 2.0.2 | Fork |
|---|---|---|
| `compileSdk` | 34 | **37** |
| `minSdk` | `minSdkVersion 21` | `minSdk 24` (matches consuming app) |
| Java source/target | 1.8 | **17** |
| Kotlin `jvmTarget` | 1.8 | **17** |
| Kotlin plugin | `ext.kotlin_version = 1.8.20` classpath pin | removed from the module; standalone builds resolve `org.jetbrains.kotlin.android` **2.4.20** via `settings.gradle` `pluginManagement` (matches consuming app) |
| AGP pin | `8.1.0` classpath in plugin | removed — the consuming app's AGP governs when included as a subproject; standalone builds resolve AGP **9.4.0** via `pluginManagement` |
| Gradle wrapper | 8.0 | **9.7.1** (generated with local Gradle; committed) |
| `namespace` | conditional (`hasProperty` guard for pre-AGP-7 consumers) | unconditional |
| `buildscript {}` / `rootProject.allprojects {}` | present | **deleted entirely** (inert legacy cruft when consumed by a Flutter app) |
| Player library | retired pre-Media3 ExoPlayer artifact 2.17.1 | **androidx.media3** `media3-exoplayer` + `media3-common` 1.11.1 |
| `androidx.multidex` | 2.0.1 | **removed** (multidex is native from API 21; the module now sits at minSdk 24) |

The `plugins {}` block is now the first statement in `android/build.gradle` (group/version below it), as required when the consuming app's AGP is injected via `pluginManagement`.

#### Built-in Kotlin gate (consuming-app issue #905)

`org.jetbrains.kotlin.android` is no longer applied unconditionally. From AGP 9 onward Kotlin may be compiled by AGP's **built-in Kotlin**, and applying KGP on top of that is a hard error. The apply is now guarded:

```groovy
def agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.tokenize('.')[0] as int
def builtInKotlin = project.findProperty('android.builtInKotlin')?.toString()?.toBoolean() ?: false
if (agpMajor < 9 || !builtInKotlin) {
    apply plugin: 'kotlin-android'
}
```

The `android.builtInKotlin` half of that condition is the part that matters. Gating on `agpMajor < 9` alone — which is what `stripe_android` 14.0.x does — is not enough, because a consuming app can be on AGP 9 while still running `android.builtInKotlin=false`. That is precisely what Flutter 3.47's own `flutter create` template ships. In that combination the guarded-out module leaves `jvmTarget` unset, KGP lets it track the JDK running Gradle, and AGP 9's target-consistency validation fails the consumer's build.

The `kotlinOptions { jvmTarget = '17' }` block that lived inside `android {}` was replaced with a guarded `kotlin { compilerOptions { jvmTarget } }` block outside it, for the same reason: under built-in Kotlin the `kotlin` extension does not exist, and AGP derives the target from `compileOptions.targetCompatibility` instead.

**Standalone module builds are not fully supported** (same as upstream): the plugin compiles against `io.flutter:flutter_embedding_*` and the androidx classpath supplied by the consuming Flutter app. Verification is done through the consuming app's build (`flutter build appbundle`), not `cd android && ./gradlew assemble`. The `settings.gradle` `pluginManagement`/`dependencyResolutionManagement` blocks are provided so tooling that resolves the module in isolation still finds repositories (AGP 9's injected `kotlin-stdlib` needs a declared resolver).

### Media3 migration decision record

The upstream dependency on the retired ExoPlayer 2 line (`2.17.1`, years behind even within that dead line) was replaced with AndroidX Media3 1.11.1 — Google's supported successor. This is the substantive change of the fork and is kept as a **separate commit** so it can be reverted independently if audio regresses.

- `AudioPlayer.kt` was the only file touching the old package root. The migration is 1:1 at the API level: `ExoPlayer.Builder`, `MediaItem.fromUri`, `prepare`, `seekTo`, `play`/`pause`/`stop`/`release`, `volume`, `setPlaybackSpeed`, `Player.Listener` and `PlaybackException` all exist under `androidx.media3.*` with the same semantics.
- The deprecated `onPlayerStateChanged(playWhenReady, state)` callback was replaced with `onPlaybackStateChanged(state)`. The old first parameter was misnamed `isReady` (it is `playWhenReady`) and was unused, so the `STATE_READY`/`STATE_ENDED` logic is unchanged.
- The app's only consumer (`lib/features/audio_recorder/data/audio_recorder_controller.dart` in the app repo) exercises the **recording** side only (`RecorderController`, `RecorderSettings`, the `AudioWaveforms` widget); the player side is migrated for package correctness.
- **Residual risk:** Media3 changed internal buffering/threading defaults versus the 2.17.1 player. Recording, live waveform rendering, playback/scrubbing, and a background/foreground cycle must be smoke tested on physical Android hardware.

### iOS (`ios/`)

- Added `ios/audio_waveforms/Package.swift` following the Flutter SPM plugin layout (swift-tools-version 5.9; library name `audio-waveforms`; the `FlutterFramework` path dependency is rewritten by `flutter_tools` at integration time, exactly as templated).
- Sources moved from `ios/Classes/` to `ios/audio_waveforms/Sources/audio_waveforms/`.
- **The ObjC registration shim (`AudioWaveformsPlugin.h/.m`) was removed and the pubspec iOS `pluginClass` now points directly at the Swift class `SwiftAudioWaveformsPlugin`.** SPM does not support a target with mixed Swift and Objective-C source files ("mixed language source files; feature not supported"), and an ObjC→Swift dependency across SPM targets is not possible either. The canonical Flutter SPM pattern (see `flutter_tools`' `plugin_darwin_spm` template and `path_provider_foundation`) is a Swift plugin class: the generated registrant falls back to `@import audio_waveforms;`, which exposes the Swift `NSObject`/`FlutterPlugin` class to ObjC. This works identically under CocoaPods, so the shim was dead weight in both integrations.
- The podspec is **kept** so CocoaPods consumers are not broken; its `source_files` now point at the new Swift-only layout.
- Podspec deployment target raised `8.0` → **15.0** (matches consuming app; iOS 8 is not a supportable floor).
- Podspec placeholder metadata fixed (summary/homepage/author).
- No external native pod dependencies (unlike the `video_thumbnail` fork's libwebp entanglement), so the SPM conversion is mechanical — nothing to gate.
- Four Swift files (`AudioPlayer.swift`, `AudioRecorder.swift`, `RecorderBytesStreamEngine.swift`, `WaveformExtractor.swift`) had `import Flutter` added: under CocoaPods they received Flutter symbols implicitly through the pod's ObjC umbrella header (underlying-module import); SPM has no such mechanism, so each file referencing `FlutterError`/`FlutterMethodChannel` must import Flutter explicitly.
- The macOS implementation (`macos/`) is untouched and keeps its own ObjC plugin class.

### Dart package

- Version bumped `2.0.2` → `2.0.3`; `repository`/`homepage`/`issue_tracker` point at the fork.
- `environment.sdk` was already `>=3.0.0 <4.0.0` — no widening required.
- The unreleased upstream 2.1.0 macOS work present on `main` is retained untouched.

## Retiring this fork

This fork is meant to be temporary. Upstream is active, so this fork has a realistic chance of retirement: if `SimformSolutionsPvtLtd/audio_waveforms` ships compileSdk 37 / AGP 9 / Media3 / SPM support, the app should switch back and this fork be retired.

**Deviation note:** the originating issue (#885) listed "a PR has been opened against upstream" as an acceptance criterion. **No upstream PR is opened from this fork by explicit owner decision** — the fork exists for consumption, not contribution, and upstream contributions are out of scope by repo-owner policy.
