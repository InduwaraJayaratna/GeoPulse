# Firebase Firestore — real backend setup

The MVP ships with `MockSyncRepository`, which simulates a Firestore real-time
feed in memory so the architecture is complete without requiring a Firebase
project. When you're ready to swap in the real backend, follow these steps.

## 1. Create the Firebase project

1. Go to [console.firebase.google.com](https://console.firebase.google.com/) and create a project (e.g. `geopulse-dev`).
2. In the project, choose **Add app → iOS**.
3. Bundle ID: `Geo-Pulse.Geo-Pulse` (must match the one in Xcode's project settings).
4. Download the generated **`GoogleService-Info.plist`** and drag it into the Xcode project at `Geo Pulse/Geo Pulse/GoogleService-Info.plist`. Tick "Copy items if needed" and ensure the **Geo Pulse** target is checked.
5. In the Firebase console sidebar, open **Firestore Database → Create database → Start in test mode** (lock it down with proper rules later).

## 2. Add the Firebase SDK via Swift Package Manager

1. Xcode → **File → Add Packages…**
2. Enter package URL: `https://github.com/firebase/firebase-ios-sdk`
3. Rule: **Up to Next Major** from `11.0.0`
4. Choose the libraries:
   - `FirebaseFirestore`
   - `FirebaseFirestoreSwift` (if offered — contains Codable support)
5. Add to the **Geo Pulse** target.

## 3. Configure Firebase on app launch

Edit `Geo_PulseApp.swift`:

```swift
import SwiftUI
import FirebaseCore

@main
struct Geo_PulseApp: App {
    @StateObject private var appState: AppState

    init() {
        FirebaseApp.configure()
        _appState = StateObject(wrappedValue: AppState())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.light)
        }
    }
}
```

## 4. Create `FirestoreSyncRepository`

Add a new file next to `MockSyncRepository.swift`:

```swift
import Foundation
import FirebaseFirestore

final class FirestoreSyncRepository: SyncRepository, @unchecked Sendable {
    private(set) var connectionStatus: SyncConnectionStatus = .connecting
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init() {
        connectionStatus = .live
    }

    func publish(inspection: Inspection) async {
        let doc: [String: Any] = [
            "siteName": inspection.siteName,
            "inspectorName": inspection.inspectorName,
            "completedAt": inspection.completedAt,
            "resultSummary": inspection.resultSummary,
            "hazardTag": inspection.hazardTag as Any,
            "hazardConfidence": inspection.hazardConfidence as Any,
            "voiceNote": inspection.voiceNote as Any
        ]
        try? await db.collection("inspections").addDocument(data: doc)
    }

    func activityFeed() -> AsyncStream<ActivityEvent> {
        AsyncStream { continuation in
            self.listener = db.collection("activity")
                .order(by: "occurredAt", descending: true)
                .limit(to: 40)
                .addSnapshotListener { snapshot, _ in
                    guard let docs = snapshot?.documentChanges else { return }
                    for change in docs where change.type == .added {
                        let d = change.document.data()
                        guard
                            let kindRaw = d["kind"] as? String,
                            let kind = ActivityEvent.Kind(rawValue: kindRaw),
                            let actorName = d["actorName"] as? String,
                            let siteName = d["siteName"] as? String,
                            let summary = d["summary"] as? String,
                            let ts = d["occurredAt"] as? Timestamp
                        else { continue }
                        continuation.yield(ActivityEvent(
                            kind: kind, actorName: actorName, siteName: siteName,
                            summary: summary, occurredAt: ts.dateValue()
                        ))
                    }
                }
            continuation.onTermination = { [weak self] _ in self?.listener?.remove() }
        }
    }
}
```

## 5. Swap it in

In `AppState.swift`, change this line:

```swift
let syncRepository: SyncRepository = MockSyncRepository()
```

to:

```swift
let syncRepository: SyncRepository = FirestoreSyncRepository()
```

That's the entire swap — every view that consumes `appState.activityFeed`
or publishes inspections now talks to Firestore automatically.

## 6. Firestore collections used

- **`inspections`** — one document per completed inspection, written by `publish(inspection:)`
- **`activity`** — one document per event (`taskAssigned`, `inspectionLogged`, `hazardFlagged`, `fallAlert`). Seed this collection manually from the Firebase console or write a small Node script to simulate manager activity.
- **`sites`** (optional, future) — site configuration + task assignments. Not yet wired.

## 7. Security rules starter

Replace the default test-mode rules with:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

…then add Firebase Auth so `request.auth` is non-null for signed-in users.
