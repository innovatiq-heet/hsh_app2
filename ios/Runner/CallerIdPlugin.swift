import CallKit
import Flutter
import UIKit

/// iOS half of `hsh/caller_id`.
///
/// iOS never tells an app who is calling. Instead we write the whole
/// phonebook (`E.164 → label`) into the shared App Group container and ask
/// CallKit to reload `CallDirectoryExtension`, which feeds those pairs to the
/// system. The label then appears on the incoming-call screen and in Recents.
final class CallerIdPlugin: NSObject, FlutterPlugin {
    /// Must match the extension target's bundle identifier.
    static let extensionIdentifier = "com.example.hshApp2.CallDirectoryExtension"
    /// Must match the App Group added to BOTH targets' entitlements.
    static let appGroup = "group.com.example.hshApp2"
    static let directoryFile = "callerid-directory.json"
    private static let activeKey = "hsh_caller_id_active"

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "hsh/caller_id", binaryMessenger: registrar.messenger())
        let instance = CallerIdPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getStatus":
            status(result)
        case "requestEnable":
            // There is no in-app prompt; the user flips the switch in Settings → Phone.
            openSettings(result)
        case "requestOverlay":
            result(false) // Android-only concept.
        case "setActive":
            let active = (call.arguments as? [String: Any])?["active"] as? Bool ?? false
            UserDefaults.standard.set(active, forKey: Self.activeKey)
            if !active { Self.clearDirectory() }
            result(nil)
        case "exportDirectory":
            guard let args = call.arguments as? [String: Any],
                  let entries = args["entries"] as? [[Any]] else {
                result(FlutterError(code: "bad_args", message: "entries required", details: nil))
                return
            }
            UserDefaults.standard.set(true, forKey: Self.activeKey)
            exportDirectory(entries, result)
        case "consumeLaunchTarget":
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Status

    private func status(_ result: @escaping FlutterResult) {
        CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(withIdentifier: Self.extensionIdentifier) { state, error in
            let iosState: String
            switch state {
            case .enabled: iosState = "enabled"
            case .disabled: iosState = "disabled"
            default: iosState = "unknown"
            }
            if let error = error { NSLog("[CallerId] status error: \(error.localizedDescription)") }
            DispatchQueue.main.async {
                result([
                    "supported": true,
                    "enabled": state == .enabled,
                    "overlayGranted": true,
                    "active": UserDefaults.standard.bool(forKey: Self.activeKey),
                    "iosState": iosState,
                ])
            }
        }
    }

    private func openSettings(_ result: @escaping FlutterResult) {
        if #available(iOS 13.4, *) {
            // Lands directly on Settings → Phone → Call Blocking & Identification.
            CXCallDirectoryManager.sharedInstance.openSettings { error in
                DispatchQueue.main.async { result(error == nil) }
            }
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url) { ok in result(ok) }
        } else {
            result(false)
        }
    }

    // MARK: - Directory

    private func exportDirectory(_ entries: [[Any]], _ result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .utility).async {
            guard let url = Self.directoryURL() else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "no_app_group", message: "App Group \(Self.appGroup) is not configured", details: nil))
                }
                return
            }
            // [[917984907753, "HSH · Rohan Sharma · Room B-204 · Father"], …] — Dart sends it
            // sorted and de-duplicated; we re-sort defensively because CallKit is strict.
            var pairs: [(Int64, String)] = []
            pairs.reserveCapacity(entries.count)
            for e in entries {
                guard e.count >= 2, let label = e[1] as? String else { continue }
                let n: Int64?
                if let i = e[0] as? Int64 { n = i } else if let i = e[0] as? Int { n = Int64(i) } else if let d = e[0] as? Double { n = Int64(d) } else { n = nil }
                guard let number = n, number > 0 else { continue }
                pairs.append((number, label))
            }
            pairs.sort { $0.0 < $1.0 }
            var dedup: [(Int64, String)] = []
            for p in pairs where dedup.last?.0 != p.0 { dedup.append(p) }

            let json: [[Any]] = dedup.map { [NSNumber(value: $0.0), $0.1] }
            do {
                let data = try JSONSerialization.data(withJSONObject: ["entries": json, "generatedAt": Date().timeIntervalSince1970])
                try data.write(to: url, options: .atomic)
            } catch {
                DispatchQueue.main.async { result(FlutterError(code: "write_failed", message: error.localizedDescription, details: nil)) }
                return
            }
            CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: Self.extensionIdentifier) { error in
                if let error = error { NSLog("[CallerId] reload error: \(error.localizedDescription)") }
                DispatchQueue.main.async { result(error == nil) }
            }
        }
    }

    private static func clearDirectory() {
        guard let url = directoryURL() else { return }
        try? FileManager.default.removeItem(at: url)
        CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: extensionIdentifier, completionHandler: nil)
    }

    static func directoryURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(directoryFile)
    }
}
