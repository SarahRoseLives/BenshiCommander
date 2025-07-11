import 'package:flutter/material.dart';
import 'dart:async';
import '../benshi/radio_controller.dart';
import '../benshi/protocol/protocol.dart';

// New enum to manage which scan mode is active
enum ScanMode { memory, vfo }

class ScannerView extends StatefulWidget {
  final RadioController radioController;
  const ScannerView({Key? key, required this.radioController}) : super(key: key);

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  // State for the channel list
  List<Channel>? _channels;
  bool _isLoading = true;
  String _statusMessage = '';

  // State for VFO scanning
  ScanMode _scanMode = ScanMode.memory;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _startFreqController = TextEditingController(text: '144.0');
  final TextEditingController _endFreqController = TextEditingController(text: '148.0');
  final TextEditingController _stepController = TextEditingController(text: '25'); // Step in kHz

  @override
  void initState() {
    super.initState();
    // Listen for updates from the radio (like status changes)
    widget.radioController.addListener(_onRadioUpdate);
    // Load all channels for the scan list display
    _loadAllChannels();
  }

  @override
  void dispose() {
    widget.radioController.removeListener(_onRadioUpdate);
    _startFreqController.dispose();
    _endFreqController.dispose();
    _stepController.dispose();
    // Ensure scanning is stopped when leaving the view
    if (widget.radioController.isVfoScanning) {
      widget.radioController.stopVfoScan();
    }
    super.dispose();
  }

  void _onRadioUpdate() {
    // A status change from the radio (e.g. `isScan` toggled, current channel changed)
    // will trigger a rebuild to update the UI.
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAllChannels() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _statusMessage = 'Reading all channels from radio...';
    });
    try {
      final channels = await widget.radioController.getAllChannels();
      if (mounted) {
        setState(() {
          _channels = channels;
          _isLoading = false;
          _statusMessage = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error loading channels: $e';
        });
      }
    }
  }

  Future<void> _toggleMasterScan() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      // Toggle the radio's scan state based on its current state
      await widget.radioController.setRadioScan(!widget.radioController.isScan);
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startVfoScan() {
    if (_formKey.currentState!.validate()) {
      final double startFreq = double.parse(_startFreqController.text);
      final double endFreq = double.parse(_endFreqController.text);
      final int stepKHz = int.parse(_stepController.text);

      if (endFreq <= startFreq) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("End frequency must be greater than start.")));
        return;
      }

      widget.radioController.startVfoScan(
        startFreqMhz: startFreq,
        endFreqMhz: endFreq,
        stepKhz: stepKHz,
      );
    }
  }

  Future<void> _toggleChannelInScanList(Channel channel, bool includeInScan) async {
    try {
      final updatedChannel = channel.copyWith(scan: includeInScan);
      await widget.radioController.writeChannel(updatedChannel);
      // Update local state to immediately reflect the change
      setState(() {
        final index = _channels?.indexWhere((c) => c.channelId == channel.channelId);
        if (index != null && index != -1) {
          _channels![index] = updatedChannel;
        }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating channel ${channel.channelId}: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final radio = widget.radioController;
    final bool isMemoryScanning = radio.isScan;
    final bool isVfoScanning = radio.isVfoScanning;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SegmentedButton<ScanMode>(
            segments: const [
              ButtonSegment(value: ScanMode.memory, label: Text('Memory Scan'), icon: Icon(Icons.list)),
              ButtonSegment(value: ScanMode.vfo, label: Text('VFO Scan'), icon: Icon(Icons.tune)),
            ],
            selected: {_scanMode},
            onSelectionChanged: (Set<ScanMode> newSelection) {
              setState(() {
                _scanMode = newSelection.first;
              });
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _scanMode == ScanMode.memory
              ? _buildMemoryScanner(isMemoryScanning)
              : _buildVfoScanner(isVfoScanning),
        ),
      ],
    );
  }

  Widget _buildMemoryScanner(bool isScanning) {
    return Column(
      children: [
        _buildControlPanel(isScanning),
        const Divider(height: 1),
        Expanded(
          child: _isLoading && _channels == null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(_statusMessage)]))
              : _buildChannelList(),
        ),
      ],
    );
  }

  Widget _buildControlPanel(bool isScanning) {
    final radio = widget.radioController;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton.icon(
            icon: Icon(isScanning ? Icons.stop_circle_outlined : Icons.play_circle_outline),
            label: Text(isScanning ? 'Stop Memory Scan' : 'Start Memory Scan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isScanning ? Colors.redAccent : Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(fontSize: 16),
            ),
            onPressed: _toggleMasterScan,
          ),
          const SizedBox(height: 16),
          _buildStatusIndicators(),
        ],
      ),
    );
  }

  Widget _buildVfoScanner(bool isScanning) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: Icon(isScanning ? Icons.stop_circle_outlined : Icons.play_circle_outline),
              label: Text(isScanning ? 'Stop VFO Scan' : 'Start VFO Scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isScanning ? Colors.redAccent : Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
              onPressed: isScanning ? () => widget.radioController.stopVfoScan() : _startVfoScan,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _startFreqController,
              decoration: const InputDecoration(labelText: 'Start Frequency (MHz)', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (double.tryParse(v ?? '') == null) ? 'Invalid frequency' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _endFreqController,
              decoration: const InputDecoration(labelText: 'End Frequency (MHz)', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (double.tryParse(v ?? '') == null) ? 'Invalid frequency' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stepController,
              decoration: const InputDecoration(labelText: 'Step (kHz)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (v) => (int.tryParse(v ?? '') == null) ? 'Invalid step' : null,
            ),
            const SizedBox(height: 24),
            _buildStatusIndicators(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicators() {
    final radio = widget.radioController;
    final isScanning = radio.isScan || radio.isVfoScanning;
    return Wrap(
      spacing: 24,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _buildStatusIndicator(Icons.track_changes, isScanning ? 'SCANNING' : 'IDLE', isScanning ? Colors.orange : Colors.grey),
        _buildStatusIndicator(
            Icons.sensors,
            radio.isInRx ? radio.currentChannelName : (_scanMode == ScanMode.vfo ? '${radio.currentVfoFrequencyMhz.toStringAsFixed(4)} MHz' : '...'),
            radio.isInRx ? Colors.green : Colors.grey),
        _buildStatusIndicator(Icons.sensors_off, radio.isSq ? 'SIGNAL DETECTED' : 'SQUELCH CLOSED', radio.isSq ? Colors.green : Colors.grey),
      ],
    );
  }

  Widget _buildStatusIndicator(IconData icon, String text, Color color) {
    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(text),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildChannelList() {
    if (_channels == null || _channels!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.list_alt, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_statusMessage.isNotEmpty ? _statusMessage : 'No channels found.'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadAllChannels, child: const Text('Reload Channels')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllChannels,
      child: ListView.builder(
        itemCount: _channels!.length,
        itemBuilder: (context, index) {
          final channel = _channels![index];
          final bool isCurrent = channel.channelId == widget.radioController.currentChannelId && (widget.radioController.isInRx || widget.radioController.isScan);
          return ListTile(
            selected: isCurrent,
            selectedTileColor: Colors.green.withOpacity(0.15),
            leading: CircleAvatar(
              backgroundColor: isCurrent ? Colors.green : Colors.blueGrey,
              foregroundColor: Colors.white,
              child: Text((channel.channelId + 1).toString()),
            ),
            title: Text(channel.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${channel.rxFreq.toStringAsFixed(4)} MHz"),
            trailing: Switch(
              value: channel.scan,
              onChanged: (newValue) => _toggleChannelInScanList(channel, newValue),
              activeColor: Colors.green,
            ),
          );
        },
      ),
    );
  }
}