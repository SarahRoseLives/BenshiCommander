// screens/donation_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/donation_service.dart';

class DonationScreen extends StatelessWidget {
  const DonationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final donationService = Provider.of<DonationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support the Project'),
      ),
      body: donationService.loading
          ? const Center(child: CircularProgressIndicator())
          : !donationService.isAvailable || donationService.products.isEmpty
              ? _buildUnavailableView()
              : _buildDonationView(context, donationService),
    );
  }

  Widget _buildDonationView(BuildContext context, DonationService service) {
    // Separate one-time from subscriptions
    final oneTimeDonations = service.products.where((p) => p.id == 'donation_coffee').toList();
    final subscriptions = service.products.where((p) => p.id != 'donation_coffee').toList();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Icon(Icons.local_cafe, size: 80, color: Colors.brown),
        const SizedBox(height: 16),
        Text(
          'Thank you for considering a donation!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Your support helps cover development costs and encourages future updates and new features. Every little bit helps!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const Divider(height: 40),

        if (oneTimeDonations.isNotEmpty) ...[
          const Text('One-Time Donation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...oneTimeDonations.map((product) => Card(
                child: ListTile(
                  title: Text(product.title),
                  subtitle: Text(product.description),
                  trailing: ElevatedButton(
                    child: Text(product.price),
                    onPressed: () => service.makePurchase(product),
                  ),
                ),
              )),
          const Divider(height: 40),
        ],

        if (subscriptions.isNotEmpty) ...[
          const Text('Ongoing Support (Subscription)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...subscriptions.map((product) => Card(
                child: ListTile(
                  title: Text(product.title),
                  subtitle: Text(product.description),
                  trailing: ElevatedButton(
                    child: Text(product.price),
                    onPressed: () => service.makePurchase(product),
                  ),
                ),
              )),
        ]
      ],
    );
  }

  Widget _buildUnavailableView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Text(
          'In-app purchases are currently unavailable. Please make sure you are logged into a valid Google account and have the latest version of the Play Store.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}