# syncTask

Minimal, zero-overhead macOS desktop task widget and companion Android app with bidirectional sync.

Designed for users who want desktop reminders that stay in sync with their phone without cloud subscriptions, electron runtimes, or background battery drain.

## Overview

- **macOS Widget**: A single-file AppKit desktop widget (`SyncTask.swift`). Sits stationary on the desktop icon layer with no dock icon, custom themes, and an embedded zero-overhead HTTP sync server (`Network.framework`).
- **Android App & Widget**: A minimal native companion (`~21 KB` APK) featuring an Android home-screen widget (`RemoteViews`) and instant bidirectional task synchronization.
- **No Dependencies**: No Node.js, Electron, CocoaPods, Gradle, or external accounts required.

## Project Structure

```
syncTask/
├── SyncTask.swift        # Single-file macOS AppKit desktop widget and embedded sync server
├── build-apk.sh          # Minimal APK build script using standard Android command-line tools
├── synctask.apk          # Pre-built lightweight Android APK (~21 KB)
├── android/              # Android source code and resource layouts
│   ├── AndroidManifest.xml
│   ├── res/              # Layout XMLs for the app and home-screen widget
│   └── src/app/synctask/sync/
│       ├── MainActivity.java
│       └── SyncTaskWidgetProvider.java
├── .gitignore
└── README.md
```

## Getting Started

### 1. Run on macOS

Compile with standard Apple clang / swiftc:

```bash
swiftc -O SyncTask.swift -framework AppKit -framework Network -o syncTask
./syncTask &
```

- Drag the widget anywhere on your desktop.
- Click **Theme** to cycle color palettes (Minimal, Glass, Childish).
- Double-click any task to edit inline.
- Click **Sync** at the bottom-right to reveal the connection panel and pairing QR code.

### 2. Run on Android

Transfer or download `synctask.apk` to your Android device, or compile from source using Android command-line tools:

```bash
chmod +x build-apk.sh
./build-apk.sh
```

- Install `synctask.apk`.
- Add the **syncTask** widget to your Android home screen.
- Tasks synced between your Mac and phone stay updated in both directions.

## Specifications

| Component | macOS Widget | Android App / Widget |
| :--- | :--- | :--- |
| **Runtime** | Native AppKit / Swift | Native Android SDK (Java) |
| **Idle Memory** | ~15 MB | 0 MB (system-rendered widget) |
| **Binary Size** | ~120 KB executable | ~21 KB APK |
| **Dependencies** | None (OS-native frameworks) | None |

## License

MIT
