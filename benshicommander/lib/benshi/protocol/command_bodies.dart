import 'dart:typed_data';
import 'common.dart';
import 'data_models.dart';
import 'utils.dart';

abstract class MessageBody {
  Uint8List toBytes();
}

class UnknownBody extends MessageBody {
  final Uint8List data;
  UnknownBody({required this.data});
  @override
  Uint8List toBytes() => data;
}

// GET_DEV_INFO
class GetDevInfoBody extends MessageBody {
  @override
  Uint8List toBytes() => Uint8List.fromList([3]);
}
class GetDevInfoReplyBody extends MessageBody {
  final ReplyStatus replyStatus;
  final DeviceInfo? devInfo;
  GetDevInfoReplyBody({required this.replyStatus, this.devInfo});
  factory GetDevInfoReplyBody.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final replyStatus = ReplyStatus.fromInt(r.readInt(8));
    return GetDevInfoReplyBody(
      replyStatus: replyStatus,
      devInfo: replyStatus == ReplyStatus.SUCCESS ? DeviceInfo.fromBytes(r.readBytes(r.remainingBits ~/ 8)) : null,
    );
  }
  @override
  Uint8List toBytes() => throw UnimplementedError();
}

// READ_RF_CH
class ReadRFChBody extends MessageBody {
  final int channelId;
  ReadRFChBody({required this.channelId});
  factory ReadRFChBody.fromBytes(Uint8List bytes) => ReadRFChBody(channelId: bytes[0]);
  @override
  Uint8List toBytes() => Uint8List.fromList([channelId]);
}
class ReadRFChReplyBody extends MessageBody {
  final ReplyStatus replyStatus;
  final Channel? rfCh;
  ReadRFChReplyBody({required this.replyStatus, this.rfCh});
  factory ReadRFChReplyBody.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final status = ReplyStatus.fromInt(r.readInt(8));
    return ReadRFChReplyBody(
      replyStatus: status,
      rfCh: status == ReplyStatus.SUCCESS ? Channel.fromBytes(r.readBytes(r.remainingBits ~/ 8)) : null,
    );
  }
  @override
  Uint8List toBytes() => throw UnimplementedError();
}

// GET_HT_STATUS
class GetHtStatusBody extends MessageBody {
  @override
  Uint8List toBytes() => Uint8List(0);
}
class GetHtStatusReplyBody extends MessageBody {
  final ReplyStatus replyStatus;
  final StatusExt? status;
  GetHtStatusReplyBody({required this.replyStatus, this.status});
  factory GetHtStatusReplyBody.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final status = ReplyStatus.fromInt(r.readInt(8));
    return GetHtStatusReplyBody(
      replyStatus: status,
      status: status == ReplyStatus.SUCCESS ? StatusExt.fromBytes(r.readBytes(r.remainingBits ~/ 8)) : null,
    );
  }
  @override
  Uint8List toBytes() => throw UnimplementedError();
}

// READ_STATUS (for battery)
class ReadPowerStatusBody extends MessageBody {
  final PowerStatusType statusType;
  ReadPowerStatusBody({required this.statusType});
  factory ReadPowerStatusBody.fromBytes(Uint8List bytes) => ReadPowerStatusBody(statusType: PowerStatusType.values.firstWhere((e) => e.value == bytes[0]));
  @override
  Uint8List toBytes() {
    final w = ByteWriter(2);
    w.writeInt(statusType.value, 16);
    return w.toBytes();
  }
}
class ReadPowerStatusReplyBody extends MessageBody {
  final ReplyStatus replyStatus;
  final num? value;
  ReadPowerStatusReplyBody({required this.replyStatus, this.value});
  factory ReadPowerStatusReplyBody.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final status = ReplyStatus.fromInt(r.readInt(8));
    if (status != ReplyStatus.SUCCESS || r.remainingBits < 16) {
      return ReadPowerStatusReplyBody(replyStatus: status);
    }
    final type = PowerStatusType.values.firstWhere((e) => e.value == r.readInt(16));
    num? val;
    if (type == PowerStatusType.BATTERY_VOLTAGE) {
      if (r.remainingBits >= 16) val = r.readInt(16) / 1000.0;
    } else {
      if (r.remainingBits >= 8) val = r.readInt(8);
    }
    return ReadPowerStatusReplyBody(replyStatus: status, value: val);
  }
  @override
  Uint8List toBytes() => throw UnimplementedError();
}

// GET_POSITION
class GetPositionBody extends MessageBody {
  @override
  Uint8List toBytes() => Uint8List(0);
}
class GetPositionReplyBody extends MessageBody {
  final ReplyStatus replyStatus;
  final Position? position;
  GetPositionReplyBody({required this.replyStatus, this.position});
  factory GetPositionReplyBody.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final status = ReplyStatus.fromInt(r.readInt(8));
    return GetPositionReplyBody(
      replyStatus: status,
      position: status == ReplyStatus.SUCCESS ? Position.fromBytes(r.readBytes(r.remainingBits ~/ 8)) : null,
    );
  }
  @override
  Uint8List toBytes() => throw UnimplementedError();
}

// EVENT_NOTIFICATION
class EventNotificationBody extends MessageBody {
  final EventType eventType;
  final MessageBody event;
  EventNotificationBody({required this.eventType, required this.event});
  factory EventNotificationBody.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final type = EventType.fromInt(r.readInt(8));
    MessageBody body;
    final remainingBytes = r.readBytes(r.remainingBits ~/ 8);
    switch(type) {
      case EventType.HT_STATUS_CHANGED:
        body = GetHtStatusReplyBody(replyStatus: ReplyStatus.SUCCESS, status: StatusExt.fromBytes(remainingBytes));
        break;
      case EventType.HT_CH_CHANGED:
        body = ReadRFChReplyBody(replyStatus: ReplyStatus.SUCCESS, rfCh: Channel.fromBytes(remainingBytes));
        break;
      default:
        body = UnknownBody(data: remainingBytes);
    }
    return EventNotificationBody(eventType: type, event: body);
  }
  @override
  Uint8List toBytes() => throw UnimplementedError();
}

// REGISTER_NOTIFICATION
class RegisterNotificationBody extends MessageBody {
  final EventType eventType;
  RegisterNotificationBody({required this.eventType});
  factory RegisterNotificationBody.fromBytes(Uint8List bytes) => RegisterNotificationBody(eventType: EventType.fromInt(bytes[0]));
  @override
  Uint8List toBytes() => Uint8List.fromList([eventType.value]);
}