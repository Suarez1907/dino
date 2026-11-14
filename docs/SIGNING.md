# Android signing

Package name: `com.akincolak.dinokazi`.

The export preset is `godot/export_presets.cfg`.

- Architectures: `arm64-v8a` only
- Gradle build: on, so the SDK fields are real
- `gradle_build/min_sdk` = `24`
- `gradle_build/target_sdk` = `35`
- Debug keystore fields are empty on purpose. Godot uses the editor debug keystore, or the `GODOT_ANDROID_KEYSTORE_DEBUG_*` environment variables.

Godot 4.7's Gradle template still **compiles** against Android 36 (`compileSdk` / build-tools `36.1.0`). Target SDK 35 is the level the app declares. CI installs platform 36 for the compiler and leaves min/target to the preset.

Internet permission is off. Debug exports may still add `INTERNET` so the Godot debugger can attach. Release exports keep it off. `VIBRATE` is on for the haptic toggle.

## Debug APK (local)

1. Install Godot **4.7.2** and the matching export templates.
2. Install JDK 17 and the Android SDK. In Editor Settings → Export → Android, set the JDK path, SDK path, and debug keystore (`androiddebugkey` / `android`).
3. Open `godot/` and install the Android build template if Godot asks (`Project → Install Android Build Template`).
4. Export the preset named `Android` with debugging on, or from a shell:

```bash
cd godot
godot --headless --export-debug "Android" build/dino-kazi-debug.apk
```

## Debug APK (GitHub Actions)

`.github/workflows/android-debug.yml` uses `barichello/godot-ci:4.7.2`, installs Android platform 36, and uploads `dino-kazi-debug-apk`. It runs on every push to `main`, on pull requests into `main`, and from the Actions tab (`workflow_dispatch`). The debug keystore baked into that image is `/root/debug.keystore` (`androiddebugkey` / `android`). Do not ship that keystore to Play. No repository secrets are required for this debug job.

## Release keystore

Create a keystore once and store it outside the repo:

```bash
keytool -genkeypair -v \
  -keystore release.keystore \
  -alias dinokazi \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$STORE_PASS" -keypass "$KEY_PASS" \
  -dname "CN=Dino Kazi, O=Akin Colak, C=TR"
```

Never commit `release.keystore`. Add these GitHub Actions secrets if you add a release job:

| Secret | Value |
| --- | --- |
| `GODOT_ANDROID_KEYSTORE_RELEASE_B64` | `base64 -w 0 release.keystore` |
| `GODOT_ANDROID_KEYSTORE_RELEASE_USER` | alias, for example `dinokazi` |
| `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` | store and key password |

Godot reads the path from `GODOT_ANDROID_KEYSTORE_RELEASE_PATH` (and `_USER` / `_PASSWORD`). A release job should decode the secret to a file, point the path env var at it, and run:

```bash
godot --headless --export-release "Android" build/dino-kazi-release.apk
```

Play App Signing can hold the app signing key. The upload key is the one in this keystore. If the upload key leaks, you can rotate it with Google. You cannot rotate a key that was pasted into a public repository, so keep the file and the passwords in a password manager.
