# iOS Caller ID Setup — Quick Reference

## Bundle Identifiers & App Group
- **Main App**: `com.avdhsh.app`
- **Call Directory Extension**: `com.avdhsh.app.CallDirectoryExtension`
- **App Group**: `group.com.avdhsh.app`

---

## Steps to Verify in Xcode (`ios/Runner.xcworkspace`)

1. **Open Workspace**:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Team Account**:
   Ensure you are logged into your paid developer account in **Xcode → Settings → Accounts**.

3. **Target `Runner`**:
   - **Signing & Capabilities** → Team: Select your paid Team
   - **App Groups** → Check `group.com.avdhsh.app`

4. **Target `CallDirectoryExtension`**:
   - **Signing & Capabilities** → Team: Select the same paid Team
   - **App Groups** → Check `group.com.avdhsh.app`

---

## 🔄 If You Change to Another Apple Developer Account (For Release)

If your release account uses a different bundle ID prefix (e.g. `com.yourcompany.app` instead of `in.innovatiq.hshApp2`):

1. **Update 4 files in the codebase**:
   - `ios/Runner/CallerIdPlugin.swift` → Change `extensionIdentifier` & `appGroup`
   - `ios/CallDirectoryExtension/CallDirectoryHandler.swift` → Change `appGroup`
   - `ios/Runner/Runner.entitlements` → Change App Group name
   - `ios/CallDirectoryExtension/CallDirectoryExtension.entitlements` → Change App Group name

2. **In Xcode (`Signing & Capabilities`)**:
   - For `Runner`: Select new Team, set new Bundle ID, select/add new App Group.
   - For `CallDirectoryExtension`: Select new Team, set `Bundle ID + .CallDirectoryExtension`, select/add same new App Group.

---

## iPhone Permission (Required)
On your iPhone:
1. Open **Settings → Phone → Call Blocking & Identification**.
2. Turn ON the toggle for **`Hsh App2`** / **`HSH Caller ID`**.

See [CALLER_ID_HANDOFF.md](CALLER_ID_HANDOFF.md) for the full architecture and troubleshooting, and [docs/PHONEBOOK_DOCS.md](../docs/PHONEBOOK_DOCS.md) for how the phonebook and caller ID work on both platforms.
