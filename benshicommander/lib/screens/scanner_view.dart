import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class ScannerView extends StatelessWidget {
  final BluetoothConnection connection;
  const ScannerView({Key? key, required this.connection}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.track_changes, size: 100, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Scanner View',
            style: TextStyle(fontSize: 24, color: Colors.grey),
          ),
          Text('Scanning controls and activity log will be here.'),
        ],
      ),
    );
  }
}