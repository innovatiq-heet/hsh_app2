# iOS Caller ID — one-time Xcode setup

The Swift code for caller ID is already in the repo, but an **app extension
target** and an **App Group** can only be added through Xcode, on a Mac. Do
this once; it takes about ten minutes.

Files involved:

| File | Target | Purpose |
|---|---|---|
| `Runner/CallerIdPlugin.swift` | Runner | Flutter channel `hsh/caller_id`; writes the directory file; reloads the extension |
| `Runner/Runner.entitlements` | Runner | App Group so the app and extension share a folder |
| `CallDirectoryExtension/CallDirectoryHandler.swift` | CallDirectoryExtension | Feeds number → label pairs to CallKit |
| `CallDirectoryExtension/Info.plist` | CallDirectoryExtension | Declares the `com.apple.callkit.call-directory` extension point |
| `CallDirectoryExtension/CallDirectoryExtension.entitlements` | CallDirectoryExtension | Same App Group |

## Steps

1. `open ios/Runner.xcworkspace`
2. **File → New → Target… → iOS → Call Directory Extension**
   - Product Name: `CallDirectoryExtension`
   - Language: Swift · Bundle Identifier must end up as **`com.example.hshApp2.CallDirectoryExtension`**
   - Click *Finish*; when asked to activate the scheme, choose **Cancel**.
3. Xcode generates its own `CallDirectoryHandler.swift` and `Info.plist` inside the new target folder.
   **Delete those two generated files** (Move to Trash) and instead drag the repo's
   `ios/CallDirectoryExtension/CallDirectoryHandler.swift` and `Info.plist` into the
   target, ticking *CallDirectoryExtension* under "Add to targets".
4. Select the **Runner** target → *Signing & Capabilities* → **+ Capability → App Groups** →
   add **`group.com.example.hshApp2`**. Xcode will point `CODE_SIGN_ENTITLEMENTS` at
   `Runner/Runner.entitlements` (already in the repo; accept/replace if prompted).
5. Select the **CallDirectoryExtension** target → *Signing & Capabilities* → **App Groups** →
   tick the same **`group.com.example.hshApp2`**. Point its entitlements file at
   `CallDirectoryExtension/CallDirectoryExtension.entitlements`.
6. Make sure `Runner/CallerIdPlugin.swift` is a member of the **Runner** target
   (Target Membership in the File Inspector).
7. Both targets: *Deployment Info* → iOS **13.0** (matches the app).
8. Build & run on a real iPhone (the simulator can't receive calls).

## If you change the bundle id or App Group

Update all four places together:

- `CallerIdPlugin.extensionIdentifier` and `.appGroup`
- `CallDirectoryHandler.appGroup`
- both `.entitlements` files
- Xcode → App Groups capability on both targets

## How the warden turns it on

Phonebook screen → **Caller ID card → Enable** → opens
*Settings → Phone → Call Blocking & Identification* → toggle **HSH App**.
After every phonebook sync the app rewrites the directory and asks iOS to
reload it, so new students appear within seconds.

## What iOS shows

Only a text label under the number on the incoming-call screen and in
Recents, e.g. `HSH · Rohan Sharma · Room B-204 · Father`. iOS does not allow
custom call UI, tap-to-open, or post-call notifications — that's a platform
rule, not a limitation of this app.

## Troubleshooting

- **Toggle missing in Settings** → the extension didn't build/sign; check the
  App Group is on *both* targets and the bundle id matches `extensionIdentifier`.
- **Toggle on but no labels** → run the app once after enabling so it exports
  the directory (`exportDirectory`); check Console.app for
  `[CallDirectoryExtension] request failed` — usually unsorted or duplicate numbers.
- **`no_app_group` error from Flutter** → the App Group capability isn't on the Runner target.
