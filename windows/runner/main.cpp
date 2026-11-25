#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>
#include <appmodel.h>

#include <cstdint>
#include <iostream>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <vector>

#include "flutter_window.h"
#include "utils.h"
#include "win32_window.h"
#include "flutter/generated_plugin_registrant.h"

#include "app_links/app_links_plugin_c_api.h"
#include "multi_window_native_plugin.h"

// Selective sub-engine plugin registration — only the two plugins the trainer
// overlay sub-window actually needs.
#include <window_manager/window_manager_plugin.h>
#include <multi_window_native/multi_window_native_plugin_c_api.h>

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
// multi_window_native: secondary-window management.
//
// The plugin is just a method-channel proxy — the host app supplies the
// actual window-creation logic via callbacks. Adapted from the package's
// example/windows/runner/main.cpp.
// ---------------------------------------------------------------------------

// The overlay's top-level window. Like FlutterWindow, it offers every message
// to the sub-engine's plugins first: window_manager learns about moves (its
// "moved" event, which saves the overlay position) and the close button only
// through HandleTopLevelWindowProc.
class OverlayWindow : public Win32Window {
 public:
  // Set to nullptr before the controller is destroyed.
  void SetController(flutter::FlutterViewController* controller) {
    controller_ = controller;
  }

 protected:
  LRESULT MessageHandler(HWND hwnd, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override {
    if (controller_) {
      std::optional<LRESULT> result =
          controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
      if (result) {
        return *result;
      }
      if (message == WM_CLOSE) {
        // window_manager has passed the close on to the overlay's Dart, which
        // reports the position and the close to the main window, then asks
        // for the window to be closed (see CloseWindowSoon). Until then the
        // window is only hidden: destroying it here would leave the engine
        // running without its window.
        ShowWindow(hwnd, SW_HIDE);
        return 0;
      }
    }
    return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
  }

  void OnDestroy() override {
    controller_ = nullptr;
    Win32Window::OnDestroy();
  }

 private:
  flutter::FlutterViewController* controller_ = nullptr;
};

struct SecondaryWindowContext {
  std::string windowId;
  std::unique_ptr<OverlayWindow> window;
  std::unique_ptr<flutter::FlutterViewController> controller;
  // The handler-owning MethodChannel must outlive the engine that uses it.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      plugin_channel;
};

static std::vector<std::unique_ptr<SecondaryWindowContext>> g_secondary_windows;

static void CloseWindow(bool isMainWindow, const std::string& windowId);

// Secondary windows whose own Dart asked to be closed.
static std::vector<std::string> g_pending_closes;

// Closes the secondary window |windowId| from the message loop. The request
// comes in on that window's own engine, which must not be shut down from
// inside one of its own channel handlers.
static void CloseWindowSoon(const std::string& windowId) {
  g_pending_closes.push_back(windowId);
  SetTimer(nullptr, 0, 0, [](HWND, UINT, UINT_PTR timer_id, DWORD) {
    KillTimer(nullptr, timer_id);
    std::vector<std::string> ids;
    ids.swap(g_pending_closes);
    for (const auto& id : ids) {
      CloseWindow(false, id);
    }
  });
}

static void CreateNewWindow(const std::vector<std::string>& args) {
  flutter::DartProject project(L"data");
  project.set_dart_entrypoint("main");
  project.set_dart_entrypoint_arguments(args);

  // 220x100 here matches the desktop overlay's intended frame; window_manager
  // resizes itself in `runDesktopOverlayWindow` anyway.
  auto controller = std::make_unique<flutter::FlutterViewController>(
      220, 100, project);

  if (!controller->engine() || !controller->view()) {
    std::cerr << "[multi_window_native] failed to create FlutterViewController"
              << std::endl;
    return;
  }

  auto* sub_messenger = controller->engine()->messenger();
  MultiWindowNativePlugin::RegisterMessenger(sub_messenger);

  auto window = std::make_unique<OverlayWindow>();
  Win32Window::Point origin(50, 50);
  Win32Window::Size size(220, 100);
  if (!window->Create(L"BikeControl Overlay", origin, size)) {
    std::cerr << "[multi_window_native] failed to create Win32 window" << std::endl;
    return;
  }

  // Selective plugin registration: only register window_manager on the
  // sub-engine. Calling RegisterPlugins() here deadlocks the sub-engine
  // before Dart main() runs — BikeControl has ~20 Windows plugins; several
  // own process-singleton OS resources already held by the main engine
  // (windows_iap, media_key_detector_windows, bluetooth_low_energy_windows,
  // etc.).
  WindowManagerPluginRegisterWithRegistrar(
      controller->engine()->GetRegistrarForPlugin("WindowManagerPlugin"));

  // DO NOT call `MultiWindowNativePluginRegisterWithRegistrar(...)` here.
  // That symbol comes from the plugin DLL, which has its OWN copy of the
  // `MultiWindowNativePlugin` class statics. Our `RegisterMessenger` /
  // `BroadcastToAll` calls in this runner link to the runner-compiled copy
  // of those statics, so the DLL's `messengers_` would stay empty and
  // broadcasts from the sub-window would iterate an empty list.
  //
  // Instead, wire the channel handler ourselves on the sub-engine —
  // identical to SetMainWindowMethodHandler. Both engines then route
  // through the runner's single copy of MultiWindowNativePlugin::messengers_.
  auto sub_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      sub_messenger, "com.coditas.multi_window_native/pluginChannel",
      &flutter::StandardMethodCodec::GetInstance());
  sub_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const auto& method = call.method_name();
        if (method == "setWindowId") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto it = args->find(flutter::EncodableValue("windowId"));
            if (it != args->end()) {
              if (auto p = std::get_if<std::string>(&it->second)) {
                if (MultiWindowNativePlugin::HasWindowIdCallback()) {
                  MultiWindowNativePlugin::CallSetWindowId(*p);
                }
              }
            }
          }
          result->Success(flutter::EncodableValue(true));
        } else if (method == "notifyUiReady") {
          result->Success(flutter::EncodableValue(true));
        } else if (method == "closeWindow") {
          // The overlay closing itself (its close button). Never the main
          // window: that one is closed only from its own engine.
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto it = args->find(flutter::EncodableValue("windowId"));
            if (it != args->end()) {
              if (auto p = std::get_if<std::string>(&it->second)) {
                CloseWindowSoon(*p);
              }
            }
          }
          result->Success(flutter::EncodableValue(true));
        } else {
          // Any other call (e.g. notifyAllWindows from this sub-window's
          // Dart) is a broadcast — fan out to every registered messenger
          // using the RUNNER's copy of the static list.
          MultiWindowNativePlugin::BroadcastToAll(method, *call.arguments());
          result->Success(flutter::EncodableValue(true));
        }
      });

  window->SetQuitOnClose(false);
  window->SetController(controller.get());
  window->SetChildContent(controller->view()->GetNativeWindow());

  HWND hwnd = GetAncestor(controller->view()->GetNativeWindow(), GA_ROOT);
  if (hwnd != nullptr) {
    SetWindowTextW(hwnd, L"BikeControl Overlay");
    ShowWindow(hwnd, SW_SHOWNORMAL);
    UpdateWindow(hwnd);
    SetForegroundWindow(hwnd);
  }

  // Kick the engine the same way FlutterWindow::OnCreate does. Without this,
  // the sub-window's engine starts at its construction size (220x100) and
  // never re-paints on subsequent resizes — producing the "white box that
  // doesn't follow the window" symptom.
  auto* raw_controller = controller.get();
  Win32Window* raw_window = window.get();
  raw_controller->engine()->SetNextFrameCallback([raw_window]() {
    raw_window->Show();
  });
  raw_controller->ForceRedraw();

  auto ctx = std::make_unique<SecondaryWindowContext>();
  // The id the window's Dart knows it by: window_manager's getId(), which is
  // this top-level HWND as a number.
  ctx->windowId = std::to_string(
      reinterpret_cast<std::intptr_t>(window->GetHandle()));
  ctx->window = std::move(window);
  ctx->controller = std::move(controller);
  ctx->plugin_channel = std::move(sub_channel);
  g_secondary_windows.push_back(std::move(ctx));
}

// Shuts down every secondary engine and destroys its window. Must run while
// the message loop is still pumping: left to the static destructor of
// g_secondary_windows (after wWinMain returns), the engine shutdown hangs the
// process with the overlay still on screen.
static void DestroySecondaryWindows() {
  for (auto& ctx : g_secondary_windows) {
    MultiWindowNativePlugin::UnregisterMessenger(
        ctx->controller->engine()->messenger());
    // The window outlives the controller below; it must not hand messages
    // to a destroyed one.
    ctx->window->SetController(nullptr);
  }
  g_secondary_windows.clear();
}

// Ends the process if shutting down takes longer than a normal exit. Plugin
// teardown can block the UI thread on Windows Bluetooth: universal_ble waits
// for a pending connect to time out and for GATT Close calls to return, which
// can take seconds or never happen. Nothing is left to save once the main
// window is gone, and the OS releases the Bluetooth handles with the process.
static void ArmExitWatchdog() {
  static std::once_flag armed;
  std::call_once(armed, [] {
    std::thread([] {
      Sleep(3000);
      TerminateProcess(GetCurrentProcess(), EXIT_SUCCESS);
    }).detach();
  });
}

static void CloseWindow(bool isMainWindow, const std::string& windowId) {
  if (isMainWindow) {
    ArmExitWatchdog();
    DestroySecondaryWindows();
    MultiWindowNativePlugin::ClearMessengers();
    PostQuitMessage(0);
    return;
  }

  auto it = std::find_if(
      g_secondary_windows.begin(), g_secondary_windows.end(),
      [&windowId](const std::unique_ptr<SecondaryWindowContext>& ctx) {
        return ctx->windowId == windowId;
      });
  if (it == g_secondary_windows.end()) return;

  // Taken out of the list first, so a second close for the same window (the
  // overlay's own close button and the overlay switch in the main window can
  // both ask) finds nothing to do.
  std::unique_ptr<SecondaryWindowContext> ctx = std::move(*it);
  g_secondary_windows.erase(it);

  MultiWindowNativePlugin::UnregisterMessenger(
      ctx->controller->engine()->messenger());
  ctx->window->SetController(nullptr);
  HWND hwnd = ctx->window->GetHandle();
  if (hwnd && IsWindow(hwnd)) DestroyWindow(hwnd);
}

static void SetMainWindowMethodHandler(flutter::FlutterViewController* controller) {
  auto* messenger = controller->engine()->messenger();
  MultiWindowNativePlugin::RegisterMessenger(messenger);

  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "com.coditas.multi_window_native/pluginChannel",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const auto& method = call.method_name();

        if (method == "createWindow") {
          if (MultiWindowNativePlugin::HasCreateWindowCallback()) {
            const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
            if (!args) {
              result->Error("INVALID_ARGS", "Expected map");
              return;
            }
            std::vector<std::string> str_args;
            for (const auto& pair : *args) {
              if (auto p = std::get_if<std::string>(&pair.second)) {
                str_args.push_back(*p);
              }
            }
            MultiWindowNativePlugin::CallCreateWindow(str_args);
          }
          result->Success(flutter::EncodableValue(true));
        } else if (method == "closeWindow") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args) {
            result->Error("INVALID_ARGS", "Expected map");
            return;
          }
          auto isMainIt = args->find(flutter::EncodableValue("isMainWindow"));
          auto windowIdIt = args->find(flutter::EncodableValue("windowId"));
          if (isMainIt != args->end() && windowIdIt != args->end()) {
            if (auto isMainPtr = std::get_if<bool>(&isMainIt->second)) {
              if (auto windowIdPtr = std::get_if<std::string>(&windowIdIt->second)) {
                if (MultiWindowNativePlugin::HasCloseWindowCallback()) {
                  MultiWindowNativePlugin::CallCloseWindow(*isMainPtr, *windowIdPtr);
                }
              }
            }
          }
          result->Success(flutter::EncodableValue(true));
        } else if (method == "getMessengerCount") {
          result->Success(flutter::EncodableValue(
              static_cast<int>(MultiWindowNativePlugin::GetMessengerCount())));
        } else if (method == "setWindowId") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args) {
            result->Error("INVALID_ARGS", "Expected map");
            return;
          }
          auto it = args->find(flutter::EncodableValue("windowId"));
          if (it != args->end()) {
            if (auto p = std::get_if<std::string>(&it->second)) {
              if (MultiWindowNativePlugin::HasWindowIdCallback()) {
                MultiWindowNativePlugin::CallSetWindowId(*p);
              }
            }
          }
          result->Success(flutter::EncodableValue(true));
        } else if (method == "notifyUiReady") {
          result->Success(flutter::EncodableValue(true));
        } else {
          // Anything else is a broadcast (notifyAllWindows).
          MultiWindowNativePlugin::BroadcastToAll(method, *call.arguments());
          result->Success(flutter::EncodableValue(true));
        }
      });

  // Outlive this function.
  static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> s_channel;
  s_channel = std::move(channel);
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

  // Register multi_window_native callbacks BEFORE creating the main window so
  // that Dart-side calls right after engine boot find them.
  MultiWindowNativePlugin::SetCreateWindowCallback(CreateNewWindow);
  MultiWindowNativePlugin::SetCloseWindowCallback(
      [](bool isMainWindow, const std::string& windowId) {
        CloseWindow(isMainWindow, windowId);
      });
  // No SetWindowIdCallback: CreateNewWindow knows each window's id itself.
  // Taking it from setWindowId named whichever window was created last, and
  // the call can arrive before that window is in the list, or come from the
  // main window.

  flutter::DartProject project(L"data");
  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"BikeControl", origin, size)) {
    return EXIT_FAILURE;
  }

  // Wire the multi_window_native method channel + bike_control/store_env on
  // the main engine.
  SetMainWindowMethodHandler(window.GetController());
  RegisterStoreEnvironmentChannel(window.GetController());

  // When the main window is closed (Alt-F4, the close button), close the
  // overlay with it, then clean up the main messenger.
  window.SetOnCloseCallback([](flutter::FlutterViewController* c) {
    ArmExitWatchdog();
    // Engine teardown can outlive the hidden window by seconds: universal_ble
    // waits for a pending connect to time out. Drop the title SendAppLinkToInstance
    // looks for, so a relaunch in that time starts instead of handing off to
    // this exiting instance. Straight to DefWindowProc: Win32Window has already
    // dropped its handle and would pass WM_SETTEXT on to a null window.
    if (c) {
      HWND root = GetAncestor(c->view()->GetNativeWindow(), GA_ROOT);
      if (root) {
        DefWindowProcW(root, WM_SETTEXT, 0, reinterpret_cast<LPARAM>(L""));
      }
    }
    DestroySecondaryWindows();
    if (c) MultiWindowNativePlugin::UnregisterMessenger(c->engine()->messenger());
  });

  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
