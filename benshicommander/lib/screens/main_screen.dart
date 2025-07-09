import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:provider/provider.dart';
import '../benshi/radio_controller.dart';
import 'connection_screen.dart';

// Import the placeholder views
import 'dashboard_view.dart';
import 'scanner_view.dart';
import 'programmer_view.dart';

class MainScreen extends StatefulWidget {
  // This screen now requires an active BluetoothDevice to be passed to it.
  final BluetoothDevice device;

  const MainScreen({Key? key, required this.device}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final RadioController _radioController;
  late final List<Widget> _toolPages;

  @override
  void initState() {
    super.initState();
    // Create ONE radio controller to share across all tool pages.
    // Pass the BluetoothDevice, not the connection.
    _radioController = RadioController(device: widget.device);
    _radioController.connect();
    _toolPages = <Widget>[
      DashboardView(radioController: _radioController),
      ScannerView(radioController: _radioController),
      ProgrammerView(radioController: _radioController),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // A simple disconnect method to show in the AppBar
  void _disconnect() {
    _radioController.dispose();
    // Navigate back to the connection screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const ConnectionScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  void dispose() {
    // Defensive: dispose RadioController here if not already
    _radioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A list of titles corresponding to the pages
    final List<String> titles = ['Dashboard', 'Scanner', 'Programmer'];

    // Wrap Scaffold with ChangeNotifierProvider for RadioController
    return ChangeNotifierProvider<RadioController>.value(
      value: _radioController,
      child: Scaffold(
        appBar: AppBar(
          title: Text(titles[_selectedIndex]), // Title changes based on selected tab
          actions: [
            // --- Speaker/Audio Monitor toggle button ---
            Consumer<RadioController>(
              builder: (context, radio, child) {
                return IconButton(
                  icon: Icon(
                    radio.isAudioMonitoring ? Icons.volume_up : Icons.volume_off,
                    color: radio.isAudioMonitoring ? Colors.blueAccent : null,                  ),
                  tooltip: radio.isAudioMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
                  onPressed: () {
                    radio.toggleAudioMonitor();
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled),
              tooltip: 'Disconnect',
              onPressed: _disconnect,
            ),
          ],
        ),
        body: Center(
          child: _toolPages.elementAt(_selectedIndex),
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.track_changes_outlined),
              activeIcon: Icon(Icons.track_changes),
              label: 'Scanner',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.edit_note_outlined),
              activeIcon: Icon(Icons.edit_note),
              label: 'Programmer',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}