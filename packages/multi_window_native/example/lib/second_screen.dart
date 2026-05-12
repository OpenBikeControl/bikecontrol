import 'package:flutter/material.dart';
import 'package:multi_window_native/multi_window_native.dart';
import 'package:window_manager/window_manager.dart';

class SecondScreen extends StatefulWidget {
  const SecondScreen({super.key});

  @override
  State<SecondScreen> createState() => _SecondScreenState();
}

class _SecondScreenState extends State<SecondScreen> with WindowListener{

  String _text = "";
  String? _listenerId;
  late String _themeListenerId;
  ThemeMode _themeMode = ThemeMode.light;
  
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
     // Register listener and store the returned ID
    _listenerId =  MultiWindowNative.registerListener("updateText", (call) async {
      setState(() {
        _text = call.arguments as String;
      });
    },);
    _themeListenerId =
        MultiWindowNative.registerListener("updateTheme", (call) async {
             debugPrint("inside second theme");
      setState(() {
        _themeMode =
            (call.arguments == "dark") ? ThemeMode.dark : ThemeMode.light;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;
      await  MultiWindowNative.notifyUiRendered();
    });
  }

  @override
  void dispose() {
    if (_listenerId != null) {
      MultiWindowNative.unregisterListener(methodName:  "updateText",id:  _listenerId!);
    }
    MultiWindowNative.unregisterListener(
        methodName: "updateTheme", id: _themeListenerId);
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    debugPrint("Window to be dleted ${await windowManager.getId()}");
    await MultiWindowNative.closeWindow(isMainWindow: false, windowId: (await windowManager.getId()).toString());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Multi Window Demo',
      themeMode: _themeMode,
      darkTheme: ThemeData.dark(),
      theme: ThemeData.light(),
      home: Scaffold(
        appBar: AppBar(title: const Text('Secondary Window')),
        body: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _themeMode == ThemeMode.dark ? Colors.grey[900] : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _text.isEmpty ? "No updates yet" : "{$_text}",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => debugPrint("Button clicked in secondary window"),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Refresh"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}