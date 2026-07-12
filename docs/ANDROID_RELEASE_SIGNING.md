# Android release signing and CI

Android release artifacts must use a private upload keystore. The project will
fail a release build when `android/key.properties` is missing, rather than
silently signing with the debug certificate.

## Local release build

Store the keystore outside the repository. Create `android/key.properties`
(which is ignored by Git):

```properties
storeFile=C:\\secure-path\\upload-keystore.jks
storePassword=<keystore-password>
keyAlias=<key-alias>
keyPassword=<key-password>
```

Then build with the photo-service configuration when it is available:

```powershell
flutter build apk --release `
  --dart-define=API_BASE_URL=https://<backend-host> `
  --dart-define=API_KEY=<scoped-client-key>
```

The app deliberately works in manual, local-only mode without these two
`dart-define` values. A beta candidate intended to test photo analysis must
include them.

## GitHub Actions secrets

The `Signed Android release build` job runs on pushes to `main` and manual
workflow runs. It fails clearly until all values below are configured; after
that it validates a real signed APK and uploads it as a workflow artifact.

| Type | Name | Value |
| --- | --- | --- |
| Repository variable | `PHOTO_FOOD_API_BASE_URL` | Production/staging backend base URL. |
| Repository secret | `ANDROID_KEYSTORE_BASE64` | Base64 encoding of the upload `.jks` file. |
| Repository secret | `ANDROID_KEYSTORE_PASSWORD` | Keystore password. |
| Repository secret | `ANDROID_KEY_ALIAS` | Alias of the upload key. |
| Repository secret | `ANDROID_KEY_PASSWORD` | Alias password. |
| Repository secret | `GOOGLE_SERVICES_JSON_BASE64` | Base64 encoding of Firebase `google-services.json`. |
| Repository secret | `PHOTO_FOOD_CLIENT_API_KEY` | A backend key limited to this mobile client. |

Never use a server-admin key as `PHOTO_FOOD_CLIENT_API_KEY`: values compiled
into an APK can be extracted. Restrict this credential by permissions, quota,
and rotation policy on the backend.
