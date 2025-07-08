import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../benshi/radio_controller.dart';
import '../benshi/protocol/protocol.dart';

class ChirpExporter {
  final RadioController radioController;
  HttpServer? _server;
  String? serverUrl;

  final Function(String message) onStatusUpdate;
  // Callback now handles a full list of channels for UI refresh after a bulk write.
  final void Function(List<Channel> updatedChannels)? onChannelsUpdatedFromWeb;

  ChirpExporter({
    required this.radioController,
    required this.onStatusUpdate,
    this.onChannelsUpdatedFromWeb,
  });

  bool get isRunning => _server != null;

  Future<void> start() async {
    if (isRunning) return;

    try {
      final ip = await NetworkInfo().getWifiIP();
      if (ip == null) {
        onStatusUpdate('Error: Could not get Wi-Fi IP. Ensure you are connected to a Wi-Fi network.');
        return;
      }
      final router = Router();

      router.get('/', _handleWebRequest);
      router.get('/channels.json', _handleChannelsJsonRequest);
      router.get('/chirp.csv', _handleChirpCsvRequest);
      router.post('/channels/update', _handleUpdateChannel);
      // NEW: Endpoint to handle writing all channels at once.
      router.post('/channels/write_all', _handleWriteAllChannels);

      final handler = const Pipeline().addHandler(router);
      _server = await shelf_io.serve(handler, ip, 8080);
      serverUrl = 'http://${_server!.address.host}:${_server!.port}';
      onStatusUpdate('Server running at $serverUrl');
    } catch (e) {
      onStatusUpdate('Error starting server: $e');
      await stop();
    }
  }

  Future<Response> _handleWebRequest(Request request) async {
    onStatusUpdate('Web UI accessed. Loading channels...');
    return Response.ok(
      _generateWebUI(),
      headers: {'Content-Type': 'text/html; charset=utf-8'},
    );
  }

  Future<Response> _handleChannelsJsonRequest(Request request) async {
    try {
      onStatusUpdate('Fetching channel data for Web UI...');
      List<Channel> channels = await radioController.getAllChannels();
      onStatusUpdate('Successfully fetched ${channels.length} channels.');

      List<Map<String, dynamic>> channelData = channels.map((c) {
        return {
          'channelId': c.channelId,
          'name': c.name,
          'rxFreq': c.rxFreq,
          'txFreq': c.txFreq,
          'rxSubAudio': _subAudioToMap(c.rxSubAudio),
          'txSubAudio': _subAudioToMap(c.txSubAudio),
          'bandwidth': c.bandwidth.name,
          'power': c.txPower,
          'scan': c.scan,
        };
      }).toList();

      return Response.ok(
        jsonEncode(channelData),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      onStatusUpdate('Error fetching channels for UI: $e');
      return Response.internalServerError(body: 'Failed to fetch channels: $e');
    }
  }

  // Handles updates for a single channel (when a field is edited).
  Future<Response> _handleUpdateChannel(Request request) async {
    try {
      final payload = await request.readAsString();
      final Map<String, dynamic> data = jsonDecode(payload);
      final int channelId = data['channelId'] ?? -1;
      if (channelId < 0) return Response(400, body: 'Invalid channelId');

      final originalChannel = await radioController.getChannel(channelId);
      final updatedChannel = _channelFromMap(originalChannel, data);

      onStatusUpdate('Channel ${channelId + 1} updated from web. Writing to radio...');
      await radioController.writeChannel(updatedChannel);
      onStatusUpdate('Successfully wrote channel ${channelId + 1}. Refreshing app list...');

      // FIX: Fetch the full, updated list from the radio to ensure UI consistency.
      final fullChannelList = await radioController.getAllChannels();
      onChannelsUpdatedFromWeb?.call(fullChannelList);

      return Response.ok(jsonEncode({'ok': true}));
    } catch (e) {
      onStatusUpdate('Error updating channel: $e');
      return Response.internalServerError(body: 'Failed to update channel: $e');
    }
  }

  // NEW: Handles writing all channels, including reordered ones.
  Future<Response> _handleWriteAllChannels(Request request) async {
    try {
      final payload = await request.readAsString();
      final List<dynamic> channelList = jsonDecode(payload);

      onStatusUpdate('Starting bulk write of ${channelList.length} channels...');

      List<Channel> updatedChannelsForApp = [];
      // To get the base channel info, we need the full list from the radio first.
      final currentRadioChannels = await radioController.getAllChannels();
      final radioChannelsMap = {for (var c in currentRadioChannels) c.channelId: c};


      for (int i = 0; i < channelList.length; i++) {
        final Map<String, dynamic> channelData = channelList[i];
        final int originalId = channelData['channelId'];

        // Get the original channel to preserve non-editable fields
      final originalChannel = radioChannelsMap[originalId];
      if (originalChannel == null) {
          throw Exception("Could not find original channel with id $originalId during bulk write.");
      }

        // Create the updated channel object, but with the *new* channelId (i)
        final updatedChannel = _channelFromMap(originalChannel, channelData).copyWith(channelId: i);

        onStatusUpdate('Writing channel ${i + 1} (was ${originalId + 1})...');
        await radioController.writeChannel(updatedChannel);
        updatedChannelsForApp.add(updatedChannel);
        await Future.delayed(const Duration(milliseconds: 50)); // Small delay
      }

      onStatusUpdate('Bulk write complete. Refreshing app state.');
      onChannelsUpdatedFromWeb?.call(updatedChannelsForApp);

      return Response.ok(jsonEncode({'ok': true, 'message': 'All channels written successfully.'}));

    } catch (e) {
      onStatusUpdate('Error during bulk write: $e');
      return Response.internalServerError(body: 'Failed to write channels: $e');
    }
  }

  // Helper to create a Channel object from a map, using an original channel as a base.
  Channel _channelFromMap(Channel original, Map<String, dynamic> data) {
    return original.copyWith(
      name: data['name'],
      rxFreq: double.tryParse(data['rxFreq'].toString()),
      txFreq: double.tryParse(data['txFreq'].toString()),
      rxSubAudio: _mapToSubAudio(data['rxSubAudio']),
      txSubAudio: _mapToSubAudio(data['txSubAudio']),
      bandwidth: (data['bandwidth'] as String).toUpperCase() == 'NARROW' ? BandwidthType.NARROW : BandwidthType.WIDE,
      scan: data['scan'],
      txAtMaxPower: data['power'] == 'High',
      txAtMedPower: data['power'] == 'Medium',
    );
  }

  Map<String, dynamic> _subAudioToMap(dynamic subAudio) {
    if (subAudio is double) return {'type': 'CTCSS', 'value': subAudio};
    if (subAudio is int) return {'type': 'DCS', 'value': subAudio};
    return {'type': 'None', 'value': null};
  }

  dynamic _mapToSubAudio(Map<String, dynamic> map) {
    final type = map['type'];
    final value = map['value'];
    if (value == null || value.toString().isEmpty) return null;
    if (type == 'CTCSS') return double.tryParse(value.toString());
    if (type == 'DCS') return int.tryParse(value.toString());
    return null;
  }

  Future<Response> _handleChirpCsvRequest(Request request) async {
    try {
      onStatusUpdate('Exporting Channel Map to Chirp Format...');
      List<Channel> channels = await radioController.getAllChannels();
      List<String> header = ['Location','Name','Frequency','Duplex','Offset','Tone','rToneFreq','cToneFreq','DtcsCode','DtcsPolarity','Mode','Power','Skip'];
      List<List<dynamic>> rows = channels.map((c) {
        final offset = c.txFreq - c.rxFreq;
        final duplexChar = c.txFreq == c.rxFreq ? '' : (offset > 0 ? '+' : '-');
        return [c.channelId + 1,c.name,c.rxFreq.toStringAsFixed(6),duplexChar,offset.abs().toStringAsFixed(6),'Tone',_formatSubAudio(c.rxSubAudio, isTone: true),_formatSubAudio(c.txSubAudio, isTone: true),_formatSubAudio(c.rxSubAudio, isTone: false),'NN',c.bandwidth == BandwidthType.NARROW ? 'NFM' : 'FM',c.txPower,c.scan ? '' : 'S'];
      }).toList();
      rows.insert(0, header);
      String csvData = const ListToCsvConverter().convert(rows);
      onStatusUpdate('Export complete. Download starting in browser.');
      return Response.ok(csvData, headers: {'Content-Type': 'text/csv','Content-Disposition': 'attachment; filename="chirp.csv"',},);
    } catch (e) {
      onStatusUpdate('Error exporting channels: $e');
      return Response.internalServerError(body: 'Failed to export channels: $e');
    }
  }

  static String _formatSubAudio(dynamic val, {required bool isTone}) {
    if (val == null) return isTone ? '88.5' : '023';
    if (val is double && isTone) return val.toStringAsFixed(1);
    if (val is int && !isTone) return val.toString().padLeft(3, '0');
    return isTone ? '88.5' : '023';
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
    serverUrl = null;
    onStatusUpdate('Server stopped.');
  }

  static String _generateWebUI() {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Benshi Commander Web Programmer</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background-color: #f4f6f8; margin: 0; padding: 0; color: #333; }
        .container { max-width: 100%; margin: 0 auto; background: #fff; box-shadow: 0 2px 10px rgba(0,0,0,0.05); }
        .main-toolbar { background: #fff; border-bottom: 1px solid #e0e0e0; padding: 10px 20px; display: flex; align-items: center; gap: 16px; position: sticky; top: 0; z-index: 10; }
        .main-toolbar .title { font-weight: 600; font-size: 1.2em; margin-right: auto; }
        button, a.btn { padding: 8px 16px; font-size: 14px; border: none; border-radius: 6px; background-color: #007aff; color: white; cursor: pointer; text-decoration: none; display: inline-flex; align-items: center; gap: 8px; }
        button:hover, a.btn:hover { background-color: #005ecb; }
        button#write-btn { background-color: #34c759; }
        button#write-btn:hover { background-color: #2ca349; }
        .table-container { overflow-x: auto; }
        .channel-table { width: 100%; border-collapse: collapse; user-select: none; }
        .channel-table th, .channel-table td { border-bottom: 1px solid #e8e8e8; padding: 8px 12px; text-align: left; font-size: 14px; vertical-align: middle; white-space: nowrap; }
        .channel-table th { background: #f9fafb; font-weight: 600; color: #555; position: sticky; top: 0; }
        .channel-table tbody tr:hover { background-color: #f0f8ff; }
        .channel-table input, .channel-table select { width: 100%; min-width: 80px; padding: 6px; border: 1px solid #ccc; border-radius: 4px; box-sizing: border-box; font-size: 14px; }
        .status-bar { padding: 10px 20px; background: #333; color: #fff; font-size: 14px; text-align: center; position: fixed; bottom: 0; width: 100%; left: 0; }
        .status-bar.error { background-color: #d32f2f; }
        .status-bar.ok { background-color: #388e3c; }
        tr.selected td { background-color: #dbeaff !important; }
        .dragging { opacity: 0.5; background: #e0e0e0; }
    </style>
</head>
<body>
    <div class="main-toolbar">
        <span class="title">Benshi Web Programmer</span>
        <a href="/chirp.csv" class="btn" download>Export CSV</a>
        <button id="refresh-btn">Refresh Data</button>
        <button id="write-btn">Write All to Radio</button>
    </div>
    <div class="container">
        <div class="table-container">
            <table class="channel-table">
                <thead>
                    <tr>
                        <th>Loc</th><th>Name</th><th>RX Freq</th><th>TX Freq</th>
                        <th>Bandwidth</th><th>Power</th><th>Scan</th><th>RX Tone</th><th>TX Tone</th>
                    </tr>
                </thead>
                <tbody id="channel-table-body"></tbody>
            </table>
        </div>
    </div>
    <div class="status-bar" id="status">Loading...</div>

    <script>
    let channelData = [];
    let lastSelectedRow = null;
    let draggingElement = null;

    const tbody = document.getElementById('channel-table-body');

    function setStatus(msg, type = "info", duration = 4000) {
        const statusEl = document.getElementById('status');
        statusEl.textContent = msg;
        statusEl.className = "status-bar " + (type === "error" ? "error" : type === "ok" ? "ok" : "");
        if (type !== 'info') {
            setTimeout(() => {
                if (statusEl.textContent === msg) {
                    statusEl.textContent = 'Ready';
                    statusEl.className = 'status-bar';
                }
            }, duration);
        }
    }

    async function writeAllChannels() {
        if (!confirm(`This will overwrite all channels on the radio with the current order and settings. Are you sure?`)) return;
        
        setStatus(`Writing all \${channelData.length} channels to radio... This may take a while.`, 'info');
        try {
            const response = await fetch('/channels/write_all', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify(channelData)
            });
            const result = await response.json();
            if (!response.ok) throw new Error(result.body || 'Unknown error during bulk write.');
            setStatus(`All channels written successfully!`, 'ok');
            // Refresh data from radio to confirm changes
            fetchChannels();
        } catch(e) {
            setStatus(`Error writing channels: \${e.message}`, 'error');
        }
    }

    function renderTable() {
        tbody.innerHTML = "";
        for (const ch of channelData) {
            const row = document.createElement('tr');
            row.dataset.id = ch.channelId;
            row.draggable = true;

            const createCell = (child) => {
                const td = document.createElement('td');
                if (child) td.append(child);
                return td;
            };

            const createInput = (key, type = 'text') => {
                const input = document.createElement('input');
                input.type = type;
                if(type === 'checkbox') input.checked = ch[key];
                else input.value = ch[key];
                
                input.onchange = () => { 
                    ch[key] = (type === 'checkbox' ? input.checked : (type === 'number' ? parseFloat(input.value) : input.value));
                    row.classList.add('modified');
                };
                return input;
            };
            
            const createSelect = (key, options) => {
                const select = document.createElement('select');
                select.innerHTML = options.map(o => \`<option value="\${o}" \${ch[key] === o ? 'selected' : ''}>\${o}</option>\`).join('');
                select.onchange = () => { ch[key] = select.value; row.classList.add('modified'); };
                return select;
            }

            const createToneEditor = (subAudioKey) => {
              const container = document.createElement('div');
              container.style.display = 'flex';
              container.style.gap = '5px';
              
              const subAudio = ch[subAudioKey];

              const typeSelect = document.createElement('select');
              typeSelect.innerHTML = ['None', 'CTCSS', 'DCS'].map(o => \`<option value="\${o}" \${subAudio.type === o ? 'selected' : ''}>\${o}</option>\`).join('');
              
              const valueInput = document.createElement('input');
              valueInput.type = 'text';
              valueInput.style.width = '80px';
              valueInput.value = subAudio.value || '';
              valueInput.disabled = subAudio.type === 'None';

              typeSelect.onchange = () => {
                subAudio.type = typeSelect.value;
                valueInput.disabled = subAudio.type === 'None';
                if(subAudio.type === 'None') subAudio.value = null;
                row.classList.add('modified');
              };

              valueInput.onchange = () => {
                subAudio.value = valueInput.value;
                row.classList.add('modified');
              }

              container.append(typeSelect, valueInput);
              return container;
            }

            const locCell = document.createElement('td');
            locCell.textContent = channelData.indexOf(ch) + 1; // Display order
            row.append(locCell,
                createCell(createInput('name')),
                createCell(createInput('rxFreq', 'number')),
                createCell(createInput('txFreq', 'number')),
                createCell(createSelect('bandwidth', ['NARROW', 'WIDE'])),
                createCell(createSelect('power', ['Low', 'Medium', 'High'])),
                createCell(createInput('scan', 'checkbox')),
                createCell(createToneEditor('rxSubAudio')),
                createCell(createToneEditor('txSubAudio'))
            );
            tbody.appendChild(row);
        }
    }

    async function fetchChannels() {
        setStatus("Loading channels from radio...", "info");
        try {
            const response = await fetch('/channels.json');
            if (!response.ok) throw new Error('Failed to fetch from device.');
            channelData = await response.json();
            renderTable();
            setStatus(`Loaded \${channelData.length} channels. Ready.`, "ok");
        } catch(e) {
            setStatus(`Error: \${e.message}`, "error");
        }
    }

    // --- Event Listeners ---
    document.getElementById('refresh-btn').onclick = fetchChannels;
    document.getElementById('write-btn').onclick = writeAllChannels;

    // Selection Logic
    tbody.addEventListener('click', (e) => {
        const row = e.target.closest('tr');
        if (!row || e.target.matches('input, select')) return;

        if (!e.ctrlKey && !e.shiftKey) {
            document.querySelectorAll('tr.selected').forEach(r => r.classList.remove('selected'));
            row.classList.add('selected');
        } else if (e.ctrlKey) {
            row.classList.toggle('selected');
        } else if (e.shiftKey && lastSelectedRow) {
            document.querySelectorAll('tr.selected').forEach(r => r.classList.remove('selected'));
            const rows = [...tbody.querySelectorAll('tr')];
            const start = rows.indexOf(lastSelectedRow);
            const end = rows.indexOf(row);
            const range = rows.slice(Math.min(start, end), Math.max(start, end) + 1);
            range.forEach(r => r.classList.add('selected'));
        }
        lastSelectedRow = row;
    });

    // Copy to Clipboard Logic
    document.addEventListener('keydown', (e) => {
        if ((e.ctrlKey || e.metaKey) && e.key === 'c') {
            const selectedRows = document.querySelectorAll('tr.selected');
            if (selectedRows.length === 0) return;
            
            let tsv = '';
            selectedRows.forEach(row => {
                const cells = [...row.querySelectorAll('td')].map(td => {
                    const input = td.querySelector('input, select');
                    if (input) return input.type === 'checkbox' ? input.checked : input.value;
                    return td.textContent;
                });
                tsv += cells.join('\\t') + '\\n';
            });

            navigator.clipboard.writeText(tsv).then(() => {
                setStatus(`Copied \${selectedRows.length} rows to clipboard.`, 'ok');
            }, () => {
                setStatus('Failed to copy rows.', 'error');
            });
        }
    });

    // Drag and Drop Logic
    tbody.addEventListener('dragstart', e => {
        draggingElement = e.target.closest('tr');
        if(draggingElement) draggingElement.classList.add('dragging');
    });

    tbody.addEventListener('dragover', e => {
        e.preventDefault();
        const target = e.target.closest('tr');
        if (target && target !== draggingElement) {
            const rect = target.getBoundingClientRect();
            const next = (e.clientY - rect.top) / rect.height > 0.5;
            tbody.insertBefore(draggingElement, next ? target.nextSibling : target);
        }
    });

    tbody.addEventListener('drop', e => {
        e.preventDefault();
        if (draggingElement) {
            draggingElement.classList.remove('dragging');
            
            const newOrderIds = [...tbody.querySelectorAll('tr')].map(r => parseInt(r.dataset.id));
            
            // Reorder the backing channelData array
            channelData.sort((a, b) => newOrderIds.indexOf(a.channelId) - newOrderIds.indexOf(b.channelId));

            // Re-render to update displayed location numbers
            renderTable();
            setStatus('Channel order changed. Click "Write All to Radio" to save.', 'info');
        }
        draggingElement = null;
    });

    document.addEventListener('DOMContentLoaded', fetchChannels);
    </script>
</body>
</html>
''';
  }
}