#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <functional>
#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  flutter::FlutterViewController* GetController() const { return flutter_controller_.get(); }

  // Backwards-compatible alias used by multi_window_native's example.
  flutter::FlutterViewController* GetFlutterViewController() const { return flutter_controller_.get(); }

  // Invoked on OnDestroy so multi_window_native can clean up its messenger
  // registration for this engine before the view goes away.
  void SetOnCloseCallback(std::function<void(flutter::FlutterViewController*)> callback);

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::function<void(flutter::FlutterViewController*)> on_close_callback_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
