import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:verhuurapp/models/gebruiker.dart';
import 'package:verhuurapp/models/toestel.dart';
import 'package:verhuurapp/services/auth_service.dart';
import 'package:verhuurapp/services/gebruiker_service.dart';
import 'package:verhuurapp/services/toestel_service.dart';
import 'package:verhuurapp/services/reservering_service.dart';

const _kBlue = Color(0xFF1E88E5);
const _kBlueLight = Color(0xFFE3F2FD);

// Hulpklasse voor adres suggesties in dit scherm
class _AdresSuggestie {
  final String displayNaam;
  final String kortNaam;
  final double lat;
  final double lon;
  final String? stad;
  final String? postnummer;
  final String? straat;
  _AdresSuggestie(this.displayNaam, this.kortNaam, this.lat, this.lon,
      {this.stad, this.postnummer, this.straat});
}

class ProfielScreen extends StatefulWidget {
  const ProfielScreen({super.key});

  @override
  State<ProfielScreen> createState() => _ProfielScreenState();
}

class _ProfielScreenState extends State<ProfielScreen> {
  Gebruiker? _gebruiker;
  bool _laadtProfiel = true;
  final _toestelService = ToestelService();
  final _gebruikerService = GebruikerService();

  @override
  void initState() {
    super.initState();
    _laadProfiel();
  }

  Future<void> _laadProfiel() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final profiel = await _gebruikerService.getProfiel(uid);
        if (mounted) setState(() => _gebruiker = profiel);
      } catch (_) {}
    }
    if (mounted) setState(() => _laadtProfiel = false);
  }

  // ── Toestel verwijderen ───────────────────────────────────────────────────

  Future<void> _verwijderToestel(Toestel toestel) async {
    final bevestigd = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Toestel verwijderen'),
        content: Text(
            'Weet je zeker dat je "${toestel.naam}" wilt verwijderen? '
            'Dit kan niet ongedaan worden gemaakt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verwijderen',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (bevestigd != true) return;
    try {
      await _toestelService.toestelVerwijderen(toestel.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Toestel verwijderd.'),
              backgroundColor: _kBlue),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Fout bij verwijderen: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Adres bijwerken bottom sheet ──────────────────────────────────────────

  Future<void> _toonAdresBottomSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AdresBottomSheet(
        gebruikerService: _gebruikerService,
        uid: FirebaseAuth.instance.currentUser!.uid,
        onOpgeslagen: _laadProfiel,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final authService = AuthService();
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
            // ── Avatar ──
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

            // ── Statistieken ──
            Row(
              children: [
                Expanded(
                  child: StreamBuilder(
                    stream: _toestelService.getMijnToestellen(user.uid),
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

            // ── Account info ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kBlueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _laadtProfiel
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Column(
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
                          waarde: user.emailVerified
                              ? 'Geverifieerd'
                              : 'Niet geverifieerd',
                        ),
                        if (_gebruiker != null) ...[
                          if (_gebruiker!.adres != null) ...[
                            const Divider(),
                            _InfoRij(
                              icoon: Icons.home,
                              label: 'Adres',
                              waarde: _gebruiker!.adres!,
                            ),
                          ],
                          if (_gebruiker!.stad != null ||
                              _gebruiker!.postnummer != null) ...[
                            const Divider(),
                            _InfoRij(
                              icoon: Icons.location_city,
                              label: 'Stad',
                              waarde: [
                                if (_gebruiker!.postnummer != null)
                                  _gebruiker!.postnummer!,
                                if (_gebruiker!.stad != null)
                                  _gebruiker!.stad!,
                              ].join(' '),
                            ),
                          ],
                          if (_gebruiker!.heeftLocatie) ...[
                            const Divider(),
                            const _InfoRij(
                              icoon: Icons.near_me,
                              label: 'Locatie opgeslagen',
                              waarde: 'Afstand tot toestellen is beschikbaar',
                            ),
                          ],
                        ],
                        const Divider(),
                        // Adres bijwerken knop
                        InkWell(
                          onTap: _toonAdresBottomSheet,
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_location_alt,
                                    color: _kBlue, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Mijn adres instellen / bijwerken',
                                  style: TextStyle(
                                      color: _kBlue,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),

            // ── Mijn toestellen ──
            const Text(
              'Mijn toestellen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Toestel>>(
              stream: _toestelService.getMijnToestellen(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final toestellen = snapshot.data ?? [];
                if (toestellen.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _kBlueLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(Icons.devices_other,
                              size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Je hebt nog geen toestellen toegevoegd.',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: toestellen
                      .map((t) => _ToestelRij(
                            toestel: t,
                            onVerwijder: () => _verwijderToestel(t),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 32),

            // ── Uitloggen ──
            ElevatedButton.icon(
              onPressed: () async {
                await authService.logout();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
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

// ── Toestel rij in profiel ────────────────────────────────────────────────────

class _ToestelRij extends StatelessWidget {
  final Toestel toestel;
  final VoidCallback onVerwijder;

  const _ToestelRij({required this.toestel, required this.onVerwijder});

  @override
  Widget build(BuildContext context) {
    final isBeschikbaar = toestel.beschikbaarheid == 'Beschikbaar';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Foto thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: toestel.fotoUrl != null
                    ? Image.network(toestel.fotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fotoPlaceholder())
                    : _fotoPlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    toestel.naam,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    toestel.categorie,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '€${toestel.prijs.toStringAsFixed(2)}/dag',
                        style: const TextStyle(
                            color: _kBlue,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isBeschikbaar
                              ? _kBlueLight
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          toestel.beschikbaarheid,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                isBeschikbaar ? _kBlue : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Verwijder knop
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Verwijderen',
              onPressed: onVerwijder,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fotoPlaceholder() => Container(
        color: _kBlueLight,
        child: const Center(
            child: Icon(Icons.devices, color: _kBlue, size: 28)),
      );
}

// ── Adres bottom sheet ────────────────────────────────────────────────────────

class _AdresBottomSheet extends StatefulWidget {
  final GebruikerService gebruikerService;
  final String uid;
  final VoidCallback onOpgeslagen;

  const _AdresBottomSheet({
    required this.gebruikerService,
    required this.uid,
    required this.onOpgeslagen,
  });

  @override
  State<_AdresBottomSheet> createState() => _AdresBottomSheetState();
}

class _AdresBottomSheetState extends State<_AdresBottomSheet> {
  final _adresController = TextEditingController();
  final _adresFocusNode = FocusNode();
  List<_AdresSuggestie> _suggesties = [];
  bool _laadtSuggesties = false;
  bool _toonSuggesties = false;
  Timer? _debounceTimer;
  _AdresSuggestie? _gekozen;
  bool _opslaan = false;

  @override
  void dispose() {
    _adresController.dispose();
    _adresFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Map<String, String> _bouwZoekParams(String query) {
    final huisnrRegex = RegExp(
        r'^(.+?)\s+(\d+[a-zA-Z]?)\s*(?:[,\s]+\s*(.+))?$',
        caseSensitive: false);
    final match = huisnrRegex.firstMatch(query.trim());
    if (match != null) {
      final straat = match.group(1)!.trim();
      final huisnr = match.group(2)!.trim();
      final stad = match.group(3)?.trim();
      if (straat.length >= 3) {
        return {
          'street': '$huisnr $straat',
          if (stad != null && stad.isNotEmpty) 'city': stad,
          'countrycodes': 'be',
          'format': 'json',
          'limit': '6',
          'addressdetails': '1',
          'accept-language': 'nl,en',
        };
      }
    }
    return {
      'q': query,
      'countrycodes': 'be',
      'format': 'json',
      'limit': '6',
      'addressdetails': '1',
      'accept-language': 'nl,en',
    };
  }

  Future<void> _zoekSuggesties(String query) async {
    if (query.trim().length < 3) {
      setState(() {
        _suggesties = [];
        _toonSuggesties = false;
      });
      return;
    }
    setState(() => _laadtSuggesties = true);
    try {
      final params = _bouwZoekParams(query);
      final uri =
          Uri.https('nominatim.openstreetmap.org', '/search', params);
      final resp = await http
          .get(uri,
              headers: {
                'User-Agent': 'Lendly-Flutter/1.0 contact@lendly.be'
              })
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return;

      List<dynamic> data = json.decode(utf8.decode(resp.bodyBytes));

      // Fallback vrij zoeken als gestructureerd leeg
      if (data.isEmpty && params.containsKey('street')) {
        final vrij =
            Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': query,
          'countrycodes': 'be',
          'format': 'json',
          'limit': '6',
          'addressdetails': '1',
          'accept-language': 'nl,en',
        });
        final fb = await http
            .get(vrij,
                headers: {
                  'User-Agent': 'Lendly-Flutter/1.0 contact@lendly.be'
                })
            .timeout(const Duration(seconds: 8));
        if (fb.statusCode == 200) {
          data = json.decode(utf8.decode(fb.bodyBytes));
        }
      }

      final suggesties = data.map((item) {
        final lat =
            double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
        final lon =
            double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
        final volledig = item['display_name']?.toString() ?? '';
        final addr = item['address'] as Map<String, dynamic>? ?? {};
        final straat = addr['road'] ?? addr['street'];
        final huisnr = addr['house_number'];
        final stad = addr['city'] ??
            addr['town'] ??
            addr['village'] ??
            addr['municipality'];
        final postcode = addr['postcode']?.toString();
        final land = addr['country'];
        final delen = <String>[];
        if (straat != null) {
          delen.add(
              huisnr != null ? '$straat $huisnr' : straat as String);
        }
        if (stad != null) delen.add(stad as String);
        if (land != null) delen.add(land as String);
        final kort = delen.isNotEmpty
            ? delen.join(', ')
            : volledig.split(',').take(3).join(',');
        return _AdresSuggestie(volledig, kort, lat, lon,
            stad: stad?.toString(),
            postnummer: postcode,
            straat: straat != null
                ? (huisnr != null ? '$straat $huisnr' : straat as String)
                : null);
      }).where((s) => s.lat != 0.0 && s.lon != 0.0).toList();

      if (mounted) {
        setState(() {
          _suggesties = suggesties;
          _toonSuggesties = suggesties.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Adres fout: $e');
    } finally {
      if (mounted) setState(() => _laadtSuggesties = false);
    }
  }

  void _onInput(String v) {
    _debounceTimer?.cancel();
    setState(() => _gekozen = null);
    _debounceTimer = Timer(
        const Duration(milliseconds: 500), () => _zoekSuggesties(v));
  }

  void _kiesSuggestie(_AdresSuggestie s) {
    setState(() {
      _gekozen = s;
      _adresController.text = s.kortNaam;
      _suggesties = [];
      _toonSuggesties = false;
    });
    _adresFocusNode.unfocus();
  }

  Future<void> _slaAdresOp() async {
    if (_gekozen == null) return;
    setState(() => _opslaan = true);
    try {
      await widget.gebruikerService.profielUpdaten(widget.uid, {
        'adres': _gekozen!.straat ?? _gekozen!.kortNaam,
        'stad': _gekozen!.stad ?? '',
        'postnummer': _gekozen!.postnummer ?? '',
        'latitude': _gekozen!.lat,
        'longitude': _gekozen!.lon,
      });
      widget.onOpgeslagen();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _opslaan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Mijn adres instellen',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Dit adres wordt gebruikt voor de afstandsindicator.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Zoekbalk
          TextField(
            controller: _adresController,
            focusNode: _adresFocusNode,
            onChanged: _onInput,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Adres zoeken (straat + stad)',
              hintText: 'bijv. Kapelstraat 5, Antwerpen',
              prefixIcon: const Icon(Icons.search, color: _kBlue),
              border: const OutlineInputBorder(),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: _kBlue, width: 2),
              ),
              suffixIcon: _laadtSuggesties
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kBlue),
                      ),
                    )
                  : null,
            ),
          ),

          // Suggesties
          if (_toonSuggesties && _suggesties.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                border:
                    Border.all(color: _kBlue.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: _suggesties.asMap().entries.map((e) {
                  final s = e.value;
                  final isLaatste = e.key == _suggesties.length - 1;
                  return Column(
                    children: [
                      InkWell(
                        onTap: () => _kiesSuggestie(s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.location_pin,
                                  color: _kBlue, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(s.kortNaam,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text(s.displayNaam,
                                        style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!isLaatste)
                        const Divider(height: 1, indent: 40),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],

          // Gekozen adres bevestiging
          if (_gekozen != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kBlueLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: _kBlue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _gekozen!.kortNaam,
                      style: const TextStyle(
                          color: _kBlue, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: (_gekozen == null || _opslaan)
                ? null
                : _slaAdresOp,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: _opslaan
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Adres opslaan',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Herbruikbare widgets ──────────────────────────────────────────────────────

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
                fontSize: 24, fontWeight: FontWeight.bold, color: _kBlue),
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
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 12)),
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
