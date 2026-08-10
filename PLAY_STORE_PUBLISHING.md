# Google Play Store Publishing Guide

This guide describes the process of preparing, signing, and submitting the **Semitone Web** Android app to the Google Play Store.

---

## Prerequisites

1. **Google Play Console Account**
   You need a Google Play Console developer account. If you do not have one, register at the [Google Play Console](https://play.google.com/console/signup) (requires a one-time $25 registration fee).

2. **Google Play App Signing**
   Google Play manages your app signing key. To publish on Google Play, you must upload your application as an **Android App Bundle (`.aab`)**, which Google uses to generate optimized APKs for different device architectures.

---

## 1. Generating a Signing Keystore

You need an **upload key** (also called a keystore) to sign your app bundles before uploading them to the Play Console. Google Play will verify the upload signature and replace it with the app signing key.

To generate a secure Java Keystore (JKS), run the following command in your terminal:

```sh
keytool -genkey -v -keystore android/release.keystore \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

*Note: Keep this keystore safe! If you lose your upload key, you will have to request a reset from Google Play Console support.*

---

## 2. Setting Up GitHub Actions Secrets for Automated Builds

Our CI/CD workflow is already configured to automatically sign and bundle the app if the correct repository secrets are present. To set this up:

1. Convert your `release.keystore` file to a Base64 string so it can be stored securely:
   ```sh
   # On macOS/Linux:
   base64 -i android/release.keystore | pbcopy  # or output to a file and copy
   ```
2. Navigate to your GitHub repository: **Settings > Secrets and variables > Actions**.
3. Create the following **Repository Secrets**:
   - `ANDROID_KEYSTORE_BASE64`: The full Base64-encoded string of your `release.keystore`.
   - `ANDROID_KEYSTORE_PASSWORD`: The password you set when creating the keystore.
   - `ANDROID_KEY_ALIAS`: The alias you specified during creation (e.g., `upload`).
   - `ANDROID_KEY_PASSWORD`: The password for the key alias (usually the same as the keystore password).

Once these secrets are set, any run of the **Release** workflow (e.g., when pushing a version tag like `v1.2.3`) will build, sign, and package a release-ready Android App Bundle (`.aab`) and attach it to your GitHub Release.

---

## 3. Local Building and Signing (Optional)

If you need to build and sign the Android App Bundle locally instead of using GitHub Actions:

1. Create a `key.properties` file in the `android/` directory (this is gitignored to protect your credentials):
   ```properties
   storeFile=release.keystore
   storePassword=your_keystore_password
   keyAlias=your_key_alias
   keyPassword=your_key_password
   ```
2. Ensure `release.keystore` is placed in the `android/` directory as well.
3. Run the Flutter build command to output the `.aab` package:
   ```sh
   flutter build appbundle --release
   ```
4. The generated bundle will be located at:
   `build/app/outputs/bundle/release/app-release.aab`

---

## 4. Creating the App in Google Play Console

1. Log into the [Google Play Console](https://play.google.com/console).
2. Click **Create app** (top right).
3. Fill in the basic details:
   - **App name**: Semitone Web
   - **Default language**: English (or your preferred default)
   - **App or game**: App
   - **Free or paid**: Free
4. Accept the developer declarations and click **Create app**.

---

## 5. Setting Up Your Store Listing

Before you can publish, complete the mandatory checklist under **Set up your app**:
1. **App access**: Indicate whether parts of your app are restricted.
2. **Ads**: Confirm that Semitone Web is ad-free.
3. **Content rating**: Complete the questionnaire (typically Utility/Tool).
4. **Target audience**: Specify age groups (e.g., All ages or 13+).
5. **News apps**: Declare that this is not a news app.
6. **Data safety**: Complete the questionnaire. Since the app only requests microphone access for local DSP/tuning and does not transmit data, declare that no data is collected or shared.
7. **Government apps**: Declare this is not a government-owned app.
8. **Select an app category**: Set to **Music & Audio** (under Application).
9. **Set up store listing**:
   - **Short description**: A minimal and pitch-perfect tuner and metronome for custom scales.
   - **Full description**: Use the descriptive features list from `README.md`.
   - **Graphics & Screenshots**: Upload an app icon (512x512 PNG), feature graphic (1024x500 JPG/PNG), and at least two screenshots of the app running on phone/tablet formats.

---

## 6. Uploading and Releasing the App Bundle

We recommend deploying to an **Internal testing** track or **Closed testing** track first to verify everything before general production:

1. Under the **Release** section in the left sidebar, click on **Testing > Internal testing** (or **Production** if going straight to live).
2. Click **Create new release**.
3. Under **App bundles**, upload the `.aab` file generated either locally or via the GitHub Actions Release run (e.g., `semitone-web-v1.0.0-...aab`).
4. Enter a **Release name** and provide **Release notes** (e.g., listing the features or bug fixes).
5. Click **Next**, review the release details, and click **Save**.
6. When ready, click **Start rollout to Internal testing** (or **Publish**).

---

## Troubleshooting

- **Microphone Permissions (Android 6.0+)**: The app uses the microphone for tuning. The `record` plugin handles requesting runtime permissions. Ensure the permission is declared in your `android/app/src/main/AndroidManifest.xml` (which is already configured by default).
- **Version and Build Numbers**: To update the version displayed on the Play Store, modify the `version: x.y.z+n` field in `pubspec.yaml` or pass `--build-name` and `--build-number` parameters to your build commands.
