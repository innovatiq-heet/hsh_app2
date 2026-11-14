import CallKit
import Foundation

/// Feeds the phonebook into iOS's caller-ID database.
///
/// iOS runs this in its own process with a tight memory budget and strict
/// rules: numbers must be added in ascending order with no repeats, or the
/// whole load is rejected. `CallerIdPlugin` writes the file in that shape;
/// we still validate here so a bad export can never brick caller ID.
final class CallDirectoryHandler: CXCallDirectoryProvider {
    private static let appGroup = "group.in.innovatiq.hshApp2"
    private static let directoryFile = "callerid-directory.json"

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        // We always publish the complete directory, so on an incremental
        // request wipe what the system has and resend everything. Simpler
        // and safer than diffing 5k entries.
        if context.isIncremental {
            context.removeAllIdentificationEntries()
        }

        for (number, label) in loadEntries() {
            context.addIdentificationEntry(withNextSequentialPhoneNumber: number, label: label)
        }
        context.completeRequest()
    }

    private func loadEntries() -> [(CXCallDirectoryPhoneNumber, String)] {
        guard let url = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)?
                .appendingPathComponent(Self.directoryFile),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = root["entries"] as? [[Any]] else {
            return []
        }

        var out: [(CXCallDirectoryPhoneNumber, String)] = []
        out.reserveCapacity(raw.count)
        for e in raw {
            guard e.count >= 2, let label = e[1] as? String, !label.isEmpty else { continue }
            let n: Int64?
            if let v = e[0] as? NSNumber { n = v.int64Value } else { n = nil }
            guard let number = n, number > 0 else { continue }
            out.append((CXCallDirectoryPhoneNumber(number), label))
        }
        out.sort { $0.0 < $1.0 }

        // Collapse duplicates (CallKit rejects them) — keep the first label.
        var unique: [(CXCallDirectoryPhoneNumber, String)] = []
        unique.reserveCapacity(out.count)
        for e in out where unique.last?.0 != e.0 { unique.append(e) }
        return unique
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        NSLog("[CallDirectoryExtension] request failed: \(error.localizedDescription)")
    }
}
