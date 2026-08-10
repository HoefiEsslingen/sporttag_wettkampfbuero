import 'package:sporttag/src/tools/sporttag_config.dart';

/// Zentrale Berechnung der zulässigen Jahrgänge, basierend auf der
/// Sporttag-Konfiguration. Wird sowohl in der Sporttag-Anmeldung
/// als auch in der Vorabanmeldung genutzt.
class JahrgangsHelper {
  JahrgangsHelper._();

  static List<int> zulaessigeJahrgaenge(SporttagConfig config) {
    final currentYear = DateTime.now().year;
    final jahrgaenge = <int>[];
    for (int i = config.kindAlterMin; i <= config.kindAlterMax; i++) {
      jahrgaenge.add(currentYear - i);
    }
    jahrgaenge.sort((a, b) => b.compareTo(a)); // absteigend
    return jahrgaenge;
  }
}