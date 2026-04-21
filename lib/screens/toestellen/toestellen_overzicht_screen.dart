import 'package:flutter/material.dart';
import 'package:verhuurapp/models/toestel.dart';
import 'package:verhuurapp/services/toestel_service.dart';
import 'package:verhuurapp/screens/toestellen/toestel_detail_screen.dart';
import 'package:verhuurapp/screens/toestellen/toestel_toevoegen_screen.dart';

class ToestellenOverzichtScreen extends StatefulWidget {
  const ToestellenOverzichtScreen({super.key});

  @override
  State<ToestellenOverzichtScreen> createState() =>
      _ToestellenOverzichtScreenState();
}

class _ToestellenOverzichtScreenState
    extends State<ToestellenOverzichtScreen> {
  final ToestelService _toestelService = ToestelService();
  String _geselecteerdeCategorie = 'Alle';

  final List<String> _categorieen = [
    'Alle',
    'Stofzuiger',
    'Grasmaaier',
    'Keukenmachine',
    'Boormachine',
    'Ladder',
    'Hogedrukreiniger',
    'Andere',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toestellen'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Categorie filter
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categorieen.length,
              itemBuilder: (context, index) {
                final categorie = _categorieen[index];
                final isGeselecteerd =
                    categorie == _geselecteerdeCategorie;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(categorie),
                    selected: isGeselecteerd,
                    onSelected: (_) {
                      setState(
                          () => _geselecteerdeCategorie = categorie);
                    },
                    selectedColor: Colors.green.shade100,
                    checkmarkColor: Colors.green,
                  ),
                );
              },
            ),
          ),
          // Toestellen lijst
          Expanded(
            child: StreamBuilder<List<Toestel>>(
              stream: _geselecteerdeCategorie == 'Alle'
                  ? _toestelService.getAlleToestellen()
                  : _toestelService
                      .getToestellenPerCategorie(_geselecteerdeCategorie),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.devices_other,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Geen toestellen gevonden.',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                final toestellen = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: toestellen.length,
                  itemBuilder: (context, index) {
                    final toestel = toestellen[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: const Icon(Icons.devices,
                              color: Colors.green),
                        ),
                        title: Text(
                          toestel.naam,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(toestel.categorie),
                            const SizedBox(height: 4),
                            Text(
                              '€${toestel.prijs.toStringAsFixed(2)} per dag',
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: toestel.beschikbaarheid == 'Beschikbaar'
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            toestel.beschikbaarheid,
                            style: TextStyle(
                              color:
                                  toestel.beschikbaarheid == 'Beschikbaar'
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ToestelDetailScreen(toestel: toestel),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ToestelToevoegenScreen(),
            ),
          );
        },
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Toestel toevoegen'),
      ),
    );
  }
}