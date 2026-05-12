#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
// Import the generated plugin registrant
#include "flutter/generated_plugin_registrant.h"

#include "flutter_window.h"
#include "utils.h"
#include "win32_window.h"
#include "multi_window_native_plugin.h"

#include <iostream>
#include <memory>
#include <string>
#include <vector>

// Context to store secondary windows
struct SecondaryWindowContext {
  std::string windowId; 
  std::unique_ptr<Win32Window> window;
  std::unique_ptr<flutter::FlutterViewController> controller;
};

static std::vector<std::unique_ptr<SecondaryWindowContext>> secondary_windows;

// Function to create new secondary windows
void CreateNewWindow(const std::vector<std::string>& args) {
   std::cerr << "Inside create window" << std::endl;
  flutter::DartProject project(L"data");
  project.set_dart_entrypoint("main");
  project.set_dart_entrypoint_arguments(args);

  auto flutter_controller = std::make_unique<flutter::FlutterViewController>(
      800, 600, project);

  if (!flutter_controller->engine() || !flutter_controller->view()) {
    std::cerr << "Failed to create FlutterViewController for secondary window"
              << std::endl;
    return;
  }

  // Register messenger with MultiWindow plugin
  MultiWindowNativePlugin::RegisterMessenger(
    flutter_controller->engine()->messenger());

  auto window = std::make_unique<Win32Window>();
  Win32Window::Point origin(50, 50);
  Win32Window::Size size(800, 600);

  if (!window->Create(L"Secondary Window", origin, size)) {
    std::cerr << "Failed to create secondary Win32 window" << std::endl;
    return;
  }

  //  Register all plugins for this engine
  RegisterPlugins(flutter_controller->engine());

  window->SetQuitOnClose(false);
  window->SetChildContent(flutter_controller->view()->GetNativeWindow());

  HWND hwnd = GetAncestor(flutter_controller->view()->GetNativeWindow(), GA_ROOT);
  if (hwnd == nullptr){
     std::cerr << "GetAncestor returned null root HWND" << std::endl;
      return;
  }
  SetWindowTextW(hwnd, L"Secondary Window");
  ShowWindow(hwnd, SW_SHOWNORMAL);
  UpdateWindow(hwnd);
  SetForegroundWindow(hwnd);

  auto ctx = std::make_unique<SecondaryWindowContext>();
  ctx->window = std::move(window);
  ctx->controller = std::move(flutter_controller);

  secondary_windows.push_back(std::move(ctx));
}

// Function to close windows
void CloseWindow(bool isMainWindow,const std::string& windowId) {
  if (isMainWindow) {
      // Close all secondary windows and quit app
      for (auto& ctx : secondary_windows) {
          if (ctx->windowId != windowId) {  // skip main window itself
              HWND hwnd = ctx->window->GetHandle();
              if (hwnd) {
                  ::PostMessage(hwnd, WM_CLOSE, 0, 0);
              }
          }
      }
      secondary_windows.clear();
      MultiWindowNativePlugin::ClearMessengers();
      PostQuitMessage(0);  
  } else {
      auto it = std::find_if(secondary_windows.begin(), secondary_windows.end(),
                              [&windowId](const std::unique_ptr<SecondaryWindowContext>& ctx) { return ctx->windowId == windowId; });
      if (it != secondary_windows.end()) {
          auto& ctx = *it;
          // Unregister messenger before destroying
          auto engine = ctx->controller->engine();
          auto messengerPtr = engine->messenger();
          MultiWindowNativePlugin::UnregisterMessenger(messengerPtr);

          // Destroy native window
          HWND hwnd = GetAncestor(ctx->controller->view()->GetNativeWindow(), GA_ROOT);
          if (hwnd) {
              DestroyWindow(hwnd);
          }
          // Remove context (this will destroy the controller and engine)
          secondary_windows.erase(it);
      }
  }
}

int APIENTRY wWinMain(HINSTANCE instance,
                      HINSTANCE prev,
                      wchar_t* command_line,
                      int show_command) {
  // Attach to console if available (flutter run) or create one for debugging
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Register callbacks for MultiWindow plugin
  MultiWindowNativePlugin::SetCreateWindowCallback(CreateNewWindow);
  MultiWindowNativePlugin::SetCloseWindowCallback([](bool isMainWindow, const std::string& windowId) {
    CloseWindow(isMainWindow, windowId);
  });
  MultiWindowNativePlugin::SetWindowIdCallback(
    [](const std::string& windowId) {
        // Update SecondaryWindowContext with this window ID
        if (!secondary_windows.empty()) {
            secondary_windows.back()->windowId = windowId;
        }
    });

  // Launch the main Flutter window
  flutter::DartProject project(L"data");
  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);

  if (!window.Create(L"multi_window_native_example", origin, size)) {
    return EXIT_FAILURE;
  }

  // Set up method call handler for main window
  auto* main_messenger = window.GetFlutterViewController()->engine()->messenger();
  MultiWindowNativePlugin::RegisterMessenger(main_messenger);
  
  // Create method channel for main window
  auto main_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      main_messenger, "com.coditas.multi_window_native/pluginChannel",
      &flutter::StandardMethodCodec::GetInstance());
  
  main_channel->SetMethodCallHandler(
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
          auto isMainWindowIt = args->find(flutter::EncodableValue("isMainWindow"));
          auto windowIdIt = args->find(flutter::EncodableValue("windowId"));
          
          if (isMainWindowIt != args->end() && windowIdIt != args->end()) {
            if (auto isMainWindowPtr = std::get_if<bool>(&isMainWindowIt->second)) {
              if (auto windowIdPtr = std::get_if<std::string>(&windowIdIt->second)) {
                if (MultiWindowNativePlugin::HasCloseWindowCallback()) {
                  MultiWindowNativePlugin::CallCloseWindow(*isMainWindowPtr, *windowIdPtr);
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
          auto windowIdIt = args->find(flutter::EncodableValue("windowId"));
          if (windowIdIt != args->end()) {
            if (auto windowIdPtr = std::get_if<std::string>(&windowIdIt->second)) {
              if (MultiWindowNativePlugin::HasWindowIdCallback()) {
                MultiWindowNativePlugin::CallSetWindowId(*windowIdPtr);
              }
            }
          }
          result->Success(flutter::EncodableValue(true));
        }  else if (call.method_name() == "notifyUiReady"){
          // no-op for now
          result->Success(flutter::EncodableValue(true));
        }
        else {
          // Handle other methods or broadcast
          MultiWindowNativePlugin::BroadcastToAll(method, *call.arguments());
          result->Success(flutter::EncodableValue(true));
        }
      });
  
  // Keep the channel alive
  static auto stored_main_channel = std::move(main_channel);

  window.SetQuitOnClose(true);

  // Run message loop
  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
