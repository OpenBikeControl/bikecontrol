import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Screenshot Tests', () {
    testWidgets('Generate phone screenshots', (WidgetTester tester) async {
      // Set phone screen size (typical Android phone - 1140x2616 to match existing)
      binding.window.physicalSizeTestValue = const Size(1140, 2616);
      binding.window.devicePixelRatioTestValue = 1.0;

      // Build a simple demo screen
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF121212),
            appBar: AppBar(
              title: const Text('SwiftControl'),
              backgroundColor: const Color(0xFF1E88E5),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bluetooth, size: 100, color: Color(0xFF1E88E5)),
                  const SizedBox(height: 20),
                  const Text(
                    'SwiftControl',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Control your virtual riding',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    ),
                    child: const Text('Connect Device', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Take screenshot
      await takeScreenshot(binding, 'mob1', tester);

      // Build second screen variant
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF121212),
            appBar: AppBar(
              title: const Text('Connected Devices'),
              backgroundColor: const Color(0xFF1E88E5),
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildDeviceCard('Zwift Click', 'Connected', true),
                _buildDeviceCard('Zwift Play', 'Paired', false),
                _buildDeviceCard('Elite Sterzo', 'Available', false),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await takeScreenshot(binding, 'mob2', tester);

      // Reset
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });

    testWidgets('Generate tablet screenshots', (WidgetTester tester) async {
      // Set tablet screen size (2248x2480 to match existing)
      binding.window.physicalSizeTestValue = const Size(2248, 2480);
      binding.window.devicePixelRatioTestValue = 1.0;

      // Build demo screen
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF121212),
            appBar: AppBar(
              title: const Text('SwiftControl'),
              backgroundColor: const Color(0xFF1E88E5),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bluetooth, size: 120, color: Color(0xFF1E88E5)),
                  const SizedBox(height: 20),
                  const Text(
                    'SwiftControl',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Control your virtual riding',
                    style: TextStyle(fontSize: 20, color: Colors.white70),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                    ),
                    child: const Text('Connect Device', style: TextStyle(fontSize: 22)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await takeScreenshot(binding, 'tab1', tester);

      // Build second screen
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF121212),
            appBar: AppBar(
              title: const Text('Connected Devices'),
              backgroundColor: const Color(0xFF1E88E5),
            ),
            body: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              children: [
                _buildDeviceCard('Zwift Click', 'Connected', true),
                _buildDeviceCard('Zwift Play', 'Paired', false),
                _buildDeviceCard('Elite Sterzo', 'Available', false),
                _buildDeviceCard('Shimano Di2', 'Available', false),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await takeScreenshot(binding, 'tab2', tester);

      // Reset
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });

    testWidgets('Generate macOS screenshots', (WidgetTester tester) async {
      // Set desktop screen size (1280x800)
      binding.window.physicalSizeTestValue = const Size(1280, 800);
      binding.window.devicePixelRatioTestValue = 1.0;

      // Build demo screen
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF121212),
            appBar: AppBar(
              title: const Text('SwiftControl'),
              backgroundColor: const Color(0xFF1E88E5),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bluetooth, size: 80, color: Color(0xFF1E88E5)),
                  const SizedBox(height: 20),
                  const Text(
                    'SwiftControl',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Control your virtual riding',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    child: const Text('Connect Device', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await takeScreenshot(binding, 'mac_screenshot_1', tester);

      // Build second screen
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF121212),
            appBar: AppBar(
              title: const Text('Connected Devices'),
              backgroundColor: const Color(0xFF1E88E5),
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildDeviceCard('Zwift Click', 'Connected', true),
                _buildDeviceCard('Zwift Play', 'Paired', false),
                _buildDeviceCard('Elite Sterzo', 'Available', false),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await takeScreenshot(binding, 'mac_screenshot_2', tester);

      // Reset
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });
  });
}

Widget _buildDeviceCard(String name, String status, bool isConnected) {
  return Card(
    color: const Color(0xFF1E1E1E),
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: ListTile(
      leading: Icon(
        isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
        color: isConnected ? Colors.green : Colors.grey,
        size: 32,
      ),
      title: Text(
        name,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      subtitle: Text(
        status,
        style: TextStyle(
          color: isConnected ? Colors.green : Colors.grey,
          fontSize: 14,
        ),
      ),
    ),
  );
}

Future<void> takeScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  String screenshotName,
  WidgetTester tester,
) async {
  await tester.pumpAndSettle();
  await binding.takeScreenshot(screenshotName);
}

