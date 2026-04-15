enum RetrofitMode {
  proxy,
  wifi,
  bluetooth;

  String get label => switch (this) {
    RetrofitMode.proxy => 'Proxy',
    RetrofitMode.wifi => 'Retrofit (WiFi)',
    RetrofitMode.bluetooth => 'Retrofit (Bluetooth)',
  };
}
