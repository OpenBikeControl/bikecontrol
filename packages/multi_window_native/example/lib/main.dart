import 'package:flutter/material.dart';
import 'package:multi_window_native/multi_window_native.dart';
import 'package:multi_window_native_example/main_screen.dart';
import 'package:multi_window_native_example/second_screen.dart';
import 'package:window_manager/window_manager.dart';

@pragma('vm:entry-point')
Future<void> main(final List<String> args)  async{
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow();
  int windowId = await windowManager.getId();
  MultiWindowNative.init(windowId);
  runApp(MyApp(args: args,));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key,this.args=const []});

  final List<String> args;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  Widget build(BuildContext context) {
    if(widget.args.isNotEmpty && widget.args.contains('secondScreen')){
    return const SecondScreen();
     } 
    return const MainScreen(); 
  }
}
