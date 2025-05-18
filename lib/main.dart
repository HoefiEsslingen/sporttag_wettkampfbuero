import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:sporttag/src/riegen_zuordnung.dart';
import 'package:sporttag/src/urkunden.dart';
import 'package:sporttag/src/anmelden_sporttag.dart';
import 'package:sporttag/src/riegen_einteilung.dart';
import 'package:sporttag/src/wettkampfbuero.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const keyApplicationId = 'WLgenML3TwDSZ80DBWggNnJaNePhJ3RQgzdCvvv0';
  const keyClientKey = 'LgXHwuUZDe5Dd1kuCEsz9Ui6gm30iyhgNvOVL0IM';
  const keyParseServerUrl = 'https://parseapi.back4app.com';

  await Parse().initialize(keyApplicationId, keyParseServerUrl,
      clientKey: keyClientKey, debug: true);

  //Logging ermöglichen
  Logger.level = Level.debug;

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

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
              textStyle: const TextStyle(
                fontSize: 24,
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: Colors.green),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            fillColor: Colors.white,
          )),
      initialRoute: 'home',
      routes: {
//        'home': (context) => const Wettkampfbuero(),

        'home': (context) => const RiegenEinteilung(titel: 'Riegen einteilen'),
        'anmeldeSeite': (context) => const AnmeldenSporttag(titel: 'Sporttag - Anmeldung'),
        'riegenEinteilung': (context) => const RiegenEinteilung(titel: 'Riegen einteilen'),
        'riegenZuordnung': (context) => const RiegenZuordnung(titel: 'Riegen den Riegenführern zuordnen'),
        'auswertung': (context) => const UrkundenDruck(titel: 'Auswerten mit Urkunden'),
      },
    );
  }
}
