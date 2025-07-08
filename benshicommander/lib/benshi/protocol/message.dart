import 'dart:typed_data';
import 'common.dart';
import 'command_bodies.dart';
import 'data_models.dart'; // Direct import to fix scope issue
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
    // 4 bytes for header (group, reply/command) + body length
    final writer = ByteWriter(4 + bodyBytes.length);
    writer.writeInt(commandGroup.value, 16);
    writer.writeBool(isReply);
    writer.writeInt((command as dynamic).value, 15);
    writer.writeBytes(bodyBytes);
    return writer.toBytes();
  }

  factory Message.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final commandGroup = CommandGroup.fromInt(r.readInt(16));
    final isReply = r.readBool();
    final commandValue = r.readInt(15);
    final bodyBytes = r.readBytes(r.remainingBits ~/ 8);

    Enum cmd;
    MessageBody parsedBody;

    if (commandGroup == CommandGroup.EXTENDED) {
      cmd = ExtendedCommand.fromInt(commandValue);
      // For now, treat all extended command bodies as unknown.
      parsedBody = UnknownBody(data: bodyBytes);
    } else {
      cmd = BasicCommand.fromInt(commandValue);
      switch (cmd) {
        case BasicCommand.GET_DEV_INFO:
          parsedBody = isReply ? GetDevInfoReplyBody.fromBytes(bodyBytes) : GetDevInfoBody();
          break;
        case BasicCommand.READ_SETTINGS:
          parsedBody = isReply ? ReadSettingsReplyBody.fromBytes(bodyBytes) : ReadSettingsBody();
          break;
        case BasicCommand.WRITE_SETTINGS:
          // A non-reply WRITE_SETTINGS is a command being sent TO the radio, which we parse from an event.
          // The body of the message is the settings object itself.
          parsedBody = isReply ? WriteSettingsReplyBody.fromBytes(bodyBytes) : WriteSettingsBody(settings: Settings.fromBytes(bodyBytes));
          break;
        case BasicCommand.READ_RF_CH:
          parsedBody = isReply ? ReadRFChReplyBody.fromBytes(bodyBytes) : ReadRFChBody(channelId: bodyBytes[0]);
          break;
        // ADDED case for handling write replies
        case BasicCommand.WRITE_RF_CH:
            parsedBody = isReply
                ? WriteRFChReplyBody.fromBytes(bodyBytes)
                : WriteRFChBody(rfCh: Channel.fromBytes(bodyBytes));
            break;
        case BasicCommand.GET_HT_STATUS:
          parsedBody = isReply ? GetHtStatusReplyBody.fromBytes(bodyBytes) : GetHtStatusBody();
          break;
        case BasicCommand.READ_STATUS:
          parsedBody = isReply ? ReadPowerStatusReplyBody.fromBytes(bodyBytes) : ReadPowerStatusBody(statusType: PowerStatusType.fromInt(ByteReader(bodyBytes).readInt(16)));
          break;
        case BasicCommand.GET_POSITION:
          parsedBody = isReply ? GetPositionReplyBody.fromBytes(bodyBytes) : GetPositionBody();
          break;
        case BasicCommand.EVENT_NOTIFICATION:
          parsedBody = EventNotificationBody.fromBytes(bodyBytes);
          break;
        case BasicCommand.REGISTER_NOTIFICATION:
          parsedBody = RegisterNotificationBody(eventType: EventType.fromInt(bodyBytes[0]));
          break;
        case BasicCommand.GET_IN_SCAN:
          parsedBody = isReply ? GetInScanReplyBody.fromBytes(bodyBytes) : GetInScanBody();
          break;
        case BasicCommand.SET_IN_SCAN:
          parsedBody = isReply ? SetInScanReplyBody.fromBytes(bodyBytes) : SetInScanBody(enable: bodyBytes[0] > 0);
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