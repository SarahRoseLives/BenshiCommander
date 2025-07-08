import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../benshi/radio_controller.dart';
import '../benshi/protocol/protocol.dart';
import '../models/repeater.dart';
import '../services/web_programmer.dart';
import '../services/memory_storage_service.dart';
import '../services/location_service.dart';
import '../services/repeaterbook_service.dart';
import 'package:geolocator/geolocator.dart' as geo;

class ProgrammerView extends StatefulWidget {
  final RadioController radioController;
  const ProgrammerView({Key? key, required this.radioController}) : super(key: key);

  @override
  _ProgrammerViewState createState() => _ProgrammerViewState();
}

class _ProgrammerViewState extends State<ProgrammerView> {
  final LocationService _locationService = LocationService();
  final RepeaterBookService _repeaterBookService = RepeaterBookService();
  StreamSubscription<geo.Position>? _positionStream;
  geo.Position? _lastLoadedPosition;

  late final ChirpExporter _chirpExporter;

  List<Channel>? _channels;
  bool _isLoading = false;
  String _statusMessage = 'Read channels from the radio to begin editing.';
  final Set<int> _modifiedChannelIds = {};
  bool _orderHasChanged = false;

  List<MemoryBackup> _backups = [];
  List<MemoryBackup> _preloadAssets = [];
  bool _loadingBackups = true;

  // Expansion state for memory library card
  bool _memoryLibraryExpanded = false;

  @override
  void initState() {
    super.initState();
    _chirpExporter = ChirpExporter(
      radioController: widget.radioController,
      onStatusUpdate: (message) {
        if (mounted) setState(() {});
      },
      onChannelsUpdatedFromWeb: (List<Channel> updatedChannels) {
        if (mounted) {
          setState(() {
            _channels = updatedChannels;
            _modifiedChannelIds.clear();
            _orderHasChanged = false;
            _statusMessage = "Radio memory synced from web programmer.";
          });
        }
      },
    );
    _refreshBackups();
    _loadPreloadAssets();
  }

  Future<void> _refreshBackups() async {
    setState(() => _loadingBackups = true);
    _backups = await MemoryStorageService().listBackups();
    setState(() => _loadingBackups = false);
  }

  Future<void> _loadPreloadAssets() async {
    _preloadAssets = await MemoryStorageService().listPreloadAssets();
    setState(() {});
  }

  @override
  void dispose() {
    _chirpExporter.stop();
    _positionStream?.cancel();
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
      _orderHasChanged = false;
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

  // --- GPS Repeater Loading ---
  Future<void> loadLocalRepeaters() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _statusMessage = 'Getting your location...';
    });

    try {
      final position = await _locationService.getCurrentLocation();
      if (position == null) {
        throw Exception("Could not get current location.");
      }

      _updateStatus('Location found. Searching for repeaters in your state...');

      final repeaters = await _repeaterBookService.getRepeatersNearby(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (repeaters.isEmpty) {
        _updateStatus('No repeaters found in your state.');
        setState(() => _isLoading = false);
        return;
      }

      final newChannels = repeaters.asMap().entries.map((e) => e.value.toChannel(e.key)).toList();

      setState(() {
        _channels = newChannels;
        _modifiedChannelIds.clear();
        _orderHasChanged = true;
        _isLoading = false;
        _statusMessage = 'Loaded ${newChannels.length} repeaters in your state. Press "Write All" to program radio.';
        _lastLoadedPosition = position;
      });

      _startLocationMonitoring();

    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error loading repeaters: $e';
      });
    }
  }

  void _startLocationMonitoring() {
    _positionStream?.cancel();
    _positionStream = _locationService.getLocationStream(distanceFilter: 1609 * 15).listen((geo.Position newPosition) {
      if (_lastLoadedPosition != null) {
        final distance = _locationService.getDistanceInMiles(_lastLoadedPosition!.latitude, _lastLoadedPosition!.longitude, newPosition.latitude, newPosition.longitude);
        if (distance > 15) {
          _updateStatus("Moved >15 miles. Automatically refreshing local repeaters...");
          loadLocalRepeaters();
        }
      }
    });
  }

  // --- End GPS Repeater Loading ---

  Future<void> _backupToPhone() async {
    if (_channels == null) return;
    final name = await _promptForName(context, "Name this backup:");
    if (name == null || name.trim().isEmpty) return;
    await MemoryStorageService().saveBackup(name, _channels!);
    await _refreshBackups();
    _closeMemoryLibraryCard();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup "$name" saved.')));
    }
  }

  Future<void> _restoreBackup(MemoryBackup backup) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore Memory List?'),
        content: Text('This will load "${backup.name}" and allow you to write it to your radio. Proceed?'),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
          TextButton(child: const Text('Load'), onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      _channels = backup.channels;
      _modifiedChannelIds.clear();
      _orderHasChanged = true;
      _statusMessage = 'Loaded backup: ${backup.name}';
      _memoryLibraryExpanded = false;
    });
  }

  Future<void> _deleteBackup(MemoryBackup backup) async {
    await MemoryStorageService().deleteBackup(backup);
    await _refreshBackups();
    // Don't close card on delete.
  }

  Future<void> _loadPreloadAsset(MemoryBackup asset) async {
    setState(() {
      _channels = asset.channels;
      _modifiedChannelIds.clear();
      _orderHasChanged = true;
      _statusMessage = 'Loaded preloaded list: ${asset.name}';
      _memoryLibraryExpanded = false;
    });
  }

  Future<void> _createNewList() async {
    setState(() {
      _channels = [];
      _modifiedChannelIds.clear();
      _orderHasChanged = true;
      _statusMessage = "Created new empty memory list.";
      _memoryLibraryExpanded = false;
    });
  }

  void _closeMemoryLibraryCard() {
    setState(() {
      _memoryLibraryExpanded = false;
    });
  }

  Future<void> _writeModifiedChannelsToRadio() async {
    if (_isLoading || _channels == null || _modifiedChannelIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No modified channels to write.'),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }

    setState(() => _isLoading = true);

    int successCount = 0;
    int errorCount = 0;
    List<int> successfullyWrittenIds = [];
    final channelsToWrite = _channels!.where((c) => _modifiedChannelIds.contains(c.channelId)).toList();

    for (final channel in channelsToWrite) {
      try {
        _updateStatus('Writing channel ${channel.channelId + 1}...');
        await widget.radioController.writeChannel(channel);
        successCount++;
        successfullyWrittenIds.add(channel.channelId);
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        errorCount++;
        _updateStatus('Error writing channel ${channel.channelId + 1}: $e');
        break;
      }
    }

    setState(() {
      _isLoading = false;
      _statusMessage = 'Write complete. Success: $successCount, Failed: $errorCount.';
      _modifiedChannelIds.removeWhere((id) => successfullyWrittenIds.contains(id));
    });
  }

  Future<void> _writeAllChannelsToRadio() async {
    if (_isLoading || _channels == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Write All'),
        content: Text('This will overwrite all ${_channels!.length} channels on the radio with the current order and settings. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Write All')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    int successCount = 0;
    int errorCount = 0;

    for (int i = 0; i < _channels!.length; i++) {
      final oldChannel = _channels![i];
      final channelToWrite = oldChannel.copyWith(channelId: i);

      try {
        _updateStatus('Writing to memory slot ${i + 1} (was ${oldChannel.channelId + 1})...');
        await widget.radioController.writeChannel(channelToWrite);
        successCount++;
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        errorCount++;
        _updateStatus('Error writing to slot ${i + 1}: $e');
        break;
      }
    }

    setState(() {
      _isLoading = false;
      _statusMessage = 'Full write complete. Success: $successCount, Failed: $errorCount.';
      _modifiedChannelIds.clear();
      _orderHasChanged = false;
    });
    await _readChannelsFromRadio();
  }

  Future<void> _editChannel(int index) async {
    if (_channels == null) return;

    final Channel originalChannel = _channels![index];
    final Channel? updatedChannel = await showDialog<Channel>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EditChannelDialog(channel: originalChannel),
    );

    if (updatedChannel != null) {
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
        _buildMemoryLibraryCard(),
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
            const Icon(Icons.edit_note, size: 100, color: Colors.grey),
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
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.gps_fixed),
              label: const Text('Load Local Repeaters'),
              onPressed: loadLocalRepeaters,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal,
                side: const BorderSide(color: Colors.teal),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgrammerView() {
    return Column(
      children: [
        Container(
          color: Colors.blue.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.blue),),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: _channels?.length ?? 0,
            itemBuilder: (context, index) {
              final channel = _channels![index];
              final isModified = _modifiedChannelIds.contains(channel.channelId) || _orderHasChanged;
              return ListTile(
                key: ValueKey(channel.channelId),
                leading: CircleAvatar(
                  backgroundColor: isModified ? Colors.orange.shade100 : Colors.blue.shade50,
                  child: Text(
                    (index + 1).toString(),
                    style: TextStyle(color: isModified ? Colors.orange.shade800 : Colors.blue.shade800),
                  ),
                ),
                title: Text(channel.name,
                    style: TextStyle(
                        fontWeight: isModified ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text(
                    '${channel.rxFreq.toStringAsFixed(4)} MHz | ${channel.txPower} | ${channel.bandwidth.name}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_note),
                      onPressed: () => _editChannel(index),
                    ),
                    const Icon(Icons.drag_handle),
                  ],
                ),
                tileColor: isModified ? Colors.orange.withOpacity(0.05) : null,
              );
            },
            onReorder: (int oldIndex, int newIndex) {
              setState(() {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                final Channel item = _channels!.removeAt(oldIndex);
                _channels!.insert(newIndex, item);
                _orderHasChanged = true;
                _statusMessage = 'Channel order changed. Press "Write All" to save.';
              });
            },
          ),
        ),
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
              if (_orderHasChanged)
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_as),
                  label: const Text('Write All Channels'),
                  onPressed: _writeAllChannelsToRadio,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                )
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text('Write Changes (${_modifiedChannelIds.length})'),
                  onPressed: _modifiedChannelIds.isNotEmpty ? _writeModifiedChannelsToRadio : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
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
        leading: Icon(Icons.http, color: Colors.teal.shade700),
        title: const Text('Web Programmer'),
        subtitle: Text(_chirpExporter.isRunning ? 'Server is ON' : 'Server is OFF'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMemoryLibraryCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: ExpansionTile(
        leading: const Icon(Icons.save),
        title: const Text('Memory Library'),
        subtitle: const Text('Save & restore radio memory lists'),
        initiallyExpanded: _memoryLibraryExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _memoryLibraryExpanded = expanded;
          });
        },
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
            child: Column(
              children: [
                if (_channels != null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.backup),
                    label: const Text('Backup current to phone'),
                    onPressed: _backupToPhone,
                  ),
                const SizedBox(height: 4),
                ElevatedButton.icon(
                  icon: const Icon(Icons.note_add),
                  label: const Text('New empty memory list'),
                  onPressed: _createNewList,
                ),
              ],
            ),
          ),
          // Scrollable content below the two top buttons
          if (_preloadAssets.isNotEmpty || _loadingBackups || _backups.isNotEmpty)
            SizedBox(
              height: 220,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_backups.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Saved Backups:', style: TextStyle(fontWeight: FontWeight.bold)),
                            for (final backup in _backups)
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.save_alt, size: 20),
                                title: Text(backup.name),
                                subtitle: Text(backup.dateString),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () => _restoreBackup(backup),
                                      child: const Text('Load'),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteBackup(backup),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      if (_preloadAssets.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Preloaded Templates:', style: TextStyle(fontWeight: FontWeight.bold)),
                            for (final asset in _preloadAssets)
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.star, color: Colors.amber, size: 20),
                                title: Text(asset.name),
                                trailing: ElevatedButton(
                                  onPressed: () => _loadPreloadAsset(asset),
                                  child: const Text('Load'),
                                ),
                              ),
                          ],
                        ),
                      if (_loadingBackups)
                        const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<String?> _promptForName(BuildContext context, String prompt) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(prompt),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('OK')),
        ],
      ),
    );
  }
}

class _EditChannelDialog extends StatefulWidget {
  final Channel channel;
  const _EditChannelDialog({Key? key, required this.channel}) : super(key: key);

  @override
  State<_EditChannelDialog> createState() => _EditChannelDialogState();
}

class _EditChannelDialogState extends State<_EditChannelDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _rxFreqController;
  late final TextEditingController _txFreqController;
  late final TextEditingController _rxToneController;
  late final TextEditingController _txToneController;

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

    final rxTuple = _getToneTypeAndValue(ch.rxSubAudio);
    _rxToneType = rxTuple.item1;
    _rxToneController = TextEditingController(text: rxTuple.item2);

    final txTuple = _getToneTypeAndValue(ch.txSubAudio);
    _txToneType = txTuple.item1;
    _txToneController = TextEditingController(text: txTuple.item2);
  }

  Tuple2<String, String> _getToneTypeAndValue(dynamic subAudio) {
    if (subAudio is double) return Tuple2('CTCSS', subAudio.toString());
    if (subAudio is int) return Tuple2('DCS', subAudio.toString());
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
      return;
    }

    dynamic parseSubAudio(String type, String value) {
      if (value.isEmpty) return null;
      if (type == 'CTCSS') return double.tryParse(value);
      if (type == 'DCS') return int.tryParse(value);
      return null;
    }

    final updatedChannel = widget.channel.copyWith(
      name: _nameController.text,
      rxFreq: double.tryParse(_rxFreqController.text),
      txFreq: double.tryParse(_txFreqController.text),
      bandwidth: _bandwidth,
      scan: _scan,
      txAtMaxPower: _power == 'High',
      txAtMedPower: _power == 'Medium',
      rxSubAudio: parseSubAudio(_rxToneType, _rxToneController.text),
      txSubAudio: parseSubAudio(_txToneType, _txToneController.text),
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
                validator: (v) => (double.tryParse(v ?? '') == null) ? 'Invalid frequency' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _txFreqController,
                decoration: const InputDecoration(labelText: 'TX Frequency (MHz)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (double.tryParse(v ?? '') == null) ? 'Invalid frequency' : null,
              ),
              const SizedBox(height: 16),
              _buildToneEditor("RX Tone", _rxToneType, _rxToneController, (type) => setState(() => _rxToneType = type)),
              const SizedBox(height: 16),
              _buildToneEditor("TX Tone", _txToneType, _txToneController, (type) => setState(() => _txToneType = type)),
              const SizedBox(height: 16),
              DropdownButtonFormField<BandwidthType>(
                value: _bandwidth,
                decoration: const InputDecoration(labelText: 'Bandwidth', border: OutlineInputBorder()),
                items: BandwidthType.values.map((bw) => DropdownMenuItem(value: bw, child: Text(bw.name))).toList(),
                onChanged: (v) => setState(() => _bandwidth = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _power,
                decoration: const InputDecoration(labelText: 'TX Power', border: OutlineInputBorder()),
                items: ['Low', 'Medium', 'High'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
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
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _buildToneEditor(String label, String currentType, TextEditingController controller, Function(String) onTypeChanged) {
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
            items: ['None', 'CTCSS', 'DCS'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
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
                hintText: currentType == 'CTCSS' ? 'e.g., 88.5' : (currentType == 'DCS' ? 'e.g., 23' : 'Disabled'),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: currentType == 'CTCSS'),
            ),
          ),
        ],
      ),
    );
  }
}

class Tuple2<T1, T2> {
  final T1 item1;
  final T2 item2;
  const Tuple2(this.item1, this.item2);
}