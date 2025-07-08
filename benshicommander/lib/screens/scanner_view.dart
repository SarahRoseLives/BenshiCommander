import 'package:flutter/material.dart';
import 'dart:async';
import '../benshi/radio_controller.dart';
import '../benshi/protocol/protocol.dart';

class ScannerView extends StatefulWidget {
  final RadioController radioController;
  const ScannerView({Key? key, required this.radioController}) : super(key: key);

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  // UI state for scanning logic
  bool _isScanning = false;
  double _scanDisplayFreq = 0.0;
  bool scanHold = false;

  // Settings for the scanner
  final TextEditingController scanStartController = TextEditingController(text: "144.000");
  final TextEditingController scanEndController = TextEditingController(text: "148.000");
  int scanStepkHz = 5;

  @override
  void initState() {
    super.initState();
    // Set initial display frequency from the controller
    _updateDisplayFreq(widget.radioController.currentRxFreq);
    // Listen for updates from the radio controller
    widget.radioController.addListener(_onRadioUpdate);
  }

  @override
  void dispose() {
    // Stop scanning if the view is destroyed
    _isScanning = false;
    widget.radioController.removeListener(_onRadioUpdate);
    scanStartController.dispose();
    scanEndController.dispose();
    super.dispose();
  }

  void _onRadioUpdate() {
    // When the radio controller gets an event (e.g., squelch changed),
    // this will trigger a rebuild if the widget is still mounted.
    if (mounted) {
      // If not scanning, update the display frequency to the radio's current channel
      if (!_isScanning) {
        setState(() {
           _scanDisplayFreq = widget.radioController.currentRxFreq;
        });
      }
    }
  }

  void _updateDisplayFreq(double freq) {
    if (mounted) {
      setState(() {
        _scanDisplayFreq = freq;
      });
    }
  }

  Future<void> _toggleScan() async {
    if (_isScanning) {
      setState(() {
        _isScanning = false;
      });
      return;
    }

    setState(() {
      _isScanning = true;
    });

    // Parse scan parameters from text fields
    double startFreq = double.tryParse(scanStartController.text) ?? 144.0;
    double endFreq = double.tryParse(scanEndController.text) ?? 148.0;
    double stepFreq = scanStepkHz / 1000.0;
    double currentScanFreq = startFreq;

    // The main scanning loop
    while (_isScanning) {
      if (!mounted) return;

      _updateDisplayFreq(currentScanFreq);
      await widget.radioController.setVfoFrequency(currentScanFreq);

      // Short delay to allow radio to tune and update status
      await Future.delayed(const Duration(milliseconds: 100));

      // Check for signal and hold if necessary
      if (widget.radioController.isSq && !scanHold) {
        // Signal detected, hold here for a couple of seconds or until signal drops
        await Future.delayed(const Duration(seconds: 2));
        continue; // Re-check the same frequency
      }

      // If holding, just loop without incrementing frequency
      if(scanHold) {
        await Future.delayed(const Duration(milliseconds: 200));
        continue;
      }

      // No signal or not holding, move to the next frequency
      currentScanFreq += stepFreq;
      if (currentScanFreq > endFreq) {
        currentScanFreq = startFreq; // Loop back to the beginning
      }
    }
     // After scan stops, set the display back to the actual current channel frequency
    _updateDisplayFreq(widget.radioController.currentRxFreq);
  }


  @override
  Widget build(BuildContext context) {
    final radio = widget.radioController;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
             // --- Top Display ---
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('FREQUENCY', style: Theme.of(context).textTheme.labelLarge),
                    Text(
                      '${_scanDisplayFreq.toStringAsFixed(4)} MHz',
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildLedIndicator(radio.isInRx && radio.isSq, 'RX', Colors.green),
                        _buildLedIndicator(_isScanning, 'SCAN', Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Signal Strength'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: LinearProgressIndicator(
                        value: radio.rssi / 100.0,
                        minHeight: 12,
                        color: Colors.green,
                        backgroundColor: Colors.grey[300],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // --- Scan Controls ---
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
                          label: Text(_isScanning ? 'Stop Scan' : 'Start Scan'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _isScanning ? Colors.red : Colors.green),
                          onPressed: _toggleScan,
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: Icon(scanHold ? Icons.play_arrow : Icons.pause),
                          label: Text(scanHold ? 'Resume' : 'Hold'),
                          onPressed: _isScanning
                              ? () {
                                  setState(() => scanHold = !scanHold);
                                }
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: scanStartController,
                            decoration: const InputDecoration(labelText: 'Start (MHz)', border: OutlineInputBorder()),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: scanEndController,
                            decoration: const InputDecoration(labelText: 'End (MHz)', border: OutlineInputBorder()),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                     const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Step:'),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: scanStepkHz,
                          items: const [
                            DropdownMenuItem(value: 5, child: Text('5 kHz')),
                            DropdownMenuItem(value: 10, child: Text('10 kHz')),
                            DropdownMenuItem(value: 12, child: Text('12.5 kHz')),
                            DropdownMenuItem(value: 25, child: Text('25 kHz')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => scanStepkHz = v);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedIndicator(bool active, String label, Color color) {
    return Column(
      children: [
        Icon(Icons.circle,
            color: active ? color : Colors.grey[400], size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}