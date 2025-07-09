import 'dart:typed_data';

// Represents a parsed audio message from the radio
abstract class AudioMessage {}

class AudioData extends AudioMessage {
  final Uint8List sbcData;
  AudioData(this.sbcData);
}

class AudioEnd extends AudioMessage {}
class AudioAck extends AudioMessage {}
class AudioUnknown extends AudioMessage {}

// A result object to hold both the parsed message and the remaining buffer
class AudioParseResult {
  final AudioMessage? message;
  final Uint8List remainingBuffer;
  AudioParseResult(this.message, this.remainingBuffer);
}

Uint8List _unescapeBytes(Uint8List bytes) {
  final out = BytesBuilder();
  for (int i = 0; i < bytes.length; i++) {
    if (bytes[i] == 0x7d) {
      i++;
      if (i < bytes.length) {
        out.addByte(bytes[i] ^ 0x20);
      }
    } else {
      out.addByte(bytes[i]);
    }
  }
  return out.toBytes();
}

// --- REWRITTEN: Non-recursive parser that handles incomplete frames ---
AudioParseResult parseAudioFrame(Uint8List buffer) {
  const frameDelimiter = 0x7e;

  // Find the start of a frame
  int start = buffer.indexOf(frameDelimiter);
  if (start == -1) {
    // No frame start found, discard buffer (or handle as needed)
    return AudioParseResult(null, Uint8List(0));
  }

  // Find the end of the frame
  int end = buffer.indexOf(frameDelimiter, start + 1);
  if (end == -1) {
    // Frame is incomplete, wait for more data
    return AudioParseResult(null, buffer.sublist(start));
  }

  // A complete frame was found, extract it
  final frameBytes = buffer.sublist(start + 1, end);
  final remaining = buffer.sublist(end + 1);
  final unescaped = _unescapeBytes(frameBytes);

  if (unescaped.isEmpty) {
    // Empty frame, move to the next part of the buffer
    return AudioParseResult(null, remaining);
  }

  AudioMessage message;
  switch (unescaped[0]) {
    case 0x00: // Audio Data
      message = AudioData(unescaped.sublist(1));
      break;
    case 0x01: // Audio End
      message = AudioEnd();
      break;
    case 0x02: // Audio Ack
      message = AudioAck();
      break;
    default:
      message = AudioUnknown();
      break;
  }

  return AudioParseResult(message, remaining);
}