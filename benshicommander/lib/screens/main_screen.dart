import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'connection_screen.dart';

// Import the placeholder views
import 'dashboard_view.dart';
import 'scanner_view.dart';
import 'programmer_view.dart';

class MainScreen extends StatefulWidget {
  // This screen requires an active Bluetooth connection to be passed to it.
  final BluetoothConnection connection;

  const MainScreen({Key? key, required this.connection}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _toolPages;

  @override
  void initState() {
    super.initState();
    // Initialize the list of pages (tools).
    // Each tool view gets a reference to the same, single bluetooth connection.
    _toolPages = <Widget>[
      DashboardView(connection: widget.connection),
      ScannerView(connection: widget.connection),
      ProgrammerView(connection: widget.connection),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // A simple disconnect method to show in the AppBar
  void _disconnect() {
    widget.connection.dispose();
    // Navigate back to the connection screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const ConnectionScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // A list of titles corresponding to the pages
    final List<String> titles = ['Dashboard', 'Scanner', 'Programmer'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]), // Title changes based on selected tab
        actions: [
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
    );
  }
}
