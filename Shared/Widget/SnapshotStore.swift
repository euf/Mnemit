import Foundation
import Security

/// Where the snapshot lives between the app, which writes it, and the widget extension, which
/// reads it.
protocol SnapshotStore: Sendable {
    func read() -> WidgetSnapshot?
    /// Whether it was stored.
    @discardableResult
    func write(_ snapshot: WidgetSnapshot) -> Bool
}

/// A keychain item in the access group both targets list in their entitlements
/// (`keychain-access-groups`, `Mnemit.entitlements`). Keychain sharing is all the free
/// Personal Team allows between an app and its extension; there is no App Group.
///
/// The group is `<team prefix>com.euf.mnemit.shared`, and the prefix depends on who signs the
/// build, so it is not written in the code: the keychain says which group an item without one
/// lands in (the first of the entitlement, here the shared group), and the prefix is read from
/// that. A build without the entitlement can't write: `write` returns `false`.
struct KeychainSnapshotStore: SnapshotStore {
    /// The group without its team prefix.
    static let groupName = "com.euf.mnemit.shared"

    var service = "com.euf.mnemit.widget"
    var account = "snapshot"

    func read() -> WidgetSnapshot? {
        guard let group = Self.accessGroup() else { return nil }
        var query = baseQuery(group: group)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return WidgetSnapshot.decoded(from: data)
    }

    @discardableResult
    func write(_ snapshot: WidgetSnapshot) -> Bool {
        guard let group = Self.accessGroup(), let data = try? snapshot.encoded() else { return false }
        var status = SecItemUpdate(baseQuery(group: group) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = baseQuery(group: group)
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(item as CFDictionary, nil)
        }
        return status == errSecSuccess
    }

    func remove() {
        guard let group = Self.accessGroup() else { return }
        SecItemDelete(baseQuery(group: group) as CFDictionary)
    }

    private func baseQuery(group: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: group,
        ]
    }

    /// The shared group with the team prefix of this build, `nil` if the keychain says nothing.
    static func accessGroup() -> String? {
        let probe: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.euf.mnemit.access-group-probe",
            kSecAttrAccount as String: "probe",
            kSecReturnAttributes as String: true,
        ]
        var result: CFTypeRef?
        var status = SecItemCopyMatching(probe as CFDictionary, &result)
        if status == errSecItemNotFound {
            var item = probe
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(item as CFDictionary, &result)
        }
        guard status == errSecSuccess, let attributes = result as? [String: Any], let first = attributes[kSecAttrAccessGroup as String] as? String else {
            return nil
        }
        return group(prefixedLike: first)
    }

    /// `first` is the group an item without one lands in: the shared group already, or one of
    /// the same team, `<team>.<bundle id>`.
    static func group(prefixedLike first: String) -> String? {
        if first == groupName || first.hasSuffix("." + groupName) { return first }
        guard let team = first.split(separator: ".").first, first.contains(".") else { return nil }
        return "\(team).\(groupName)"
    }
}
