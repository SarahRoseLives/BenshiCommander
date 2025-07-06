import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'protocol.dart';

class RadioController {
  final BluetoothConnection connection;
  final StreamController<Message> _messageStreamController = StreamController<Message>.broadcast();
  late StreamSubscription _btStreamSubscription;
  Uint8List _rxBuffer = Uint8List(0); // Buffer for incoming data

  RadioController({required this.connection}) {
    _btStreamSubscription = connection.input!.listen((Uint8List data) {
      _rxBuffer = Uint8List.fromList([..._rxBuffer, ...data]); // Append new data to buffer

      while (true) {
        // Try to parse a frame from the buffer
        final result = _parseGaiaFrameFromBuffer();
        if (result == null) {
          break; // Not enough data for a full frame, wait for more
        }

        // A frame was successfully parsed, update the buffer with the remainder
        _rxBuffer = result.remainingBuffer;
        final frame = result.frame;

        if (kDebugMode) {
          print('Radio RX (raw Gaia payload): ${frame.messageBytes.map((c) => c.toRadixString(16).padLeft(2, '0')).join(' ')}');
        }

        try {
          // Parse the message from the frame's payload
          final message = Message.fromBytes(frame.messageBytes);
          if (kDebugMode) {
            print('Radio RX (parsed): '
                'cmdGroup=${message.commandGroup}, '
                'isReply=${message.isReply}, '
                'command=${message.command}, '
                'body=${message.body}');
          }
          _messageStreamController.add(message);
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing message from Gaia frame: $e');
          }
        }
      }
    });
  }

  /// Parses a single GaiaFrame from the _rxBuffer.
  /// Returns a result object if successful, otherwise null.
  GaiaParseResult? _parseGaiaFrameFromBuffer() {
    // Find the start of a potential frame
    int frameStart = _rxBuffer.indexOf(GaiaFrame.startByte);
    if (frameStart == -1) {
      // No start byte, can't proceed. Clear buffer to avoid infinite loops on garbage data.
      _rxBuffer = Uint8List(0);
      return null;
    }

    // Discard any data before the start byte
    if (frameStart > 0) {
      _rxBuffer = _rxBuffer.sublist(frameStart);
    }

    // A GAIA frame needs at least 4 bytes for its header
    if (_rxBuffer.length < 4) {
      return null; // Not enough data for header
    }

    // Check version byte
    if (_rxBuffer[1] != GaiaFrame.version) {
       // Invalid version, discard the start byte and try again
      _rxBuffer = _rxBuffer.sublist(1);
      return null;
    }

    // The length of the inner message's payload (not including its 4-byte header)
    final messagePayloadLength = _rxBuffer[3];
    // The length of the full inner message (header + payload)
    final fullMessageLength = messagePayloadLength + 4;
    // The length of the entire GAIA frame (GAIA header + full message)
    final fullFrameLength = fullMessageLength + 4;

    if (_rxBuffer.length < fullFrameLength) {
      return null; // Not enough data for the full frame
    }

    final messageBytes = _rxBuffer.sublist(4, fullFrameLength);
    final frame = GaiaFrame(flags: _rxBuffer[2], messageBytes: messageBytes);
    final remainingBuffer = _rxBuffer.sublist(fullFrameLength);

    return GaiaParseResult(frame, remainingBuffer);
  }

  // MODIFIED: This function now wraps the command in a GaiaFrame.
  Future<void> _sendCommand(Message command) async {
    final messageBytes = command.toBytes();
    final gaiaFrame = GaiaFrame(messageBytes: messageBytes);
    final bytes = gaiaFrame.toBytes();

    // Debug log to see all outgoing data
    if (kDebugMode) {
      print('Radio TX (raw): ${bytes.map((c) => c.toRadixString(16).padLeft(2, '0')).join(' ')}');
      print('Radio TX (parsed): '
          'cmdGroup=${command.commandGroup}, '
          'isReply=${command.isReply}, '
          'command=${command.command}, '
          'body=${command.body}');
    }
    connection.output.add(bytes);
    await connection.output.allSent;
  }

  // --- The rest of your RadioController class is unchanged ---
  // _sendCommandExpectReply, getDeviceInfo, getChannel, getAllChannels, dispose
  Future<T> _sendCommandExpectReply<T extends MessageBody>({
    required Message command,
    required BasicCommand replyCommand,
    // Increased timeout for more reliability
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final completer = Completer<T>();

    late StreamSubscription streamSub;
    streamSub = _messageStreamController.stream.listen((message) {
      if (message.command == replyCommand && message.isReply) {
        if (!completer.isCompleted) {
          completer.complete(message.body as T);
          streamSub.cancel();
        }
      }
    });

    await _sendCommand(command);

    // Timeout logic
    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Radio did not reply in time for command ${command.command.name}.'));
        streamSub.cancel();
      }
    });

    return completer.future;
  }

  Future<DeviceInfo> getDeviceInfo() async {
    final command = Message(
      commandGroup: CommandGroup.BASIC,
      command: BasicCommand.GET_DEV_INFO,
      isReply: false,
      body: GetDevInfoBody(),
    );

    final reply = await _sendCommandExpectReply<GetDevInfoReplyBody>(
      command: command,
      replyCommand: BasicCommand.GET_DEV_INFO,
    );

    if (reply.devInfo == null) {
      throw Exception('Failed to get device info.');
    }
    return reply.devInfo!;
  }

  Future<Channel> getChannel(int channelId) async {
    final command = Message(
      commandGroup: CommandGroup.BASIC,
      command: BasicCommand.READ_RF_CH,
      isReply: false,
      body: ReadRFChBody(channelId: channelId),
    );

    final reply = await _sendCommandExpectReply<ReadRFChReplyBody>(
      command: command,
      replyCommand: BasicCommand.READ_RF_CH,
    );

    if (reply.rfCh == null) {
      throw Exception('Failed to get channel $channelId.');
    }
    return reply.rfCh!;
  }

  Future<List<Channel>> getAllChannels() async {
    final deviceInfo = await getDeviceInfo();
    final channels = <Channel>[];
    for (int i = 0; i < deviceInfo.channelCount; i++) {
      try {
        final channel = await getChannel(i);
        channels.add(channel);
        // Small delay between requests to not overwhelm the radio
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        if (kDebugMode) {
          print('Failed to get channel $i: $e');
        }
      }
    }
    return channels;
  }

  void dispose() {
    _btStreamSubscription.cancel();
    _messageStreamController.close();
  }
}