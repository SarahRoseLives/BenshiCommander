import 'dart:typed_data';
import 'dart:convert'; // Added missing import
import 'utils.dart';
import 'common.dart';

class DeviceInfo {
  final int vendorId;
  final int productId;
  final int hardwareVersion;
  final int firmwareVersion;
  final bool supportsRadio;
  final bool supportsMediumPower;
  final bool hasSpeaker;
  final bool supportsVfo;
  final bool supportsDmr;
  final int channelCount;
  final int frequencyRangeCount;

  DeviceInfo({
    required this.vendorId,
    required this.productId,
    required this.hardwareVersion,
    required this.firmwareVersion,
    required this.supportsRadio,
    required this.supportsMediumPower,
    required this.hasSpeaker,
    required this.supportsVfo,
    required this.supportsDmr,
    required this.channelCount,
    required this.frequencyRangeCount,
  });

  factory DeviceInfo.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final vendorId = r.readInt(8);
    final productId = r.readInt(16);
    final hwVer = r.readInt(8);
    final softVer = r.readInt(16);
    final supportsRadio = r.readBool();
    final supportsMediumPower = r.readBool();
    r.readBool(); // fixedLocSpeakerVol - Not used in UI
    r.readBool(); // notSupportSoftPowerCtrl - Not used in UI
    final hasSpeaker = !r.readBool(); // have_no_speaker
    r.readBool(); // haveHmSpeaker - Not used in UI
    r.readInt(6); // regionCount - Not used in UI
    r.readBool(); // supportNoaa - Not used in UI
    r.readBool(); // gmrs - Not used in UI
    final supportsVfo = r.readBool();
    final supportsDmr = r.readBool();
    final channelCount = r.readInt(8);
    final freqRangeCount = r.readInt(4);

    return DeviceInfo(
      vendorId: vendorId,
      productId: productId,
      hardwareVersion: hwVer,
      firmwareVersion: softVer,
      supportsRadio: supportsRadio,
      supportsMediumPower: supportsMediumPower,
      hasSpeaker: hasSpeaker,
      supportsVfo: supportsVfo,
      supportsDmr: supportsDmr,
      channelCount: channelCount,
      frequencyRangeCount: freqRangeCount,
    );
  }

  // Helpers for UI
  String get vendorName => {0x12: "Benshi", 0x21: "BTECH"}[vendorId] ?? 'Vendor($vendorId)';
  String get productName => {0x8001: "Commander Pro", 0x8002: "GMRS-PRO"}[productId] ?? 'Product($productId)';
}

class Status {
  static const bitLength = 2 * 8; // 2 bytes = 16 bits
  final bool isPowerOn;
  final bool isInTx;
  final bool isSq;
  final bool isInRx;
  final ChannelType doubleChannel;
  final bool isScan;
  final bool isRadio;
  final int currChIdLower;
  final bool isGpsLocked;
  final bool isHfpConnected;
  final bool isAocConnected;

  Status({
    required this.isPowerOn,
    required this.isInTx,
    required this.isSq,
    required this.isInRx,
    required this.doubleChannel,
    required this.isScan,
    required this.isRadio,
    required this.currChIdLower,
    required this.isGpsLocked,
    required this.isHfpConnected,
    required this.isAocConnected,
  });

  factory Status.fromReader(ByteReader r) {
    return Status(
      isPowerOn: r.readBool(),
      isInTx: r.readBool(),
      isSq: r.readBool(),
      isInRx: r.readBool(),
      doubleChannel: ChannelType.fromInt(r.readInt(2)),
      isScan: r.readBool(),
      isRadio: r.readBool(),
      currChIdLower: r.readInt(4),
      isGpsLocked: r.readBool(),
      isHfpConnected: r.readBool(),
      isAocConnected: r.readBool(),
    );
  }
}

class StatusExt extends Status {
  static const bitLengthExt = 4 * 8; // 4 bytes = 32 bits
  final double rssi;
  final int currRegion;
  final int currChannelIdUpper;

  StatusExt({
    required super.isPowerOn,
    required super.isInTx,
    required super.isSq,
    required super.isInRx,
    required super.doubleChannel,
    required super.isScan,
    required super.isRadio,
    required super.currChIdLower,
    required super.isGpsLocked,
    required super.isHfpConnected,
    required super.isAocConnected,
    required this.rssi,
    required this.currRegion,
    required this.currChannelIdUpper,
  });

  int get currentChannelId => (currChannelIdUpper << 4) | currChIdLower;

  factory StatusExt.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final baseStatus = Status.fromReader(r);
    r.skipBits(1); // unknown bit

    // Handle variable length status message
    if (r.remainingBits < 16) {
       return StatusExt(
         // copy from base
        isPowerOn: baseStatus.isPowerOn,
        isInTx: baseStatus.isInTx,
        isSq: baseStatus.isSq,
        isInRx: baseStatus.isInRx,
        doubleChannel: baseStatus.doubleChannel,
        isScan: baseStatus.isScan,
        isRadio: baseStatus.isRadio,
        currChIdLower: baseStatus.currChIdLower,
        isGpsLocked: baseStatus.isGpsLocked,
        isHfpConnected: baseStatus.isHfpConnected,
        isAocConnected: baseStatus.isAocConnected,
        // Defaults for extended fields
        rssi: 0.0,
        currRegion: 0,
        currChannelIdUpper: 0,
       );
    }

    return StatusExt(
      // copy from base
      isPowerOn: baseStatus.isPowerOn,
      isInTx: baseStatus.isInTx,
      isSq: baseStatus.isSq,
      isInRx: baseStatus.isInRx,
      doubleChannel: baseStatus.doubleChannel,
      isScan: baseStatus.isScan,
      isRadio: baseStatus.isRadio,
      currChIdLower: baseStatus.currChIdLower,
      isGpsLocked: baseStatus.isGpsLocked,
      isHfpConnected: baseStatus.isHfpConnected,
      isAocConnected: baseStatus.isAocConnected,
      // parse extended fields
      rssi: r.readInt(4) * (100.0 / 15.0),
      currRegion: r.readInt(6),
      currChannelIdUpper: r.readInt(4),
    );
  }
}

class Position {
  static const bitLength = 17 * 8;
  final double latitude;
  final double longitude;
  final int? altitude;
  final int? speed;
  final int? heading;
  final DateTime time;
  final int accuracy;

  Position({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.heading,
    required this.time,
    required this.accuracy,
  });

  factory Position.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final lat = r.readSignedInt(24) / (60.0 * 500.0);
    final lon = r.readSignedInt(24) / (60.0 * 500.0);
    final alt = r.readSignedInt(16);
    final spd = r.readInt(16);
    final hdg = r.readInt(16);
    final timeInt = r.readInt(32);
    final acc = r.readInt(16);
    return Position(
      latitude: lat,
      longitude: lon,
      altitude: alt == -32768 ? null : alt,
      speed: spd == 0xFFFF ? null : spd,
      heading: hdg == 0xFFFF ? null : hdg,
      time: DateTime.fromMillisecondsSinceEpoch(timeInt * 1000, isUtc: true),
      accuracy: acc,
    );
  }
}

// REPLACE the ENTIRE Channel class with the code below.

class Channel {
  final int channelId;
  final ModulationType txMod;
  final double txFreq;
  final ModulationType rxMod;
  final double rxFreq;
  final dynamic txSubAudio; // Can be double (CTCSS) or int (DCS)
  final dynamic rxSubAudio;
  final bool scan;
  final bool txAtMaxPower;
  final bool txAtMedPower;
  final BandwidthType bandwidth;
  final String name;

  // These fields are now correctly used in toBytes()
  final bool talkAround;
  final bool preDeEmphBypass;
  final bool sign;
  final bool txDisable;
  final bool fixedFreq;
  final bool fixedBandwidth;
  final bool fixedTxPower;
  final bool mute;

  Channel({
    required this.channelId,
    required this.txMod,
    required this.txFreq,
    required this.rxMod,
    required this.rxFreq,
    this.txSubAudio,
    this.rxSubAudio,
    required this.scan,
    required this.txAtMaxPower,
    required this.txAtMedPower,
    required this.bandwidth,
    required this.name,
    this.talkAround = false,
    this.preDeEmphBypass = false,
    this.sign = false,
    this.txDisable = false,
    this.fixedFreq = false,
    this.fixedBandwidth = false,
    this.fixedTxPower = false,
    this.mute = false,
  });

  factory Channel.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final channelId = r.readInt(8);
    final txMod = ModulationType.values[r.readInt(2)];
    final txFreq = r.readInt(30) / 1e6;
    final rxMod = ModulationType.values[r.readInt(2)];
    final rxFreq = r.readInt(30) / 1e6;
    final txSubAudioRaw = r.readInt(16);
    final rxSubAudioRaw = r.readInt(16);
    final scan = r.readBool();
    final txAtMaxPower = r.readBool();
    final talkAround = r.readBool();
    final bandwidth = BandwidthType.values[r.readInt(1)];
    final preDeEmphBypass = r.readBool();
    final sign = r.readBool();
    final txAtMedPower = r.readBool();
    final txDisable = r.readBool();
    final fixedFreq = r.readBool();
    final fixedBandwidth = r.readBool();
    final fixedTxPower = r.readBool();
    final mute = r.readBool();
    r.skipBits(4); // padding
    final name = r.readString(10);

    return Channel(
      channelId: channelId,
      txMod: txMod,
      txFreq: txFreq,
      rxMod: rxMod,
      rxFreq: rxFreq,
      txSubAudio: _parseSubAudio(txSubAudioRaw),
      rxSubAudio: _parseSubAudio(rxSubAudioRaw),
      scan: scan,
      txAtMaxPower: txAtMaxPower,
      talkAround: talkAround,
      bandwidth: bandwidth,
      preDeEmphBypass: preDeEmphBypass,
      sign: sign,
      txAtMedPower: txAtMedPower,
      txDisable: txDisable,
      name: name,
      fixedFreq: fixedFreq,
      fixedBandwidth: fixedBandwidth,
      fixedTxPower: fixedTxPower,
      mute: mute,
    );
  }

  static int _encodeSubAudio(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return (val * 100).round();
    return 0;
  }

  Uint8List toBytes() {
    final writer = ByteWriter(25); // 25 bytes = 208 bits
    writer.writeInt(channelId, 8);
    writer.writeInt(txMod.index, 2);
    writer.writeInt((txFreq * 1e6).round(), 30);
    writer.writeInt(rxMod.index, 2);
    writer.writeInt((rxFreq * 1e6).round(), 30);
    writer.writeInt(_encodeSubAudio(txSubAudio), 16);
    writer.writeInt(_encodeSubAudio(rxSubAudio), 16);
    writer.writeBool(scan);
    writer.writeBool(txAtMaxPower);
    writer.writeBool(talkAround);
    writer.writeInt(bandwidth.index, 1);
    writer.writeBool(preDeEmphBypass);
    writer.writeBool(sign);
    writer.writeBool(txAtMedPower);
    writer.writeBool(txDisable);
    writer.writeBool(fixedFreq);
    writer.writeBool(fixedBandwidth);
    writer.writeBool(fixedTxPower);
    writer.writeBool(mute);
    writer.writeInt(0, 4); // padding
    // Correctly handle name encoding to be exactly 10 bytes
    writer.writeBytes(utf8.encode(name.padRight(10, '\u0000').substring(0, 10)));
    return writer.toBytes();
  }

  Channel copyWith({
    int? channelId,
    ModulationType? txMod,
    double? txFreq,
    ModulationType? rxMod,
    double? rxFreq,
    dynamic txSubAudio,
    dynamic rxSubAudio,
    bool? scan,
    bool? txAtMaxPower,
    bool? txAtMedPower,
    BandwidthType? bandwidth,
    String? name,
    bool? talkAround,
    bool? preDeEmphBypass,
    bool? sign,
    bool? txDisable,
    bool? fixedFreq,
    bool? fixedBandwidth,
    bool? fixedTxPower,
    bool? mute,
  }) {
    return Channel(
      channelId: channelId ?? this.channelId,
      txMod: txMod ?? this.txMod,
      txFreq: txFreq ?? this.txFreq,
      rxMod: rxMod ?? this.rxMod,
      rxFreq: rxFreq ?? this.rxFreq,
      txSubAudio: txSubAudio, // Use the new value directly
      rxSubAudio: rxSubAudio, // Use the new value directly
      scan: scan ?? this.scan,
      txAtMaxPower: txAtMaxPower ?? this.txAtMaxPower,
      txAtMedPower: txAtMedPower ?? this.txAtMedPower,
      bandwidth: bandwidth ?? this.bandwidth,
      name: name ?? this.name,
      talkAround: talkAround ?? this.talkAround,
      preDeEmphBypass: preDeEmphBypass ?? this.preDeEmphBypass,
      sign: sign ?? this.sign,
      txDisable: txDisable ?? this.txDisable,
      fixedFreq: fixedFreq ?? this.fixedFreq,
      fixedBandwidth: fixedBandwidth ?? this.fixedBandwidth,
      fixedTxPower: fixedTxPower ?? this.fixedTxPower,
      mute: mute ?? this.mute,
    );
  }

  static dynamic _parseSubAudio(int val) {
    if (val == 0) return null;
    if (val < 6700) return val; // DCS code
    return val / 100.0; // CTCSS frequency
  }

  String get txPower {
     if (txAtMaxPower) return "High";
     if (txAtMedPower) return "Medium";
     return "Low";
  }

  String get txTone => _formatSubAudio(txSubAudio);
  String get rxTone => _formatSubAudio(rxSubAudio);

  static String _formatSubAudio(dynamic val) {
    if (val == null) return "None";
    if (val is int) return 'DCS $val';
    if (val is double) return '${val.toStringAsFixed(1)} Hz';
    return "Unknown";
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
      'Tone',
      '88.5',
      '88.5',
      '023',
      'NN',
      'FM',
      '5.000000',
      'High',
      'On',
    ];
  }
}

class Settings {
  final int channelA;
  final int channelB;
  final bool scan;
  final int squelchLevel;
  final int micGain;
  final int btMicGain;
  final bool supportsVfo; // Simplified for UI

  Settings({
    required this.channelA,
    required this.channelB,
    required this.scan,
    required this.squelchLevel,
    required this.micGain,
    required this.btMicGain,
    required this.supportsVfo,
  });

  factory Settings.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final channelALower = r.readInt(4);
    final channelBLower = r.readInt(4);
    final scan = r.readBool();
    r.skipBits(1); // aghfp_call_mode
    r.skipBits(2); // double_channel
    final squelchLevel = r.readInt(4);
    r.skipBits(12);
    final micGain = r.readInt(3);
    r.skipBits(9);
    final btMicGain = r.readInt(3);
    r.skipBits(22);
    final vfoX = r.readInt(2);
    r.skipBits(1);
    final channelAUpper = r.readInt(4);
    final channelBUpper = r.readInt(4);
    // This is a rough approximation, as true VFO support is in device info.
    // This setting just determines which VFO is active if any.
    final supportsVfo = vfoX > 0;

    return Settings(
      channelA: (channelAUpper << 4) | channelALower,
      channelB: (channelBUpper << 4) | channelBLower,
      scan: scan,
      squelchLevel: squelchLevel,
      micGain: micGain,
      btMicGain: btMicGain,
      supportsVfo: supportsVfo,
    );
  }

  Uint8List toBytes() {
    // This is a simplified implementation for demonstration.
    // A full implementation would require tracking all fields.
    final w = ByteWriter(20); // Correct size for full settings
    // This would write all the fields back out. For now, it's not needed
    // for scanner functionality, which is primarily read-only or simple sets.
    return w.toBytes();
  }
}