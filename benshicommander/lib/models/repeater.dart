import '../benshi/protocol/protocol.dart';

class Repeater {
  final String callsign;
  final double outputFrequency; // RX Freq
  final double inputFrequency;  // TX Freq
  final String uplinkTone;
  final String downlinkTone;
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
    // Helper to get a value regardless of key format (e.g., snake_case vs. Title Case)
    dynamic getValue(String key1, String key2) {
      return json[key1] ?? json[key2];
    }

    // Safely parse the output frequency (RX)
    final outputFreq = double.tryParse(getValue('frequency', 'Frequency')?.toString() ?? '0.0') ?? 0.0;

    // Safely parse the input frequency (TX)
    double inputFreq = double.tryParse(getValue('input_frequency', 'Input Frequency')?.toString() ?? '0.0') ?? 0.0;

    // If TX frequency is 0, calculate it from the offset and duplex direction
    if (inputFreq == 0.0) {
        final double offsetVal = double.tryParse(getValue('offset', 'Offset')?.toString() ?? '0.0') ?? 0.0;
        final String duplex = getValue('duplex', 'Duplex')?.toString() ?? '';

        if (offsetVal != 0.0 && duplex.isNotEmpty && (duplex == '+' || duplex == '-')) {
            inputFreq = duplex == '+' ? outputFreq + offsetVal : outputFreq - offsetVal;
        } else {
            // Assume simplex if no offset/duplex info is available
            inputFreq = outputFreq;
        }
    }

    return Repeater(
      callsign: getValue('callsign', 'Callsign')?.toString() ?? 'N/A',
      outputFrequency: outputFreq,
      inputFrequency: inputFreq,
      uplinkTone: getValue('uplink_tone', 'PL/CTCSS Uplink')?.toString() ?? 'None',
      downlinkTone: getValue('downlink_tone', 'PL/CTCSS TSQ Downlink')?.toString() ?? 'None',
      name: getValue('nearest_city', 'Location/Nearest City')?.toString() ?? 'Repeater',
      latitude: double.tryParse(getValue('lat', 'Latitude')?.toString() ?? '0.0') ?? 0.0,
      longitude: double.tryParse(getValue('lng', 'Longitude')?.toString() ?? '0.0') ?? 0.0,
    );
  }

  // Helper to convert a Repeater into a radio Channel
  Channel toChannel(int channelId) {
    dynamic rxSubAudio;
    dynamic txSubAudio;

    // Parse RX subaudio from the repeater's downlink tone
    if (double.tryParse(downlinkTone) != null) {
      rxSubAudio = double.parse(downlinkTone);
    } else if (downlinkTone.startsWith('D') && downlinkTone.length >= 4) {
      // Handles DCS codes like "D023N"
      rxSubAudio = int.tryParse(downlinkTone.substring(1, 4));
    }

    // Parse TX subaudio from the repeater's uplink tone
    if (double.tryParse(uplinkTone) != null) {
      txSubAudio = double.parse(uplinkTone);
    } else if (uplinkTone.startsWith('D') && uplinkTone.length >= 4) {
      txSubAudio = int.tryParse(uplinkTone.substring(1, 4));
    }

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
      bandwidth: BandwidthType.WIDE, // Correctly set to WIDE for ham repeaters
      name: callsign.length > 10 ? callsign.substring(0, 10) : callsign,
    );
  }
}