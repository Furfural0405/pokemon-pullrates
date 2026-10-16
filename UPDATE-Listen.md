# Update: Benutzernamen und mehrere Listen

Die Datenbankänderung ist bereits im zugehörigen Supabase-Projekt angewendet.
SQL-Dateien dienen der Dokumentation und sollen dort nicht erneut ausgeführt werden.

## Webseite aktualisieren

1. ZIP entpacken.
2. Die enthaltenen Dateien im bestehenden Repository **Furfural0405/pokemon-pullrates** an denselben Pfaden hochladen und vorhandene Dateien ersetzen. `collections.js` ist neu. Die Ordner `supabase` und `tests` mit ihren Unterordnern erhalten.
3. Den GitHub-Pages-Build abwarten und die Webseite neu laden (ggf. Strg+F5).
4. Anmelden. Unter „Meine Pulls“ steht die bisherige Liste „Meine Sammlung“ mit unveränderten Kartenwerten bereit.

Keine bestehenden assets-, Karten- oder Konfigurationsdateien löschen.

## Was enthalten ist

- Änderbare, eindeutige Benutzernamen (3–24 Zeichen, Buchstaben, Zahlen, Bindestrich, Unterstrich).
- Schimpfwort- und Extremismus-Sperrliste, auch für einige Schreibvarianten. Sie erfasst nicht jede denkbare Umgehung; der Admin kann Namen zusätzlich ändern, entfernen oder sperren.
- Bis zu zehn benennbare Listen pro Nutzer, standardmäßig privat. Listen können auch vor Kontofreigabe privat angelegt und gespeichert werden.
- Veröffentlichung und Suche erst nach Admin-Freigabe und mit Benutzernamen; der Admin kann ohne eigenen Benutzernamen suchen und alle Listen prüfen.
- Pro Liste: alles zeigen, nur Boosterzahl ausblenden oder nur Pullraten zeigen. Der Admin erhält immer sämtliche Werte. Aus sichtbaren Kartenanzahlen bleibt die ausgeblendete Boosterzahl ableitbar.
- Angebots-/Tauschlisten ohne Pullratenberechnung und ohne Übernahme in die Gesamtstatistik. Bei „Nur Pullraten“ bleiben bei einer Angebotsliste entsprechend keine Mengen sichtbar.
- Listen einzeln in die Gesamtstatistik übernehmen, aktualisieren oder herausnehmen. Die Übernahme ersetzt den geprüften Stand dieser Liste. Nutzer müssen doppelt erfasste Pulls über verschiedene Listen vermeiden.
- Persönlicher Backup/Import für die ausgewählte Liste; Gesamtbackup Version 2 für alle Listen. Vorhandene Backups der Version 1 bleiben importierbar und betreffen die ursprünglichen Listen. Gesamtwiederherstellung setzt Kartenwerte und geprüfte Beiträge vorhandener Listen zurück; Konten und Listen-Einstellungen bleiben bestehen. Nicht mehr vorhandene Listen werden nicht stillschweigend neu erzeugt.
- Bisheriger Bilder-Upload, Namens-/Seltenheitsbearbeitung, Anmeldungsverwaltung und Anzeige-Schalter für die Gesamtstatistik bleiben erhalten.

## Erhaltung der bisherigen Werte

Vor und nach der Migration wurden alle bisherigen Profil-Stückzahlen, Versionen, freigegebenen Beiträge, öffentlichen Pullraten und aggregierten Mengen verglichen: unverändert. Die bestehenden Listen sind zunächst privat. Die frühere Admin-Liste bleibt wie bisher direkt für die Gesamtstatistik berücksichtigt. Bei einer manuellen erneuten Übernahme wird auch für sie ein geprüfter Stand gespeichert, bis sie erneut übernommen wird.

## Prüfung

- `npm test`: 13 bestandene Tests.
- `npm run test:db`: Tests mit lokalem PostgreSQL (PGlite) für Migration, Listenlimit, Zugriffsrechte, Namensfilter, Sichtbarkeit, geprüfte Beiträge, Angebotslisten, Moderation und Backups.
- `npm run build`: erfolgreich.
- Zusätzlich wurden die RPC-Zugriffe mit der Rolle `authenticated` im Zielprojekt geprüft. Testkonten und Änderungen wurden vollständig zurückgerollt.

Ein interaktiver Browsertest der neuen Oberfläche steht noch aus. Die Oberfläche wurde gebaut; die HTML-Ziele, die Ausgabe und die Berechtigungsfälle wurden automatisiert geprüft.
