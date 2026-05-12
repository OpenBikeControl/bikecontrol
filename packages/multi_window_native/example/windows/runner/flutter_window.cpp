#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}


flutter::FlutterViewController* FlutterWindow::GetFlutterViewController() const {
  return flutter_controller_.get();
}

//plugin chnges
void FlutterWindow::SetOnCloseCallback(std::function<void(flutter::FlutterViewController*)> callback) {
  on_close_callback_ = callback;
}

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
  //newly added
  if (!flutter_controller_ || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([this]() { //newly added
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  //plugin changes
  if (on_close_callback_ && flutter_controller_) {
    on_close_callback_(flutter_controller_.get());
  }
  flutter_controller_ = nullptr;
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

  // Handle window focus events to prevent freezing
  switch (message) {
    case WM_ACTIVATE:
      if (flutter_controller_ && LOWORD(wparam) != WA_INACTIVE) {
        // Window is being activated - force Flutter to redraw
        // This ensures the render pipeline resumes properly
        flutter_controller_->ForceRedraw();
      }
      break;
      
    case WM_SETFOCUS:
      if (flutter_controller_) {
        // Window gained focus - ensure Flutter redraws
        flutter_controller_->ForceRedraw();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}


