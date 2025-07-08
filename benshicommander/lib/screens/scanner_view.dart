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
  // State for the channel list
  List<Channel>? _channels;
  bool _isLoading = true;
  String _statusMessage = '';

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
    final bool isScanning = radio.isScan;

    return Column(
      children: [
        // --- Top Control Panel ---
        _buildControlPanel(isScanning, radio),
        const Divider(height: 1),
        // --- Channel List ---
        Expanded(
          child: _isLoading && _channels == null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(_statusMessage)]))
              : _buildChannelList(),
        ),
      ],
    );
  }

  Widget _buildControlPanel(bool isScanning, RadioController radio) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
            ],
          ),
          const SizedBox(height: 16),
          // --- Status Indicators ---
          Wrap(
            spacing: 24,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildStatusIndicator(
                  Icons.track_changes,
                  isScanning ? 'SCANNING' : 'IDLE',
                  isScanning ? Colors.orange : Colors.grey),
              _buildStatusIndicator(
                  Icons.sensors,
                  radio.isInRx ? radio.currentChannelName : '...',
                  radio.isInRx ? Colors.green : Colors.grey),
              _buildStatusIndicator(
                  Icons.sensors_off,
                  radio.isSq ? 'SIGNAL DETECTED' : 'SQUELCH CLOSED',
                  radio.isSq ? Colors.green : Colors.grey),
            ],
          )
        ],
      ),
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