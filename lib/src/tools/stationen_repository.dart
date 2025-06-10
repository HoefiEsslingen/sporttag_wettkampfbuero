import '../klassen/kind_klasse.dart';
import 'kind_repository.dart';
import 'logger.util.dart';

class StationenRepository {
  final log = getLogger();
  
  var kindRepository = KindRepository();
  
  late List<Kind> riegenKinder;
      final int aktuellesJahr = DateTime.now().year;


  Future<List<Kind>> riegeLaden(int riegenNummer) async {

    // Lade die Kinder der Riege und aktualisiere die Liste
    List<Kind> geladeneKinder =
        await kindRepository.loadKinderAusRiege(mitRiegenNummer: riegenNummer);
      riegenKinder = geladeneKinder; // Aktualisiere die globale Liste


    riegenKinder.sort((a, b) {
      final geschlechtVergleich = a.geschlecht.compareTo(b.geschlecht);
      if (geschlechtVergleich != 0) return geschlechtVergleich;

      final jahrgangVergleich = b.jahrgang.compareTo(a.jahrgang);
      if (jahrgangVergleich != 0) return jahrgangVergleich;

      return a.nachname.compareTo(b.nachname);
    });
    return riegenKinder;
  }
/*
    int hoechsterJahrgang = int.parse((riegenKinder
          ..sort((a, b) => a.jahrgang.compareTo(a.jahrgang)))
        .first
        .jahrgang);
    int hoechstesAlter = (aktuellesJahr - hoechsterJahrgang);
    if (hoechstesAlter < 6) {
      altersKlasse = 'U6';
    } else if (hoechstesAlter < 8) {
      altersKlasse = 'U8';
    } else if (hoechstesAlter < 10) {
      altersKlasse = 'U10';
    } else {
      altersKlasse = 'Ü9';
    }
  }
*/
}