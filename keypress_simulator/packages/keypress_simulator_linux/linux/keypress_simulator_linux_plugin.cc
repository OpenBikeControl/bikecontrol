#include "include/keypress_simulator_linux/keypress_simulator_linux_plugin.h"

#include <fcntl.h>
#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <linux/uinput.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <algorithm>
#include <cerrno>
#include <cmath>
#include <cstring>

// Input is injected through virtual devices on /dev/uinput, which works on both
// X11 and Wayland (the compositor sees them as real hardware). The user needs
// write access to /dev/uinput, e.g. via a udev rule granting it to the seat
// user (TAG+="uaccess") or the "input" group.

const char kChannelName[] = "dev.leanflutter.plugins/keypress_simulator";
const char kUinputPath[] = "/dev/uinput";

// Range of the absolute pointer axes; the compositor maps it onto the bounding
// box of all monitors.
const int kAbsMax = 32767;

struct _FlKeypressSimulatorLinuxPlugin {
  GObject parent_instance;

  FlMethodChannel* channel;

  int keyboard_fd;
  int pointer_fd;
};

G_DEFINE_TYPE(FlKeypressSimulatorLinuxPlugin, fl_keypress_simulator_linux_plugin, g_object_get_type())

// USB HID keyboard usage (page 0x07) -> evdev key code, from the kernel's
// drivers/hid/hid-input.c.
static const unsigned char kHidKeyboard[256] = {
    0,   0,   0,   0,   30,  48,  46,  32,  18,  33,  34,  35,  23,  36,  37,  38,  //
    50,  49,  24,  25,  16,  19,  31,  20,  22,  47,  17,  45,  21,  44,  2,   3,   //
    4,   5,   6,   7,   8,   9,   10,  11,  28,  1,   14,  15,  57,  12,  13,  26,  //
    27,  43,  43,  39,  40,  41,  51,  52,  53,  58,  59,  60,  61,  62,  63,  64,  //
    65,  66,  67,  68,  87,  88,  99,  70,  119, 110, 102, 104, 111, 107, 109, 106,  //
    105, 108, 103, 69,  98,  55,  74,  78,  96,  79,  80,  81,  75,  76,  77,  71,  //
    72,  73,  82,  83,  86,  127, 116, 117, 183, 184, 185, 186, 187, 188, 189, 190,  //
    191, 192, 193, 194, 134, 138, 130, 132, 128, 129, 131, 137, 133, 135, 136, 113,  //
    115, 114, 0,   0,   0,   121, 0,   89,  93,  124, 92,  94,  95,  0,   0,   0,    //
    122, 123, 90,  91,  85,  0,   0,   0,   0,   0,   0,   0,   111, 0,   0,   0,    //
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,    //
    0,   0,   0,   0,   0,   0,   179, 180, 0,   0,   0,   0,   0,   0,   0,   0,    //
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,    //
    0,   0,   0,   0,   0,   0,   0,   0,   111, 0,   0,   0,   0,   0,   0,   0,    //
    29,  42,  56,  125, 97,  54,  100, 126, 164, 166, 165, 163, 161, 115, 114, 113,  //
    150, 158, 159, 128, 136, 177, 178, 176, 142, 152, 173, 140, 0,   0,   0,   0,    //
};

// Flutter's PhysicalKeyboardKey.usbHidUsage -> evdev key code (0 if unknown).
static int evdev_code_for_hid_usage(int64_t usage) {
  const int64_t page = usage >> 16;
  const int64_t id = usage & 0xffff;
  if (page == 0x07 && id < 256) return kHidKeyboard[id];
  if (page == 0x0c) {
    switch (id) {
      case 0xb5: return KEY_NEXTSONG;
      case 0xb6: return KEY_PREVIOUSSONG;
      case 0xb7: return KEY_STOPCD;
      case 0xcd: return KEY_PLAYPAUSE;
      case 0xe2: return KEY_MUTE;
      case 0xe9: return KEY_VOLUMEUP;
      case 0xea: return KEY_VOLUMEDOWN;
    }
  }
  return 0;
}

static int modifier_code(const gchar* name) {
  if (strcmp(name, "shiftModifier") == 0) return KEY_LEFTSHIFT;
  if (strcmp(name, "controlModifier") == 0) return KEY_LEFTCTRL;
  if (strcmp(name, "altModifier") == 0) return KEY_LEFTALT;
  if (strcmp(name, "metaModifier") == 0) return KEY_LEFTMETA;
  return 0;
}

static void emit(int fd, int type, int code, int value) {
  struct input_event ev;
  memset(&ev, 0, sizeof(ev));
  ev.type = type;
  ev.code = code;
  ev.value = value;
  if (write(fd, &ev, sizeof(ev)) < 0) g_warning("keypress_simulator: uinput write failed: %s", strerror(errno));
}

static void emit_sync(int fd) { emit(fd, EV_SYN, SYN_REPORT, 0); }

static int create_device(const char* name, void (*configure)(int fd)) {
  int fd = open(kUinputPath, O_WRONLY | O_NONBLOCK);
  if (fd < 0) {
    g_warning("keypress_simulator: cannot open %s: %s", kUinputPath, strerror(errno));
    return -1;
  }
  configure(fd);

  struct uinput_setup setup;
  memset(&setup, 0, sizeof(setup));
  setup.id.bustype = BUS_VIRTUAL;
  setup.id.vendor = 0x1209;
  setup.id.product = 0xbc01;
  strncpy(setup.name, name, UINPUT_MAX_NAME_SIZE - 1);
  if (ioctl(fd, UI_DEV_SETUP, &setup) < 0 || ioctl(fd, UI_DEV_CREATE) < 0) {
    g_warning("keypress_simulator: cannot create uinput device: %s", strerror(errno));
    close(fd);
    return -1;
  }
  return fd;
}

static void configure_keyboard(int fd) {
  ioctl(fd, UI_SET_EVBIT, EV_KEY);
  // Keyboard and media keys only: BTN_* codes would make it look like a
  // joystick to games and to the app's own gamepad detection.
  for (int code = KEY_ESC; code < BTN_MISC; code++) ioctl(fd, UI_SET_KEYBIT, code);
}

static void configure_pointer(int fd) {
  ioctl(fd, UI_SET_EVBIT, EV_KEY);
  ioctl(fd, UI_SET_KEYBIT, BTN_LEFT);
  ioctl(fd, UI_SET_KEYBIT, BTN_RIGHT);
  ioctl(fd, UI_SET_KEYBIT, BTN_MIDDLE);
  ioctl(fd, UI_SET_EVBIT, EV_ABS);
  for (int axis : {ABS_X, ABS_Y}) {
    struct uinput_abs_setup abs;
    memset(&abs, 0, sizeof(abs));
    abs.code = axis;
    abs.absinfo.minimum = 0;
    abs.absinfo.maximum = kAbsMax;
    ioctl(fd, UI_ABS_SETUP, &abs);
  }
}

// Devices are created up front: the compositor needs a moment to pick up a new
// device, and events sent before that are dropped.
static void ensure_devices(FlKeypressSimulatorLinuxPlugin* self) {
  if (self->keyboard_fd < 0) self->keyboard_fd = create_device("BikeControl Virtual Keyboard", configure_keyboard);
  if (self->pointer_fd < 0) self->pointer_fd = create_device("BikeControl Virtual Pointer", configure_pointer);
}

static gboolean is_access_allowed() { return access(kUinputPath, W_OK) == 0; }

static FlMethodResponse* simulate_key_press(FlKeypressSimulatorLinuxPlugin* self, FlValue* args) {
  ensure_devices(self);
  if (self->keyboard_fd < 0) {
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("NO_ACCESS", "Cannot write to /dev/uinput", nullptr));
  }

  FlValue* usage_value = fl_value_lookup_string(args, "usbHidUsage");
  FlValue* down_value = fl_value_lookup_string(args, "keyDown");
  FlValue* modifiers_value = fl_value_lookup_string(args, "modifiers");
  const bool key_down = down_value == nullptr || fl_value_get_bool(down_value);

  int key = 0;
  if (usage_value != nullptr && fl_value_get_type(usage_value) == FL_VALUE_TYPE_INT) {
    key = evdev_code_for_hid_usage(fl_value_get_int(usage_value));
    if (key == 0) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new("UNSUPPORTED_KEY", "Unsupported key", nullptr));
    }
  }

  const int fd = self->keyboard_fd;
  const size_t modifier_count =
      modifiers_value != nullptr && fl_value_get_type(modifiers_value) == FL_VALUE_TYPE_LIST
          ? fl_value_get_length(modifiers_value)
          : 0;
  auto set_modifiers = [&](int value) {
    for (size_t i = 0; i < modifier_count; i++) {
      FlValue* modifier = fl_value_get_list_value(modifiers_value, i);
      if (fl_value_get_type(modifier) != FL_VALUE_TYPE_STRING) continue;
      const int code = modifier_code(fl_value_get_string(modifier));
      if (code != 0) emit(fd, EV_KEY, code, value);
    }
    emit_sync(fd);
  };

  if (key_down) {
    set_modifiers(1);
    if (key != 0) {
      emit(fd, EV_KEY, key, 1);
      emit_sync(fd);
    }
  } else {
    if (key != 0) {
      emit(fd, EV_KEY, key, 0);
      emit_sync(fd);
    }
    set_modifiers(0);
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

// Bounding box of all monitors and the origin of the primary one, in the same
// logical coordinates the compositor maps absolute devices onto.
static void get_screen_layout(GdkRectangle* bounds, GdkRectangle* primary) {
  GdkDisplay* display = gdk_display_get_default();
  const int count = display != nullptr ? gdk_display_get_n_monitors(display) : 0;
  *bounds = {0, 0, 0, 0};
  *primary = {0, 0, 0, 0};
  if (count == 0) return;

  GdkMonitor* primary_monitor = gdk_display_get_primary_monitor(display);
  if (primary_monitor == nullptr) primary_monitor = gdk_display_get_monitor(display, 0);
  gdk_monitor_get_geometry(primary_monitor, primary);

  int left = G_MAXINT, top = G_MAXINT, right = G_MININT, bottom = G_MININT;
  for (int i = 0; i < count; i++) {
    GdkRectangle geometry;
    gdk_monitor_get_geometry(gdk_display_get_monitor(display, i), &geometry);
    left = std::min(left, geometry.x);
    top = std::min(top, geometry.y);
    right = std::max(right, geometry.x + geometry.width);
    bottom = std::max(bottom, geometry.y + geometry.height);
  }
  *bounds = {left, top, right - left, bottom - top};
}

static FlMethodResponse* simulate_mouse_click(FlKeypressSimulatorLinuxPlugin* self, FlValue* args) {
  ensure_devices(self);
  if (self->pointer_fd < 0) {
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("NO_ACCESS", "Cannot write to /dev/uinput", nullptr));
  }

  const double x = fl_value_get_float(fl_value_lookup_string(args, "x"));
  const double y = fl_value_get_float(fl_value_lookup_string(args, "y"));
  FlValue* down_value = fl_value_lookup_string(args, "keyDown");
  const bool key_down = down_value == nullptr || fl_value_get_bool(down_value);

  GdkRectangle bounds, primary;
  get_screen_layout(&bounds, &primary);
  if (bounds.width <= 0 || bounds.height <= 0) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("NO_DISPLAY", "No monitor found", nullptr));
  }

  // x/y are relative to the primary monitor.
  auto scale = [](double value, int origin, int size) {
    return std::clamp(static_cast<int>(std::lround((value - origin) * kAbsMax / size)), 0, kAbsMax);
  };
  const int abs_x = scale(primary.x + x, bounds.x, bounds.width);
  const int abs_y = scale(primary.y + y, bounds.y, bounds.height);

  const int fd = self->pointer_fd;
  emit(fd, EV_ABS, ABS_X, abs_x);
  emit(fd, EV_ABS, ABS_Y, abs_y);
  emit_sync(fd);
  emit(fd, EV_KEY, BTN_LEFT, key_down ? 1 : 0);
  emit_sync(fd);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

static FlMethodResponse* simulate_media_key(FlKeypressSimulatorLinuxPlugin* self, FlValue* args) {
  ensure_devices(self);
  if (self->keyboard_fd < 0) {
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("NO_ACCESS", "Cannot write to /dev/uinput", nullptr));
  }

  FlValue* key_value = fl_value_lookup_string(args, "key");
  const gchar* key = key_value != nullptr ? fl_value_get_string(key_value) : "";
  int code = 0;
  if (strcmp(key, "playPause") == 0) code = KEY_PLAYPAUSE;
  else if (strcmp(key, "stop") == 0) code = KEY_STOPCD;
  else if (strcmp(key, "next") == 0) code = KEY_NEXTSONG;
  else if (strcmp(key, "previous") == 0) code = KEY_PREVIOUSSONG;
  else if (strcmp(key, "volumeUp") == 0) code = KEY_VOLUMEUP;
  else if (strcmp(key, "volumeDown") == 0) code = KEY_VOLUMEDOWN;
  if (code == 0) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("UNSUPPORTED_KEY", "Unsupported media key", nullptr));
  }

  const int fd = self->keyboard_fd;
  emit(fd, EV_KEY, code, 1);
  emit_sync(fd);
  emit(fd, EV_KEY, code, 0);
  emit_sync(fd);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

// Called when a method call is received from Flutter.
static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
  FlKeypressSimulatorLinuxPlugin* self = FL_KEYPRESS_SIMULATOR_LINUX_PLUGIN(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  g_autoptr(FlMethodResponse) response = nullptr;
  if (strcmp(method, "isAccessAllowed") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(is_access_allowed())));
  } else if (strcmp(method, "requestAccess") == 0) {
    // Access to /dev/uinput can only be granted outside the app (udev rule).
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "simulateKeyPress") == 0) {
    response = simulate_key_press(self, args);
  } else if (strcmp(method, "simulateMouseClick") == 0) {
    response = simulate_mouse_click(self, args);
  } else if (strcmp(method, "simulateMediaKey") == 0) {
    response = simulate_media_key(self, args);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error))
    g_warning("Failed to send method call response: %s", error->message);
}

static void fl_keypress_simulator_linux_plugin_dispose(GObject* object) {
  FlKeypressSimulatorLinuxPlugin* self = FL_KEYPRESS_SIMULATOR_LINUX_PLUGIN(object);
  for (int* fd : {&self->keyboard_fd, &self->pointer_fd}) {
    if (*fd >= 0) {
      ioctl(*fd, UI_DEV_DESTROY);
      close(*fd);
      *fd = -1;
    }
  }
  g_clear_object(&self->channel);
  G_OBJECT_CLASS(fl_keypress_simulator_linux_plugin_parent_class)->dispose(object);
}

static void fl_keypress_simulator_linux_plugin_class_init(FlKeypressSimulatorLinuxPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = fl_keypress_simulator_linux_plugin_dispose;
}

static void fl_keypress_simulator_linux_plugin_init(FlKeypressSimulatorLinuxPlugin* self) {
  self->keyboard_fd = -1;
  self->pointer_fd = -1;
}

FlKeypressSimulatorLinuxPlugin* fl_keypress_simulator_linux_plugin_new(FlPluginRegistrar* registrar) {
  FlKeypressSimulatorLinuxPlugin* self =
      FL_KEYPRESS_SIMULATOR_LINUX_PLUGIN(g_object_new(fl_keypress_simulator_linux_plugin_get_type(), nullptr));

  if (is_access_allowed()) ensure_devices(self);

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar), kChannelName, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->channel, method_call_cb, g_object_ref(self), g_object_unref);

  return self;
}

void keypress_simulator_linux_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FlKeypressSimulatorLinuxPlugin* plugin = fl_keypress_simulator_linux_plugin_new(registrar);
  g_object_unref(plugin);
}
