# iSign FSL

An offline AI-driven Filipino Sign Language (FSL) recording and translation system with cloud sync and admin panel.

## Architecture

```
isign/
├── lib/                      # Flutter mobile app (Android/iOS)
├── admin/                    # Flutter web admin panel
├── packages/isign_shared/    # Shared models & services
├── android/                  # Android native config
├── assets/                   # Images, models, seed data
└── test/
```

## Features

### Mobile App
- **Offline FSL Translation**: Real-time sign language recognition using MediaPipe + TensorFlow Lite
- **Training Module**: Record custom signs with 5-sample training per sign
- **Cloud Sync**: Bidirectional Firestore sync (catalog, recordings, user data)
- **Background Upload**: WorkManager for WiFi/mobile uploads
- **Multi-language**: Filipino/English support

### Admin Panel (Flutter Web)
- **Catalog Management**: CRUD for sign catalog with categories
- **User Recordings Review**: Approve/reject community submissions
- **CSV Export**: Export recordings for dataset building
- **Auto-delete Config**: Configurable cleanup of rejected recordings
- **Real-time Dashboard**: Live stats from Firestore

### Shared Package
- **Models**: `FslSignModel`, `CategoryModel`, `UserRecording`, `SignCatalogEntry`
- **Services**: `SignTranslator`, `AppSettings`

## Prerequisites

- Flutter SDK 3.44.4 (stable)
- Dart 3.12.2
- Java 17 (for Android)
- Android SDK with NDK 28.2.13676358
- Firebase project: `isign-fsl`
- Git

## Quick Start

### 1. Clone & Setup
```bash
git clone <repo-url>
cd isign
flutter pub get
cd admin && flutter pub get && cd ..
cd packages/isign_shared && flutter pub get && cd ../..
```

### 2. Firebase Configuration
```bash
# Android: Add google-services.json to android/app/
# iOS: Add GoogleService-Info.plist to ios/Runner/
# Admin: Uses firebase.json config (project: isign-fsl)
```

### 3. Run Mobile App
```bash
flutter run
# Or for release:
flutter build apk --release
```

### 4. Run Admin Panel (Web)
```bash
cd admin
flutter run -d chrome
# Or build for deployment:
flutter build web --release
firebase deploy --project isign-fsl --only hosting:admin
```

## Configuration Files

| File | Purpose |
|------|---------|
| `firebase.json` | Firebase Hosting config (admin panel) |
| `firestore.rules` | Firestore security rules |
| `firestore.indexes.json` | Firestore composite indexes |
| `android/app/build.gradle.kts` | Android build config + signing |
| `admin/firebase.json` | Admin panel hosting config |

## Category Mapping (Mobile + Admin)

| ID | Filipino | English |
|----|----------|---------|
| 0 | Alpabeto | Alphabet |
| 1 | Mga Karaniwang Parirala | Common Phrases |
| 2 | Mga Bilang | Numbers |
| 3 | Mga Pangunahing Galaw | Basic Gestures |

## Signing Configuration

### Local Development
Create `android/key.properties` (gitignored):
```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=isign
storeFile=../key.jks
```

### CI/CD (GitHub Actions)
Add these secrets in GitHub repo settings:
- `KEYSTORE_PASSWORD`
- `KEY_PASSWORD`
- `KEY_ALIAS` (default: `isign`)
- `FIREBASE_SERVICE_ACCOUNT` (from `firebase login:ci`)

## Cloud Sync Mechanism

1. **Upload (Step 2)**: Local `fsl_signs` → Firestore `catalog` collection
2. **Download (Step 3)**: Firestore `catalog` → Local `fsl_signs` + `categories`
3. **Category Mapping**: Cloud categoryId (0-3) ↔ Local categories table
4. **Background**: WorkManager uploads approved recordings every 15min (WiFi) / 30min (mobile)

## Deployment

### Mobile (Google Play)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Admin Panel (Firebase Hosting)
```bash
cd admin && flutter build web --release
firebase deploy --project isign-fsl --only hosting:admin
# Live at: https://isign-fsl.web.app/
```

### GitHub Actions CI/CD
- **mobile-build.yml**: Builds APK/AAB on push/PR
- **admin-deploy.yml**: Deploys admin on push to main (admin/ changes)
- **test.yml**: Runs analyze + tests on all pushes

## Project Structure Details

### Mobile App (`lib/`)
```
lib/
├── ai/                     # MediaPipe + TFLite integration
├── data/
│   ├── database/           # SQLite (DbHelper, migrations)
│   ├── models/             # FslSignModel, CategoryModel
│   └── repositories/       # TrainingRepository
├── features/
│   ├── settings/           # SettingsScreen (cloud sync UI)
│   ├── signs/              # SignsScreen (catalog browser)
│   ├── training/           # SignRecorderScreen
│   └── translation/        # TranslationScreen
└── shared/services/        # SyncService, TrainingUploadService
```

### Admin Panel (`admin/lib/`)
```
admin/lib/
├── screens/
│   ├── catalog_screen.dart       # Sign catalog CRUD
│   ├── user_recordings_screen.dart  # Recording review (needs fix)
│   ├── dashboard_home_screen.dart   # Stats dashboard
│   └── recordings_screen.dart    # Legacy recordings view
└── main.dart
```

## Known Issues

1. **Mobile Windows Build**: `dartcv4` (OpenCV) native build fails on Windows due to CMake/ninja permissions. Works on Linux/macOS and CI/CD (Ubuntu).
2. **Admin Panel**: `user_recordings_screen.dart` has corrupted/incomplete code - needs rewrite.

## Contributing

1. Fork the repo
2. Create feature branch: `git checkout -b feature/name`
3. Run checks: `flutter analyze && flutter test`
4. Commit: `git commit -m "feat: description"`
5. Push & create PR

## License

Proprietary - iSign FSL Project

## Support

- Email: isignfsl@gmail.com
- Firebase Project: isign-fsl
- Admin Panel: https://isign-fsl.web.app/