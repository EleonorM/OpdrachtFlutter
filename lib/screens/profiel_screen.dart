import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:verhuurapp/services/auth_service.dart';
import 'package:verhuurapp/services/toestel_service.dart';
import 'package:verhuurapp/services/reservering_service.dart';

const _kBlue = Color(0xFF1E88E5);
const _kBlueLight = Color(0xFFE3F2FD);

class ProfielScreen extends StatelessWidget {
  const ProfielScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final authService = AuthService();
    final toestelService = ToestelService();
    final reserveringService = ReserveringService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mijn profiel'),
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: _kBlue,
                child: Text(
                  user.email!.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      fontSize: 36,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                user.email!,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
            // Statistieken
            Row(
              children: [
                Expanded(
                  child: StreamBuilder(
                    stream: toestelService.getMijnToestellen(user.uid),
                    builder: (context, snapshot) {
                      final aantal = snapshot.data?.length ?? 0;
                      return _StatCard(
                        label: 'Mijn toestellen',
                        waarde: '$aantal',
                        icoon: Icons.devices,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder(
                    stream: reserveringService.getMijnReserveringen(user.uid),
                    builder: (context, snapshot) {
                      final aantal = snapshot.data?.length ?? 0;
                      return _StatCard(
                        label: 'Mijn reserveringen',
                        waarde: '$aantal',
                        icoon: Icons.calendar_today,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Info sectie
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kBlueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _InfoRij(
                    icoon: Icons.email,
                    label: 'E-mailadres',
                    waarde: user.email!,
                  ),
                  const Divider(),
                  _InfoRij(
                    icoon: Icons.verified_user,
                    label: 'Account status',
                    waarde: user.emailVerified ? 'Geverifieerd' : 'Niet geverifieerd',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Uitloggen
            ElevatedButton.icon(
              onPressed: () async {
                await authService.logout();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Uitloggen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String waarde;
  final IconData icoon;

  const _StatCard(
      {required this.label, required this.waarde, required this.icoon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBlueLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icoon, color: _kBlue, size: 28),
          const SizedBox(height: 8),
          Text(
            waarde,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _kBlue),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InfoRij extends StatelessWidget {
  final IconData icoon;
  final String label;
  final String waarde;

  const _InfoRij(
      {required this.icoon, required this.label, required this.waarde});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icoon, color: _kBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12)),
                Text(waarde,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
