#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <appmodel.h>
#include "flutter_window.h"
#include "utils.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include "app_links/app_links_plugin_c_api.h"

namespace
{

  bool IsPackagedApp()
  {
    UINT32 length = 0;
    // GetCurrentPackageFullName returns APPMODEL_ERROR_NO_PACKAGE when unpackaged.
    const LONG rc = GetCurrentPackageFullName(&length, nullptr);
    return rc != APPMODEL_ERROR_NO_PACKAGE;
  }

  void RegisterStoreEnvironmentChannel(flutter::FlutterViewController *controller)
  {
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        controller->engine()->messenger(), "bike_control/store_env",
        &flutter::StandardMethodCodec::GetInstance());

    channel->SetMethodCallHandler(
        [](const flutter::MethodCall<flutter::EncodableValue> &call,
           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
        {
          if (call.method_name() == "isPackaged")
          {
            result->Success(flutter::EncodableValue(IsPackagedApp()));
            return;
          }
          result->NotImplemented();
        });

    // Channel must outlive this function.
    static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> s_channel;
    s_channel = std::move(channel);
  }

} // namespace

bool SendAppLinkToInstance(const std::wstring &title)
{
  // Find our exact window
  HWND hwnd = ::FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", title.c_str());

  if (hwnd)
  {
    // Dispatch new link to current window
    SendAppLink(hwnd);

    // (Optional) Restore our window to front in same state
    WINDOWPLACEMENT place = {sizeof(WINDOWPLACEMENT)};
    GetWindowPlacement(hwnd, &place);

    switch (place.showCmd)
    {
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
    // END (Optional) Restore

    // Window has been found, don't create another one.
    return true;
  }

  return false;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command)
{
  // Replace "example" with the generated title found as parameter of `window.Create` in this file.
  // You may ignore the result if you need to create another window.
  if (SendAppLinkToInstance(L"BikeControl"))
  {
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent())
  {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"BikeControl", origin, size))
  {
    return EXIT_FAILURE;
  }

  // Register our small environment channel after engine/window creation.
  // FlutterWindow exposes the controller via GetController().
  RegisterStoreEnvironmentChannel(window.GetController());

  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0))
  {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
