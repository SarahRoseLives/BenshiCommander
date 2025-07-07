import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../benshi/radio_controller.dart';
import '../services/chirp_exporter.dart';

class ProgrammerView extends StatefulWidget {
  final RadioController radioController;
  const ProgrammerView({Key? key, required this.radioController}) : super(key: key);

  @override
  _ProgrammerViewState createState() => _ProgrammerViewState();
}

class _ProgrammerViewState extends State<ProgrammerView> {
  late final ChirpExporter _chirpExporter;

  String _statusMessage = 'Press "Start Server" to begin the Chirp export process.';

  @override
  void initState() {
    super.initState();
    _chirpExporter = ChirpExporter(
      radioController: widget.radioController,
      onStatusUpdate: (message) {
        if (mounted) {
          setState(() {
            _statusMessage = message;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _chirpExporter.stop();
    // DO NOT dispose the radioController here! Parent manages it.
    super.dispose();
  }

  void _toggleServer() {
    if (_chirpExporter.isRunning) {
      _chirpExporter.stop();
    } else {
      _chirpExporter.start();
    }
    setState(() {}); // Update button text and UI
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.import_export, size: 100, color: Colors.blueAccent),
            const SizedBox(height: 24),
            const Text(
              'Chirp CSV Export',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      _chirpExporter.isRunning
                          ? 'Server is running. Open this address in a web browser on the same network:'
                          : 'Server is stopped.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_chirpExporter.isRunning && _chirpExporter.serverUrl != null)
                      SelectableText(
                        _chirpExporter.serverUrl!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _toggleServer,
              style: ElevatedButton.styleFrom(
                backgroundColor: _chirpExporter.isRunning ? Colors.redAccent : Colors.green,
              ),
              child: Text(_chirpExporter.isRunning ? 'Stop Server' : 'Start Server'),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            Text(
              'Status:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}