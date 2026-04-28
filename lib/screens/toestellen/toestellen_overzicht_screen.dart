import 'package:flutter/material.dart';
import 'package:verhuurapp/models/toestel.dart';
import 'package:verhuurapp/services/toestel_service.dart';
import 'package:verhuurapp/screens/toestellen/toestel_detail_screen.dart';

const _kBlue = Color(0xFF1E88E5);
const _kBlueLight = Color(0xFFE3F2FD);

class ToestellenOverzichtScreen extends StatefulWidget {
  const ToestellenOverzichtScreen({super.key});

  @override
  State<ToestellenOverzichtScreen> createState() =>
      _ToestellenOverzichtScreenState();
}

class _ToestellenOverzichtScreenState extends State<ToestellenOverzichtScreen> {
  final ToestelService _toestelService = ToestelService();
  final TextEditingController _zoekController = TextEditingController();
  String _geselecteerdeCategorie = 'Alle';
  String _zoekTekst = '';

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
  void dispose() {
    _zoekController.dispose();
    super.dispose();
  }

  List<Toestel> _filterToestellen(List<Toestel> alle) {
    return alle.where((t) {
      // Alleen beschikbare toestellen
      if (t.beschikbaarheid != 'Beschikbaar') return false;
      // Categorie filter
      if (_geselecteerdeCategorie != 'Alle' &&
          t.categorie != _geselecteerdeCategorie) return false;
      // Zoekbalk filter
      if (_zoekTekst.isNotEmpty &&
          !t.naam.toLowerCase().contains(_zoekTekst.toLowerCase()) &&
          !t.beschrijving.toLowerCase().contains(_zoekTekst.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Zoekbalk
          Container(
            color: _kBlue,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _zoekController,
              onChanged: (v) => setState(() => _zoekTekst = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Zoek een toestel...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon: _zoekTekst.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _zoekController.clear();
                          setState(() => _zoekTekst = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          // Categorie chips
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _categorieen.length,
              itemBuilder: (context, index) {
                final categorie = _categorieen[index];
                final isGeselecteerd = categorie == _geselecteerdeCategorie;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(categorie),
                    selected: isGeselecteerd,
                    onSelected: (_) =>
                        setState(() => _geselecteerdeCategorie = categorie),
                    selectedColor: _kBlue,
                    labelStyle: TextStyle(
                      color: isGeselecteerd ? Colors.white : Colors.black87,
                      fontWeight: isGeselecteerd
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    checkmarkColor: Colors.white,
                    backgroundColor: _kBlueLight,
                  ),
                );
              },
            ),
          ),
          // Toestellen grid
          Expanded(
            child: StreamBuilder<List<Toestel>>(
              stream: _toestelService.getAlleToestellen(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Fout: ${snapshot.error}'));
                }

                final gefilterd = _filterToestellen(snapshot.data ?? []);

                if (gefilterd.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.devices_other, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Geen toestellen gevonden.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: gefilterd.length,
                  itemBuilder: (context, index) {
                    final toestel = gefilterd[index];
                    return _ToestelKaart(toestel: toestel);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ToestelKaart extends StatelessWidget {
  final Toestel toestel;

  const _ToestelKaart({required this.toestel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ToestelDetailScreen(toestel: toestel),
          ),
        );
      },
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Foto
            Expanded(
              flex: 3,
              child: toestel.fotoUrl != null
                  ? Image.network(
                      toestel.fotoUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: const Color(0xFFE3F2FD),
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (_, __, ___) => _fotoPlaceholder(),
                    )
                  : _fotoPlaceholder(),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      toestel.naam,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      toestel.categorie,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      '€${toestel.prijs.toStringAsFixed(2)}/dag',
                      style: const TextStyle(
                        color: _kBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fotoPlaceholder() {
    return Container(
      color: const Color(0xFFE3F2FD),
      child: const Center(
        child: Icon(Icons.devices, size: 48, color: _kBlue),
      ),
    );
  }
}
