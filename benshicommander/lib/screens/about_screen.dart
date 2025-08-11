import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'donation_screen.dart'; // Import the DonationScreen

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removed AppBar with "About" header
      body: ListView(
        children: <Widget>[
          const SizedBox(height: 20),
          const Center(
            child: FlutterLogo(size: 80),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              _packageInfo.appName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Version: ${_packageInfo.version}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 40),

          // --- NEW: Support the Project Section ---
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            color: Colors.blue.shade50,
            elevation: 0,
            child: ListTile(
              leading: Icon(Icons.favorite, color: Colors.red.shade400),
              title: const Text('Support This Project', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('If you find this app useful, consider a donation to support its development.'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const DonationScreen()),
                );
              },
            ),
          ),
          const Divider(height: 40),

          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('View Licenses'),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: _packageInfo.appName,
                applicationVersion: _packageInfo.version,
                applicationIcon: const FlutterLogo(),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'About SarahRose',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              "Hi! I'm SarahRose, the developer of this app. I’m passionate about building useful and delightful software, and I hope you enjoy using this app as much as I enjoyed creating it. If you have feedback, suggestions, or just want to connect, feel free to reach out!",
              style: TextStyle(fontSize: 16.0),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}