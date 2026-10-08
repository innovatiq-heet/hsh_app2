# iOS Caller ID — Complete Implementation & Xcode Handoff Guide

## 1. Overview & Architecture

iOS does not allow third-party apps to intercept incoming calls in real-time or read the caller's phone number during an incoming call.

Instead, Apple provides **CallKit's Call Directory Extension (`CXCallDirectoryProvider`)**. The host app exports phone numbers with labels into a shared sandbox container (**App Group**), and the extension feeds them into iOS's system-level Caller ID database.

### End-to-End Flow:
```
┌─────────────────────────────────────────────────────────────┐
│                       Flutter App                           │
│  • Builds entries from the phonebook SQLite cache           │
│  • MethodChannel `hsh/caller_id`                            │
└──────────────────────────────┬──────────────────────────────┘
                               │ (exportDirectory)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                  Runner / AppDelegate.swift                 │
│  • CallerIdPlugin.swift validates & sorts pairs             │
│  • Writes JSON to shared App Group container                │
│    `group.com.avdhsh.app/callerid-directory.json`     │
│  • Calls CXCallDirectoryManager.reloadExtension()           │
└──────────────────────────────┬──────────────────────────────┘
                               │ (Triggers background reload)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│               CallDirectoryExtension.appex                  │
│  • CallDirectoryHandler.swift reads JSON from App Group     │
│  • Calls context.addIdentificationEntry(number, label)      │
│  • Ingested into iOS system-level caller ID database        │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    iOS Native Phone UI                      │
│  • Incoming call & Recents display:                         │
│    "Rohan Sharma · Rm 204 (Param) · Father"                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Current Configuration & Identifiers

| Setting | Current Value | Description |
|---|---|---|
| **Main App Bundle ID** | `com.avdhsh.app` | Primary Flutter iOS app |
| **Extension Bundle ID** | `com.avdhsh.app.CallDirectoryExtension` | Extension embedded in `Runner.app/PlugIns/` |
| **App Group** | `group.com.avdhsh.app` | Shared container between app and extension |
| **Method Channel** | `hsh/caller_id` | Flutter ↔ Native bridge |
| **Directory File** | `callerid-directory.json` | Shared JSON database in App Group |
| **Development Team** | `INNOVATIQ SYSTEMS PRIVATE LIMITED` (Team ID `K3FAYYRWH6`) | Paid Apple Developer Team |

### When the directory is exported

`CallerIdService.syncDirectory()` (Dart) rebuilds and exports the full directory:

- after every successful phonebook sync;
- when the warden taps **Open Settings** to enable caller ID;
- every time the phonebook screen opens while caller ID is enabled.

`setActive(false)` (Turn off, logout, or a non-admin/warden login) deletes `callerid-directory.json` and reloads the extension, so labels disappear.

**Label format** (built in `CallerIdService.buildDirectoryEntries()`): `<who> · <place> · <relation>`, e.g. `Rohan Sharma · Rm 204 (Param) · Father`. The relation is omitted for the student's own number; siblings sharing a number are merged (`Rohan Sharma & Meet Sharma`, `Rohan Sharma +2`); labels over 60 characters are truncated. There is **no** `HSH ·` prefix, even though the in-app "Caller ID is on" card still says so.

Full feature documentation (Android and iOS): [docs/PHONEBOOK_DOCS.md](../docs/PHONEBOOK_DOCS.md).

---

## 3. 🚨 Checklist: Switching to Another Apple Developer Account (For Release)

When you are ready to publish or build the app with a **different Apple Developer Account**, follow this complete checklist:

### Step 1: Sign into the New Account in Xcode
1. Open `ios/Runner.xcworkspace` in Xcode.
2. In the menu bar: **Xcode → Settings… → Accounts**.
3. Click the **`+`** button (bottom-left) → **Apple ID** → Log in with the new paid Developer Account.

---

### Step 2: Update the 4 Code Files (If Bundle ID / App Group Changes)

If the new developer account uses a new Bundle ID (for example: `com.yourcompany.app`), update these **4 files**:

#### 1. `ios/Runner/CallerIdPlugin.swift` (Lines 13–15)
```swift
/// Must match the extension target's bundle identifier:
static let extensionIdentifier = "com.yourcompany.app.CallDirectoryExtension"

/// Must match the App Group identifier:
static let appGroup = "group.com.yourcompany.app"
```

#### 2. `ios/CallDirectoryExtension/CallDirectoryHandler.swift` (Line 11)
```swift
/// Must match the same App Group identifier:
private static let appGroup = "group.com.yourcompany.app"
```

#### 3. `ios/Runner/Runner.entitlements` (Line 7)
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.yourcompany.app</string>
</array>
```

#### 4. `ios/CallDirectoryExtension/CallDirectoryExtension.entitlements` (Line 7)
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.yourcompany.app</string>
</array>
```

---

### Step 3: Update Xcode Targets & Capabilities

Open `ios/Runner.xcworkspace` and update the targets:

#### A. Target: `Runner`
1. Click **Runner** target → **Signing & Capabilities** tab.
2. **Team**: Select your **New Developer Team**.
3. **Bundle Identifier**: Set to your new ID (e.g. `com.yourcompany.app`).
4. **App Groups**:
   - If the new App Group (e.g. `group.com.yourcompany.app`) is not listed, click **`+`** under App Groups, enter `group.com.yourcompany.app`, and make sure it is checked with a blue checkmark.

#### B. Target: `CallDirectoryExtension`
1. Click **CallDirectoryExtension** target → **Signing & Capabilities** tab.
2. **Team**: Select the **Same New Developer Team**.
3. **Bundle Identifier**: Set to `com.yourcompany.app.CallDirectoryExtension` (must prefix with Runner bundle ID).
4. **App Groups**:
   - Check the identical App Group (`group.com.yourcompany.app`).

#### C. Target: `RunnerTests`
1. Click **RunnerTests** target → **Signing & Capabilities**.
2. **Team**: Select the **Same New Developer Team**.

---

## 4. Files Created and Modified Reference

### Native iOS Files:
1. `ios/Runner/CallerIdPlugin.swift`
   - Handles Flutter method calls:
     - `getStatus` → `{supported, enabled, overlayGranted: true, active, iosState}`;
     - `requestEnable` → opens Settings → Phone → Call Blocking & Identification (directly on iOS 13.4+);
     - `requestOverlay` → always `false` (Android-only concept);
     - `setActive` → stores the flag; `false` deletes the directory file and reloads the extension;
     - `exportDirectory` → writes the directory (and sets active);
     - `consumeLaunchTarget` → always `nil` (no tap-to-open on iOS).
   - Formats, de-duplicates, and sorts `(Int64 phone, String label)` pairs defensively in ascending order.
   - Saves `callerid-directory.json` into `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)`.
   - Signals `CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: extensionIdentifier)`.

2. `ios/Runner/AppDelegate.swift`
   - Registers the plugin in `didInitializeImplicitFlutterEngine(_:)`, right after `GeneratedPluginRegistrant`:
     `CallerIdPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "CallerIdPlugin")!)`.

3. `ios/CallDirectoryExtension/CallDirectoryHandler.swift`
   - Subclasses `CXCallDirectoryProvider`.
   - Reads `callerid-directory.json` from the shared App Group.
   - Feeds entries via `context.addIdentificationEntry(withNextSequentialPhoneNumber: number, label: label)`.

4. `ios/CallDirectoryExtension/Info.plist`
   - Configures `NSExtension` with `com.apple.callkit.call-directory`.
   - Configures `CFBundleVersion` (`$(CURRENT_PROJECT_VERSION)`) and `CFBundleShortVersionString` (`$(MARKETING_VERSION)`).

5. `ios/Runner/Runner.entitlements` & `ios/CallDirectoryExtension/CallDirectoryExtension.entitlements`
   - Contain the shared App Group entitlement key.

6. `ios/Runner.xcodeproj/project.pbxproj`
   - Added native target `CallDirectoryExtension` (product type `com.apple.product-type.app-extension`).
   - Added `Embed App Extensions` copy files build phase in `Runner` target **before** the `Thin Binary` script phase (avoids Xcode dependency cycles).
   - Linked `CallKit.framework` and configured target dependencies.

---

## 5. iPhone User Permission (Required)

Because iOS protects user privacy, the user must enable the app in iOS Settings:

1. Deploy the app to a physical iPhone:
   ```bash
   flutter run -d <device-id>
   ```
2. On the iPhone, go to:
   **Settings → Phone → Call Blocking & Identification**
3. Turn **ON** the toggle switch for **`Hsh App2`** / **`HSH Caller ID`**.
4. Any incoming calls matching numbers in the directory will display the contact tag on the incoming call screen and in Recents.

---

## 6. Key Gotchas & Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| *"An Application Group with identifier is not available"* | Using a Free / Personal Apple ID. | App Groups and CallKit extensions require a **Paid Apple Developer Account**. Select your Paid Team in Xcode. |
| *"MissingBundleVersion: does not have a CFBundleVersion key"* | `Info.plist` had empty/unresolved build number variable. | Ensure `CallDirectoryExtension/Info.plist` uses `$(CURRENT_PROJECT_VERSION)` and the pbxproj target defines `CURRENT_PROJECT_VERSION = 1;`. |
| *Dependency cycle in Xcode build* | `Embed App Extensions` was placed after Flutter's `Thin Binary` phase. | The `Embed App Extensions` phase must run **before** `Thin Binary`. |
| *Caller ID not showing on incoming calls* | Numbers must be pure digits without symbols in E.164 without leading `+` (e.g., `919876543210`). Also must be sorted strictly in ascending order. | `CallerIdPlugin.swift` sanitizes, sorts, and de-duplicates all entries before writing to the shared JSON. |
| *Call Directory does not work on Simulator* | iOS Simulators cannot receive phone calls or test Call Directory extensions. | Must be tested on a **physical iPhone**. |
