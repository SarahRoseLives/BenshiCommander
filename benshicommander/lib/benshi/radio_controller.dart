import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'protocol/protocol.dart';

class RadioController extends ChangeNotifier {
  final BluetoothConnection? connection;
  final StreamController<Message> _messageStreamController = StreamController<Message>.broadcast();
  StreamSubscription? _btStreamSubscription;
  Uint8List _rxBuffer = Uint8List(0);

  // --- State Properties ---
  DeviceInfo? deviceInfo;
  StatusExt? status;
  Settings? settings;
  Position? gps;
  Channel? currentChannel;
  double? batteryVoltage;
  int? batteryLevelAsPercentage;

  // --- UI Getters with safe defaults ---
  bool get isReady => deviceInfo != null && status != null && settings != null;
  bool get isPowerOn => status?.isPowerOn ?? true;
  bool get isInTx => status?.isInTx ?? false;
  bool get isInRx => status?.isInRx ?? false;
  double get rssi => status?.rssi ?? 0.0;
  bool get isSq => status?.isSq ?? false;
  bool get isScan => status?.isScan ?? false;
  int get currentChannelId => status?.currentChannelId ?? 0;
  String get currentChannelName => currentChannel?.name ?? 'Loading...';
  double get currentRxFreq => currentChannel?.rxFreq ?? 0.0;
  bool get isGpsLocked => status?.isGpsLocked ?? false;
  bool get supportsVfo => deviceInfo?.supportsVfo ?? false;

  RadioController({this.connection}) {
    if (connection != null) {
      _btStreamSubscription = connection!.input!.listen(_onDataReceived);
      _initializeRadioState();
    }
  }

  void _onDataReceived(Uint8List data) {
    if (kDebugMode) {
      print("RAW RX: $data");
    }
    _rxBuffer = Uint8List.fromList([..._rxBuffer, ...data]);
    while (true) {
      final result = _parseGaiaFrameFromBuffer();
      if (result == null) break;

      _rxBuffer = result.remainingBuffer;
      try {
        final message = Message.fromBytes(result.frame.messageBytes);

        if (message.command == BasicCommand.EVENT_NOTIFICATION && message.body is EventNotificationBody) {
          _handleEvent(message.body as EventNotificationBody);
        } else {
          _messageStreamController.add(message);
        }

      } catch (e, s) {
        if (kDebugMode) {
          print('Error parsing message: $e');
          print('Stack trace: $s');
        }
      }
    }
  }

  void _handleEvent(EventNotificationBody eventBody) {
    bool dataChanged = false;
    switch (eventBody.eventType) {
      case EventType.HT_STATUS_CHANGED:
        final statusReply = eventBody.event as GetHtStatusReplyBody;
        if (statusReply.status != null) {
          final oldChannelId = status?.currentChannelId ?? -1;
          status = statusReply.status;
          if (status!.currentChannelId != oldChannelId) {
             getChannel(status!.currentChannelId);
          }
          dataChanged = true;
        }
        break;
      case EventType.HT_SETTINGS_CHANGED:
        final settingsReply = eventBody.event as ReadSettingsReplyBody;
        if (settingsReply.settings != null) {
           settings = settingsReply.settings;
           dataChanged = true;
        }
        break;
      case EventType.HT_CH_CHANGED:
        final channelReply = eventBody.event as ReadRFChReplyBody;
        if (channelReply.rfCh != null) {
           currentChannel = channelReply.rfCh;
           dataChanged = true;
        }
        break;
      default:
        if (kDebugMode) print("Unhandled Event: ${eventBody.eventType}");
    }
    if (dataChanged) {
      notifyListeners();
    }
  }

  Future<void> _initializeRadioState() async {
    try {
      await _registerForEvents();

      final results = await Future.wait([
        getDeviceInfo(),
        getStatus(),
        getSettings(),
        getBatteryPercentage(),
        getBatteryVoltage(),
        getPosition(),
      ]);

      deviceInfo = results[0] as DeviceInfo;
      status = results[1] as StatusExt;
      settings = results[2] as Settings;
      batteryLevelAsPercentage = (results[3] as num).toInt();
      batteryVoltage = (results[4] as num).toDouble();
      gps = results[5] as Position?;

      if (status != null) {
        currentChannel = await getChannel(status!.currentChannelId);
      }
    } catch (e) {
      if (kDebugMode) print('Error initializing radio state: $e');
    } finally {
      notifyListeners();
    }
  }

  GaiaParseResult? _parseGaiaFrameFromBuffer() {
    int frameStart = _rxBuffer.indexOf(GaiaFrame.startByte);
    if (frameStart == -1) {
       _rxBuffer = Uint8List(0);
       return null;
    }
    if (frameStart > 0) _rxBuffer = _rxBuffer.sublist(frameStart);
    if (_rxBuffer.length < 4) return null;
    if (_rxBuffer[1] != GaiaFrame.version) {
       _rxBuffer = _rxBuffer.sublist(1);
       return _parseGaiaFrameFromBuffer();
    }
    final messagePayloadLength = _rxBuffer[3];
    final fullMessageLength = messagePayloadLength + 4;
    final fullFrameLength = 4 + fullMessageLength;
    if (_rxBuffer.length < fullFrameLength) return null;

    final messageBytes = _rxBuffer.sublist(4, fullFrameLength);
    final frame = GaiaFrame(flags: _rxBuffer[2], messageBytes: messageBytes);
    final remainingBuffer = _rxBuffer.sublist(fullFrameLength);

    return GaiaParseResult(frame, remainingBuffer);
  }

  Future<void> _sendCommand(Message command) async {
    final messageBytes = command.toBytes();
    final gaiaFrame = GaiaFrame(messageBytes: messageBytes);
    final bytes = gaiaFrame.toBytes();
    if (kDebugMode) {
      print("RAW TX: $bytes");
    }
    connection?.output.add(bytes);
    await connection?.output.allSent;
  }

  // UPDATED to be more generic and reliable
  Future<T> _sendCommandExpectReply<T extends ReplyBody>({
    required Message command,
    required BasicCommand replyCommand,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final completer = Completer<T>();
    late StreamSubscription streamSub;

    streamSub = _messageStreamController.stream.listen((message) {
      if (message.command == replyCommand && message.isReply) {
        if (!completer.isCompleted) {
          final body = message.body as T;
          if (body.replyStatus != ReplyStatus.SUCCESS) {
            completer.completeError(Exception("Command failed with status: ${body.replyStatus}"));
          } else {
            completer.complete(body);
          }
          streamSub.cancel();
        }
      }
    });

    await _sendCommand(command);

    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Radio did not reply in time for ${command.command}.'));
        streamSub.cancel();
      }
    });

    return completer.future;
  }


  Future<void> _registerForEvents() async {
    final eventsToRegister = [EventType.HT_STATUS_CHANGED, EventType.HT_SETTINGS_CHANGED, EventType.HT_CH_CHANGED];
    for (var eventType in eventsToRegister) {
       final command = Message(
         commandGroup: CommandGroup.BASIC,
         command: BasicCommand.REGISTER_NOTIFICATION,
         isReply: false,
         body: RegisterNotificationBody(eventType: eventType)
       );
       await _sendCommand(command);
       await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Get the VFO channel (usually channelId 0)
  Future<Channel> getVfoChannel() async {
    // Most Benshi radios use channelId=0 for VFO.
    const vfoChannelId = 0;
    return await getChannel(vfoChannelId);
  }

  /// Set VFO frequency by always operating on VFO channel (channelId 0)
  Future<void> setVfoFrequency(double frequency) async {
    const vfoChannelId = 0;
    final vfoChannel = await getChannel(vfoChannelId);

    final newChannel = vfoChannel.copyWith(
      rxFreq: frequency,
      txFreq: frequency,
    );

    await writeChannel(newChannel);
    currentChannel = newChannel;
    notifyListeners();
  }

  // NEW: Writes a single channel's configuration to the radio.
  Future<void> writeChannel(Channel channel) async {
      final reply = await _sendCommandExpectReply<WriteRFChReplyBody>(
          command: Message(
              commandGroup: CommandGroup.BASIC,
              command: BasicCommand.WRITE_RF_CH,
              isReply: false,
              body: WriteRFChBody(rfCh: channel)
          ),
          replyCommand: BasicCommand.WRITE_RF_CH,
          timeout: const Duration(seconds: 3), // Writing can take a moment
      );
      // Error handling is now done in _sendCommandExpectReply
      if (kDebugMode) {
        print('Successfully wrote channel ${reply.channelId}');
      }
  }

  Future<DeviceInfo> getDeviceInfo() async {
    final reply = await _sendCommandExpectReply<GetDevInfoReplyBody>(
      command: Message(commandGroup: CommandGroup.BASIC, command: BasicCommand.GET_DEV_INFO, isReply: false, body: GetDevInfoBody()),
      replyCommand: BasicCommand.GET_DEV_INFO,
    );
    if (reply.devInfo == null) throw Exception('Failed to get device info.');
    deviceInfo = reply.devInfo;
    notifyListeners();
    return reply.devInfo!;
  }

  Future<Settings> getSettings() async {
    final reply = await _sendCommandExpectReply<ReadSettingsReplyBody>(
      command: Message(commandGroup: CommandGroup.BASIC, command: BasicCommand.READ_SETTINGS, isReply: false, body: ReadSettingsBody()),
      replyCommand: BasicCommand.READ_SETTINGS,
    );
    if (reply.settings == null) throw Exception('Failed to get settings.');
    settings = reply.settings;
    notifyListeners();
    return reply.settings!;
  }

  Future<StatusExt> getStatus() async {
    final reply = await _sendCommandExpectReply<GetHtStatusReplyBody>(
      command: Message(commandGroup: CommandGroup.BASIC, command: BasicCommand.GET_HT_STATUS, isReply: false, body: GetHtStatusBody()),
      replyCommand: BasicCommand.GET_HT_STATUS,
    );
    if (reply.status == null) throw Exception('Failed to get status');
    status = reply.status;
    notifyListeners();
    return reply.status!;
  }

  Future<num> getBatteryVoltage() async {
    final reply = await _sendCommandExpectReply<ReadPowerStatusReplyBody>(
      command: Message(commandGroup: CommandGroup.BASIC, command: BasicCommand.READ_STATUS, isReply: false, body: ReadPowerStatusBody(statusType: PowerStatusType.BATTERY_VOLTAGE)),
      replyCommand: BasicCommand.READ_STATUS,
    );
    if (reply.value == null) throw Exception('Failed to get battery voltage.');
    batteryVoltage = reply.value?.toDouble();
    notifyListeners();
    return reply.value!;
  }

  Future<num> getBatteryPercentage() async {
    final reply = await _sendCommandExpectReply<ReadPowerStatusReplyBody>(
      command: Message(commandGroup: CommandGroup.BASIC, command: BasicCommand.READ_STATUS, isReply: false, body: ReadPowerStatusBody(statusType: PowerStatusType.BATTERY_LEVEL_AS_PERCENTAGE)),
      replyCommand: BasicCommand.READ_STATUS,
    );
    if (reply.value == null) throw Exception('Failed to get battery percentage.');
    batteryLevelAsPercentage = reply.value as int;
    notifyListeners();
    return reply.value!;
  }

  Future<Position?> getPosition() async {
    try {
      final reply = await _sendCommandExpectReply<GetPositionReplyBody>(
        command: Message(commandGroup: CommandGroup.BASIC, command: BasicCommand.GET_POSITION, isReply: false, body: GetPositionBody()),
        replyCommand: BasicCommand.GET_POSITION,
      );
      gps = reply.position;
      notifyListeners();
      return reply.position;
    } catch(e) {
      if (kDebugMode) print("Could not get position: $e");
      return null;
    }
  }

  Future<Channel> getChannel(int channelId) async {
    final reply = await _sendCommandExpectReply<ReadRFChReplyBody>(
      command: Message(commandGroup: CommandGroup.BASIC, command: BasicCommand.READ_RF_CH, isReply: false, body: ReadRFChBody(channelId: channelId)),
      replyCommand: BasicCommand.READ_RF_CH,
    );
    if (reply.rfCh == null) throw Exception('Failed to get channel $channelId.');
    if (status?.currentChannelId == channelId) {
       currentChannel = reply.rfCh;
       notifyListeners();
    }
    return reply.rfCh!;
  }

  Future<List<Channel>> getAllChannels() async {
    if (deviceInfo == null) await getDeviceInfo();
    if (deviceInfo == null) return [];

    final channels = <Channel>[];
    for (int i = 0; i < (deviceInfo?.channelCount ?? 0); i++) {
      try {
        final channel = await getChannel(i);
        channels.add(channel);
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        if (kDebugMode) print('Failed to get channel $i: $e');
      }
    }
    return channels;
  }

  /// Scan API: sets VFO frequency in a loop for scanning
  Future<void> scanFrequencies(List<double> frequencies, {Duration dwell = const Duration(milliseconds: 250), bool stopOnCarrier = false}) async {
    for (final freq in frequencies) {
      if (stopOnCarrier && (isInRx || isInTx)) {
        break;
      }
      await setVfoFrequency(freq);
      await Future.delayed(dwell);
      // Force status update so that isInRx/isInTx is fresh for stopOnCarrier
      await getStatus();
    }
  }

  /// Enables or disables the radio's built-in memory channel scanning by writing to the main Settings block.
  Future<void> setRadioScan(bool enable) async {
    // 1. Ensure we have the latest settings from the radio.
    if (settings == null) await getSettings();
    if (settings == null) throw Exception("Could not load radio settings to modify them.");

    // 2. Create a new settings object with the desired scan state.
    final newSettings = settings!.copyWith(scan: enable);

    // 3. Build and send the WRITE_SETTINGS command.
    final reply = await _sendCommandExpectReply<WriteSettingsReplyBody>(
      command: Message(
        commandGroup: CommandGroup.BASIC,
        command: BasicCommand.WRITE_SETTINGS,
        isReply: false,
        body: WriteSettingsBody(settings: newSettings),
      ),
      replyCommand: BasicCommand.WRITE_SETTINGS,
    );

    // 4. On success, update the local state and refresh radio status.
    if (reply.replyStatus == ReplyStatus.SUCCESS) {
      if (kDebugMode) {
        print("Successfully sent WRITE_SETTINGS with scan: $enable");
      }
      settings = newSettings; // Update local copy of settings
      await getStatus(); // Refresh status to get the radio's `isScan` state
      notifyListeners(); // Notify UI to rebuild
    } else {
      throw Exception("Failed to set scan mode via WRITE_SETTINGS.");
    }
  }

  @override
  void dispose() {
    _btStreamSubscription?.cancel();
    _messageStreamController.close();
    super.dispose();
  }
}