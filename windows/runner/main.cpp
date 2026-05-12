#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>
#include <appmodel.h>

#include <memory>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

#include "app_links/app_links_plugin_c_api.h"

// ---------------------------------------------------------------------------
// Packaged-app detection + small environment MethodChannel (pre-existing).
// ---------------------------------------------------------------------------
namespace {

bool IsPackagedApp() {
  UINT32 length = 0;
  // GetCurrentPackageFullName returns APPMODEL_ERROR_NO_PACKAGE when unpackaged.
  const LONG rc = GetCurrentPackageFullName(&length, nullptr);
  return rc != APPMODEL_ERROR_NO_PACKAGE;
}

void RegisterStoreEnvironmentChannel(flutter::FlutterViewController* controller) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      controller->engine()->messenger(), "bike_control/store_env",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "isPackaged") {
          result->Success(flutter::EncodableValue(IsPackagedApp()));
          return;
        }
        result->NotImplemented();
      });

  // Channel must outlive this function.
  static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> s_channel;
  s_channel = std::move(channel);
}

}  // namespace

bool SendAppLinkToInstance(const std::wstring& title) {
  HWND hwnd = ::FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", title.c_str());
  if (hwnd) {
    SendAppLink(hwnd);

    WINDOWPLACEMENT place = {sizeof(WINDOWPLACEMENT)};
    GetWindowPlacement(hwnd, &place);
    switch (place.showCmd) {
      case SW_SHOWMAXIMIZED:
        ShowWindow(hwnd, SW_SHOWMAXIMIZED);
        break;
      case SW_SHOWMINIMIZED:
        ShowWindow(hwnd, SW_RESTORE);
        break;
      default:
        ShowWindow(hwnd, SW_NORMAL);
        break;
    }

    SetWindowPos(0, HWND_TOP, 0, 0, 0, 0, SWP_SHOWWINDOW | SWP_NOSIZE | SWP_NOMOVE);
    SetForegroundWindow(hwnd);
    return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t* command_line, _In_ int show_command) {
  // If another instance of BikeControl is already running, forward the deep
  // link to it and exit (pre-existing behaviour).
  if (SendAppLinkToInstance(L"BikeControl")) {
    return EXIT_SUCCESS;
  }

  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");
  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"BikeControl", origin, size)) {
    return EXIT_FAILURE;
  }

  // Wire the bike_control/store_env channel on the main engine.
  RegisterStoreEnvironmentChannel(window.GetController());

  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
