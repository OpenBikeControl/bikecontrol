import AVKit
import UIKit

enum DeviceCapabilities {
    /// No public API exposes "has Dynamic Island". Heuristic: Dynamic Island
    /// iPhones report a larger portrait top safe-area inset (~59pt) than notch
    /// devices (≤48pt). iPads have no Dynamic Island.
    ///
    /// Misdetection is benign: the only false positive is a DI iPhone evaluated
    /// in landscape (small top inset) being treated as non-DI, which merely adds
    /// a (redundant) PiP alongside the Dynamic Island. A non-DI phone can never
    /// be mistaken for DI (its inset never reaches the threshold).
    static var hasDynamicIsland: Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return false }
        return keyWindowTopInset() >= 51
    }

    /// PiP is the chosen floating display on iPad and on iPhones WITHOUT a
    /// Dynamic Island. Requires iOS 16+ (ImageRenderer) and device PiP support.
    static var pipEligible: Bool {
        guard #available(iOS 16.0, *) else { return false }
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return false }
        if UIDevice.current.userInterfaceIdiom == .pad { return true }
        return !hasDynamicIsland
    }

    private static func keyWindowTopInset() -> CGFloat {
        for scene in UIApplication.shared.connectedScenes {
            guard let ws = scene as? UIWindowScene else { continue }
            if let w = ws.windows.first(where: { $0.isKeyWindow }) ?? ws.windows.first {
                return w.safeAreaInsets.top
            }
        }
        return 0
    }
}
