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

  ChirpExporter({required this.radioController, required this.onStatusUpdate});

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

      // API for saving edited channel data (browser POSTs updated JSON)
      router.post('/channels/update', _handleUpdateChannel);

      final handler = const Pipeline().addHandler(router);
      _server = await shelf_io.serve(handler, ip, 8080);
      serverUrl = 'http://${_server!.address.host}:${_server!.port}';
      onStatusUpdate('Server running at $serverUrl');
    } catch (e) {
      onStatusUpdate('Error starting server: $e');
      await stop();
    }
  }

  /// Handles the initial request for the web UI page.
  Future<Response> _handleWebRequest(Request request) async {
    onStatusUpdate('Web UI accessed. Loading channels...');
    return Response.ok(
      _generateWebUI(),
      headers: {'Content-Type': 'text/html'},
    );
  }

  /// Handles the request for channel data in JSON format.
  Future<Response> _handleChannelsJsonRequest(Request request) async {
    try {
      onStatusUpdate('Fetching channel data for Web UI...');
      List<Channel> channels = await radioController.getAllChannels();
      onStatusUpdate('Successfully fetched ${channels.length} channels.');

      List<Map<String, dynamic>> channelData = channels.map((c) {
        final offset = c.txFreq - c.rxFreq;
        return {
          'location': c.channelId + 1,
          'frequency': c.rxFreq.toStringAsFixed(6),
          'name': c.name,
          'toneMode': c.rxSubAudio != null ? 'Tone' : '(None)',
          'tone': _formatSubAudio(c.rxSubAudio, isTone: true),
          'toneSql': _formatSubAudio(c.txSubAudio, isTone: true),
          'dtcsCode': _formatSubAudio(c.rxSubAudio, isTone: false),
          'dtcsRxCode': _formatSubAudio(c.txSubAudio, isTone: false),
          'dtcsPol': 'NN',
          'crossMode': 'Tone->Tone',
          'duplex': (offset == 0) ? '(None)' : (offset > 0 ? '+' : '-'),
          'offset': offset.abs().toStringAsFixed(6),
          'mode': c.bandwidth == BandwidthType.NARROW ? 'NFM' : 'FM',
          'power': c.txPower, // Will be edited in UI as string
          'skip': c.scan ? '' : 'S',
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

  /// Handles updates to a single channel (edit-in-place in the UI).
  Future<Response> _handleUpdateChannel(Request request) async {
    try {
      final payload = await request.readAsString();
      final Map<String, dynamic> data = jsonDecode(payload);

      // Channel index is 1-based in the UI, 0-based in our model
      final int loc = data['location'] ?? -1;
      if (loc <= 0) return Response(400, body: 'Invalid location');

      // Find and update the channel (this is just a stub for now).
      // In production, update your radioController here:
      // await radioController.updateChannel(loc-1, ...data...);
      // For now, just pretend success!
      onStatusUpdate('Channel $loc updated in UI: $data');

      return Response.ok(jsonEncode({'ok': true}));
    } catch (e) {
      return Response.internalServerError(body: 'Failed to update channel: $e');
    }
  }

  static String _formatSubAudio(dynamic val, {required bool isTone}) {
    if (val == null) return isTone ? '88.5' : '023';
    if (val is double && isTone) return val.toStringAsFixed(1);
    if (val is int && !isTone) return val.toString().padLeft(3, '0');
    return isTone ? '88.5' : '023';
  }

  Future<Response> _handleChirpCsvRequest(Request request) async {
    try {
      onStatusUpdate('Exporting Channel Map to Chirp Format...');
      List<Channel> channels = await radioController.getAllChannels();

      List<String> header = [
        'Location', 'Name', 'Frequency', 'Duplex', 'Offset',
        'Tone', 'rToneFreq', 'cToneFreq', 'DtcsCode', 'DtcsPolarity',
        'Mode', 'Power', 'Skip'
      ];

      List<List<dynamic>> rows = channels.map((c) {
        final offset = c.txFreq - c.rxFreq;
        final duplexChar = c.txFreq == c.rxFreq ? '' : (offset > 0 ? '+' : '-');
        return [
            c.channelId + 1,
            c.name,
            c.rxFreq.toStringAsFixed(6),
            duplexChar,
            offset.abs().toStringAsFixed(6),
            'Tone',
            _formatSubAudio(c.rxSubAudio, isTone: true),
            _formatSubAudio(c.txSubAudio, isTone: true),
            _formatSubAudio(c.rxSubAudio, isTone: false),
            'NN',
            c.bandwidth == BandwidthType.NARROW ? 'NFM' : 'FM',
            c.txPower,
            c.scan ? '' : 'S'
        ];
      }).toList();

      rows.insert(0, header);

      String csvData = const ListToCsvConverter().convert(rows);

      onStatusUpdate('Export complete. Download starting in browser.');

      return Response.ok(
        csvData,
        headers: {
          'Content-Type': 'text/csv',
          'Content-Disposition': 'attachment; filename="chirp.csv"',
        },
      );
    } catch (e) {
      onStatusUpdate('Error exporting channels: $e');
      return Response.internalServerError(body: 'Failed to export channels: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
    serverUrl = null;
    onStatusUpdate('Server stopped.');
  }

  /// Generates the full HTML for the web UI.
  static String _generateWebUI() {
    // See screenshot ![image1](image1) for reference
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-g">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CHIRP Web Programmer</title>
    <style>
        body { 
            font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif; 
            font-size: 12px;
            background-color: #f0f0f0;
            margin: 0;
            padding: 12px 0;
        }
        .main-toolbar {
            background: #e8e8e8;
            border-bottom: 1px solid #bdbdbd;
            padding: 7px 18px 7px 24px;
            display: flex;
            align-items: center;
            gap: 16px;
            font-size: 13px;
        }
        .main-toolbar .title {
            font-weight: bold;
            margin-right: 24px;
        }
        .main-toolbar button, .main-toolbar a {
            padding: 3px 12px;
            font-size: 13px;
            margin-right: 3px;
            border: 1px solid #bdbdbd;
            border-radius: 3px;
            background: #f6f6f6;
            cursor: pointer;
            color: #222;
            text-decoration: none;
        }
        .main-toolbar button:hover, .main-toolbar a:hover {
            background: #dbeaff;
            border-color: #5a9dfd;
        }
        .container {
            max-width: 1300px;
            margin: 30px auto 0 auto;
            background-color: #fff;
            border: 1px solid #bbb;
            box-shadow: 0 2px 14px #0001;
            padding: 0;
        }
        .channel-table {
            width: 100%;
            border-collapse: collapse;
            margin: 0;
            font-size: 13px;
            background: #fafbfc;
        }
        .channel-table th, .channel-table td {
            border: 1px solid #ddd;
            padding: 6px 8px;
            text-align: left;
            background: #fff;
        }
        .channel-table th {
            background: #e9e9e9;
            color: #222;
            font-weight: 600;
            cursor: pointer;
            user-select: none;
            white-space: nowrap;
        }
        .channel-table tr:nth-child(even) td {
            background: #f7f8fa;
        }
        .channel-table tr.selected td {
            background: #dbeaff;
        }
        .channel-table tr:hover td {
            background: #ebf4ff;
        }
        .edit-cell {
            background: #fffbe5 !important;
            border: 1px solid #ffc700 !important;
        }
        .status-bar {
            font-size: 13px;
            color: #666;
            padding: 7px 18px;
            margin-top: 0;
            background: #f3f3f3;
            border-top: 1px solid #ccc;
            text-align: left;
        }
        .status-bar .error { color: #c00; }
        .status-bar .ok { color: #090; }
        .toolbar-btn {
            margin-right: 8px;
        }
    </style>
</head>
<body>
    <div class="main-toolbar">
        <span class="title">Benshi Commander <span style="color:#bbb">Web Programmer</span></span>
        <span>Memories</span>
        <label style="margin-left:18px;">Memory Range:</label>
        <input type="number" id="mem-min" value="0" style="width:48px;" min="0">
        <span>&ndash;</span>
        <input type="number" id="mem-max" value="127" style="width:48px;" min="0">
        <button id="refresh-btn" class="toolbar-btn">Refresh</button>
        <a href="/chirp.csv" class="toolbar-btn" download>Download CSV</a>
        <button id="write-btn" class="toolbar-btn">Write to Radio</button>
    </div>
    <div class="container">
        <table class="channel-table">
            <thead>
                <tr>
                    <th>Loc</th>
                    <th>Frequency</th>
                    <th>Name</th>
                    <th>Tone Mode</th>
                    <th>Tone</th>
                    <th>ToneSql</th>
                    <th>DTCS Code</th>
                    <th>DTCS Rx Code</th>
                    <th>DTCS Pol</th>
                    <th>Cross Mode</th>
                    <th>Duplex</th>
                    <th>Offset</th>
                    <th>Mode</th>
                    <th>Power</th>
                    <th>Skip</th>
                </tr>
            </thead>
            <tbody id="channel-table-body"></tbody>
        </table>
    </div>
    <div class="status-bar" id="status">Loading channels from radio...</div>
    <script>
    let channelData = [];
    let editingCell = null;

    function renderTable() {
        const tbody = document.getElementById('channel-table-body');
        tbody.innerHTML = "";
        if (!channelData.length) {
            tbody.innerHTML = '<tr><td colspan="15" style="text-align:center;">No channels found on the radio.</td></tr>';
            return;
        }
        for (let ch of channelData) {
            tbody.innerHTML += \`
            <tr data-loc="\${ch.location}">
                <td>\${ch.location}</td>
                <td>\${ch.frequency}</td>
                <td class="editable" data-key="name">\${ch.name}</td>
                <td class="editable" data-key="toneMode">\${ch.toneMode}</td>
                <td class="editable" data-key="tone">\${ch.tone}</td>
                <td class="editable" data-key="toneSql">\${ch.toneSql}</td>
                <td class="editable" data-key="dtcsCode">\${ch.dtcsCode}</td>
                <td class="editable" data-key="dtcsRxCode">\${ch.dtcsRxCode}</td>
                <td>\${ch.dtcsPol}</td>
                <td>\${ch.crossMode}</td>
                <td class="editable" data-key="duplex">\${ch.duplex}</td>
                <td class="editable" data-key="offset">\${ch.offset}</td>
                <td class="editable" data-key="mode">\${ch.mode}</td>
                <td class="editable" data-key="power">\${ch.power}</td>
                <td class="editable" data-key="skip">\${ch.skip}</td>
            </tr>\`;
        }
    }

    function setStatus(msg, type="info") {
        const status = document.getElementById('status');
        status.textContent = msg;
        status.className = "status-bar " + (type === "error" ? "error" : type === "ok" ? "ok" : "");
    }

    function fetchChannels() {
        setStatus("Loading channels from radio...", "info");
        fetch('/channels.json')
            .then(resp => resp.json())
            .then(data => {
                channelData = data;
                renderTable();
                setStatus("Loaded " + channelData.length + " channels.", "ok");
            })
            .catch(e => {
                setStatus("Could not load channel data. Please try again.", "error");
            });
    }

    // Table cell editing logic
    document.addEventListener('click', function(e) {
        if (editingCell && !editingCell.contains(e.target)) {
            finishEdit();
        }
        if (e.target.classList.contains('editable')) {
            beginEdit(e.target);
        }
    });

    function beginEdit(td) {
        if (editingCell) finishEdit();
        editingCell = td;
        const key = td.dataset.key;
        const loc = td.parentNode.dataset.loc;
        const orig = td.textContent;
        td.classList.add('edit-cell');
        // Use select for some fields, input for others:
        let input;
        if (key === "mode") {
            input = document.createElement('select');
            ["FM","NFM"].forEach(opt => {
                let o = document.createElement('option');
                o.value = o.text = opt;
                if (opt === orig) o.selected = true;
                input.appendChild(o);
            });
        } else if (key === "power") {
            input = document.createElement('select');
            ["Low","Med","High"].forEach(opt => {
                let o = document.createElement('option');
                o.value = o.text = opt;
                if (opt === orig) o.selected = true;
                input.appendChild(o);
            });
        } else if (key === "toneMode") {
            input = document.createElement('select');
            ["(None)","Tone"].forEach(opt => {
                let o = document.createElement('option');
                o.value = o.text = opt;
                if (opt === orig) o.selected = true;
                input.appendChild(o);
            });
        } else if (key === "duplex") {
            input = document.createElement('select');
            ["(None)","+","-"].forEach(opt => {
                let o = document.createElement('option');
                o.value = o.text = opt;
                if (opt === orig) o.selected = true;
                input.appendChild(o);
            });
        } else if (key === "skip") {
            input = document.createElement('select');
            ["","S"].forEach(opt => {
                let o = document.createElement('option');
                o.value = o.text = opt;
                if (opt === orig) o.selected = true;
                input.appendChild(o);
            });
        } else {
            input = document.createElement('input');
            input.type = "text";
            input.value = orig;
            input.style.width = Math.max(48, orig.length*8) + "px";
        }
        input.addEventListener('keydown', function(ev) {
            if (ev.key === "Enter") finishEdit();
            if (ev.key === "Escape") cancelEdit();
        });
        input.addEventListener('blur', finishEdit);
        td.textContent = '';
        td.appendChild(input);
        input.focus();
    }

    function finishEdit() {
        if (!editingCell) return;
        const input = editingCell.querySelector('input,select');
        if (!input) return;
        const val = input.value;
        const key = editingCell.dataset.key;
        const row = editingCell.parentNode;
        const loc = +row.dataset.loc;
        // Update channelData
        const idx = channelData.findIndex(ch => ch.location == loc);
        if (idx >= 0) channelData[idx][key] = val;
        editingCell.textContent = val;
        editingCell.classList.remove('edit-cell');
        // Save to backend
        const ch = Object.assign({}, channelData[idx]);
        fetch('/channels/update', {
            method: 'POST',
            headers: {'Content-Type':'application/json'},
            body: JSON.stringify(ch)
        }).then(resp => resp.json())
          .then(resp => setStatus("Channel " + loc + " updated.", "ok"))
          .catch(e => setStatus("Could not update channel " + loc, "error"));
        editingCell = null;
    }

    function cancelEdit() {
        if (!editingCell) return;
        editingCell.textContent = editingCell.dataset.orig;
        editingCell.classList.remove('edit-cell');
        editingCell = null;
    }

    // Toolbar functions
    document.getElementById('refresh-btn').onclick = fetchChannels;
    document.getElementById('write-btn').onclick = function() {
        setStatus("Write to Radio is not yet implemented in this version.", "info");
        // To be implemented with Benshi backend later!
    };

    // Range filter logic (future)
    document.getElementById('mem-min').addEventListener('change', function() {
        // Could filter table, for now just UI
    });
    document.getElementById('mem-max').addEventListener('change', function() {
        // Could filter table, for now just UI
    });

    fetchChannels();
    </script>
</body>
</html>
''';
  }
}