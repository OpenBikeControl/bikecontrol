import 'package:flutter/material.dart';
import 'package:multi_window_native/multi_window_native.dart';
import 'package:window_manager/window_manager.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WindowListener {

  final TextEditingController _controller = TextEditingController();
  String? _listenerId;
  ThemeMode _themeMode = ThemeMode.light;

  Future<void> createNewWindow() async {
    await MultiWindowNative.createWindow([
      'secondScreen', 
      '{}',    
      _themeMode.name, 
    ]);
  }
  
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    MultiWindowNative.registerListener("updateTheme", (call) async {
      debugPrint("inside main theme");
      setState(() {
        _themeMode =
            (call.arguments == "dark") ? ThemeMode.dark : ThemeMode.light;
      });
    });

    _listenerId =  MultiWindowNative.registerListener("updateText", (call)async{
      setState(() {
        _controller.text = call.arguments as String;
      });
  }
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;
      await  MultiWindowNative.notifyUiRendered();
    });
  }


  @override
  void dispose() {
    MultiWindowNative.unregisterListener(methodName:  "updateText", id: _listenerId!);
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    debugPrint("Window to be dleted");
    await MultiWindowNative.closeWindow(isMainWindow: true, windowId: (await windowManager.getId()).toString());
  }

  Future<void> _toggleTheme() async {
    final newTheme = _themeMode == ThemeMode.light ? "dark" : "light";
    await MultiWindowNative.notifyAllWindows("updateTheme", newTheme);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      darkTheme: ThemeData.dark(),
      theme: ThemeData.light(),
      home: Scaffold(
        appBar: AppBar(title: const Text('Multi Window Native Plugin Example')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _themeMode == ThemeMode.dark ? Colors.grey[900] : Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        SizedBox(
                          width: 300,
                          child: TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              labelText: 'Enter text',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final text = _controller.text;
                            await MultiWindowNative.notifyAllWindows("updateText", text);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Pass data to new windows'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: createNewWindow,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open New Window'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _toggleTheme,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text("Switch to ${_themeMode.name == 'light' ? "Dark" : "Light"} Theme"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}