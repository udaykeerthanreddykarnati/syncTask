# syncTask

Minimal, zero-overhead macOS desktop task widget and companion Android app with real-time bidirectional sync.

Designed for users who want desktop reminders synced with their phone without cloud subscriptions, Electron runtimes, or background battery drain.

## Overview

- **macOS Widget**: A single-file AppKit desktop widget (`SyncTask.swift`) with persistent window position, multi-monitor bounds clamping, single-instance lock, `Enter`/`Esc` shortcuts, custom themes, and an embedded token-authenticated HTTP + real-time SSE (`ntfy.sh`) sync engine.
- **Conflict-Safe Merging**: Tasks sync per-UUID with `updatedAt` timestamps and soft-delete tombstones so simultaneous Mac and phone edits merge cleanly.
- **Android App & Widget**: A minimal native companion (`~21 KB` APK) with an Android home-screen widget (`RemoteViews`) and live SSE sync.
- **No Dependencies**: Zero Node.js, Electron, CocoaPods, Gradle, or third-party packages.

## Project Structure

```text
syncTask/
├── SyncTask.swift        # macOS AppKit desktop widget + authenticated LAN & SSE sync server
├── build-apk.sh          # Zero-Gradle APK build script (persists local signing keystore)
├── synctask.apk          # Pre-built lightweight Android APK
├── android/              # Android source code and resource layouts
│   ├── AndroidManifest.xml
│   ├── res/
│   └── src/app/synctask/sync/
│       ├── MainActivity.java
│       └── SyncTaskWidgetProvider.java
├── .gitignore
└── README.md
```

## Getting Started

### 1. Run on macOS

```bash
swiftc -O SyncTask.swift -framework AppKit -framework CoreImage -framework Network -framework Security -o SyncTask
./SyncTask &
```

- Drag the widget anywhere on your desktop (position is saved automatically).
- Press **+ Add** (`Enter` to add, `Esc` to cancel) or double-click any task to edit inline.
- Click **Theme** to cycle color palettes (`Minimal`, `Glass`, `Childish`).
- Click **Sync** at the bottom-right to show the pairing QR code and 128-bit random Sync Key.

### 2. Run on Android

Transfer `synctask.apk` to your Android device, or compile from source using standard Android SDK build tools:

```bash
chmod +x build-apk.sh
./build-apk.sh
```

`build-apk.sh` keeps a persistent local keystore (`synctask.keystore`, gitignored) so future APK updates install cleanly in-place without wiping your saved Sync Key.

## Specifications

| Component | macOS Widget | Android App / Widget |
| :--- | :--- | :--- |
| **Runtime** | Native AppKit / Swift | Native Android SDK (Java) |
| **Sync Transport** | Real-time SSE (`ntfy.sh`) + Authenticated LAN HTTP | Real-time SSE + `RemoteViews` polling |
| **Idle Memory** | ~15 MB | 0 MB (system-rendered widget) |
| **Dependencies** | None (OS-native frameworks) | None |

## License

MIT
