import 'dart:typed_data';
import 'common.dart';
import 'command_bodies.dart';
import 'utils.dart';

class Message {
  final CommandGroup commandGroup;
  final bool isReply;
  final Enum command; // Can be BasicCommand or ExtendedCommand
  final MessageBody body;

  Message({
    required this.commandGroup,
    required this.isReply,
    required this.command,
    required this.body,
  });

  Uint8List toBytes() {
    final bodyBytes = body.toBytes();
    final writer = ByteWriter(4 + bodyBytes.length);
    writer.writeInt(commandGroup.value, 16);
    writer.writeBool(isReply);
    writer.writeInt((command as dynamic).value, 15);
    writer.writeBytes(bodyBytes);
    return writer.toBytes();
  }

  factory Message.fromBytes(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final commandGroup = CommandGroup.fromInt(data.getUint16(0, Endian.big));
    final isReply = (data.getUint8(2) & 0x80) != 0;
    final commandValue = data.getUint16(2, Endian.big) & 0x7FFF;
    final bodyBytes = bytes.sublist(4);

    Enum cmd;
    MessageBody parsedBody;

    if (commandGroup == CommandGroup.EXTENDED) {
      cmd = ExtendedCommand.fromInt(commandValue);
      // Handle extended commands if necessary, otherwise treat as unknown
      parsedBody = UnknownBody(data: bodyBytes);
    } else {
      cmd = BasicCommand.fromInt(commandValue);
      switch (cmd) {
        case BasicCommand.GET_DEV_INFO:
          parsedBody = isReply ? GetDevInfoReplyBody.fromBytes(bodyBytes) : GetDevInfoBody();
          break;
        case BasicCommand.READ_RF_CH:
          parsedBody = isReply ? ReadRFChReplyBody.fromBytes(bodyBytes) : ReadRFChBody.fromBytes(bodyBytes);
          break;
        case BasicCommand.GET_HT_STATUS:
          parsedBody = isReply ? GetHtStatusReplyBody.fromBytes(bodyBytes) : GetHtStatusBody();
          break;
        case BasicCommand.READ_STATUS:
          parsedBody = isReply ? ReadPowerStatusReplyBody.fromBytes(bodyBytes) : ReadPowerStatusBody.fromBytes(bodyBytes);
          break;
        case BasicCommand.GET_POSITION:
          parsedBody = isReply ? GetPositionReplyBody.fromBytes(bodyBytes) : GetPositionBody();
          break;
        case BasicCommand.EVENT_NOTIFICATION:
          parsedBody = EventNotificationBody.fromBytes(bodyBytes);
          break;
        case BasicCommand.REGISTER_NOTIFICATION:
          parsedBody = RegisterNotificationBody.fromBytes(bodyBytes);
          break;
        default:
          parsedBody = UnknownBody(data: bodyBytes);
      }
    }

    return Message(
      commandGroup: commandGroup,
      isReply: isReply,
      command: cmd,
      body: parsedBody,
    );
  }
}