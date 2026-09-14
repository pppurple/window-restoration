# Window Restoration

English | [日本語](README_ja.md)

A macOS menu bar app that saves and restores window positions and sizes for each display configuration.

The current MVP provides the following features:

- Identifies display configurations by connected display UUIDs, arrangement, and scale factors
- Saves the positions and sizes of currently open windows
- Restores the layout associated with the current display configuration
- Lists connected and previously saved displays and lets you assign friendly names
- Shows display names, window counts, and save times for saved configurations
- Provides controls from the menu bar
- Guides you through granting Accessibility permission

## Requirements

- macOS 13 or later
- Swift 5.10 or later, provided by Xcode or Xcode Command Line Tools

## Build

```sh
./scripts/build-app.sh
```

The app is generated at `dist/Window Restoration.app`. Open it in Finder or copy it to `/Applications` as needed.

The build script automatically selects a macOS SDK compatible with the installed Swift compiler. To select an SDK explicitly, set `WINDOW_RESTORATION_SDKROOT`.

If the script is not executable, run this once:

```sh
chmod +x scripts/build-app.sh
```

## Usage

1. Launch `Window Restoration.app`.
2. Click the window icon in the menu bar.
3. Click **権限を許可** (Grant Permission) and allow the app in System Settings.
4. Return to the app and click **状態を再確認** (Refresh Status).
5. Arrange your windows and click **現在の配置を保存** (Save Current Layout).
6. If the layout changes, click **保存した配置を復元** (Restore Saved Layout).

To give a display a friendly name such as “Home Monitor,” “Office 24-inch Monitor,” or “MacBook Display,” click **名前を変更** (Rename) in the Displays section or double-click the display name. Friendly names are used only in the interface; display configurations continue to be identified internally by their macOS display UUIDs.

### If the app requests Accessibility permission even though it is already enabled

Older builds used an ad-hoc signature that caused macOS to treat each rebuild as a different app. The current build script embeds a stable designated requirement so rebuilt versions are recognized as the same app.

If an older build is already registered, complete the following steps once:

1. Quit Window Restoration.
2. Open **System Settings → Privacy & Security → Accessibility**.
3. Select the existing `Window Restoration.app` and remove it with the `−` button.
4. Rebuild the app with `./scripts/build-app.sh`.
5. Move the app to the location where you intend to keep it, then launch it.
6. Add the app to the Accessibility list and enable it.

This app is intended for personal use and uses an ad-hoc signature with an explicit local bundle identifier. Do not run untrusted apps that use the same bundle identifier.

When checking permissions, launch the `Window Restoration.app` generated above from its permanent location. Do not launch it with Xcode's Run button or `swift run`: executables in Xcode or Swift Package Manager build directories are treated as different apps from the registered `.app` bundle.

Layout data is stored as JSON at:

```text
~/Library/Application Support/WindowRestoration/profiles/
```

## Current limitations

- The app does not launch applications or open windows that are not already running.
- Windows in other macOS Spaces, full-screen windows, and tiled windows are not supported.
- Some applications reject move or resize operations through the Accessibility API.
- Automatic saving and restoration are not implemented yet.

## Tests

```sh
swift test
```

Running the tests requires Xcode with matching Swift compiler and SDK versions, including XCTest.

## Possible future improvements

- Debounced automatic saving using window creation, move, and resize notifications
- Automatic restoration when the display configuration changes
- Suspending automatic saves during display transitions and restoration
- Layout history and an “Undo Last Restore” action
- Per-application exclusion settings
