import 'package:flutter/material.dart';
import '../benshi/radio_controller.dart';

class DashboardView extends StatelessWidget {
  final RadioController radioController;
  const DashboardView({Key? key, required this.radioController}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard, size: 100, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Dashboard View',
            style: TextStyle(fontSize: 24, color: Colors.grey),
          ),
          Text('Live status and controls will be here.'),
        ],
      ),
    );
  }
}