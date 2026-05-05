import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:verhuurapp/models/gebruiker.dart';
import 'package:verhuurapp/services/auth_service.dart';
import 'package:verhuurapp/services/gebruiker_service.dart';

const _kBlue = Color(0xFF1E88E5);

class _AdresSuggestie {
  final String display;
  final String straat;
  final String stad;
  final String postnummer;
  final double lat;
  final double lon;
  _AdresSuggestie(this.display, this.straat, this.stad, this.postnummer, this.lat, this.lon);
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _adresController = TextEditingController();
  final _stadController = TextEditingController();
  final _postnummerController = TextEditingController();
  final FocusNode _adresFocusNode = FocusNode();

  final _authService = AuthService();
  final _gebruikerService = GebruikerService();

  bool _isLoading = false;
  bool _wachtwoordZichtbaar = false;
  bool _bevestigZichtbaar = false;
  String? _errorMessage;

  // Adres autocomplete
  List<_AdresSuggestie> _suggesties = [];
  bool _laadtSuggesties = false;
  bool _toonSuggesties = false;
  Timer? _debounceTimer;
  double? _geselecteerdeLat;
  double? _geselecteerdeLon;

  @override
  void initState() {
    super.initState();
    _adresFocusNode.addListener(() {
      if (!_adresFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _toonSuggesties = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _adresController.dispose();
    _stadController.dispose();
    _postnummerController.dispose();
    _adresFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ── Adres autocomplete ────────────────────────────────────────────────────

  void _onAdresGewijzigd(String waarde) {
    _debounceTimer?.cancel();
    setState(() {
      _geselecteerdeLat = null;
      _geselecteerdeLon = null;
    });
    if (waarde.trim().length < 3) {
      setState(() {
        _suggesties = [];
        _toonSuggesties = false;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _zoekSuggesties(waarde.trim());
    });
  }

  Future<void> _zoekSuggesties(String query) async {
    setState(() => _laadtSuggesties = true);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '6',
        'addressdetails': '1',
        'accept-language': 'nl',
        'countrycodes': 'be', // Alleen België
      });
      final response = await http
          .get(uri, headers: {'User-Agent': 'Lendly-Flutter/1.0 contact@lendly.be'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));

      final suggesties = data.map((item) {
        final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
        final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
        final addr = item['address'] as Map<String, dynamic>? ?? {};

        final straat = [
          addr['road'] ?? addr['street'],
          addr['house_number'],
        ].whereType<String>().join(' ');

        final stad = (addr['city'] ??
                addr['town'] ??
                addr['village'] ??
                addr['municipality'] ??
                '') as String;

        final postcode = (addr['postcode'] ?? '') as String;
        final display = item['display_name']?.toString() ?? '';

        return _AdresSuggestie(display, straat, stad, postcode, lat, lon);
      }).where((s) => s.lat != 0.0 && s.lon != 0.0).toList();

      if (mounted) {
        setState(() {
          _suggesties = suggesties;
          _toonSuggesties = suggesties.isNotEmpty;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _toonSuggesties = false);
    } finally {
      if (mounted) setState(() => _laadtSuggesties = false);
    }
  }

  void _suggestieGekozen(_AdresSuggestie s) {
    _adresController.text = s.straat.isNotEmpty ? s.straat : s.display.split(',').first;
    _stadController.text = s.stad;
    _postnummerController.text = s.postnummer;
    _adresFocusNode.unfocus();
    setState(() {
      _geselecteerdeLat = s.lat;
      _geselecteerdeLon = s.lon;
      _suggesties = [];
      _toonSuggesties = false;
    });
  }

  // ── Registreren ───────────────────────────────────────────────────────────

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmController.text) {
      setState(() => _errorMessage = 'Wachtwoorden komen niet overeen.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Firebase account aanmaken
      final user = await _authService.register(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // 2. Gebruikersprofiel opslaan in Firestore
      if (user != null) {
        final profiel = Gebruiker(
          uid: user.uid,
          email: user.email!,
          adres: _adresController.text.trim().isEmpty
              ? null
              : _adresController.text.trim(),
          stad: _stadController.text.trim().isEmpty
              ? null
              : _stadController.text.trim(),
          postnummer: _postnummerController.text.trim().isEmpty
              ? null
              : _postnummerController.text.trim(),
          latitude: _geselecteerdeLat,
          longitude: _geselecteerdeLon,
        );
        await _gebruikerService.profielOpslaan(profiel);
      }

      // 3. Terug naar root → StreamBuilder toont HomeScreen
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBlue,
      appBar: AppBar(
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              children: [
                Icon(Icons.person_add, size: 52, color: Colors.white),
                SizedBox(height: 8),
                Text('Account aanmaken',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                SizedBox(height: 4),
                Text('Gratis · Snel · Eenvoudig',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 4),

                      // ── Account ──────────────────────────────────────────
                      _sectionLabel('Account', Icons.account_circle),
                      const SizedBox(height: 12),
                      _veld(
                        controller: _emailController,
                        label: 'E-mailadres',
                        icon: Icons.email,
                        type: TextInputType.emailAddress,
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Vul je e-mailadres in.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _wachtwoordVeld(
                        controller: _passwordController,
                        label: 'Wachtwoord',
                        zichtbaar: _wachtwoordZichtbaar,
                        onToggle: () => setState(
                            () => _wachtwoordZichtbaar = !_wachtwoordZichtbaar),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Minimaal 6 tekens.'
                            : null,
                        helper: 'Minimaal 6 tekens',
                      ),
                      const SizedBox(height: 12),
                      _wachtwoordVeld(
                        controller: _confirmController,
                        label: 'Bevestig wachtwoord',
                        zichtbaar: _bevestigZichtbaar,
                        onToggle: () => setState(
                            () => _bevestigZichtbaar = !_bevestigZichtbaar),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Bevestig je wachtwoord.' : null,
                      ),
                      const SizedBox(height: 24),

                      // ── Adres ─────────────────────────────────────────────
                      _sectionLabel('Jouw adres (optioneel)', Icons.home),
                      const SizedBox(height: 4),
                      const Text(
                        'Wordt gebruikt als standaardlocatie bij het verhuren.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 12),

                      // Adres tekstveld met autocomplete
                      TextField(
                        controller: _adresController,
                        focusNode: _adresFocusNode,
                        onChanged: _onAdresGewijzigd,
                        decoration: InputDecoration(
                          labelText: 'Straat en huisnummer',
                          prefixIcon: const Icon(Icons.search, color: _kBlue),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: _kBlue, width: 2),
                          ),
                          suffixIcon: _laadtSuggesties
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: _kBlue)),
                                )
                              : (_geselecteerdeLat != null
                                  ? const Icon(Icons.check_circle,
                                      color: _kBlue)
                                  : null),
                        ),
                      ),

                      // Suggesties
                      if (_toonSuggesties && _suggesties.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                                color: _kBlue.withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: _suggesties.asMap().entries.map((e) {
                              final s = e.value;
                              final isLast = e.key == _suggesties.length - 1;
                              final hoofdTekst = s.straat.isNotEmpty
                                  ? '${s.straat}, ${s.stad}'
                                  : s.display.split(',').take(2).join(',');
                              return Column(
                                children: [
                                  InkWell(
                                    onTap: () => _suggestieGekozen(s),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
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
                                                Text(hoofdTekst,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 13)),
                                                Text(s.display,
                                                    style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 11),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (!isLast)
                                    const Divider(height: 1, indent: 44),
                                ],
                              );
                            }).toList(),
                          ),
                        ),

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _veld(
                              controller: _stadController,
                              label: 'Stad',
                              icon: Icons.location_city,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _veld(
                              controller: _postnummerController,
                              label: 'Postnummer',
                              icon: Icons.markunread_mailbox,
                              type: TextInputType.number,
                            ),
                          ),
                        ],
                      ),

                      // Foutmelding
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red.shade700, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_errorMessage!,
                                    style:
                                        TextStyle(color: Colors.red.shade800)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Account aanmaken',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Al een account? Inloggen',
                            style: TextStyle(color: _kBlue)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String tekst, IconData icoon) {
    return Row(
      children: [
        Icon(icoon, color: _kBlue, size: 18),
        const SizedBox(width: 6),
        Text(tekst,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _kBlue)),
      ],
    );
  }

  Widget _veld({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
    String? helper,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _kBlue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBlue, width: 2),
        ),
        helperText: helper,
      ),
      validator: validator,
    );
  }

  Widget _wachtwoordVeld({
    required TextEditingController controller,
    required String label,
    required bool zichtbaar,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    String? helper,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !zichtbaar,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock, color: _kBlue),
        suffixIcon: IconButton(
          icon: Icon(zichtbaar ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBlue, width: 2),
        ),
        helperText: helper,
      ),
      validator: validator,
    );
  }
}
