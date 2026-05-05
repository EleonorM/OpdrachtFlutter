import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:verhuurapp/models/reservering.dart';
import 'package:verhuurapp/services/reservering_service.dart';

const _kBlue = Color(0xFF1E88E5);

class MijnReserveringenScreen extends StatelessWidget {
  const MijnReserveringenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final ReserveringService reserveringService = ReserveringService();

    return Scaffold(
      body: StreamBuilder<List<Reservering>>(
        stream: reserveringService.getMijnReserveringen(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Geen reserveringen gevonden.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final reserveringen = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reserveringen.length,
            itemBuilder: (context, index) {
              final reservering = reserveringen[index];
              final kanAnnuleren = reservering.status == 'In afwachting' ||
                  reservering.status == 'Goedgekeurd';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              reservering.toestelNaam,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          _statusBadge(reservering.status),
                        ],
                      ),
                      const Divider(),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            '${_fmt(reservering.startDatum)} → ${_fmt(reservering.eindDatum)}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            '${reservering.aantalDagen} dagen',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.euro, size: 16, color: _kBlue),
                          const SizedBox(width: 8),
                          Text(
                            '€${reservering.totalePrijs.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: _kBlue,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (kanAnnuleren) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final bevestigd = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Reservering annuleren'),
                                  content: const Text(
                                      'Weet je zeker dat je deze reservering wilt annuleren?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Nee'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Ja, annuleren',
                                          style:
                                              TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (bevestigd == true && context.mounted) {
                                await reserveringService
                                    .reserveringAnnuleren(reservering.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Reservering geannuleerd.'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            label: const Text('Annuleren',
                                style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Widget _statusBadge(String status) {
    Color kleur;
    switch (status) {
      case 'Goedgekeurd':
        kleur = Colors.green;
        break;
      case 'Geweigerd':
      case 'Geannuleerd':
        kleur = Colors.red;
        break;
      default:
        kleur = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kleur),
      ),
      child: Text(
        status,
        style: TextStyle(color: kleur, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
