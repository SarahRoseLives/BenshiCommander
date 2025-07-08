import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'about_screen.dart';
import 'main_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({Key? key}) : super(key: key);

  @override
  _ConnectionScreenState createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  // Bluetooth state
  List<BluetoothDevice> _devicesList = [];
  BluetoothDevice? _selectedDevice;
  bool isConnecting = false;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndLoadDevices();
  }

  Future<void> _requestPermissionsAndLoadDevices() async {
    // Request all necessary permissions at once
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    // If permissions are granted, get the list of paired devices
    if (statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted) {
      _getPairedDevices();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Permissions not granted. Cannot scan for devices.')),
        );
      }
    }
  }

  void _getPairedDevices() async {
    try {
      List<BluetoothDevice> devices =
          await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() {
        _devicesList = devices;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting paired devices: $e')),
        );
      }
    }
  }

  void _connect() async {
    if (_selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a device to connect.')),
      );
      return;
    }

    setState(() {
      isConnecting = true;
    });

    try {
      BluetoothConnection connection =
          await BluetoothConnection.toAddress(_selectedDevice!.address);

      // If connection is successful, navigate to the MainScreen
      // and replace the current screen so the user can't go "back" to it.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainScreen(connection: connection),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
      setState(() {
        isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Radio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: () {
              // Navigate to the AboutScreen, allowing the user to return
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AboutScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.radio, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text(
              'Select a Paired Radio',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<BluetoothDevice>(
              items: _devicesList
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(d.name ?? d.address),
                      ))
                  .toList(),
              onChanged: (device) => setState(() => _selectedDevice = device),
              value: _selectedDevice,
              decoration: InputDecoration(
                labelText: 'Paired Devices',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              isExpanded: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_selectedDevice == null || isConnecting) ? null : _connect,
              child: isConnecting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3.0),
                    )
                  : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}