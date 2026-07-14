import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

/// Schützt den dahinterliegenden Bereich (z.B. Wettkampfbüro-Modus)
/// mit einer PIN-Abfrage. Die Prüfung erfolgt serverseitig über die
/// Cloud-Function 'checkWettkampfbueroPin', sodass der PIN-Hash nie
/// an den Client übertragen wird.
class PinGate extends StatefulWidget {
  final Widget child;

  const PinGate({super.key, required this.child});

  @override
  State<PinGate> createState() => _PinGateState();
}

class _PinGateState extends State<PinGate> {
  final _controller = TextEditingController();
  bool _authentifiziert = false;
  bool _laedt = false;
  String? _fehlermeldung;

  Future<void> _pinPruefen() async {
    setState(() {
      _laedt = true;
      _fehlermeldung = null;
    });

    try {
      final function = ParseCloudFunction('checkWettkampfbueroPin');
      final response = await function.execute(
        parameters: {'pin': _controller.text},
      );

      if (!response.success) {
        // Technischer Fehler (z.B. Klasse/Feld nicht gefunden)
        setState(() {
          _fehlermeldung =
              'Prüfung fehlgeschlagen: ${response.error?.message ?? "unbekannter Fehler"}';
          _laedt = false;
        });
        return;
      }

      final ergebnis = response.result as Map;
      final erfolgreich = ergebnis['erfolgreich'] == true;

      if (erfolgreich) {
        setState(() {
          _authentifiziert = true;
          _laedt = false;
        });
      } else {
        setState(() {
          _fehlermeldung = 'Falsche PIN';
          _laedt = false;
        });
      }
    } catch (e) {
      setState(() {
        _fehlermeldung = 'Verbindungsfehler: $e';
        _laedt = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_authentifiziert) return widget.child;

    return Scaffold(
      appBar: AppBar(title: const Text('Wettkampfbüro')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bitte PIN eingeben:'),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                enabled: !_laedt,
                onSubmitted: (_) => _pinPruefen(),
              ),
              if (_fehlermeldung != null) ...[
                const SizedBox(height: 8),
                Text(_fehlermeldung!, style: const TextStyle(color: Colors.white)),
              ],
              const SizedBox(height: 8),
              _laedt
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _pinPruefen,
                      child: const Text('Bestätigen'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}