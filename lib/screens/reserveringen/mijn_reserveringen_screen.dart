import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:verhuurapp/models/reservering.dart';
import 'package:verhuurapp/services/reservering_service.dart';

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
                          Text(
                            reservering.toestelNaam,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
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
                            '${reservering.startDatum.day}/${reservering.startDatum.month}/${reservering.startDatum.year} → ${reservering.eindDatum.day}/${reservering.eindDatum.month}/${reservering.eindDatum.year}',
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
                          const Icon(Icons.euro,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            '€${reservering.totalePrijs.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
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
        color: kleur.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kleur),
      ),
      child: Text(
        status,
        style: TextStyle(color: kleur, fontWeight: FontWeight.bold),
      ),
    );
  }
}