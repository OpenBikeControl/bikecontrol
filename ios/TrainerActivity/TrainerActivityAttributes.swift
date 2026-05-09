import ActivityKit
import Foundation

// The `live_activities` Flutter plugin always launches activities of this
// exact type. The plugin's own ContentState carries `appGroupId`, so the
// widget's ContentState MUST mirror that field — otherwise ActivityKit
// rejects the request with `ActivityInput error 0` (malformedAttributes).
//
// Payload data is NOT encoded into ContentState. The plugin writes each
// entry into the App Group's UserDefaults keyed by `<id>_<fieldName>` and
// the widget reads them back via `attributes.prefixedKey(...)`.
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable {
        var appGroupId: String
    }

    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}
