import 'dart:typed_data';
import 'common.dart';
import 'data_models.dart';
import 'utils.dart';

// Abstract base class for all message bodies.
abstract class MessageBody {
  Uint8List toBytes();
}

// NEW: Abstract base class for all reply bodies to standardize status checking.
abstract class ReplyBody extends MessageBody {
  final ReplyStatus replyStatus;
  ReplyBody({required this.replyStatus});
}


// A generic body for commands that are not yet fully implemented.
class UnknownBody extends MessageBody {
  final Uint8List data;
  UnknownBody({required this.data});
  @override
  Uint8List toBytes() => data;
}

// --- GET_DEV_INFO ---
class GetDevInfoBody extends MessageBody {
  @override
  Uint8List toBytes() => Uint8List.fromList([3]);
}

class GetDevInfoReplyBody extends ReplyBody {
  final DeviceInfo? devInfo;
  GetDevInfoReplyBody({required super.replyStatus, this.devInfo});

  factory GetDevInfoReplyBody.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final replyStatus = ReplyStatus.fromInt(r.readInt(8));
    return GetDevInfoReplyBody(
      replyStatus: replyStatus,
      devInfo: replyStatus == ReplyStatus.SUCCESS ? DeviceInfo.fromBytes(r.readBytes(r.remainingBits ~/ 8)) : null,
    );
  }
  @override
  Uint8List toBytes() => throw UnimplementedError("Reply bodies are not intended to be converted to bytes.");
}

// --- READ_SETTINGS ---
class ReadSettingsBody extends MessageBody {
  @override
  Uint8List toBytes() => Uint8List(0);
}

class ReadSettingsReplyBody extends ReplyBody {
  final Settings? settings;
  ReadSettingsReplyBody({required super.replyStatus, this.settings});

  factory ReadSettingsReplyBody.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final status = ReplyStatus.fromInt(r.readInt(8));
    return ReadSettingsReplyBody(
      replyStatus: status,
      settings: status == ReplyStatus.SUCCESS ? Settings.fromBytes(r.readBytes(r.remainingBits ~/ 8)) : null,
    );
  }
  @override
  Uint8List toBytes() => throw UnimplementedError("Reply bodies are not intended to be converted to bytes.");
}

// --- WRITE_SETTINGS ---
class WriteSettingsBody extends MessageBody {
  final Settings settings;
  WriteSettingsBody({required this.settings});

  @override
  Uint8List toBytes() => settings.toBytes();
}

class WriteSettingsReplyBody extends ReplyBody {
  WriteSettingsReplyBody({required super.replyStatus});

  factory WriteSettingsReplyBody.fromBytes(Uint8List bytes) {
    return WriteSettingsReplyBody(replyStatus: ReplyStatus.fromInt(bytes[0]));
  }

  @override
  Uint8List toBytes() => throw UnimplementedError("Reply bodies are not intended to be converted to bytes.");
}


// --- READ_RF_CH ---
class ReadRFChBody extends MessageBody {
  final int channelId;
  ReadRFChBody({required this.channelId});

  @override
  Uint8List toBytes() => Uint8List.fromList([channelId]);
}

class ReadRFChReplyBody extends ReplyBody {
  final Channel? rfCh;
  ReadRFChReplyBody({required super.replyStatus, this.rfCh});

  factory ReadRFChReplyBody.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final status = ReplyStatus.fromInt(r.readInt(8));
    return ReadRFChReplyBody(
      replyStatus: status,
      rfCh: status == ReplyStatus.SUCCESS ? Channel.fromBytes(r.readBytes(r.remainingBits ~/ 8)) : null,
    );
  }
  @override
  Uint8List toBytes() => throw UnimplementedError("Reply bodies are not intended to be converted to bytes.");
}

// --- WRITE_RF_CH ---
class WriteRFChBody extends MessageBody {
  final Channel rfCh;
  WriteRFChBody({required this.rfCh});
  @override
  Uint8List toBytes() => rfCh.toBytes();
}
class WriteRFChReplyBody extends ReplyBody {
  final int? channelId; // FIX: Make channelId nullable
  WriteRFChReplyBody({required super.replyStatus, this.channelId});

  factory WriteRFChReplyBody.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final status = ReplyStatus.fromInt(r.readInt(8));
    int? chId;
    // FIX: Only read channelId if status is SUCCESS and data is available
    if (status == ReplyStatus.SUCCESS && r.remainingBits >= 8) {
      chId = r.readInt(8);
    }
    return WriteRFChReplyBody(
      replyStatus: status,
      channelId: chId,
    );
  }

  @override
  Uint8List toBytes() => throw UnimplementedError();
}


// --- GET_HT_STATUS ---
class GetHtStatusBody extends MessageBody {
  @override
  Uint8List toBytes() => Uint8List(0);
}

class GetHtStatusReplyBody extends ReplyBody {
  final StatusExt? status;
  GetHtStatusReplyBody({required super.replyStatus, this.status});

  factory GetHtStatusReplyBody.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final status = ReplyStatus.fromInt(r.readInt(8));
    // The body can be variable length, so we check if there's enough data for a status object.
    if (status != ReplyStatus.SUCCESS || r.remainingBits < Status.bitLength) {
       return GetHtStatusReplyBody(replyStatus: status, status: null);
    }
    return GetHtStatusReplyBody(
      replyStatus: status,
      status: StatusExt.fromBytes(r.readBytes(r.remainingBits ~/ 8)),
    );
  }
  @override
  Uint8List toBytes() => throw UnimplementedError("Reply bodies are not intended to be converted to bytes.");
}

// --- READ_STATUS (for battery) ---
class ReadPowerStatusBody extends MessageBody {
  final PowerStatusType statusType;
  ReadPowerStatusBody({required this.statusType});

  @override
  Uint8List toBytes() {
    final w = ByteWriter(2);
    w.writeInt(statusType.value, 16);
    return w.toBytes();
  }
}

class ReadPowerStatusReplyBody extends ReplyBody {
  final num? value;
  ReadPowerStatusReplyBody({required super.replyStatus, this.value});

  factory ReadPowerStatusReplyBody.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final status = ReplyStatus.fromInt(r.readInt(8));
    if (status != ReplyStatus.SUCCESS || r.remainingBits < 16) {
      return ReadPowerStatusReplyBody(replyStatus: status);
    }
    final type = PowerStatusType.fromInt(r.readInt(16));
    num? val;
    if (type == PowerStatusType.BATTERY_VOLTAGE) {
      if (r.remainingBits >= 16) val = r.readInt(16) / 1000.0;
    } else {
      if (r.remainingBits >= 8) val = r.readInt(8);
    }
    return ReadPowerStatusReplyBody(replyStatus: status, value: val);
  }
  @override
  Uint8List toBytes() => throw UnimplementedError("Reply bodies are not intended to be converted to bytes.");
}

// --- GET_POSITION ---
class GetPositionBody extends MessageBody {
  @override
  Uint8List toBytes() => Uint8List(0);
}

class GetPositionReplyBody extends ReplyBody {
  final Position? position;
  GetPositionReplyBody({required super.replyStatus, this.position});

  factory GetPositionReplyBody.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final status = ReplyStatus.fromInt(r.readInt(8));
     if (status != ReplyStatus.SUCCESS || r.remainingBits < Position.bitLength) {
       return GetPositionReplyBody(replyStatus: status, position: null);
    }
    return GetPositionReplyBody(
      replyStatus: status,
      position: Position.fromBytes(r.readBytes(r.remainingBits ~/ 8)),
    );
  }
  @override
  Uint8List toBytes() => throw UnimplementedError("Reply bodies are not intended to be converted to bytes.");
}

// --- EVENT_NOTIFICATION ---
class EventNotificationBody extends MessageBody {
  final EventType eventType;
  final MessageBody event;
  EventNotificationBody({required this.eventType, required this.event});

  factory EventNotificationBody.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final type = EventType.fromInt(r.readInt(8));
    MessageBody body;
    final remainingBytes = r.readBytes(r.remainingBits ~/ 8);
    switch (type) {
      case EventType.HT_STATUS_CHANGED:
        body = GetHtStatusReplyBody(replyStatus: ReplyStatus.SUCCESS, status: StatusExt.fromBytes(remainingBytes));
        break;
      case EventType.HT_SETTINGS_CHANGED:
        body = ReadSettingsReplyBody(replyStatus: ReplyStatus.SUCCESS, settings: Settings.fromBytes(remainingBytes));
        break;
      case EventType.HT_CH_CHANGED:
        body = ReadRFChReplyBody(replyStatus: ReplyStatus.SUCCESS, rfCh: Channel.fromBytes(remainingBytes));
        break;
      // Other events can be added here as needed.
      default:
        body = UnknownBody(data: remainingBytes);
    }
    return EventNotificationBody(eventType: type, event: body);
  }
  @override
  Uint8List toBytes() => throw UnimplementedError("Reply bodies are not intended to be converted to bytes.");
}

// --- REGISTER_NOTIFICATION ---
class RegisterNotificationBody extends MessageBody {
  final EventType eventType;
  RegisterNotificationBody({required this.eventType});

  @override
  Uint8List toBytes() => Uint8List.fromList([eventType.value]);
}

// --- GET_IN_SCAN ---
class GetInScanBody extends MessageBody {
  @override
  Uint8List toBytes() => Uint8List(0);
}

class GetInScanReplyBody extends ReplyBody {
  final bool isScanning;
  GetInScanReplyBody({required super.replyStatus, this.isScanning = false});

  factory GetInScanReplyBody.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final status = ReplyStatus.fromInt(r.readInt(8));
    return GetInScanReplyBody(
      replyStatus: status,
      // The reply body is a single boolean
      isScanning: status == ReplyStatus.SUCCESS ? r.readBool() : false,
    );
  }
  @override
  Uint8List toBytes() => throw UnimplementedError("Reply bodies are not intended to be converted to bytes.");
}

// --- SET_IN_SCAN ---
class SetInScanBody extends MessageBody {
  final bool enable;
  SetInScanBody({required this.enable});

  @override
  Uint8List toBytes() {
    final w = ByteWriter(1);
    w.writeBool(enable);
    return w.toBytes();
  }
}

class SetInScanReplyBody extends ReplyBody {
  SetInScanReplyBody({required super.replyStatus});

  factory SetInScanReplyBody.fromBytes(Uint8List bytes) {
    return SetInScanReplyBody(
      replyStatus: ReplyStatus.fromInt(ByteReader(bytes).readInt(8))
    );
  }

  @override
  Uint8List toBytes() => throw UnimplementedError("Reply bodies are not intended to be converted to bytes.");
}