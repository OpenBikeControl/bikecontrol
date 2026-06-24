#ifndef SCREEN_RECORDER_CAPTURE_RECORDER_H_
#define SCREEN_RECORDER_CAPTURE_RECORDER_H_
#include <string>

namespace screen_recorder {
// Captures the primary monitor via Windows.Graphics.Capture and encodes to
// H.264 mp4 in the user's Videos\BikeControl folder via Media Foundation.
class CaptureRecorder {
 public:
  static bool IsSupported();           // GraphicsCaptureSession::IsSupported()
  bool Start();                        // returns true if capture started
  std::string Stop();                  // returns saved path, or "" on failure
  ~CaptureRecorder();
 private:
  struct Impl;
  Impl* impl_ = nullptr;
};
}  // namespace screen_recorder
#endif
