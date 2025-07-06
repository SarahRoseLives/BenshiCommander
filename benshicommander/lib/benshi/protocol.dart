import 'dart:typed_data';
import 'dart:convert';

// --- Enums with correct protocol values ---
enum CommandGroup {
  BASIC(2),
  EXTENDED(10);

  const CommandGroup(this.value);
  final int value;
}

enum BasicCommand {
  GET_DEV_INFO(4),
  READ_RF_CH(13);

  const BasicCommand(this.value);
  final int value;
}

// --- Helper classes for serializing/deserializing ---
class ByteWriter {
  final ByteData _data;
  int _bitOffset = 0;
  int _byteIndex = 0;
  int _bitInByte = 0;

  ByteWriter(int length) : _data = ByteData(length);

  void writeInt(int value, int bitLength) {
    for (int i = bitLength - 1; i >= 0; i--) {
      writeBool((value >> i) & 1 == 1);
    }
  }

  void writeBool(bool value) {
    if (value) {
      _data.setUint8(_byteIndex, _data.getUint8(_byteIndex) | (1 << (7 - _bitInByte)));
    }
    _bitOffset++;
    _bitInByte = _bitOffset % 8;
    _byteIndex = _bitOffset ~/ 8;
  }

  void writeBytes(Uint8List bytes) {
    for (var byte in bytes) {
      writeInt(byte, 8);
    }
  }

  Uint8List toBytes() => _data.buffer.asUint8List();
}

class ByteReader {
  final ByteData _data;
  int _bitOffset = 0;

  ByteReader(Uint8List bytes) : _data = ByteData.sublistView(bytes);

  int readInt(int bitLength) {
    int value = 0;
    for (int i = 0; i < bitLength; i++) {
      int currentBit = _bitOffset + i;
      int byteIndex = currentBit ~/ 8;
      int bitInByte = currentBit % 8;
      if ((_data.getUint8(byteIndex) >> (7 - bitInByte)) & 1 == 1) {
        value |= (1 << (bitLength - 1 - i));
      }
    }
    _bitOffset += bitLength;
    return value;
  }

  void skipBits(int bitLength) {
    _bitOffset += bitLength;
  }

  String readString(int byteLength) {
    final bytes = Uint8List(byteLength);
    for (int i = 0; i < byteLength; i++) {
      bytes[i] = readInt(8);
    }
    return utf8.decode(bytes, allowMalformed: true).replaceAll('\u0000', '').trim();
  }
}

// --- GAIA Frame and Parse Result ---

/// Represents a GAIA protocol frame, necessary for RFCOMM communication.
class GaiaFrame {
  static const int startByte = 0xFF;
  static const int version = 0x01;

  final int flags;
  final Uint8List messageBytes; // The bytes from Message.toBytes()

  GaiaFrame({this.flags = 0, required this.messageBytes});

  /// Serializes the GaiaFrame to bytes for sending to the radio.
  Uint8List toBytes() {
    // The GAIA payload length is the message length minus the standard 4-byte message header.
    final messagePayloadLength = messageBytes.length - 4;

    // 4 bytes for GAIA header + the full length of the message
    final writer = ByteWriter(4 + messageBytes.length);

    writer.writeInt(startByte, 8);        // 0xFF
    writer.writeInt(version, 8);          // 0x01
    writer.writeInt(flags, 8);            // 0x00
    writer.writeInt(messagePayloadLength, 8); // e.g., 1 for GET_DEV_INFO
    writer.writeBytes(messageBytes);      // The actual message bytes

    return writer.toBytes();
  }
}

// Result holder for the parsing logic
class GaiaParseResult {
  final GaiaFrame frame;
  final Uint8List remainingBuffer;
  GaiaParseResult(this.frame, this.remainingBuffer);
}

// --- Message and Body Abstractions ---
abstract class MessageBody {
  Uint8List toBytes();
}

class Message {
  final CommandGroup commandGroup;
  final bool isReply;
  final BasicCommand command;
  final MessageBody body;

  Message({required this.commandGroup, required this.isReply, required this.command, required this.body});

  Uint8List toBytes() {
    final bodyBytes = body.toBytes();
    final writer = ByteWriter(4 + bodyBytes.length);
    writer.writeInt(commandGroup.value, 16);
    writer.writeBool(isReply);
    writer.writeInt(command.value, 15);
    writer.writeBytes(bodyBytes);
    return writer.toBytes();
  }

  factory Message.fromBytes(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    bool isReply = (data.getUint8(2) & 0x80) != 0;
    int commandValue = data.getUint16(2, Endian.big) & 0x7FFF;

    BasicCommand cmd = BasicCommand.values.firstWhere((e) => e.value == commandValue, orElse: () => throw Exception('Unknown command value: $commandValue'));

    Uint8List bodyBytes = bytes.sublist(4);
    MessageBody parsedBody;

    switch (cmd) {
      case BasicCommand.GET_DEV_INFO:
        parsedBody = isReply ? GetDevInfoReplyBody.fromBytes(bodyBytes) : GetDevInfoBody();
        break;
      case BasicCommand.READ_RF_CH:
        parsedBody = isReply ? ReadRFChReplyBody.fromBytes(bodyBytes) : ReadRFChBody.fromBytes(bodyBytes);
        break;
      default:
        throw UnimplementedError('Command parsing not implemented for $cmd');
    }

    return Message(
      commandGroup: CommandGroup.BASIC,
      isReply: isReply,
      command: cmd,
      body: parsedBody,
    );
  }
}

// --- Data Models ---
// (Python bitfield order for DevInfo)
// vendor_id: 8
// product_id: 16
// hw_ver: 8
// soft_ver: 16
// support_radio: 1
// support_medium_power: 1
// fixed_loc_speaker_vol: 1
// not_support_soft_power_ctrl: 1
// have_no_speaker: 1
// have_hm_speaker: 1
// region_count: 6
// support_noaa: 1
// gmrs: 1
// support_vfo: 1
// support_dmr: 1
// channel_count: 8
// freq_range_count: 4
// support_noise_reduction: 1 (optional, default False)
// support_smart_beacon: 1 (optional, default False)
// _pad: 2

enum ReplyStatus {
  SUCCESS(0),
  FAILURE(1);

  const ReplyStatus(this.value);
  final int value;

  static ReplyStatus fromInt(int value) =>
      ReplyStatus.values.firstWhere((e) => e.value == value, orElse: () => ReplyStatus.FAILURE);
}

class DeviceInfo {
  final int vendorId;
  final int productId;
  final int hwVer;
  final int softVer;
  final bool supportRadio;
  final bool supportMediumPower;
  final bool fixedLocSpeakerVol;
  final bool notSupportSoftPowerCtrl;
  final bool haveNoSpeaker;
  final bool haveHmSpeaker;
  final int regionCount;
  final bool supportNoaa;
  final bool gmrs;
  final bool supportVfo;
  final bool supportDmr;
  final int channelCount;
  final int freqRangeCount;
  final bool supportNoiseReduction;
  final bool supportSmartBeacon;

  DeviceInfo({
    required this.vendorId,
    required this.productId,
    required this.hwVer,
    required this.softVer,
    required this.supportRadio,
    required this.supportMediumPower,
    required this.fixedLocSpeakerVol,
    required this.notSupportSoftPowerCtrl,
    required this.haveNoSpeaker,
    required this.haveHmSpeaker,
    required this.regionCount,
    required this.supportNoaa,
    required this.gmrs,
    required this.supportVfo,
    required this.supportDmr,
    required this.channelCount,
    required this.freqRangeCount,
    this.supportNoiseReduction = false,
    this.supportSmartBeacon = false,
  });

  factory DeviceInfo.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final vendorId = r.readInt(8);
    final productId = r.readInt(16);
    final hwVer = r.readInt(8);
    final softVer = r.readInt(16);
    final supportRadio = r.readInt(1) == 1;
    final supportMediumPower = r.readInt(1) == 1;
    final fixedLocSpeakerVol = r.readInt(1) == 1;
    final notSupportSoftPowerCtrl = r.readInt(1) == 1;
    final haveNoSpeaker = r.readInt(1) == 1;
    final haveHmSpeaker = r.readInt(1) == 1;
    final regionCount = r.readInt(6);
    final supportNoaa = r.readInt(1) == 1;
    final gmrs = r.readInt(1) == 1;
    final supportVfo = r.readInt(1) == 1;
    final supportDmr = r.readInt(1) == 1;
    final channelCount = r.readInt(8);
    final freqRangeCount = r.readInt(4);
    bool supportNoiseReduction = false;
    bool supportSmartBeacon = false;
    if (r._bitOffset + 2 <= bytes.length * 8) {
      // Only if there are enough bits left for these optional fields
      supportNoiseReduction = r.readInt(1) == 1;
      supportSmartBeacon = r.readInt(1) == 1;
      r.skipBits(2); // _pad
    }

    return DeviceInfo(
      vendorId: vendorId,
      productId: productId,
      hwVer: hwVer,
      softVer: softVer,
      supportRadio: supportRadio,
      supportMediumPower: supportMediumPower,
      fixedLocSpeakerVol: fixedLocSpeakerVol,
      notSupportSoftPowerCtrl: notSupportSoftPowerCtrl,
      haveNoSpeaker: haveNoSpeaker,
      haveHmSpeaker: haveHmSpeaker,
      regionCount: regionCount,
      supportNoaa: supportNoaa,
      gmrs: gmrs,
      supportVfo: supportVfo,
      supportDmr: supportDmr,
      channelCount: channelCount,
      freqRangeCount: freqRangeCount,
      supportNoiseReduction: supportNoiseReduction,
      supportSmartBeacon: supportSmartBeacon,
    );
  }
}

// --- Channel Model (unchanged) ---
class Channel {
  final int channelId;
  final String name;
  final double rxFreq;
  final double txFreq;
  final String mode;
  final String tone;
  final String duplex;

  Channel({
    required this.channelId,
    required this.name,
    required this.rxFreq,
    required this.txFreq,
    this.mode = 'FM',
    this.tone = 'None',
    this.duplex = '',
  });

  factory Channel.fromBytes(Uint8List bytes) {
    final reader = ByteReader(bytes);
    int channelId = reader.readInt(8);
    reader.skipBits(2); // tx_mod
    double txFreq = reader.readInt(30) / 1e6;
    reader.skipBits(2); // rx_mod
    double rxFreq = reader.readInt(30) / 1e6;
    reader.skipBits(16); // tx_sub_audio
    reader.skipBits(16); // rx_sub_audio
    reader.skipBits(12); // various booleans and bandwidth
    reader.skipBits(4);
    String name = reader.readString(10);

    return Channel(channelId: channelId, name: name, rxFreq: rxFreq, txFreq: txFreq);
  }

  List<String> toChirpRow() {
    final offset = txFreq - rxFreq;
    final duplexChar = txFreq == rxFreq ? '' : (offset > 0 ? '+' : '-');
    return [
      (channelId + 1).toString(),
      name,
      rxFreq.toStringAsFixed(6),
      duplexChar,
      offset.abs().toStringAsFixed(6),
      'Tone', '88.5', '88.5', '023', 'NN', 'FM', 'S'
    ];
  }
}

// --- Specific Command Bodies ---
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
    final replyStatusInt = r.readInt(8);
    final replyStatus = ReplyStatus.fromInt(replyStatusInt);
    DeviceInfo? devInfo;
    if (replyStatus == ReplyStatus.SUCCESS) {
      final remainingBytes = bytes.sublist(1);
      devInfo = DeviceInfo.fromBytes(remainingBytes);
    }
    return GetDevInfoReplyBody(replyStatus: replyStatus, devInfo: devInfo);
  }

  @override
  Uint8List toBytes() => throw UnimplementedError();
}

class ReadRFChBody extends MessageBody {
  final int channelId;
  ReadRFChBody({required this.channelId});
  factory ReadRFChBody.fromBytes(Uint8List bytes) => ReadRFChBody(channelId: bytes[0]);
  @override
  Uint8List toBytes() => Uint8List.fromList([channelId]);
}

class ReadRFChReplyBody extends MessageBody {
  final Channel? rfCh;
  ReadRFChReplyBody({this.rfCh});
  factory ReadRFChReplyBody.fromBytes(Uint8List bytes) {
    return bytes[0] == 0 ? ReadRFChReplyBody(rfCh: Channel.fromBytes(bytes.sublist(1))) : ReadRFChReplyBody(rfCh: null);
  }
  @override
  Uint8List toBytes() => throw UnimplementedError();
}