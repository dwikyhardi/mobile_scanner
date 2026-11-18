# MONIT-2031: scanner fork migration

## Sources and upstream choice

Inspected both fork sources before rebasing:

- `improve`: `256e44f98a7ba2f3c44baf761e1a2592b5f73792`, based on upstream
  `2c51a37` (7.2.0-era master).
- QRIS `0d9a516c7fe2a6a94ac140a1c9a6b5b15892f5a6` pins scanner
  `c7e0210400f997dfa30454078ec41cfb85aa45ad`. Fetched that exact object from
  the fork; it is outside `improve` and contains the gallery API and its test.
  Its upstream parent is `7d8936e4168e53e06c5b8c0e8fe37bd0ee7c5a86`.

Upstream is <https://github.com/juliansteenbakker/mobile_scanner>.
On 2026-11-18 its default branch is `develop`, at
`676312ed7a89acdbc4d256ec0c198409474fc8c4`. Selected that current default
instead of release-only master `e77c618782bb982f9559de810140f4d6bc27f8e1`:
both contain 7.5.0, and develop additionally fixes camera start/stop/pause
serialization, CameraX lint, web resume, and inline muted preview playback.

Replayed `c7e0210` onto that upstream base on
`feat/MONIT-2031-rebase-mobile-scanner`, then restored the remaining fork
configuration. `improve`, `master`, remote-tracking refs, and the original
checkout were not changed. No workflow files were edited relative to upstream.

## Fork patch inventory

| Original commits | Intent | Result |
| --- | --- | --- |
| `4057db3c`, `76c1cc70`, `f7ebe34f` | Public `addBarcode`, null/closed-stream guard and documentation | Preserved through the equivalent `c7e0210` patch; expanded docs/tests |
| `4057db3c`, `c7e0210` | `plugin_platform_interface: ^2.1.8` | Preserved |
| `bbd10a50` | Newer example SDK, image_picker and lint requirements | Superseded by higher upstream SDK/analysis requirements; image_picker remains at the fork's `^1.2.0` |
| `e07ec014` | Bundled ML Kit barcode scanning 17.3.0 | Already upstream, retained in `android/build.gradle.kts` |
| `5f466516` | FVM config/ignore, image_picker 1.2.0, scoped meta import | Retained; FVM updated from 3.35.3 to requested 3.50.0 |
| `c7e0210` | Gallery API and test on upstream 7.4.2 | Rebased without conflicts; initial `git range-diff 7d8936e4..c7e0210 676312ed..9769a00f` reports identical patches |

The net `improve` delta against its upstream parent was five files: FVM config,
ignore, example image_picker, controller API/meta alias and dependency floor.
There were no additional fork-only Android/Gradle/Kotlin changes to transplant.
Current upstream Kotlin DSL, Java 17, CameraX, AGP/Kotlin handling and Darwin
plugin registration remain intact.

## Consumer compatibility

- `MobileScannerController.addBarcode(BarcodeCapture?)` keeps its signature and
  behavior. It delivers the same object to active broadcast-stream listeners
  and `MobileScanner.onDetect`, without requiring a running camera. Null and
  calls during/after disposal are ignored; events are not replayed.
- QRISController constructor parameters, `analyzeImage`, `barcodes`,
  `BarcodeCapture` and barcode exports used by QRIS remain available. The
  inspected gallery path still calls `analyzeImage` then `addBarcode`.
- Source, tests and examples import `package:material_ui/material_ui.dart`.
  Direct dependency: stable `material_ui ^1.11.1`; `cupertino_ui 1.1.7` resolves
  transitively. There are no direct Cupertino imports needing a dependency.
- Package and example SDK floors are Dart 3.13 / Flutter 3.47, matching the
  extracted UI packages. Development uses Flutter 3.50.0 through FVM.
- The example gallery button now publishes results through `addBarcode`.
- Upstream's Android plugin requires minSdk 23, compileSdk 36 and Java 17;
  its example uses minSdk 24, compile/targetSdk 37, AGP 9.4.1, Kotlin 2.4.20
  and Gradle 9.8.0. Darwin SPM and CocoaPods package support are retained;
  the upstream iOS example uses SPM and targets iOS 15.
- QRIS should retain its committed git pin and use a temporary, untracked
  `pubspec_overrides.yaml` pointing `mobile_scanner` at this worktree until
  publishing is separately approved. No package was published or pushed.

## Validation

Using FVM Flutter 3.50.0 / Dart 3.14.0:

- `fvm flutter pub get` succeeds for package and example, resolving
  material_ui 1.11.1 and cupertino_ui 1.1.7.
- `fvm flutter test`: 407 passing package tests, including controller session
  ownership/start/disposal, lens switching, method channels and overlays.
- Gallery regression tests cover two listeners, ignored nulls, ignored events
  during/after disposal, and mocked `analyzeImage` -> `addBarcode` -> `onDetect`
  delivery exactly once without starting the camera.
- Example `fvm flutter test`: 10 passing widget tests.
- `fvm flutter test --platform chrome test/web`: 60 passing browser tests.
- `fvm flutter analyze --no-fatal-infos`: no errors or warnings; 134
  informational notices in existing code (120 constructor type names,
  11 enum constructor const modifiers, two unnecessary unawaited calls,
  one null-aware element). Default fatal-infos analysis reports those notices;
  they were not suppressed or expanded into unrelated cleanup.
- FVM Dart formatting check passes for all 31 changed Dart files.
- `git diff --check` passes; no legacy Material/Cupertino imports remain.
- `fvm flutter build ios --no-codesign --debug`: succeeds with Xcode 27.1.
- `fvm flutter build web`: succeeds, including Wasm dry run.
- `fvm flutter build apk --debug`: succeeds. Gradle installed the example's
  required Android SDK Platform 37.0 automatically.
- From `example/android`, `./gradlew :mobile_scanner:testDebugUnitTest
  :mobile_scanner:lintDebug --console=plain`: succeeds; 57 Android unit tests
  pass (12 scanner, nine auto-torch, 36 lens selection). Lint reports zero
  errors and four dependency-update warnings. Existing Flutter/AGP/Kotlin and
  JUnit Vintage deprecation messages remain; no suppressions were added.

- macOS build was attempted, including a command-local `FLUTTER_MACOS=true`
  retry. Flutter refuses the build because macOS desktop is disabled in its
  configuration. No macOS build or runtime behavior is claimed as verified.

Review: no outstanding correctness findings in the fork/migration diff. The
original gallery patch was preserved exactly before test/doc expansion, and a
final comparison confirms its method body is still identical. Native and CI
files have no fork-specific edits relative to the chosen upstream base.

Unit/widget and mocked browser tests do not verify real camera, gallery,
permissions, orientation or torch behavior on devices.
