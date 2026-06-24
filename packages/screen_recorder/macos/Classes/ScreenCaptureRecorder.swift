import Foundation
import AVFoundation
import CoreGraphics
@preconcurrency import ScreenCaptureKit

/// Records the main display to an mp4 using ScreenCaptureKit + AVAssetWriter.
@available(macOS 12.3, *)
final class ScreenCaptureRecorder: NSObject, SCStreamOutput {
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

    let dir = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Movies/BikeControl", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("BikeControl_\(Int(Date().timeIntervalSince1970)).mp4")
    self.outputURL = url

    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let settings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: display.width,
      AVVideoHeightKey: display.height,
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = true
    writer.add(input)
    self.writer = writer
    self.videoInput = input

    let filter = SCContentFilter(display: display, excludingWindows: [])
    let config = SCStreamConfiguration()
    config.width = display.width
    config.height = display.height
    config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
    config.queueDepth = 5
    config.pixelFormat = kCVPixelFormatType_32BGRA

    let stream = SCStream(filter: filter, configuration: config, delegate: nil)
    try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "screen_recorder.capture"))
    self.stream = stream
    writer.startWriting()
    try await stream.startCapture()
  }

  func stop() async -> String? {
    guard let stream = stream else { return nil }
    try? await stream.stopCapture()
    self.stream = nil
    videoInput?.markAsFinished()
    await writer?.finishWriting()
    let path = outputURL?.path
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
}
