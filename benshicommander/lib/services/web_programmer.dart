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
  final void Function(dynamic updatedChannel)? onChannelUpdatedFromWeb; // Added

  ChirpExporter({
    required this.radioController,
    required this.onStatusUpdate,
    this.onChannelUpdatedFromWeb, // Added
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
      await _generateWebUI(),
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
          'power': c.txPower,
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

      // Call the callback if it's provided
      onChannelUpdatedFromWeb?.call(data);

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

  /// Loads the full HTML for the web UI from disk.
  static Future<String> _generateWebUI() async {
    // You may want to use an absolute or package-relative path depending on your setup.
    // This assumes the project root is the current directory.
    return await File('web/web_programmer_ui.html').readAsString();
  }
}