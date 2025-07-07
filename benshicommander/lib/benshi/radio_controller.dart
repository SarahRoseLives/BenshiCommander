import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'protocol/protocol.dart';

// --- State Holder Classes ---
class RadioStatus {
  bool isPowerOn = true; // Assume ON if connected
  bool isInTx = false;
  bool isInRx = false;
  double rssi = 0;
  bool isSq = false;
  bool isScan = false;
  String doubleChannel = "OFF";
  int currChId = 0;
  bool isGpsLocked = false;
  bool isHfpConnected = false;

  void updateFrom(StatusExt status) {
    isPowerOn = status.isPowerOn;
    isInTx = status.isInTx;
    isInRx = status.isInRx;
    rssi = status.rssi;
    isSq = status.isSq;
    isScan = status.isScan;
    doubleChannel = status.doubleChannel.name;
    currChId = status.currChId;
    isGpsLocked = status.isGpsLocked;
    isHfpConnected = status.isHfpConnected;
  }
}

class RadioChannelInfo {
  String name = "Loading...";
  double rxFreq = 0.0;
  double txFreq = 0.0;
  String bandwidth = "WIDE";
  String txPower = "Low";
  String rxTone = "None";
  String txTone = "None";

  void updateFrom(Channel channel) {
    name = channel.name;
    rxFreq = channel.rxFreq;
    txFreq = channel.txFreq;
    bandwidth = channel.bandwidth;
    txPower = channel.txPower;
    rxTone = channel.rxTone;
    txTone = channel.txTone;
  }
}

class RadioGpsData {
  double latitude = 0.0;
  double longitude = 0.0;
  int speed = 0;
  int heading = 0;
  int altitude = 0;
  int accuracy = 0;
  DateTime time = DateTime.now().toUtc();

  void updateFrom(Position position) {
    latitude = position.latitude;
    longitude = position.longitude;
    speed = position.speed ?? 0;
    heading = position.heading ?? 0;
    altitude = position.altitude ?? 0;
    accuracy = position.accuracy;
    time = position.time;
  }
}

class RadioDeviceInfo {
  String vendorId = "Unknown";
  String productId = "Unknown";
  String hardwareVersion = "N/A";
  String firmwareVersion = "N/A";
  int channelCount = 0;

  void updateFrom(DeviceInfo info) {
    vendorId = info.vendorId;
    productId = info.productId;
    hardwareVersion = info.hwVer;
    firmwareVersion = info.softVer;
    channelCount = info.channelCount;
  }
}

class RadioController extends ChangeNotifier {
  final BluetoothConnection? connection;
  final StreamController<Message> _messageStreamController = StreamController<Message>.broadcast();
  StreamSubscription? _btStreamSubscription;
  Uint8List _rxBuffer = Uint8List(0);

  // State objects
  final RadioStatus status = RadioStatus();
  final RadioChannelInfo channelInfo = RadioChannelInfo();
  final RadioGpsData gps = RadioGpsData();
  final RadioDeviceInfo deviceInfo = RadioDeviceInfo();
  double batteryVoltage = 0.0;
  int batteryLevelAsPercentage = 0;

  // UI Getters
  bool get isPowerOn => status.isPowerOn;
  bool get isInTx => status.isInTx;
  bool get isInRx => status.isInRx;
  double get rssi => status.rssi;
  bool get isSq => status.isSq;
  bool get isScan => status.isScan;
  String get doubleChannel => status.doubleChannel;
  int get currChId => status.currChId;
  bool get isGpsLocked => status.isGpsLocked;
  bool get isHfpConnected => status.isHfpConnected;
  String get name => channelInfo.name;
  double get rxFreq => channelInfo.rxFreq;
  double get txFreq => channelInfo.txFreq;
  String get bandwidth => channelInfo.bandwidth;
  String get txPower => channelInfo.txPower;
  String get rxTone => channelInfo.rxTone;
  String get txTone => channelInfo.txTone;
  double get latitude => gps.latitude;
  double get longitude => gps.longitude;
  int get speed => gps.speed;
  int get heading => gps.heading;
  int get altitude => gps.altitude;
  int get accuracy => gps.accuracy;
  DateTime get time => gps.time;
  String get vendorId => deviceInfo.vendorId;
  String get productId => deviceInfo.productId;
  String get hardwareVersion => deviceInfo.hardwareVersion;
  String get firmwareVersion => deviceInfo.firmwareVersion;

  int get squelchLevel => 2;
  int get micGain => 5;
  int get btMicGain => 7;

  RadioController({this.connection}) {
    if (connection != null) {
      _btStreamSubscription = connection!.input!.listen(_onDataReceived);
      _initializeRadioState();
    }
  }

  void _onDataReceived(Uint8List data) {
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

      } catch (e) {
        if (kDebugMode) print('Error parsing message: $e');
      }
    }
  }

  void _handleEvent(EventNotificationBody eventBody) {
      if (eventBody.eventType == EventType.HT_STATUS_CHANGED) {
          final statusReply = eventBody.event as GetHtStatusReplyBody;
          if (statusReply.status != null) {
              status.updateFrom(statusReply.status!);
              if (status.currChId != channelInfo.name.hashCode) { // Simple check to see if channel changed
                getChannel(status.currChId).then((ch) {
                    channelInfo.updateFrom(ch);
                    notifyListeners();
                });
              } else {
                notifyListeners();
              }
          }
      }
  }

  Future<void> _initializeRadioState() async {
    try {
      await _registerForEvents();

      final results = await Future.wait([
        getDeviceInfo(),
        getStatus(),
        getBatteryPercentage(),
        getBatteryVoltage(),
        getPosition(),
      ]);

      deviceInfo.updateFrom(results[0] as DeviceInfo);
      status.updateFrom(results[1] as StatusExt);
      batteryLevelAsPercentage = (results[2] as num).toInt();
      batteryVoltage = (results[3] as num).toDouble();
      gps.updateFrom(results[4] as Position);

      final currentChannel = await getChannel(status.currChId);
      channelInfo.updateFrom(currentChannel);
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
      return null;
    }
    final messagePayloadLength = _rxBuffer[3];
    final fullMessageLength = messagePayloadLength + 4;
    final fullFrameLength = fullMessageLength + 4;
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
    connection?.output.add(bytes);
    await connection?.output.allSent;
  }

  Future<T> _sendCommandExpectReply<T extends MessageBody>({
    required Message command,
    required BasicCommand replyCommand,
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
    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Radio did not reply in time.'));
        streamSub.cancel();
      }
    });
    return completer.future;
  }

  Future<void> _registerForEvents() async {
      final command = Message(
          commandGroup: CommandGroup.BASIC,
          command: BasicCommand.REGISTER_NOTIFICATION,
          isReply: false,
          body: RegisterNotificationBody(eventType: EventType.HT_STATUS_CHANGED)
      );
      await _sendCommand(command);
  }

  Future<DeviceInfo> getDeviceInfo() async {
    final reply = await _sendCommandExpectReply<GetDevInfoReplyBody>(
      command: Message(commandGroup: CommandGroup.BASIC, command: BasicCommand.GET_DEV_INFO, isReply: false, body: GetDevInfoBody()),
      replyCommand: BasicCommand.GET_DEV_INFO,
    );
    if (reply.devInfo == null) throw Exception('Failed to get device info.');
    deviceInfo.updateFrom(reply.devInfo!);
    notifyListeners();
    return reply.devInfo!;
  }

  Future<StatusExt> getStatus() async {
      final reply = await _sendCommandExpectReply<GetHtStatusReplyBody>(
          command: Message(commandGroup: CommandGroup.BASIC, command: BasicCommand.GET_HT_STATUS, isReply: false, body: GetHtStatusBody()),
          replyCommand: BasicCommand.GET_HT_STATUS,
      );
      if(reply.status == null) throw Exception('Failed to get status');
      return reply.status!;
  }

  Future<num> getBatteryVoltage() async {
      final reply = await _sendCommandExpectReply<ReadPowerStatusReplyBody>(
          command: Message(commandGroup: CommandGroup.BASIC, command: BasicCommand.READ_STATUS, isReply: false, body: ReadPowerStatusBody(statusType: PowerStatusType.BATTERY_VOLTAGE)),
          replyCommand: BasicCommand.READ_STATUS,
      );
      if (reply.value == null) throw Exception('Failed to get battery voltage.');
      return reply.value!;
  }

  Future<num> getBatteryPercentage() async {
      final reply = await _sendCommandExpectReply<ReadPowerStatusReplyBody>(
          command: Message(commandGroup: CommandGroup.BASIC, command: BasicCommand.READ_STATUS, isReply: false, body: ReadPowerStatusBody(statusType: PowerStatusType.BATTERY_LEVEL_AS_PERCENTAGE)),
          replyCommand: BasicCommand.READ_STATUS,
      );
      if (reply.value == null) throw Exception('Failed to get battery percentage.');
      return reply.value!;
  }

  Future<Position> getPosition() async {
      final reply = await _sendCommandExpectReply<GetPositionReplyBody>(
          command: Message(commandGroup: CommandGroup.BASIC, command: BasicCommand.GET_POSITION, isReply: false, body: GetPositionBody()),
          replyCommand: BasicCommand.GET_POSITION,
      );
      if (reply.position == null) throw Exception('Failed to get position.');
      return reply.position!;
  }

  Future<Channel> getChannel(int channelId) async {
    final reply = await _sendCommandExpectReply<ReadRFChReplyBody>(
      command: Message(commandGroup: CommandGroup.BASIC, command: BasicCommand.READ_RF_CH, isReply: false, body: ReadRFChBody(channelId: channelId)),
      replyCommand: BasicCommand.READ_RF_CH,
    );
    if (reply.rfCh == null) throw Exception('Failed to get channel $channelId.');
    return reply.rfCh!;
  }

  /// Re-added method for Chirp compatibility
  Future<List<Channel>> getAllChannels() async {
    if (deviceInfo.channelCount == 0) {
      // Make sure we have device info first
      await getDeviceInfo();
    }
    final channels = <Channel>[];
    for (int i = 0; i < deviceInfo.channelCount; i++) {
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

  @override
  void dispose() {
    _btStreamSubscription?.cancel();
    _messageStreamController.close();
    super.dispose();
  }

  static RadioController fakeForUi() => RadioController(connection: null);
}