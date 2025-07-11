import '../benshi/protocol/protocol.dart';

class Repeater {
  final String callsign;
  final double outputFrequency; // RX Freq (what you listen to)
  final double inputFrequency;  // TX Freq (what you transmit on)
  final String uplinkTone;      // TX tone (to access the repeater)
  final String downlinkTone;    // RX tone (from repeater, for squelch)
  final String name;
  final double latitude;
  final double longitude;

  Repeater({
    required this.callsign,
    required this.outputFrequency,
    required this.inputFrequency,
    required this.uplinkTone,
    required this.downlinkTone,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory Repeater.fromJson(Map<String, dynamic> json) {
    // Direct mapping for RepeaterBook API fields based on your sample JSON

    // RX frequency (what you listen to)
    final double outputFreq = double.tryParse(
      (json['Frequency'] ?? json['frequency'] ?? '').toString()
    ) ?? 0.0;

    // TX frequency (what you transmit on)
    final double inputFreq = double.tryParse(
      (json['Input Freq'] ?? json['input_frequency'] ?? json['Input Frequency'] ?? '').toString()
    ) ?? 0.0;

    // TX tone (to access the repeater)
    final String uplinkTone = (json['PL'] ?? json['PL/CTCSS Uplink'] ?? '').toString().trim();
    // RX tone (for squelch, optional)
    final String downlinkTone = (json['TSQ'] ?? json['PL/CTCSS TSQ Downlink'] ?? '').toString().trim();

    // Name/location
    final String name = (json['Nearest City'] ?? json['nearest_city'] ?? json['Location/Nearest City'] ?? json['city'] ?? '').toString();

    // Latitude/Longitude
    final double latitude = double.tryParse(
      (json['Lat'] ?? json['lat'] ?? json['latitude'] ?? '').toString()
    ) ?? 0.0;
    final double longitude = double.tryParse(
      (json['Long'] ?? json['lng'] ?? json['longitude'] ?? '').toString()
    ) ?? 0.0;

    // Callsign
    final String callsign = (json['Callsign'] ?? json['callsign'] ?? '').toString();

    return Repeater(
      callsign: callsign.isNotEmpty ? callsign : 'N/A',
      outputFrequency: outputFreq,
      inputFrequency: inputFreq,
      uplinkTone: uplinkTone.isNotEmpty ? uplinkTone : 'None',
      downlinkTone: downlinkTone.isNotEmpty ? downlinkTone : 'None',
      name: name.isNotEmpty ? name : 'Repeater',
      latitude: latitude,
      longitude: longitude,
    );
  }

  // Convert a Repeater into a radio Channel
  Channel toChannel(int channelId) {
    dynamic rxSubAudio;
    dynamic txSubAudio;

    // Parse RX subaudio from the repeater's downlink tone
    rxSubAudio = _parseToneField(downlinkTone);

    // Parse TX subaudio from the repeater's uplink tone
    txSubAudio = _parseToneField(uplinkTone);

    return Channel(
      channelId: channelId,
      txMod: ModulationType.FM,
      txFreq: inputFrequency,
      rxMod: ModulationType.FM,
      rxFreq: outputFrequency,
      txSubAudio: txSubAudio,
      rxSubAudio: rxSubAudio,
      scan: false,
      txAtMaxPower: true,
      txAtMedPower: false,
      bandwidth: BandwidthType.WIDE, // Ham repeaters use wide FM
      name: callsign.length > 10 ? callsign.substring(0, 10) : callsign,
    );
  }

  // Helpers for tone parsing
  static dynamic _parseToneField(String tone) {
    final t = tone.trim();
    if (t.isEmpty || t.toLowerCase() == 'none' || t == '-') return null;
    // DCS format: D023N, D023, D654, D054N etc.
    if (t.startsWith('D') && t.length >= 4 && RegExp(r'^D\d{3}[A-Z]?$').hasMatch(t)) {
      // Parse just the numeric part
      final dcsNum = int.tryParse(t.substring(1, 4));
      return dcsNum;
    }
    // CTCSS/PL: 88.5, 151.4, etc.
    final ctcssVal = double.tryParse(t);
    if (ctcssVal != null) return ctcssVal;
    return null;
  }
}