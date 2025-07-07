import 'package:flutter/material.dart';
import '../benshi/radio_controller.dart';

class ScannerView extends StatelessWidget {
  final RadioController radioController;
  const ScannerView({Key? key, required this.radioController}) : super(key: key);

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