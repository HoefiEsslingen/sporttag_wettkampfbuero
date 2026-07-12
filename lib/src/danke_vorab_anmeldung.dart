import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sporttag/src/tools/sporttag_config.dart';
import 'hilfs_widgets/meine_appbar.dart';

class DankeVorabAnmeldung extends StatefulWidget {
  const DankeVorabAnmeldung({super.key, required this.titel});
  final String titel;

  @override
  State<DankeVorabAnmeldung> createState() => _DankeVorabAnmeldungState();
}

class _DankeVorabAnmeldungState extends State<DankeVorabAnmeldung> {
  late SporttagConfig config;

  @override
  void initState() {
    super.initState();
    // Zugriff über context.read, da initState synchron ist
    config = context.read<SporttagConfig>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeineAppBar(titel: widget.titel),
      body: Center(
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 24.0,
            ),
            children: <TextSpan>[
              const TextSpan(
                text: 'Vielen Dank für Ihre Anmeldung\n',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 26.0,
                ),
              ),
              TextSpan(
                text: 'Am Sporttag selbst müssen Sie nur noch\n'
                    'die Startgebühr von € ${config.gebuehr.toStringAsFixed(2).replaceAll('.', ',')} bezahlen,\n'
                    'damit die Anmeldung aktiv wird.\n\n'
                    'Bitte finden Sie sich \n'
                    'am ${config.datumKurz}\n'
                    'um ${config.uhrzeit} Uhr\n'
                    'im ${config.ort} ein.\n'
                    '',
              ),
              TextSpan(
                text: '\nIhrem Kind wünschen wir bereits heute viel Spass.\n'
                    'Wir sehen uns am\n${config.datumLang}!\n\n'
                    'Gerne können Sie nun das Browserfenster schließen.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
