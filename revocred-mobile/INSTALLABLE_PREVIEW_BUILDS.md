# Installable Preview Builds (Expo Go not required)

Use this when you want a real installable build instead of scanning a development QR code.

## 1) Log in to Expo/EAS

```bash
cd /workspace/revocred-mobile
npx eas-cli login
```

## 2) Link this app to your Expo account (first time only)

```bash
npx eas-cli init
```

Accept defaults when prompted.

## 3) Build an Android installable APK (preview)

```bash
npm run build:android:preview
```

When the build finishes, Expo gives you a download link for an APK you can install directly on Android.

## 4) Build iOS for TestFlight

```bash
npm run build:ios:testflight
```

After build completes, submit to TestFlight:

```bash
npm run submit:ios:testflight
```

You need an Apple Developer account for TestFlight distribution.

## Optional: production builds

- Android store bundle (AAB):

  ```bash
  npx eas-cli build --platform android --profile production
  ```

- iOS production:

  ```bash
  npx eas-cli build --platform ios --profile production
  ```
