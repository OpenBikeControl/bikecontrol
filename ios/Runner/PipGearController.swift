import AVFoundation
import AVKit
import SwiftUI
import UIKit

/// Renders the current-gear readout into a floating Picture-in-Picture window
/// that survives the trainer app going full-screen. Frames are drawn natively
/// from `GearReadoutView` (no Flutter render loop), so the window keeps updating
/// while BikeControl is backgrounded, riding on the active background audio
/// session that `SharedLogic.keepAlive` already maintains.
@available(iOS 16.0, *)
final class PipGearController: NSObject {
    static let shared = PipGearController()

    private let displayLayer = AVSampleBufferDisplayLayer()
    private var pipController: AVPictureInPictureController?
    private var pump: DispatchSourceTimer?
    private var hostView: UIView?
    private var pool: CVPixelBufferPool?
    private var ptsCount: Int64 = 0
    private var lastHash: Int?
    private var snapshot: GearSnapshot?

    private let fps: Int32 = 2
    private let renderSize = CGSize(width: 480, height: 270) // 16:9

    private override init() { super.init() }

    /// Prepare and arm PiP while the app is foreground. PiP becomes visible
    /// automatically when the app is backgrounded (canStart...FromInline).
    func start(initial: [String: Any]) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            NSLog("[PiP] unsupported device"); return
        }
        guard pipController == nil else { update(initial); return } // already armed
        snapshot = GearSnapshot.fromMap(initial)
        configureAudioSession()
        guard attachLayer() else { NSLog("[PiP] no window to attach layer"); return }
        makePool()

        displayLayer.videoGravity = .resizeAspect
        let source = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        )
        let controller = AVPictureInPictureController(contentSource: source)
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.delegate = self
        pipController = controller

        startPump()
    }

    func update(_ map: [String: Any]) {
        snapshot = GearSnapshot.fromMap(map)
    }

    func stop() {
        pump?.cancel(); pump = nil
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        }
        pipController = nil
        displayLayer.flushAndRemoveImage()
        hostView?.removeFromSuperview()
        hostView = nil
        pool = nil
        snapshot = nil
        lastHash = nil
        ptsCount = 0
    }

    // MARK: - Audio session

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .mixWithOthers so we never duck/stop the trainer app's audio.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            NSLog("[PiP] audio session error: \(error)")
        }
    }

    // MARK: - Layer hosting

    private func attachLayer() -> Bool {
        guard let rootView = Self.keyRootView() else { return false }
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        container.isUserInteractionEnabled = false
        container.layer.addSublayer(displayLayer)
        displayLayer.frame = container.bounds
        rootView.insertSubview(container, at: 0) // behind Flutter; effectively invisible
        hostView = container
        return true
    }

    private static func keyRootView() -> UIView? {
        for scene in UIApplication.shared.connectedScenes {
            guard let ws = scene as? UIWindowScene else { continue }
            if let w = ws.windows.first(where: { $0.isKeyWindow }) ?? ws.windows.first {
                return w.rootViewController?.view
            }
        }
        return nil
    }

    // MARK: - Pixel buffer pool

    private func makePool() {
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(renderSize.width),
            kCVPixelBufferHeightKey as String: Int(renderSize.height),
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        let status = CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attrs as CFDictionary, &pool)
        if status != kCVReturnSuccess {
            NSLog("[PiP] CVPixelBufferPoolCreate failed: \(status)")
        }
    }

    // MARK: - Frame pump

    private func startPump() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(Int(1000 / fps)))
        timer.setEventHandler { [weak self] in Task { @MainActor in self?.renderTick() } }
        timer.resume()
        pump = timer
    }

    // Runs on the main actor: `ImageRenderer` (in makePixelBuffer) is
    // @MainActor-isolated. The pump's DispatchSource timer fires on `.main`, then
    // hops onto the main actor via `Task { @MainActor in }` (MainActor.assumeIsolated
    // would be tidier but is iOS 17+; this feature targets iOS 16). If the pump is
    // ever moved off-main to survive backgrounding, keep the CGImage render on the
    // main actor and enqueue the finished CMSampleBuffer off-main.
    @MainActor private func renderTick() {
        guard let snapshot = snapshot else { return }
        let hash = snapshot.contentHash
        // Skip identical frames, but always emit the first one.
        if hash == lastHash, ptsCount > 0 { return }
        lastHash = hash

        guard let pb = makePixelBuffer(for: snapshot),
              let sample = makeSampleBuffer(from: pb) else { return }
        if displayLayer.status == .failed { displayLayer.flush() }
        displayLayer.enqueue(sample)
    }

    @MainActor private func makePixelBuffer(for snapshot: GearSnapshot) -> CVPixelBuffer? {
        guard let pool = pool else { return nil }
        var pbOut: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pbOut) == kCVReturnSuccess,
              let pb = pbOut else { return nil }

        let renderer = ImageRenderer(content:
            GearReadoutView(snapshot: snapshot)
                .frame(width: renderSize.width, height: renderSize.height)
        )
        renderer.scale = 2.0
        guard let cgImage = renderer.cgImage else { return nil }

        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pb),
            width: CVPixelBufferGetWidth(pb),
            height: CVPixelBufferGetHeight(pb),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0,
                                     width: CVPixelBufferGetWidth(pb),
                                     height: CVPixelBufferGetHeight(pb)))
        return pb
    }

    private func makeSampleBuffer(from pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
        var fmt: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &fmt
        ) == noErr, let fmt = fmt else { return nil }

        let scale = CMTimeScale(fps)
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: scale),
            presentationTimeStamp: CMTime(value: ptsCount, timescale: scale),
            decodeTimeStamp: .invalid
        )
        ptsCount += 1
        var sampleOut: CMSampleBuffer?
        guard CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: fmt,
            sampleTiming: &timing,
            sampleBufferOut: &sampleOut
        ) == noErr else { return nil }
        return sampleOut
    }
}

@available(iOS 16.0, *)
extension PipGearController: AVPictureInPictureControllerDelegate {
    func pictureInPictureController(_ c: AVPictureInPictureController,
                                    failedToStartPictureInPictureWithError error: Error) {
        NSLog("[PiP] failed to start: \(error)")
    }

    func pictureInPictureController(
        _ c: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true) // tapping the window brings BikeControl forward
    }
}

@available(iOS 16.0, *)
extension PipGearController: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ c: AVPictureInPictureController, setPlaying playing: Bool) {}
    func pictureInPictureControllerTimeRangeForPlayback(_ c: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity) // live, no scrubber
    }
    func pictureInPictureControllerIsPlaybackPaused(_ c: AVPictureInPictureController) -> Bool { false }
    func pictureInPictureController(_ c: AVPictureInPictureController,
                                    didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}
    func pictureInPictureController(_ c: AVPictureInPictureController,
                                    skipByInterval skipInterval: CMTime,
                                    completion: @escaping () -> Void) { completion() }
}
