#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include <desktop_multi_window/desktop_multi_window_plugin.h>

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // DIAGNOSTIC: do NOT call RegisterPlugins on the secondary engine.
  // Several of BikeControl's Windows plugins (windows_iap, smtc_windows,
  // media_key_detector_windows, bluetooth_low_energy_windows, ...) own
  // process-singleton OS resources already held by this main engine. A
  // second RegisterWithRegistrar pass on a second engine may not error but
  // can deadlock the engine's boot before Dart main() runs — matching the
  // symptom seen here with BOTH desktop_multi_window and multi_window_native.
  //
  // With plugin registration skipped, the trainer overlay sub-window won't
  // have access to most plugins, but it doesn't need them — it only needs
  // the desktop_multi_window plugin (to receive WindowMethodChannel calls
  // from the parent) and window_manager (for position/size). Selectively
  // register only those if the diagnostic confirms the theory.
  DesktopMultiWindowSetWindowCreatedCallback([](void *controller) {
    (void)controller;
    // Intentionally empty for the moment. If Dart main() now runs in the
    // sub-window, we'll add per-plugin registration here for the handful
    // the overlay actually uses.
  });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
