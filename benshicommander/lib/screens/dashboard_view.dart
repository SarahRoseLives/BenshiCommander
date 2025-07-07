import 'package:flutter/material.dart';
import '../benshi/radio_controller.dart';
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
    // Listen for changes in the controller to rebuild the UI
    widget.radioController.addListener(_onRadioUpdate);
  }

  @override
  void dispose() {
    // Clean up the listener when the widget is removed
    widget.radioController.removeListener(_onRadioUpdate);
    super.dispose();
  }

  void _onRadioUpdate() {
    // This triggers a rebuild of the widget with the new data
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
    // Use the radioController from the widget, which is always the same instance
    final radio = widget.radioController;

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
                      Icon(Icons.network_cell, color: Colors.blueGrey),
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
                        label: "Dual Watch: ${radio.doubleChannel}",
                        color: radio.doubleChannel == "OFF" ? Colors.grey : Colors.blue,
                      ),
                      _StatusChip(
                        icon: Icons.confirmation_num,
                        label: "Channel: ${radio.currChId + 1}", // Show 1-based index
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
                      Icon(Icons.list_alt, color: Colors.deepPurple, size: 28),
                      const SizedBox(width: 8),
                      Text("Channel Info", style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                  const Divider(),
                  Text(
                    radio.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoTile(
                        icon: Icons.arrow_downward,
                        label: "RX",
                        value: "${radio.rxFreq.toStringAsFixed(4)} MHz",
                      ),
                      _InfoTile(
                        icon: Icons.arrow_upward,
                        label: "TX",
                        value: "${radio.txFreq.toStringAsFixed(4)} MHz",
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
                        label: "BW: ${radio.bandwidth}",
                        color: Colors.teal,
                      ),
                      _StatusChip(
                        icon: Icons.music_note,
                        label: "RX Tone: ${radio.rxTone}",
                        color: Colors.blueGrey,
                      ),
                      _StatusChip(
                        icon: Icons.music_note_outlined,
                        label: "TX Tone: ${radio.txTone}",
                        color: Colors.blueGrey,
                      ),
                      _StatusChip(
                        icon: Icons.bolt,
                        label: "TX Power: ${radio.txPower}",
                        color: radio.txPower == "High"
                            ? Colors.red
                            : (radio.txPower == "Medium" ? Colors.amber : Colors.green),
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
                      Icon(Icons.gps_fixed, color: Colors.green, size: 28),
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
                        label: "Lat: ${radio.latitude.toStringAsFixed(5)}",
                        color: Colors.blue,
                      ),
                      _StatusChip(
                        icon: Icons.location_on_outlined,
                        label: "Lon: ${radio.longitude.toStringAsFixed(5)}",
                        color: Colors.blue,
                      ),
                      _StatusChip(
                        icon: Icons.speed,
                        label: "Speed: ${radio.speed} km/h",
                        color: Colors.amber,
                      ),
                      _StatusChip(
                        icon: Icons.navigation,
                        label: "Heading: ${radio.heading}°",
                        color: Colors.purple,
                      ),
                      _StatusChip(
                        icon: Icons.height,
                        label: "Alt: ${radio.altitude} m",
                        color: Colors.teal,
                      ),
                      _StatusChip(
                        icon: Icons.precision_manufacturing,
                        label: "Accuracy: ${radio.accuracy} m",
                        color: Colors.deepOrange,
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      "Last Fix: ${DateFormat.yMd().add_Hms().format(radio.time.toLocal())}",
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
                      Icon(Icons.settings, color: Colors.indigo, size: 28),
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
                        value: "${radio.batteryVoltage.toStringAsFixed(2)} V",
                      ),
                      _InfoTile(
                        icon: Icons.battery_charging_full,
                        label: "Battery",
                        value: "${radio.batteryLevelAsPercentage}%",
                      ),
                      _InfoTile(
                        icon: Icons.bluetooth,
                        label: "HFP",
                        value: radio.isHfpConnected ? "Connected" : "Not Connected",
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoTile(
                        icon: Icons.mic,
                        label: "Mic Gain",
                        value: "${radio.micGain}",
                      ),
                      _InfoTile(
                        icon: Icons.mic_external_on,
                        label: "BT Mic Gain",
                        value: "${radio.btMicGain}",
                      ),
                      _InfoTile(
                        icon: Icons.volume_up,
                        label: "Squelch",
                        value: "${radio.squelchLevel}",
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
                      _AboutChip(label: "Vendor: ${radio.vendorId}"),
                      _AboutChip(label: "Product: ${radio.productId}"),
                      _AboutChip(label: "HW: ${radio.hardwareVersion}"),
                      _AboutChip(label: "FW: ${radio.firmwareVersion}"),
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