// lib/services/chirp_exporter.dart

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../benshi/radio_controller.dart';
import '../benshi/protocol.dart';

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

      // Route for the main page
      router.get('/', (Request request) {
        return Response.ok(
          _htmlContent,
          headers: {'Content-Type': 'text/html'},
        );
      });

      // Route to trigger the export and download the CSV
      router.get('/chirp.csv', _handleChirpRequest);

      final handler = const Pipeline().addHandler(router);
      _server = await shelf_io.serve(handler, ip, 8080);
      serverUrl = 'http://${_server!.address.host}:${_server!.port}';
      onStatusUpdate('Server running at $serverUrl');
    } catch (e) {
      onStatusUpdate('Error starting server: $e');
      await stop();
    }
  }

  Future<Response> _handleChirpRequest(Request request) async {
    try {
      onStatusUpdate('Exporting Channel Map to Chirp Format...');

      List<Channel> channels = await radioController.getAllChannels();

      // Define CSV headers
      List<String> header = [
        'Location', 'Name', 'Frequency', 'Duplex', 'Offset',
        'Tone', 'rToneFreq', 'cToneFreq', 'DtcsCode', 'DtcsPolarity',
        'Mode', 'ScanSkip'
      ];

      List<List<String>> rows = [header];
      rows.addAll(channels.map((c) => c.toChirpRow()));

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

  static const String _htmlContent = '''
  <!DOCTYPE html>
  <html>
  <head>
    <title>Chirp Export</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      body { font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #f0f0f0; margin: 0;}
      .container { text-align: center; padding: 20px; }
      h1 { color: #333; }
      .button { background-color: #007bff; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; font-size: 18px; transition: background-color 0.3s; }
      .button:hover { background-color: #0056b3; }
    </style>
  </head>
  <body>
    <div class="container">
      <h1>Radio Programmer</h1>
      <p>Click the button below to download the channel list in CHIRP format.</p>
      <br>
      <a href="/chirp.csv" class="button">Export Channel Map to Chirp Format</a>
    </div>
  </body>
  </html>
  ''';
}