import 'dart:typed_data';
import 'utils.dart';
import 'common.dart';

class DeviceInfo {
  final String vendorId;
  final String productId;
  final String hwVer;
  final String softVer;
  final int channelCount;

  DeviceInfo({
    required this.vendorId,
    required this.productId,
    required this.hwVer,
    required this.softVer,
    required this.channelCount,
  });

  factory DeviceInfo.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final vendorMap = {0x12: "Benshi", 0x21: "BTECH"};
    final productMap = {0x8001: "Commander Pro", 0x8002: "GMRS-PRO"};
    final vendorIdInt = r.readInt(8);
    final productIdInt = r.readInt(16);
    final hwVer = r.readInt(8);
    final softVer = r.readInt(16);
    r.skipBits(16);
    final channelCount = r.readInt(8);
    return DeviceInfo(
      vendorId: vendorMap[vendorIdInt] ?? 'Vendor($vendorIdInt)',
      productId: productMap[productIdInt] ?? 'Product($productIdInt)',
      hwVer: 'v$hwVer',
      softVer: 'v$softVer',
      channelCount: channelCount,
    );
  }
}

class StatusExt {
  final bool isPowerOn;
  final bool isInTx;
  final bool isSq;
  final bool isInRx;
  final ChannelType doubleChannel;
  final bool isScan;
  final bool isRadio;
  final int currChId;
  final bool isGpsLocked;
  final bool isHfpConnected;
  final double rssi;

  StatusExt({
    required this.isPowerOn,
    required this.isInTx,
    required this.isSq,
    required this.isInRx,
    required this.doubleChannel,
    required this.isScan,
    required this.isRadio,
    required this.currChId,
    required this.isGpsLocked,
    required this.isHfpConnected,
    required this.rssi,
  });

  factory StatusExt.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final isPowerOn = r.readBool();
    final isInTx = r.readBool();
    final isSq = r.readBool();
    final isInRx = r.readBool();
    final doubleChannel = ChannelType.fromInt(r.readInt(2));
    final isScan = r.readBool();
    final isRadio = r.readBool();
    final currChIdLower = r.readInt(4);
    final isGpsLocked = r.readBool();
    final isHfpConnected = r.readBool();
    r.readBool(); // unknown bit
    r.readBool(); // aoc_connected bit (not used in UI)
    final rssi = r.readInt(4) * (100.0 / 15.0);
    r.readInt(6); // curr_region
    final currChIdUpper = r.readInt(4);
    r.skipBits(2); // padding
    return StatusExt(
      isPowerOn: isPowerOn,
      isInTx: isInTx,
      isSq: isSq,
      isInRx: isInRx,
      doubleChannel: doubleChannel,
      isScan: isScan,
      isRadio: isRadio,
      currChId: (currChIdUpper << 4) | currChIdLower,
      isGpsLocked: isGpsLocked,
      isHfpConnected: isHfpConnected,
      rssi: rssi,
    );
  }
}

class Position {
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

class Channel {
  final int channelId;
  final String name;
  final double rxFreq;
  final double txFreq;
  final String bandwidth;
  final String txPower;
  final String rxTone;
  final String txTone;

  Channel({
    required this.channelId,
    required this.name,
    required this.rxFreq,
    required this.txFreq,
    required this.bandwidth,
    required this.txPower,
    required this.rxTone,
    required this.txTone,
  });

  factory Channel.fromBytes(Uint8List bytes) {
    final r = ByteReader(bytes);
    final channelId = r.readInt(8);
    r.skipBits(2);
    final txFreq = r.readInt(30) / 1e6;
    r.skipBits(2);
    final rxFreq = r.readInt(30) / 1e6;
    final txSubAudio = r.readInt(16);
    final rxSubAudio = r.readInt(16);
    r.readBool();
    final txAtMaxPower = r.readBool();
    r.readBool();
    final bandwidth = r.readBool() ? "WIDE" : "NARROW";
    r.skipBits(3);
    final txAtMedPower = r.readBool();
    r.skipBits(8);
    final name = r.readString(10);
    return Channel(
      channelId: channelId,
      name: name,
      rxFreq: rxFreq,
      txFreq: txFreq,
      bandwidth: bandwidth,
      txPower: txAtMaxPower
          ? "High"
          : (txAtMedPower ? "Medium" : "Low"),
      rxTone: _formatSubAudio(rxSubAudio),
      txTone: _formatSubAudio(txSubAudio),
    );
  }

  static String _formatSubAudio(int val) {
    if (val == 0) return "None";
    if (val < 6700) return 'DCS $val';
    return '${(val / 100).toStringAsFixed(1)} Hz';
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