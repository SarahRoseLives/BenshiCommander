// benshi/audio_controller.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

// --- CORRECTED IMPORTS ---
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import 'protocol/audio_protocol.dart';

class AudioController {
  final String deviceAddress;
  final int rfcommChannel;
  BluetoothConnection? _audioConnection;
  StreamSubscription? _audioStreamSubscription;
  Uint8List _audioBuffer = Uint8List(0);

  final AudioPlayer _audioPlayer = AudioPlayer();
  final StreamController<Uint8List> _pcmStreamController = StreamController.broadcast();

  AudioController({required this.deviceAddress, required this.rfcommChannel});

  bool get isMonitoring => _audioConnection?.isConnected ?? false;

  Future<void> startMonitoring() async {
    if (isMonitoring) return;
    try {
      _audioConnection = await BluetoothConnection.toAddress(deviceAddress);

      await _audioPlayer.setAudioSource(
        InputStreamAudioSource(stream: _pcmStreamController.stream)
      );
      _audioPlayer.play();

      _audioStreamSubscription = _audioConnection!.input!.listen(
        _onAudioData,
        onDone: stopMonitoring,
        onError: (e) {
          if (kDebugMode) print('Audio stream error: $e');
          stopMonitoring();
        },
      );
    } catch (e) {
      if (kDebugMode) print('Error starting audio monitor: $e');
      await stopMonitoring();
    }
  }

  Future<void> stopMonitoring() async {
    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    await _audioConnection?.close();
    _audioConnection = null;
    await _audioPlayer.stop();
    _audioBuffer = Uint8List(0);
  }

  void _onAudioData(Uint8List data) {
    _audioBuffer = Uint8List.fromList([..._audioBuffer, ...data]);

    while (_audioBuffer.isNotEmpty) {
      final result = parseAudioFrame(_audioBuffer);
      if (result.message == null) {
        break;
      }
      final message = result.message!;
      if (message is AudioData) {
        // Use the corrected method here
        _decodeAndPlayWithFiles(message.sbcData);
      }
      _audioBuffer = result.remainingBuffer;
    }
  }

  // --- CORRECTED METHOD using temporary files ---
  // This is simple and works, but has higher latency.
  void _decodeAndPlayWithFiles(Uint8List sbcData) async {
    if (sbcData.isEmpty) return;

    final tempDir = await getTemporaryDirectory();
    final sbcFile = File('${tempDir.path}/input.sbc');
    final pcmFile = File('${tempDir.path}/output.pcm');

    try {
      await sbcFile.writeAsBytes(sbcData, flush: true);

      // FFmpegKit will decode the SBC into raw PCM.
      // The -y flag overwrites the output file if it exists.
      final session = await FFmpegKit.execute(
        '-y -f sbc -i ${sbcFile.path} -f s16le -c:a pcm_s16le -ar 32000 -ac 1 ${pcmFile.path}'
      );

      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        if (await pcmFile.exists()) {
          final pcmBytes = await pcmFile.readAsBytes();
          if (pcmBytes.isNotEmpty) {
            _pcmStreamController.add(pcmBytes);
          }
        }
      } else {
        if (kDebugMode) {
          print("FFmpeg process failed with code $returnCode.");
          final logs = await session.getLogsAsString();
          print("FFmpeg logs: $logs");
        }
      }
    } catch (e) {
      if (kDebugMode) print("Error during file-based decoding: $e");
    } finally {
      // Clean up temp files
      if (await sbcFile.exists()) await sbcFile.delete();
      if (await pcmFile.exists()) await pcmFile.delete();
    }
  }

  void dispose() {
    stopMonitoring();
    _pcmStreamController.close();
    _audioPlayer.dispose();
  }
}

// Custom AudioSource for just_audio to handle a raw PCM stream.
class InputStreamAudioSource extends StreamAudioSource {
    final Stream<Uint8List> stream;
    InputStreamAudioSource({required this.stream});

    @override
    Future<StreamAudioResponse> request([int? start, int? end]) async {
        start ??= 0;
        end ??= -1;

        return StreamAudioResponse(
            sourceLength: null, // Length is unknown
            contentLength: null,
            offset: start,
            stream: stream,
            contentType: 'audio/pcm;rate=32000;encoding=signed-integer;bits=16;channels=1',
        );
    }
}