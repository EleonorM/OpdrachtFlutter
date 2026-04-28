import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:verhuurapp/app_state.dart';
import 'package:verhuurapp/models/toestel.dart';
import 'package:verhuurapp/models/reservering.dart';
import 'package:verhuurapp/services/reservering_service.dart';

const _kBlue = Color(0xFF1E88E5);
const _kBlueLight = Color(0xFFE3F2FD);

class ReserveringMakenScreen extends StatefulWidget {
  final Toestel toestel;

  const ReserveringMakenScreen({super.key, required this.toestel});

  @override
  State<ReserveringMakenScreen> createState() => _ReserveringMakenScreenState();
}

class _ReserveringMakenScreenState extends State<ReserveringMakenScreen> {
  final ReserveringService _reserveringService = ReserveringService();
  DateTime? _startDatum;
  DateTime? _eindDatum;
  bool _isLoading = false;
  List<Reservering> _bestaandeReserveringen = [];

  @override
  void initState() {
    super.initState();
    _laadBestaandeReserveringen();
  }

  Future<void> _laadBestaandeReserveringen() async {
    final reserveringen = await _reserveringService
        .getActieveReserveringenVoorToestel(widget.toestel.id);
    setState(() => _bestaandeReserveringen = reserveringen);
  }

  bool _isDatumGeblokkeerd(DateTime dag) {
    for (final r in _bestaandeReserveringen) {
      if (!dag.isBefore(r.startDatum) && !dag.isAfter(r.eindDatum)) {
        return true;
      }
    }
    return false;
  }

  double get _totalePrijs {
    if (_startDatum == null || _eindDatum == null) return 0;
    final dagen = _eindDatum!.difference(_startDatum!).inDays;
    return dagen * widget.toestel.prijs;
  }

  int get _aantalDagen {
    if (_startDatum == null || _eindDatum == null) return 0;
    return _eindDatum!.difference(_startDatum!).inDays;
  }

  Future<void> _selecteerStartDatum() async {
    final datum = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (dag) => !_isDatumGeblokkeerd(dag),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _kBlue),
        ),
        child: child!,
      ),
    );
    if (datum != null) {
      setState(() {
        _startDatum = datum;
        if (_eindDatum != null && _eindDatum!.isBefore(_startDatum!)) {
          _eindDatum = null;
        }
      });
    }
  }

  Future<void> _selecteerEindDatum() async {
    if (_startDatum == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecteer eerst een startdatum.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final datum = await showDatePicker(
      context: context,
      initialDate: _startDatum!.add(const Duration(days: 1)),
      firstDate: _startDatum!.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (dag) => !_isDatumGeblokkeerd(dag),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _kBlue),
        ),
        child: child!,
      ),
    );
    if (datum != null) {
      setState(() => _eindDatum = datum);
    }
  }

  Future<void> _reserveringMaken() async {
    if (_startDatum == null || _eindDatum == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecteer een start- en einddatum.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final reservering = Reservering(
        id: '',
        toestelId: widget.toestel.id,
        toestelNaam: widget.toestel.naam,
        huurderUid: user.uid,
        huurderEmail: user.email!,
        verhuurderUid: widget.toestel.verhuurderUid,
        startDatum: _startDatum!,
        eindDatum: _eindDatum!,
        totalePrijs: _totalePrijs,
        status: 'In afwachting',
      );

      await _reserveringService.reserveringToevoegen(reservering);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservering succesvol gemaakt!'),
            backgroundColor: _kBlue,
          ),
        );
        // Ga terug naar home en switch naar "Mijn huur" tab (index 3)
        homeTabNotifier.value = 3;
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatDatum(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservering maken'),
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Toestel info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kBlueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.toestel.naam,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '€${widget.toestel.prijs.toStringAsFixed(2)} per dag',
                    style: const TextStyle(
                        color: _kBlue, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (_bestaandeReserveringen.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange, size: 16),
                        SizedBox(width: 4),
                        Text('Al geboekte periodes:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ..._bestaandeReserveringen.map((r) => Text(
                          '• ${_formatDatum(r.startDatum)} → ${_formatDatum(r.eindDatum)}',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.orange),
                        )),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Startdatum
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              leading: const Icon(Icons.calendar_today, color: _kBlue),
              title: const Text('Startdatum'),
              subtitle: Text(
                _startDatum == null
                    ? 'Selecteer een datum'
                    : _formatDatum(_startDatum!),
              ),
              onTap: _selecteerStartDatum,
            ),
            const SizedBox(height: 16),
            // Einddatum
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              leading: const Icon(Icons.calendar_month, color: _kBlue),
              title: const Text('Einddatum'),
              subtitle: Text(
                _eindDatum == null
                    ? 'Selecteer een datum'
                    : _formatDatum(_eindDatum!),
              ),
              onTap: _selecteerEindDatum,
            ),
            const SizedBox(height: 24),
            // Totale prijs
            if (_aantalDagen > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kBlueLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Aantal dagen'),
                        Text('$_aantalDagen dagen'),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Totale prijs',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '€${_totalePrijs.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _kBlue,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _reserveringMaken,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Reservering bevestigen',
                      style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
