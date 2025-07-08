import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../benshi/protocol/protocol.dart';

class MemoryBackup {
  final String name;
  final DateTime? date;
  final List<Channel> channels;
  final bool isAsset;
  MemoryBackup({required this.name, required this.channels, this.date, this.isAsset = false});
  String get dateString => date != null ? date!.toLocal().toIso8601String().substring(0, 16).replaceFirst('T', ' ') : '';
}

class MemoryStorageService {
  // Use "backups" sub-dir in app's docs dir
  Future<Directory> _backupDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/backups');
    if (!await backupDir.exists()) await backupDir.create(recursive: true);
    return backupDir;
  }

  // List user backups
  Future<List<MemoryBackup>> listBackups() async {
    final dir = await _backupDir();
    final files = (await dir.list().toList())
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return Future.wait(files.map((f) async {
      final name = f.uri.pathSegments.last.replaceAll('.json', '');
      final data = await f.readAsString();
      final json = jsonDecode(data) as Map<String, dynamic>;
      final channels = (json['channels'] as List)
          .map<Channel>((c) => Channel.fromJson(c as Map<String, dynamic>))
          .toList();
      final date = DateTime.tryParse(json['date'] ?? '') ?? (await f.lastModified());
      return MemoryBackup(name: name, date: date, channels: channels);
    }));
  }

  // Save a backup
  Future<void> saveBackup(String name, List<Channel> channels) async {
    final dir = await _backupDir();
    final file = File('${dir.path}/$name.json');
    final now = DateTime.now();
    await file.writeAsString(jsonEncode({
      'name': name,
      'date': now.toIso8601String(),
      'channels': channels.map((c) => c.toJson()).toList(),
    }));
  }

  // Delete a backup
  Future<void> deleteBackup(MemoryBackup backup) async {
    final dir = await _backupDir();
    final file = File('${dir.path}/${backup.name}.json');
    if (await file.exists()) await file.delete();
  }

  // List preloaded asset lists: load all JSON files in assets/memorylists/
  Future<List<MemoryBackup>> listPreloadAssets() async {
    // List asset files: you must declare the directory in pubspec.yaml
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = jsonDecode(manifestContent);

    // Only include assets in assets/memorylists/ and ending with .json
    final assetPaths = manifestMap.keys
        .where((String key) => key.startsWith('assets/memorylists/') && key.endsWith('.json'))
        .toList();

    final List<MemoryBackup> assetBackups = [];
    for (final path in assetPaths) {
      final data = await rootBundle.loadString(path);
      final json = jsonDecode(data) as Map<String, dynamic>;
      final channels = (json['channels'] as List)
          .map<Channel>((c) => Channel.fromJson(c as Map<String, dynamic>))
          .toList();
      final name = json['name'] ?? path.split('/').last.replaceAll('.json', '');
      final date = DateTime.tryParse(json['date'] ?? '');
      assetBackups.add(MemoryBackup(name: name, date: date, channels: channels, isAsset: true));
    }
    return assetBackups;
  }
}