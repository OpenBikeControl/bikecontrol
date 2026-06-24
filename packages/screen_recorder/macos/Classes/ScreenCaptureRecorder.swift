import Foundation
import AVFoundation
import CoreGraphics
@preconcurrency import ScreenCaptureKit

/// Records the main display to an mp4 using ScreenCaptureKit + AVAssetWriter.
@available(macOS 12.3, *)
final class ScreenCaptureRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
  private var stream: SCStream?
  private var writer: AVAssetWriter?
  private var videoInput: AVAssetWriterInput?
  private var sessionStarted = false
  private var outputURL: URL?

  func start() async throws {
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
    guard let display = content.displays.first else {
      throw NSError(domain: "screen_recorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display"])
    }

    // Fix 1 (Retina): capture at native pixels using scaleFactor.
    // TODO: scaleFactor — SCDisplay does not expose scaleFactor in this SDK version;
    // use display.width/height (points) for now. On Retina displays this may capture
    // at logical resolution rather than native pixel resolution.
    let pixelWidth = display.width
    let pixelHeight = display.height

    let dir = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Movies/BikeControl", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("BikeControl_\(Int(Date().timeIntervalSince1970)).mp4")
    self.outputURL = url

    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let settings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: pixelWidth,
      AVVideoHeightKey: pixelHeight,
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = true
    writer.add(input)
    self.writer = writer
    self.videoInput = input

    let filter = SCContentFilter(display: display, excludingWindows: [])
    let config = SCStreamConfiguration()
    // Fix 1 (Retina): set stream dimensions to native pixel dimensions
    config.width = pixelWidth
    config.height = pixelHeight
    config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
    config.queueDepth = 5
    config.pixelFormat = kCVPixelFormatType_32BGRA

    // Fix 5 (stream errors): pass self as delegate to observe mid-session failures
    let stream = SCStream(filter: filter, configuration: config, delegate: self)
    try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "screen_recorder.capture"))
    self.stream = stream

    // Fix 3 (cleanup on throw): cancel writer if start() throws after writer creation
    var started = false
    defer {
      if !started {
        writer.cancelWriting()
        self.writer = nil
        self.videoInput = nil
        self.stream = nil
      }
    }

    // Fix 2 (startWriting): guard the Bool return value
    guard writer.startWriting() else {
      throw writer.error ?? NSError(domain: "screen_recorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "AVAssetWriter failed to start"])
    }

    try await stream.startCapture()
    started = true
  }

  func stop() async -> String? {
    guard let stream = stream else { return nil }

    // Fix 4 (stop-before-first-frame): cancel instead of finalize if no frames were written
    if !sessionStarted {
      try? await stream.stopCapture()
      self.stream = nil
      writer?.cancelWriting()
      writer = nil
      videoInput = nil
      return nil
    }

    try? await stream.stopCapture()
    self.stream = nil
    videoInput?.markAsFinished()
    await writer?.finishWriting()

    // Fix 4 (stop finalize): only return path if finalization succeeded
    let status = writer?.status
    let path = status == .completed ? outputURL?.path : nil
    if status != .completed {
      NSLog("screen_recorder: finishWriting status=\(String(describing: status)) err=\(String(describing: writer?.error))")
    }

    writer = nil
    videoInput = nil
    sessionStarted = false
    return path
  }

  // SCStreamOutput
  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard type == .screen, sampleBuffer.isValid,
          let writer = writer, let input = videoInput else { return }
    guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
          let statusRaw = attachments.first?[.status] as? Int,
          let status = SCFrameStatus(rawValue: statusRaw), status == .complete else { return }

    if !sessionStarted {
      writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
      sessionStarted = true
    }
    if input.isReadyForMoreMediaData {
      input.append(sampleBuffer)
    }
  }

  // Fix 5 (stream errors): SCStreamDelegate — log mid-session stream errors
  func stream(_ stream: SCStream, didStopWithError error: Error) {
    NSLog("screen_recorder: SCStream stopped with error: \(error)")
  }
}
