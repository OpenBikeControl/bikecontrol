import ReplayKit
import AVFoundation

// IMPORTANT: This file belongs to the ScreenRecordBroadcast Broadcast Upload Extension target.
// It is NOT compiled by the Runner target. Manual Xcode steps required:
//
//   1. File ▸ New ▸ Target ▸ Broadcast Upload Extension
//      - Name: ScreenRecordBroadcast
//      - Bundle Identifier: de.jonasbark.swiftcontrol.darwin.ScreenRecordBroadcast
//      - Uncheck "Include UI Extension"
//   2. Replace the generated SampleHandler.swift with this file (or add this file to the target
//      and delete the generated one).
//   3. In Apple Developer portal: create App Group "group.de.jonasbark.swiftcontrol.darwin"
//      and enable it on BOTH Runner and ScreenRecordBroadcast targets.
//
// App Group: group.de.jonasbark.swiftcontrol.darwin (MUST match ScreenRecorderPlugin.swift)

class SampleHandler: RPBroadcastSampleHandler {
  // MUST match ScreenRecorderPlugin.appGroup
  static let appGroup = "group.de.jonasbark.swiftcontrol.darwin"

  // MUST match ScreenRecorderPlugin.stopNotificationName
  static let stopNotificationName = "de.jonasbark.swiftcontrol.darwin.stopBroadcast"

  private var writer: AVAssetWriter?
  private var videoInput: AVAssetWriterInput?
  private var sessionStarted = false
  private var outputURL: URL?

  override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: SampleHandler.appGroup) else {
      NSLog("SampleHandler: failed to get App Group container — check portal config")
      return
    }

    let timestamp = Int(Date().timeIntervalSince1970)
    let url = container.appendingPathComponent("BikeControl_\(timestamp).mp4")
    outputURL = url
    try? FileManager.default.removeItem(at: url)

    // Use main screen size and scale for full-resolution capture.
    let screen = UIScreen.main.bounds.size
    let scale = UIScreen.main.scale
    let videoSettings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: Int(screen.width * scale),
      AVVideoHeightKey: Int(screen.height * scale),
    ]

    guard let assetWriter = try? AVAssetWriter(outputURL: url, fileType: .mp4) else {
      NSLog("SampleHandler: failed to create AVAssetWriter at \(url.path)")
      return
    }
    writer = assetWriter

    let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    input.expectsMediaDataInRealTime = true
    videoInput = input

    if assetWriter.canAdd(input) {
      assetWriter.add(input)
    }
    assetWriter.startWriting()

    // Listen for the app's stop signal via Darwin notification center.
    // The host app posts this when the user triggers "stop recording".
    CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      Unmanaged.passUnretained(self).toOpaque(),
      { _, observer, _, _, _ in
        guard let observer = observer else { return }
        let handler = Unmanaged<SampleHandler>.fromOpaque(observer).takeUnretainedValue()
        // Finish with an error to terminate the broadcast; broadcastFinished() will then run.
        handler.finishBroadcastWithError(
          NSError(domain: "de.jonasbark.swiftcontrol.darwin", code: 0,
                  userInfo: [NSLocalizedDescriptionKey: "Recording stopped by app"]))
      },
      SampleHandler.stopNotificationName as CFString,
      nil,
      .deliverImmediately)
  }

  override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
    guard sampleBufferType == .video,
          let writer = writer,
          let input = videoInput,
          CMSampleBufferDataIsReady(sampleBuffer) else { return }

    if !sessionStarted {
      let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
      writer.startSession(atSourceTime: pts)
      sessionStarted = true
    }

    if input.isReadyForMoreMediaData {
      input.append(sampleBuffer)
    }
  }

  override func broadcastFinished() {
    // Remove the Darwin observer to avoid dangling pointer after dealloc.
    CFNotificationCenterRemoveObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      Unmanaged.passUnretained(self).toOpaque(),
      CFNotificationName(SampleHandler.stopNotificationName as CFString),
      nil)

    let group = DispatchGroup()
    group.enter()
    videoInput?.markAsFinished()
    writer?.finishWriting { group.leave() }
    group.wait()

    // Write the output path into the shared App Group defaults so the host app
    // can read it back when its stop() method channel call returns.
    if let path = outputURL?.path {
      UserDefaults(suiteName: SampleHandler.appGroup)?.set(path, forKey: "lastRecordingPath")
      NSLog("SampleHandler: recording saved to \(path)")
    }
  }
}
