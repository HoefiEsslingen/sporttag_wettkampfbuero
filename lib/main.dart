import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:sporttag/src/riegen_zuordnung.dart';
import 'package:sporttag/src/tools/pin_gate.dart';
import 'package:sporttag/src/tools/sporttag_config.dart';
import 'package:sporttag/src/urkunden.dart';
import 'package:sporttag/src/anmelden_sporttag.dart';
import 'package:sporttag/src/riegen_einteilung.dart';
import 'package:sporttag/src/wettkampfbuero.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import 'src/anmelden_vorher.dart';
import 'src/danke_vorab_anmeldung.dart';
import 'src/wettbewerb.dart';
import 'package:sporttag/src/tools/parse_config.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE', null);

  await Parse().initialize(keyApplicationId, keyParseServerUrl,
      clientKey: keyClientKey, debug: true);

  //Logging ermöglichen
  Logger.level = Level.debug;

  // Konfiguration laden und Startroute bestimmen
  final config = await SporttagConfig.laden();
  final startRoute = switch (config.routeEntscheiden()) {
    RouteEntscheidung.vorabAnmeldung => 'vorabAnmeldung',
    RouteEntscheidung.wettkampfbuero => 'home',
  };

  runApp(
    Provider<SporttagConfig>.value(
      value: config,
      child: MainApp(startRoute: startRoute),
    ),
  );
}

class MainApp extends StatelessWidget {
  final String startRoute;
//  final SporttagConfig config;

  const MainApp({super.key, required this.startRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light().copyWith(
        primaryColor: const Color.fromARGB(255, 241, 79, 15),
        scaffoldBackgroundColor: const Color.fromARGB(255, 246, 65, 10),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 246, 65, 10),
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 38.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.green,
            textStyle: const TextStyle(fontSize: 24),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              backgroundColor: Colors.white, foregroundColor: Colors.green),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          fillColor: Colors.white,
        ),
      ),
      // Die App startet bei der in der sporttag-config-Datei bestimmten Route
      // entspricht Wettkampfbuero() --> falls aktuelles Datum nach Anmeldeschluss liegt
      // entspricht AnmeldenVorher() --> falls aktuelles Datum vor Anmeldeschluss liegt
      initialRoute: startRoute,
      // Diese Funktion wird aufgerufen, wann immer eine Route aufgerufen wird, die nicht explizit in routes: registriert ist.
      // Du kannst hier dynamisch auf den Routen-String reagieren.
      onGenerateRoute: (settings) {
        // Wandelt den Routennamen (z. B. /wettkampf/3/Zehnkampf) in ein Uri-Objekt um,
        // um bequem auf Pfadsegmente (pathSegments) zuzugreifen.
        final uri = Uri.parse(settings.name ?? '');

        // Dynamische QR-Code-Route
        // Prüft, ob die Route drei Segmente hat und das erste Segment 'wettkampf' ist.
        // Das zweite Segment sollte eine Zahl (Riegen-Nummer) sein und das dritte Segment sollte ein String (Wettbewerbs-Typ) sein.
        // Beispiel: /wettkampf/3/Zehnkampf bzw. /wettkampf/5/Fuenfkampf
        // Wenn die Route korrekt ist, wird eine MaterialPageRoute zurückgegeben, die zur Wettbewerb-Seite führt.
        // if (uri.pathSegments.length == 3 &&
        //     uri.pathSegments[0] == 'wettkampf') {
        //   // Extrahiert die Riegennummer (als int) und Wettbewerbstyp (z. B. "Zehnkampf")
        //   final riegenNummer = int.tryParse(uri.pathSegments[1]);
        //   final wettbewerbsTyp = Uri.decodeComponent(uri.pathSegments[2]);
        //   if (riegenNummer != null && wettbewerbsTyp.isNotEmpty) {
        //     return MaterialPageRoute(
        //       builder: (_) => Wettbewerb(
        //         riegenNummer: riegenNummer,
        //         wettbewerbsTyp: wettbewerbsTyp,
        //       ),
        //     );
        //   }
        if (uri.pathSegments.length == 2 &&
            uri.pathSegments[0] == 'wettkampf') {
          final riegenNummer = int.tryParse(uri.pathSegments[1]);
          if (riegenNummer != null) {
            return MaterialPageRoute(
              builder: (_) => Wettbewerb(riegenNummer: riegenNummer),
            );
          }
        } else if (uri.pathSegments.length == 1) {
          // Diese Route zeigt auf die Voranameldung für den Zehnkampf.
          // Beispiel: 'Sporttag - Vorab - Anmeldung'
          if (uri.pathSegments[0] == 'vorabAnmeldung') {
            return MaterialPageRoute(
                builder: (_) => const AnmeldenVorher(
                    title: 'Sporttag - Vorab - Anmeldung'));
          }
        }

        // Wenn keine QR-Code-Route erkannt wurde, wird eine normale fixe Route geladen.
        switch (settings.name) {
          // case 'home':
          //   return MaterialPageRoute(builder: (_) => const Wettkampfbuero());
          case 'home':
            return MaterialPageRoute(
              builder: (_) => const PinGate(
                child: Wettkampfbuero(),
              ),
            );
          case 'anmeldeSeite':
            return MaterialPageRoute(
                builder: (_) =>
                    const AnmeldenSporttag(titel: 'Sporttag - Anmeldung'));
          case 'riegenEinteilung':
            return MaterialPageRoute(
                builder: (_) =>
                    const RiegenEinteilung(titel: 'Riegen einteilen'));
          case 'riegenZuordnung':
            return MaterialPageRoute(
                builder: (_) => const RiegenZuordnung(
                    titel: 'Riegen den Riegenführern zuordnen'));
          case 'auswertung':
            return MaterialPageRoute(
                builder: (_) =>
                    const UrkundenDruck(titel: 'Auswerten mit Urkunden'));
          case 'dankeschoen':
            return MaterialPageRoute(
                builder: (_) => const DankeVorabAnmeldung(
                    titel: 'Sporttag - Vorab - Anmeldung'));
          default:
            return MaterialPageRoute(
                builder: (_) => const DankeVorabAnmeldung(
                    titel: 'Sporttag - Vorab - Anmeldung'));
        }
      },
    );
  }
}
