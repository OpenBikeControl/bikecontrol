import ActivityKit
import Foundation

// The `live_activities` Flutter plugin always launches activities of this
// exact type. Field data is NOT encoded into ContentState — the plugin
// writes each entry into the App Group's UserDefaults keyed by
// `<id>_<fieldName>` and the widget reads them back via
// `attributes.prefixedKey(...)`.
//
// ContentState is intentionally empty to match the package's example.
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable {}

    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}
