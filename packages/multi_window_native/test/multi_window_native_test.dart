// import 'package:flutter_test/flutter_test.dart';
// import 'package:multi_window_native/multi_window_native.dart';
// import 'package:multi_window_native/multi_window_native_platform_interface.dart';
// import 'package:multi_window_native/multi_window_native_method_channel.dart';
// import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// class MockMultiWindowNativePlatform
//     with MockPlatformInterfaceMixin
//     implements MultiWindowNativePlatform {

//   @override
//   Future<int> getMessengerCount() => Future.value(3);

//   @override
//   Future<void> createAndRegisterWindow({required String routeName, required String theme, String? argsJson, void Function()? onCreation}) {
//     return Future.value();
//   }

//   @override
//   Future<void> notifyWindowClose() {
//     return Future.value();
//   }

  
// }

// void main() {
//   final MultiWindowNativePlatform initialPlatform = MultiWindowNativePlatform.instance;

//   test('$MethodChannelMultiWindowNative is the default instance', () {
//     expect(initialPlatform, isInstanceOf<MethodChannelMultiWindowNative>());
//   });

//   test('windowCount returns mocked count', () async {
//     MultiWindowNative multiWindowNativePlugin = MultiWindowNative();
//     MockMultiWindowNativePlatform fakePlatform = MockMultiWindowNativePlatform();
//     MultiWindowNativePlatform.instance = fakePlatform;

//     final count = await multiWindowNativePlugin.windowCount();
//     expect(count, 3);
//   });

//   test('createWindow completes without error', () async {
//     MultiWindowNative multiWindowNativePlugin = MultiWindowNative();
//     MockMultiWindowNativePlatform fakePlatform = MockMultiWindowNativePlatform();
//     MultiWindowNativePlatform.instance = fakePlatform;

//     // Should complete without throwing an error
//     expect(
//       () async => await multiWindowNativePlugin.createWindow([
//         'testRoute',
//         '{"test": "data"}',
//         'light'
//       ]),
//       returnsNormally,
//     );
//   });

//   test('closeWindow completes without error', () async {
//     MultiWindowNative multiWindowNativePlugin = MultiWindowNative();
//     MockMultiWindowNativePlatform fakePlatform = MockMultiWindowNativePlatform();
//     MultiWindowNativePlatform.instance = fakePlatform;

//     // Should complete without throwing an error
//     expect(
//       () async => await multiWindowNativePlugin.closeWindow(),
//       returnsNormally,
//     );
//   });


// }
