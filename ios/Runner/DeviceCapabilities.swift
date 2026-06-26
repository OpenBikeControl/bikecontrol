import AVKit
import UIKit

enum DeviceCapabilities {
    /// No public API exposes "has Dynamic Island". Heuristic: Dynamic Island
    /// iPhones report a larger safe-area inset (~59pt) on the cutout edge than
    /// notch devices (≤48pt). iPads have no Dynamic Island.
    ///
    /// We use the MAX of all four insets, not just `top`: in landscape the
    /// cutout moves to a side edge and the top inset collapses to ~0, so a
    /// top-only check would misread a Dynamic-Island iPhone as non-DI and
    /// auto-start a redundant PiP. The max inset stays orientation-independent.
    static var hasDynamicIsland: Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return false }
        return keyWindowMaxInset() >= 51
    }

    /// Whether PiP is technically possible at all: iOS 16+ (ImageRenderer) and
    /// the device supports PiP — regardless of the Dynamic Island. Drives the
    /// opt-in toggle and honoring it on Dynamic-Island iPhones.
    static var isPipCapable: Bool {
        guard #available(iOS 16.0, *) else { return false }
        return AVPictureInPictureController.isPictureInPictureSupported()
    }

    /// PiP is the AUTOMATIC floating display on iPad and on iPhones WITHOUT a
    /// Dynamic Island (Dynamic-Island iPhones default to the Live Activity, but
    /// can opt into PiP via settings).
    static var pipEligible: Bool {
        guard isPipCapable else { return false }
        if UIDevice.current.userInterfaceIdiom == .pad { return true }
        return !hasDynamicIsland
    }

    /// iPad has room to show the floating window immediately (foreground), rather
    /// than only once BikeControl is backgrounded.
    static var prefersForegroundPip: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private static func keyWindowMaxInset() -> CGFloat {
        for scene in UIApplication.shared.connectedScenes {
            guard let ws = scene as? UIWindowScene else { continue }
            if let w = ws.windows.first(where: { $0.isKeyWindow }) ?? ws.windows.first {
                let i = w.safeAreaInsets
                return max(max(i.top, i.bottom), max(i.left, i.right))
            }
        }
        return 0
    }
}
