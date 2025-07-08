import 'package:flutter/material.dart';
import 'dart:async';
import '../benshi/radio_controller.dart';
import '../benshi/protocol/protocol.dart';
import '../services/web_programmer.dart';

class ProgrammerView extends StatefulWidget {
  final RadioController radioController;
  const ProgrammerView({Key? key, required this.radioController}) : super(key: key);

  @override
  _ProgrammerViewState createState() => _ProgrammerViewState();
}

class _ProgrammerViewState extends State<ProgrammerView> {
  late final ChirpExporter _chirpExporter;

  // UI State
  List<Channel>? _channels;
  bool _isLoading = false;
  String _statusMessage = 'Read channels from the radio to begin editing.';
  final Set<int> _modifiedChannelIds = {};

  @override
  void initState() {
    super.initState();
    _chirpExporter = ChirpExporter(
      radioController: widget.radioController,
      onStatusUpdate: (message) {
        if (mounted) {
          setState(() {
            // This is for the ChirpExporter's own status, not the main view status
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _chirpExporter.stop();
    super.dispose();
  }

  void _updateStatus(String message) {
    if (mounted) setState(() => _statusMessage = message);
  }

  Future<void> _readChannelsFromRadio() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _statusMessage = 'Reading all channels from radio...';
      _modifiedChannelIds.clear();
    });

    try {
      final channels = await widget.radioController.getAllChannels();
      setState(() {
        _channels = channels;
        _isLoading = false;
        _statusMessage = 'Successfully loaded ${_channels?.length ?? 0} channels.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error reading channels: $e';
      });
    }
  }

  Future<void> _writeChannelsToRadio() async {
    if (_isLoading || _channels == null || _modifiedChannelIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No modified channels to write.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _isLoading = true);

    int successCount = 0;
    int errorCount = 0;
    List<int> successfullyWrittenIds = [];

    for (final channelId in _modifiedChannelIds) {
      final channel = _channels!.firstWhere((c) => c.channelId == channelId);
      try {
        _updateStatus('Writing channel ${channelId + 1}...');
        await widget.radioController.writeChannel(channel);
        successCount++;
        successfullyWrittenIds.add(channelId);
        await Future.delayed(const Duration(milliseconds: 50)); // Small delay between writes
      } catch (e) {
        errorCount++;
        _updateStatus('Error writing channel ${channelId + 1}: $e');
      }
    }

    setState(() {
      _isLoading = false;
      _statusMessage = 'Write complete. Success: $successCount, Failed: $errorCount.';
      // Remove only the successfully written channels from the modified set
      _modifiedChannelIds.removeWhere((id) => successfullyWrittenIds.contains(id));
    });
  }

  Future<void> _editChannel(int index) async {
    if (_channels == null) return;

    final Channel originalChannel = _channels![index];
    final Channel? updatedChannel = await showDialog<Channel>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EditChannelDialog(channel: originalChannel),
    );

    if (updatedChannel != null && updatedChannel != originalChannel) {
      setState(() {
        _channels![index] = updatedChannel;
        _modifiedChannelIds.add(updatedChannel.channelId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading ? _buildLoadingView() : _buildMainContent();
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        Expanded(
          child: _channels == null ? _buildInitialView() : _buildProgrammerView(),
        ),
        _buildChirpExportCard(),
      ],
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              _statusMessage,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.radio, size: 100, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              'In-App Programmer',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.download_for_offline),
              label: const Text('Read from Radio'),
              onPressed: _readChannelsFromRadio,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgrammerView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(_statusMessage),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _channels?.length ?? 0,
            itemBuilder: (context, index) {
              final channel = _channels![index];
              final isModified = _modifiedChannelIds.contains(channel.channelId);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isModified ? Colors.orange.shade100 : Colors.blue.shade50,
                  child: Text(
                    (channel.channelId + 1).toString(),
                    style: TextStyle(color: isModified ? Colors.orange.shade800 : Colors.blue.shade800),
                  ),
                ),
                title: Text(channel.name,
                    style: TextStyle(
                        fontWeight: isModified ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text(
                    '${channel.rxFreq.toStringAsFixed(4)} MHz | ${channel.txPower} Power | ${channel.bandwidth.name}'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_note),
                  onPressed: () => _editChannel(index),
                ),
                tileColor: isModified ? Colors.orange.withOpacity(0.05) : null,
              );
            },
          ),
        ),
        // FIX: Added the action buttons back into the view's layout
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.sync),
                label: const Text('Read Again'),
                onPressed: _readChannelsFromRadio,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: Text('Write Changes (${_modifiedChannelIds.length})'),
                onPressed: _modifiedChannelIds.isNotEmpty ? _writeChannelsToRadio : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChirpExportCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: ExpansionTile(
        leading: Icon(
          Icons.import_export,
          color: Colors.teal.shade700,
        ),
        title: const Text('Web Programmer'),
        subtitle: Text(_chirpExporter.isRunning ? 'Server is ON' : 'Server is OFF'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                _chirpExporter.isRunning
                    ? 'Server is running. Open this address in a web browser on the same network:'
                    : 'Start the server to edit channels over your local network.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (_chirpExporter.isRunning && _chirpExporter.serverUrl != null)
                SelectableText(
                  _chirpExporter.serverUrl!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (_chirpExporter.isRunning) {
                    _chirpExporter.stop();
                  } else {
                    _chirpExporter.start();
                  }
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _chirpExporter.isRunning ? Colors.redAccent : Colors.green,
                ),
                child: Text(_chirpExporter.isRunning ? 'Stop Server' : 'Start Server'),
              ),
            ]),
          )
        ],
      ),
    );
  }
}

// A dialog for editing a single channel.
class _EditChannelDialog extends StatefulWidget {
  final Channel channel;
  const _EditChannelDialog({Key? key, required this.channel}) : super(key: key);

  @override
  State<_EditChannelDialog> createState() => _EditChannelDialogState();
}

class _EditChannelDialogState extends State<_EditChannelDialog> {
  // Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _rxFreqController;
  late final TextEditingController _txFreqController;
  late final TextEditingController _rxToneController;
  late final TextEditingController _txToneController;

  // State variables
  late BandwidthType _bandwidth;
  late String _power;
  late bool _scan;
  late String _rxToneType;
  late String _txToneType;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final ch = widget.channel;
    _nameController = TextEditingController(text: ch.name);
    _rxFreqController = TextEditingController(text: ch.rxFreq.toString());
    _txFreqController = TextEditingController(text: ch.txFreq.toString());

    _bandwidth = ch.bandwidth;
    _power = ch.txPower;
    _scan = ch.scan;

    // Initialize RX Tone
    final rxTuple = _getToneTypeAndValue(ch.rxSubAudio);
    _rxToneType = rxTuple.item1;
    _rxToneController = TextEditingController(text: rxTuple.item2);

    // Initialize TX Tone
    final txTuple = _getToneTypeAndValue(ch.txSubAudio);
    _txToneType = txTuple.item1;
    _txToneController = TextEditingController(text: txTuple.item2);
  }

  Tuple2<String, String> _getToneTypeAndValue(dynamic subAudio) {
    if (subAudio is double) {
      return Tuple2('CTCSS', subAudio.toString());
    }
    if (subAudio is int) {
      return Tuple2('DCS', subAudio.toString());
    }
    return const Tuple2('None', '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rxFreqController.dispose();
    _txFreqController.dispose();
    _rxToneController.dispose();
    _txToneController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return; // Don't save if form is invalid
    }

    // Helper to parse tones
    dynamic parseSubAudio(String type, String value) {
      if (type == 'CTCSS') return double.tryParse(value);
      if (type == 'DCS') return int.tryParse(value);
      return null;
    }

    final updatedChannel = Channel(
      channelId: widget.channel.channelId,
      name: _nameController.text,
      rxFreq: double.tryParse(_rxFreqController.text) ?? widget.channel.rxFreq,
      txFreq: double.tryParse(_txFreqController.text) ?? widget.channel.txFreq,
      bandwidth: _bandwidth,
      scan: _scan,
      // Convert power string back to booleans
      txAtMaxPower: _power == 'High',
      txAtMedPower: _power == 'Medium',
      // Parse sub-audio tones
      rxSubAudio: parseSubAudio(_rxToneType, _rxToneController.text),
      txSubAudio: parseSubAudio(_txToneType, _txToneController.text),
      // Copy other properties from the original channel
      txMod: widget.channel.txMod, // Assume FM for now
      rxMod: widget.channel.rxMod,
      // Copy fixed properties
      talkAround: widget.channel.talkAround,
      preDeEmphBypass: widget.channel.preDeEmphBypass,
      sign: widget.channel.sign,
      txDisable: widget.channel.txDisable,
      fixed_freq: widget.channel.fixed_freq,
      fixed_bandwidth: widget.channel.fixed_bandwidth,
      fixed_tx_power: widget.channel.fixed_tx_power,
      mute: widget.channel.mute,
    );
    Navigator.of(context).pop(updatedChannel);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Channel ${widget.channel.channelId + 1}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.isEmpty) ? 'Name cannot be empty' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rxFreqController,
                decoration: const InputDecoration(labelText: 'RX Frequency (MHz)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) =>
                    (double.tryParse(v ?? '') == null) ? 'Invalid frequency' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _txFreqController,
                decoration: const InputDecoration(labelText: 'TX Frequency (MHz)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) =>
                    (double.tryParse(v ?? '') == null) ? 'Invalid frequency' : null,
              ),
              const SizedBox(height: 16),
              _buildToneEditor("RX Tone", _rxToneType, _rxToneController,
                  (type) => setState(() => _rxToneType = type)),
              const SizedBox(height: 16),
              _buildToneEditor("TX Tone", _txToneType, _txToneController,
                  (type) => setState(() => _txToneType = type)),
              const SizedBox(height: 16),
              DropdownButtonFormField<BandwidthType>(
                value: _bandwidth,
                decoration: const InputDecoration(labelText: 'Bandwidth', border: OutlineInputBorder()),
                items: BandwidthType.values
                    .map((bw) => DropdownMenuItem(value: bw, child: Text(bw.name)))
                    .toList(),
                onChanged: (v) => setState(() => _bandwidth = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _power,
                decoration: const InputDecoration(labelText: 'TX Power', border: OutlineInputBorder()),
                items: ['Low', 'Medium', 'High']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _power = v!),
              ),
              SwitchListTile(
                title: const Text('Add to Scan List'),
                value: _scan,
                onChanged: (v) => setState(() => _scan = v),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildToneEditor(String label, String currentType,
      TextEditingController controller, Function(String) onTypeChanged) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        children: [
          DropdownButton<String>(
            value: currentType,
            underline: Container(),
            items: ['None', 'CTCSS', 'DCS']
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) {
              if (v != null) onTypeChanged(v);
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: controller,
              enabled: currentType != 'None',
              decoration: InputDecoration(
                isDense: true,
                hintText: currentType == 'CTCSS'
                    ? 'e.g., 88.5'
                    : (currentType == 'DCS' ? 'e.g., 23' : 'Disabled'),
              ),
              keyboardType:
                  TextInputType.numberWithOptions(decimal: currentType == 'CTCSS'),
            ),
          ),
        ],
      ),
    );
  }
}

// A simple tuple class to help with tone parsing.
class Tuple2<T1, T2> {
  final T1 item1;
  final T2 item2;
  const Tuple2(this.item1, this.item2);
}