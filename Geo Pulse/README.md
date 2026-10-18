# GeoPulse

**Geofenced Smart Field Operations Platform**

GeoPulse is a native iOS field-operations app that binds inspection and maintenance tasks directly to physical GPS geofences. The moment a worker enters a job-site boundary, the app surfaces that site's pending tasks, fetches localised weather, and enables hands-free hazard logging via voice and on-device image classification.

---

## Target users

Mobile field professionals — site engineers, safety inspectors, facilities technicians — who manage inspection work across physical sites and need their phone to react to location instead of waiting for taps.

---

## Core workflow

1. **Arrival** — iPhone detects geofence entry and raises a local notification with that site's open tasks.
2. **Inspection** — Worker opens a task, captures a photo, and an on-device Core ML classifier flags likely hazards (cracks, corrosion, exposed wiring) with a confidence score.
3. **Hands-free log** — Voice note is transcribed on-device via the Speech framework while the worker continues working.
4. **Save & sync** — Record saves to Core Data locally first ("Saved locally"), then syncs to Firestore when connectivity returns ("Synced to team").
5. **Safety** — While lone-worker monitoring is active, Core Motion watches for fall-pattern events. If detected, a 30-second countdown runs; if uncancelled, the alert and last-known location escalate to the nominated contact.

---

## Features (MVP)

| # | Feature | Description |
|---|---------|-------------|
| 1 | Job Sites & Tasks | Drop a map pin, set a geofence radius, assign tasks per site |
| 2 | Settings | Lone-worker toggle, notification preferences, sync status |
| 3 | Home Dashboard | Live geofence card, today's tasks, sync indicator |
| 4 | External API | OpenWeatherMap weather + Firestore team sync |
| 5 | Push Notifications | Geofence entry/exit, recheck reminders, fall alerts |
| 6 | Core Data | Offline-first storage for sites, tasks, photos, notes |
| 7 | Inspection Flow | Photo + Core ML hazard tag + voice note + save |
| 8 | History | Completed inspections and hazards, filterable |
| 9 | Lone-Worker Monitoring | Fall detection with countdown and auto-escalation |

---

## Advanced SDK integrations

- **MapKit + Core Location** — `CLCircularRegion` geofences drive the whole task workflow (primary advanced feature)
- **Vision + Core ML** — On-device photo classification with no network call (primary advanced feature)
- **Core Motion** — Accelerometer/gyroscope fusion for fall detection
- **Firebase Firestore** — Real-time task assignment and live manager activity feed
- **Speech framework** — On-device speech-to-text for voice logging
- **WidgetKit** — Home-screen widget for nearest site, task count, and weather (stretch)

---

## Architecture

MVVM-ish with dependency-injected service objects:

```
Geo Pulse/
├── Theme/              AppColors, AppTypography
├── Components/         Reusable UI (cards, badges, buttons, top bar)
├── Models/             Site, FieldTask, Inspection, UserProfile
├── Services/
│   ├── AppState            Root ObservableObject
│   ├── LocationService     CoreLocation + geofencing
│   ├── NotificationService UserNotifications wrapper
│   ├── WeatherService      OpenWeatherMap client
│   ├── HazardClassifier    Vision + Core ML wrapper
│   ├── SpeechService       SFSpeechRecognizer wrapper
│   ├── MotionService       Core Motion fall detection
│   ├── CoreDataStack       Programmatic Core Data model
│   └── SampleData          Seed data for previews
├── Features/
│   ├── Login
│   ├── Home
│   ├── Map
│   ├── Inspect             + OpenInspection, ViewTask, ReviewSignOff, CertifiedReport
│   ├── Settings
│   ├── History
│   └── Map/SiteDossier
├── RootView.swift      Custom tab bar + auth gate
└── Geo_PulseApp.swift  App entry
```

---

## UI structure

**iPhone — 4-tab layout for one-handed field use:**
- **Home** — status, priority tasks, nearby sectors, quick log
- **Map** — interactive geofence map, site detail bottom sheet, dossier
- **Inspect** — task detail with voice capture, camera, hazard analysis
- **Settings** — profile, lone-worker toggle, notifications, sync, history

**iPad (planned)** — `NavigationSplitView` site-manager overview with sidebar, map, task assignment, Swift Charts analytics, and a real-time team activity feed.

---

## Platform frameworks

Swift / SwiftUI · MapKit · CoreLocation · Vision · CoreML · UserNotifications · CoreData · AVFoundation · Speech · CoreMotion · PhotosUI · Combine

---

## Requirements

- Xcode 26.5+
- iOS 26.5+ deployment target
- Signing: automatic (Personal team is fine for development)

---

## Getting started

```sh
git clone https://github.com/InduwaraJayaratna/GeoPulse.git
cd GeoPulse
open "Geo Pulse/Geo Pulse.xcodeproj"
```

Build and run on an iPhone simulator or device. On first launch the app shows the Login screen — tap **Sign In to Active Shift** to enter the main tab experience (authentication is stubbed in the current MVP).

---

## Permissions

The app requires the following privacy permissions, declared via `INFOPLIST_KEY_*` settings:

- **Location (When In Use + Always)** — Geofence monitoring in foreground and background
- **Camera** — Capture inspection photos
- **Microphone** — Record voice notes
- **Speech Recognition** — Transcribe voice notes on-device
- **Motion** — Fall detection for lone-worker monitoring
- **Photo Library** — Attach existing photos to inspections

Background Modes: **Location updates** and **Background fetch**.

---

## Status

This is the Component 2 MVP scaffold. All nine MVP screens are implemented with navigation, sample data, and the advertised sensor hooks. Firebase Firestore wiring, Core ML model binding, and the iPad analytics dashboard are the main items still to land before full assessment.

---

## License

Coursework submission — University of Westminster · COBSCCOMP251P-017.
