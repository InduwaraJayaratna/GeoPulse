# GeoPulse

**Geofenced Smart Field Operations Platform** — a native iOS app for mobile field professionals (site engineers, safety inspectors, facilities technicians) that binds inspection and maintenance tasks directly to physical GPS geofences. On arrival at a job site, the app surfaces that site's pending tasks, fetches localised weather, runs on-device hazard classification on captured photos, and automatically escalates safety alerts when motion sensors detect a fall.

---

## Core workflow

1. **Arrival** — iPhone detects geofence entry via `CLCircularRegion` and raises a time-sensitive local notification with that site's open tasks.
2. **Inspection** — Worker opens a task, captures a photo via the native camera, and an on-device `VNClassifyImageRequest` flags likely hazards (corrosion, cracks, exposed wiring, fluid leaks, debris, smoke) with a confidence score.
3. **Hands-free log** — Voice note is transcribed live via `SFSpeechRecognizer` while the worker continues working.
4. **Review & save** — Review screen shows the real captured hazard + transcript. Signing writes an `Inspection` record to Core Data (survives relaunch) and publishes it to the team activity feed.
5. **Report** — Share PDF Report renders a one-page audit document via `ImageRenderer` and hands it to the system share sheet.
6. **Safety** — While lone-worker monitoring is on, Core Motion watches for a fall-pattern event. A full-screen 30-second countdown appears; if uncancelled, a critical alert and last-known location escalate to the nominated contact.

---

## Architecture

MVVM-ish with dependency-injected services. `AppState` is the single `ObservableObject` root; services are stored on it as `let` properties so they're trivially swappable in tests.

```
Geo Pulse/
├── Theme/              AppColors, AppTypography
├── Components/         Reusable UI (CardContainer, StatusBadge, PrimaryButton,
│                       SectionHeader, AppTopBar, CameraPicker)
├── Models/
│   ├── Site, FieldTask, Inspection, UserProfile
│   └── InspectionDraft (in-flight data between Inspect ⇄ Review)
├── Services/
│   ├── AppState            Root ObservableObject; owns all services
│   ├── LocationService     CoreLocation + geofencing (20-region cap, auto Always-promotion)
│   ├── NotificationService UserNotifications (geofence entry/exit, fall, recheck)
│   ├── WeatherService      OpenWeatherMap client, key from xcconfig → Info.plist
│   ├── HazardClassifier    Vision VNClassifyImageRequest + keyword mapping
│   ├── SpeechService       SFSpeechRecognizer live transcription
│   ├── MotionService       Core Motion fall detection (impact + stillness)
│   ├── BiometricService    LocalAuthentication (Face ID / Touch ID / passcode)
│   ├── CoreDataStack       Programmatic model, SQLite persistence of inspections
│   ├── PDFReportBuilder    SwiftUI ImageRenderer → one-page PDF
│   ├── SyncRepository      Protocol for team-sync backend
│   ├── MockSyncRepository  In-memory async-stream implementation
│   └── SampleData          Seed data for first launch
├── Features/
│   ├── Login               Email + password + Face/Touch ID
│   ├── Home                Dashboard, priority tasks, live team activity feed
│   ├── Map                 MapKit with geofence overlays + site detail
│   ├── Inspect             Capture + voice + Vision + Review + Certified Report
│   ├── Settings            Lone-worker toggle, sync, notifications, history, simulate fall
│   ├── Safety              Full-screen fall alert overlay with countdown
│   ├── History             Persisted inspection list
│   └── iPad                NavigationSplitView site-manager layout
├── RootView.swift          Auth gate + size-class switch (phone tabs vs iPad split)
└── Geo_PulseApp.swift      App entry
```

**Key architectural decisions:**
- **Programmatic Core Data model** (no `.xcdatamodeld`) keeps the project navigator clean and avoids the schema-editor file-format churn in version control.
- **Protocol-based sync layer** (`SyncRepository`) lets the UI consume an `AsyncStream<ActivityEvent>` without caring whether events come from an in-memory simulator or Firestore. Swap is a one-line change in `AppState` — see `FirebaseSetup.md`.
- **Device-adaptive root** — `RootView` reads `horizontalSizeClass`. iPhone portrait gets the 4-tab UI; iPad / iPhone Max landscape gets the three-column `NavigationSplitView` (sidebar / site detail / team activity).
- **Secrets via xcconfig** — `Secrets.xcconfig` holds `OPENWEATHER_API_KEY`; the project's build configuration file setting pipes it into `Info.plist` via `$(…)` substitution, which `WeatherService` reads at runtime. The xcconfig is `.gitignore`d and excluded from the app bundle.

---

## Platform & SDK coverage

### Mandatory (Component 2)
| Feature | Framework | Role |
|---------|-----------|------|
| Push notifications | `UserNotifications` | Geofence entry/exit, recheck reminders, fall alerts |
| Local persistence | `CoreData` | Inspection records (SQLite, survive relaunch) |
| External API | `OpenWeatherMap REST` | Live weather + severe-warning JSON per site |

### Primary advanced (Component 3)
| Feature | Framework |
|---------|-----------|
| Geofenced task automation | `MapKit` + `CoreLocation` (`CLCircularRegion`) |
| On-device hazard classification | `Vision` + `CoreML` (`VNClassifyImageRequest`) |

### Supporting / stretch (Component 5)
| Feature | Framework |
|---------|-----------|
| Fall detection | `CoreMotion` (accelerometer + gyroscope) |
| Voice logging | `Speech` (`SFSpeechRecognizer`) |
| Biometric sign-in | `LocalAuthentication` (`LAContext`) |
| PDF export | SwiftUI `ImageRenderer` + `CoreGraphics` PDF context |
| iPad site-manager view | SwiftUI `NavigationSplitView` |
| Real-time team sync | `SyncRepository` protocol (mock), Firestore swap documented |

### Not used (per proposal)
- Face ID *not* chosen as a Component 2 feature (Push Notifications + Core Data are the two) — Face ID is used only as login-UX polish.
- CloudKit, WidgetKit — documented as stretch; not implemented.

---

## Permissions

Declared in `Geo-Pulse-Info.plist`:

- `NSLocationWhenInUseUsageDescription` + `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`
- `NSMotionUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSFaceIDUsageDescription`
- `UIBackgroundModes` → `location`, `fetch`

---

## Getting started

```sh
git clone https://github.com/InduwaraJayaratna/GeoPulse.git
cd GeoPulse
cp "Secrets.xcconfig.example" "Secrets.xcconfig"   # if an example is provided
# then edit Secrets.xcconfig and paste your OpenWeatherMap API key
open "Geo Pulse/Geo Pulse.xcodeproj"
```

Build and run on an iPhone or iPad simulator (iOS 26.5+). The Login screen appears first — sign in with the pre-filled credentials, or tap **Face / Touch ID**.

**Simulator tips:**
- **Features → Face ID → Enrolled** before tapping the biometric card
- **Features → Location → Custom Location…** inside Riverside / Baton Rouge coords to trigger geofence entry
- Camera isn't available on simulator; Inspect falls back to photo library automatically
- **Settings → Simulate fall event** triggers the fall-detection flow without having to actually drop the phone

---

## Status

The MVP is feature-complete against the proposal's nine items. The remaining stretch work (Firestore real backend, WidgetKit, CloudKit) is documented but not implemented — see `FirebaseSetup.md` for the one-line swap to real Firestore. All screens match the Figma mockups and all referenced sensor hooks are real, not stubs.

---

## License

Coursework submission — University of Coventry · COBSCCOMP251P-017.
