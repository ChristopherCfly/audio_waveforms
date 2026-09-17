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

**Standalone module builds are not fully supported** (same as upstream): the plugin compiles against `io.flutter:flutter_embedding_*` and the androidx classpath supplied by the consuming Flutter app. Verification is done through the consuming app's build (`flutter build appbundle`), not `cd android && ./gradlew assemble`. The `settings.gradle` `pluginManagement`/`dependencyResolutionManagement` blocks are provided so tooling that resolves the module in isolation still finds repositories (AGP 9's injected `kotlin-stdlib` needs a declared resolver).

### Media3 migration decision record

The upstream dependency on the retired ExoPlayer 2 line (`2.17.1`, years behind even within that dead line) was replaced with AndroidX Media3 1.11.1 — Google's supported successor. This is the substantive change of the fork and is kept as a **separate commit** so it can be reverted independently if audio regresses.

- `AudioPlayer.kt` was the only file touching the old package root. The migration is 1:1 at the API level: `ExoPlayer.Builder`, `MediaItem.fromUri`, `prepare`, `seekTo`, `play`/`pause`/`stop`/`release`, `volume`, `setPlaybackSpeed`, `Player.Listener` and `PlaybackException` all exist under `androidx.media3.*` with the same semantics.
- The deprecated `onPlayerStateChanged(playWhenReady, state)` callback was replaced with `onPlaybackStateChanged(state)`. The old first parameter was misnamed `isReady` (it is `playWhenReady`) and was unused, so the `STATE_READY`/`STATE_ENDED` logic is unchanged.
- The app's only consumer (`lib/features/audio_recorder/data/audio_recorder_controller.dart` in the app repo) exercises the **recording** side only (`RecorderController`, `RecorderSettings`, the `AudioWaveforms` widget); the player side is migrated for package correctness.
- **Residual risk:** Media3 changed internal buffering/threading defaults versus the 2.17.1 player. Recording, live waveform rendering, playback/scrubbing, and a background/foreground cycle must be smoke tested on physical Android hardware.

### iOS (`ios/`)

- Added `ios/audio_waveforms/Package.swift` following the Flutter SPM plugin layout (swift-tools-version 5.9; library name `audio-waveforms`; the `FlutterFramework` path dependency is rewritten by `flutter_tools` at integration time, exactly as templated).
- Sources moved from `ios/Classes/` to `ios/audio_waveforms/Sources/audio_waveforms/`, with the public ObjC header under `include/` (`publicHeadersPath`).
- The podspec is **kept** so CocoaPods consumers are not broken; its `source_files`/`public_header_files` now point at the new layout.
- Podspec deployment target raised `8.0` → **15.0** (matches consuming app; iOS 8 is not a supportable floor).
- Podspec placeholder metadata fixed (summary/homepage/author).
- No external native pod dependencies (unlike the `video_thumbnail` fork's libwebp entanglement), so the SPM conversion is mechanical — nothing to gate.

### Dart package

- Version bumped `2.0.2` → `2.0.3`; `repository`/`homepage`/`issue_tracker` point at the fork.
- `environment.sdk` was already `>=3.0.0 <4.0.0` — no widening required.
- The unreleased upstream 2.1.0 macOS work present on `main` is retained untouched.

## Retiring this fork

This fork is meant to be temporary. Upstream is active, so this fork has a realistic chance of retirement: if `SimformSolutionsPvtLtd/audio_waveforms` ships compileSdk 37 / AGP 9 / Media3 / SPM support, the app should switch back and this fork be retired.

**Deviation note:** the originating issue (#885) listed "a PR has been opened against upstream" as an acceptance criterion. **No upstream PR is opened from this fork by explicit owner decision** — the fork exists for consumption, not contribution, and upstream contributions are out of scope by repo-owner policy.
