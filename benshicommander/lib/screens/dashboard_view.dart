import 'package:flutter/material.dart';
import '../benshi/radio_controller.dart';
import '../benshi/protocol/protocol.dart'; // Added this import
import 'package:intl/intl.dart';

class DashboardView extends StatefulWidget {
  final RadioController radioController;
  const DashboardView({Key? key, required this.radioController}) : super(key: key);

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  @override
  void initState() {
    super.initState();
    widget.radioController.addListener(_onRadioUpdate);
  }

  @override
  void dispose() {
    widget.radioController.removeListener(_onRadioUpdate);
    super.dispose();
  }

  void _onRadioUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  // --- UI Helper Methods ---
  Color getActivityColor(bool isTx, bool isRx) {
    if (isTx) return Colors.red;
    if (isRx) return Colors.green;
    return Colors.grey;
  }

  IconData getActivityIcon(bool isTx, bool isRx) {
    if (isTx) return Icons.upload_rounded;
    if (isRx) return Icons.download_rounded;
    return Icons.pause_circle_filled_rounded;
  }

  String getActivityText(bool isTx, bool isRx) {
    if (isTx) return "Transmitting";
    if (isRx) return "Receiving";
    return "Idle";
  }

  @override
  Widget build(BuildContext context) {
    final radio = widget.radioController;

    if (!radio.isReady) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ======= Real-Time Radio Status =======
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.radio, color: radio.isPowerOn ? Colors.blue : Colors.grey, size: 32),
                      const SizedBox(width: 12),
                      Text(
                        radio.isPowerOn ? "Power: ON" : "Power: OFF",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: radio.isPowerOn ? Colors.blue : Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      Icon(getActivityIcon(radio.isInTx, radio.isInRx),
                          color: getActivityColor(radio.isInTx, radio.isInRx), size: 28),
                      const SizedBox(width: 4),
                      Text(getActivityText(radio.isInTx, radio.isInRx),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: getActivityColor(radio.isInTx, radio.isInRx),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // RSSI Bar and Value
                  Row(
                    children: [
                      const Icon(Icons.network_cell, color: Colors.blueGrey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (radio.rssi) / 100, // RSSI is 0-100 now
                          backgroundColor: Colors.grey.shade300,
                          color: Colors.blueAccent,
                          minHeight: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${radio.rssi.toStringAsFixed(0)}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Text("RSSI"),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _StatusChip(
                        icon: Icons.settings_voice_rounded,
                        label: "Squelch: ${radio.isSq ? "Open" : "Closed"}",
                        color: radio.isSq ? Colors.green : Colors.grey,
                      ),
                      _StatusChip(
                        icon: Icons.sync_rounded,
                        label: radio.isScan ? "Scanning" : "Not Scanning",
                        color: radio.isScan ? Colors.orange : Colors.grey,
                      ),
                      _StatusChip(
                        icon: Icons.visibility,
                        label: "Dual Watch: ${radio.status?.doubleChannel.name ?? 'OFF'}",
                        color: radio.status?.doubleChannel == ChannelType.OFF ? Colors.grey : Colors.blue,
                      ),
                      _StatusChip(
                        icon: Icons.confirmation_num,
                        label: "Channel: ${radio.currentChannelId + 1}", // Show 1-based index
                        color: Colors.indigo,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ===== Channel Information =====
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.list_alt, color: Colors.deepPurple, size: 28),
                      const SizedBox(width: 8),
                      Text("Channel Info", style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                  const Divider(),
                  Text(
                    radio.currentChannelName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoTile(
                        icon: Icons.arrow_downward,
                        label: "RX",
                        value: "${radio.currentRxFreq.toStringAsFixed(4)} MHz",
                      ),
                      _InfoTile(
                        icon: Icons.arrow_upward,
                        label: "TX",
                        value: "${radio.currentChannel?.txFreq.toStringAsFixed(4) ?? 'N/A'} MHz",
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                        _StatusChip(
                          icon: Icons.waves,
                          label: "BW: ${radio.currentChannel?.bandwidth.name ?? 'N/A'}",
                          color: Colors.teal,
                        ),
                        _StatusChip(
                          icon: Icons.music_note,
                          label: "RX Tone: ${radio.currentChannel?.rxTone ?? 'N/A'}",
                          color: Colors.blueGrey,
                        ),
                        _StatusChip(
                          icon: Icons.music_note_outlined,
                          label: "TX Tone: ${radio.currentChannel?.txTone ?? 'N/A'}",
                          color: Colors.blueGrey,
                        ),
                        _StatusChip(
                          icon: Icons.bolt,
                          label: "TX Power: ${radio.currentChannel?.txPower ?? 'N/A'}",
                          color: radio.currentChannel?.txPower == "High"
                              ? Colors.red
                              : (radio.currentChannel?.txPower == "Medium" ? Colors.amber : Colors.green),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ======= GPS & Location =======
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.gps_fixed, color: Colors.green, size: 28),
                      const SizedBox(width: 8),
                      Text("GPS & Location", style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                  const Divider(),
                  Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _StatusChip(
                        icon: Icons.satellite_alt,
                        label: radio.isGpsLocked ? "GPS: Locked" : "GPS: Searching",
                        color: radio.isGpsLocked ? Colors.green : Colors.grey,
                      ),
                      _StatusChip(
                        icon: Icons.location_on,
                        label: "Lat: ${radio.gps?.latitude.toStringAsFixed(5) ?? 'N/A'}",
                        color: Colors.blue,
                      ),
                      _StatusChip(
                        icon: Icons.location_on_outlined,
                        label: "Lon: ${radio.gps?.longitude.toStringAsFixed(5) ?? 'N/A'}",
                        color: Colors.blue,
                      ),
                      _StatusChip(
                        icon: Icons.speed,
                        label: "Speed: ${radio.gps?.speed ?? 'N/A'} km/h",
                        color: Colors.amber,
                      ),
                      _StatusChip(
                        icon: Icons.navigation,
                        label: "Heading: ${radio.gps?.heading ?? 'N/A'}°",
                        color: Colors.purple,
                      ),
                      _StatusChip(
                        icon: Icons.height,
                        label: "Alt: ${radio.gps?.altitude ?? 'N/A'} m",
                        color: Colors.teal,
                      ),
                      _StatusChip(
                        icon: Icons.precision_manufacturing,
                        label: "Accuracy: ${radio.gps?.accuracy ?? 'N/A'} m",
                        color: Colors.deepOrange,
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      radio.gps != null ? "Last Fix: ${DateFormat.yMd().add_Hms().format(radio.gps!.time.toLocal())}" : "Last Fix: N/A",
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ======= Device & Settings =======
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings, color: Colors.indigo, size: 28),
                      const SizedBox(width: 8),
                      Text("Device & Settings", style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      _InfoTile(
                        icon: Icons.battery_full,
                        label: "Voltage",
                        value: "${radio.batteryVoltage?.toStringAsFixed(2) ?? 'N/A'} V",
                      ),
                      _InfoTile(
                        icon: Icons.battery_charging_full,
                        label: "Battery",
                        value: "${radio.batteryLevelAsPercentage ?? 'N/A'}%",
                      ),
                      _InfoTile(
                        icon: Icons.bluetooth,
                        label: "HFP",
                        value: (radio.status?.isHfpConnected ?? false) ? "Connected" : "Not Connected",
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoTile(
                        icon: Icons.mic,
                        label: "Mic Gain",
                        value: "${radio.settings?.micGain ?? 'N/A'}",
                      ),
                      _InfoTile(
                        icon: Icons.mic_external_on,
                        label: "BT Mic Gain",
                        value: "${radio.settings?.btMicGain ?? 'N/A'}",
                      ),
                       _InfoTile(
                        icon: Icons.volume_up,
                        label: "Squelch",
                        value: "${radio.settings?.squelchLevel ?? 'N/A'}",
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // About Section
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        "About",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _AboutChip(label: "Vendor: ${radio.deviceInfo?.vendorName ?? 'N/A'}"),
                      _AboutChip(label: "Product: ${radio.deviceInfo?.productName ?? 'N/A'}"),
                      _AboutChip(label: "HW: v${radio.deviceInfo?.hardwareVersion ?? 'N/A'}"),
                      _AboutChip(label: "FW: v${radio.deviceInfo?.firmwareVersion ?? 'N/A'}"),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Custom Widget Components ---
class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusChip({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      backgroundColor: color.withOpacity(0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withOpacity(0.2))
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

class _AboutChip extends StatelessWidget {
  final String label;
  const _AboutChip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Chip(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.grey.shade200,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}