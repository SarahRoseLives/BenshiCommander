import 'dart:typed_data';
import 'utils.dart';

class GaiaFrame {
  static const int startByte = 0xFF;
  static const int version = 0x01;
  final int flags;
  final Uint8List messageBytes;

  GaiaFrame({this.flags = 0, required this.messageBytes});

  Uint8List toBytes() {
    // The payload length in the GAIA header does NOT include the 4 command bytes.
    final messagePayloadLength = messageBytes.length - 4;

    // The total frame length is 4 header bytes + message length
    final writer = ByteWriter(4 + messageBytes.length);

    writer.writeInt(startByte, 8);
    writer.writeInt(version, 8);
    writer.writeInt(flags, 8);
    writer.writeInt(messagePayloadLength, 8);
    writer.writeBytes(messageBytes);

    return writer.toBytes();
  }
}

class GaiaParseResult {
  final GaiaFrame frame;
  final Uint8List remainingBuffer;
  GaiaParseResult(this.frame, this.remainingBuffer);
}