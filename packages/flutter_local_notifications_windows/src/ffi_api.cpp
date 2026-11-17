#include <windows.h>  // <-- This must be the first Windows header
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Data.Xml.Dom.h>

#include "ffi_api.h"
#include "plugin.hpp"
#include "utils.hpp"

using winrt::Windows::Data::Xml::Dom::XmlDocument;

// Every function below is called from Dart through FFI. A C++ exception that
// escapes one ends the app (FAIL_FAST_FATAL_APP_EXIT), and WinRT throws for
// ordinary conditions (notifications turned off, platform unavailable, ...), so
// each one catches everything and reports failure instead.

bool hasPackageIdentity() {
  if (!IsWindows8OrGreater()) return false;
  uint32_t length = 0;
  int error = GetCurrentPackageFullName(&length, nullptr);
  return error != APPMODEL_ERROR_NO_PACKAGE;
}

NativePlugin* createPlugin() { return new NativePlugin(); }

void disposePlugin(NativePlugin* plugin) { delete plugin; }

bool init(
  NativePlugin* plugin, char* appName, char* aumId, char* guid, char* iconPath,
  NativeNotificationCallback callback
) {
  try {
    string icon;
    if (iconPath != nullptr) icon = string(iconPath);
    const auto didRegister = plugin->registerApp(aumId, appName, guid, icon, callback);
    if (!didRegister) return false;
    plugin->hasIdentity = hasPackageIdentity();
    plugin->aumid = winrt::to_hstring(aumId);
    plugin->notifier = plugin->hasIdentity
      ? ToastNotificationManager::CreateToastNotifier()
      : ToastNotificationManager::CreateToastNotifier(plugin->aumid);
    plugin->history = ToastNotificationManager::History();
    plugin->isReady = true;
    return true;
  } catch (...) {
    plugin->isReady = false;
    return false;
  }
}

bool isValidXml(char* xml) {
  try {
    XmlDocument doc = XmlDocument();
    doc.LoadXml(winrt::to_hstring(xml));
    return true;
  } catch (...) {
    return false;
  }
}

bool showNotification(NativePlugin* plugin, int id, char* xml, NativeStringMap bindings) {
  if (!plugin->isReady) return false;
  try {
    XmlDocument doc;
    doc.LoadXml(winrt::to_hstring(xml));
    ToastNotification notification(doc);
    const auto data = dataFromMap(bindings);
    notification.Tag(winrt::to_hstring(id));
    notification.Data(data);
    plugin->notifier.value().Show(notification);
    return true;
  } catch (...) {
    return false;
  }
}

bool scheduleNotification(NativePlugin* plugin, int id, char* xml, int time) {
  if (!plugin->isReady) return false;
  try {
    XmlDocument doc;
    doc.LoadXml(winrt::to_hstring(xml));
    ScheduledToastNotification notification(doc, winrt::clock::from_time_t(time));
    notification.Tag(winrt::to_hstring(id));
    plugin->notifier.value().AddToSchedule(notification);
    return true;
  } catch (...) {
    return false;
  }
}

NativeUpdateResult updateNotification(NativePlugin* plugin, int id, NativeStringMap bindings) {
  if (!plugin->isReady) return NativeUpdateResult::failed;
  try {
    const auto tag = winrt::to_hstring(id);
    const auto data = dataFromMap(bindings);
    const auto result = plugin->notifier.value().Update(data, tag);
    return (NativeUpdateResult) result;
  } catch (...) {
    return NativeUpdateResult::failed;
  }
}

void cancelAll(NativePlugin* plugin) {
  if (!plugin->isReady) return;
  try {
    if (plugin->hasIdentity) {
      plugin->history.value().Clear();
    } else {
      plugin->history.value().Clear(plugin->aumid);
    }
    for (const auto notification : plugin->notifier.value().GetScheduledToastNotifications()) {
      plugin->notifier.value().RemoveFromSchedule(notification);
    }
  } catch (...) {
  }
}

void cancelNotification(NativePlugin* plugin, int id) {
  if (!plugin->isReady) return;
  try {
    const auto tag = winrt::to_hstring(id);
    if (plugin->hasIdentity) plugin->history.value().Remove(tag);
    for (const auto notification : plugin->notifier.value().GetScheduledToastNotifications()) {
      if (notification.Tag() == tag) {
        plugin->notifier.value().RemoveFromSchedule(notification);
        return;
      }
    }
  } catch (...) {
  }
}

NativeNotificationDetails* getActiveNotifications(NativePlugin* plugin, int* size) {
  // TODO: Get more details here
  *size = 0;
  if (!plugin->isReady || !plugin->hasIdentity) return nullptr;
  NativeNotificationDetails* result = nullptr;
  try {
    const auto active = plugin->history.value().GetHistory();
    const int count = (int) active.Size();
    result = new NativeNotificationDetails[count];
    int index = 0;
    for (const auto notification : active) {
      if (index >= count) break;
      const auto tagStr = winrt::to_string(notification.Tag());
      result[index++].id = std::stoi(tagStr);  // tags not set by this plugin throw
    }
    *size = index;
    return result;
  } catch (...) {
    delete[] result;
    *size = 0;
    return nullptr;
  }
}

NativeNotificationDetails* getPendingNotifications(NativePlugin* plugin, int* size) {
  // TODO: Get more details here
  *size = 0;
  if (!plugin->isReady) return nullptr;
  NativeNotificationDetails* result = nullptr;
  try {
    const auto pending = plugin->notifier.value().GetScheduledToastNotifications();
    const int count = (int) pending.Size();
    result = new NativeNotificationDetails[count];
    int index = 0;
    for (const auto notification : pending) {
      if (index >= count) break;
      const auto tagStr = winrt::to_string(notification.Tag());
      result[index++].id = std::stoi(tagStr);  // tags not set by this plugin throw
    }
    *size = index;
    return result;
  } catch (...) {
    delete[] result;
    *size = 0;
    return nullptr;
  }
}

void freeDetailsArray(NativeNotificationDetails* ptr) { delete[] ptr; }

void freeLaunchDetails(NativeLaunchDetails details) {
  if (details.payload != nullptr) delete[] details.payload;
  for (int index = 0; index < details.data.size; index++) {
    const auto pair = details.data.entries[index];
    delete pair.key;
    delete pair.value;
  }
  if (details.data.entries != nullptr) delete[] details.data.entries;
}
