# Gemeinsame Anzahlen auch ohne Anmeldung

`app.js` und `index.html` im Stammverzeichnis des vorhandenen Repositorys Furfural0405/pokemon-pullrates ersetzen. Danach den Build abwarten und die Seite neu laden. Diese Dateien setzen die vorherige Version mit Seltenheitsstatistiken voraus; vorhandene weitere Dateien beibehalten.

Die Datenbankänderung ist bereits angewendet; die enthaltene SQL-Datei nicht erneut ausführen.

Der Schalter heißt jetzt „Gemeinsame Kartenanzahlen und Boosterzahl für alle Besucher anzeigen (auch ohne Anmeldung)“.

- Eingeschaltet: gemeinsame Kartenanzahlen, Klassenanzahlen und die Booster-Gesamtsumme sind auch für nicht angemeldete Besucher sichtbar.
- Ausgeschaltet: diese gemeinsamen Anzahlen bleiben weiterhin ausschließlich für Admins sichtbar.
- Die Sichtbarkeit persönlicher Listen bleibt unverändert und wird separat pro Liste gesteuert.
- Die bisher gewählte Schalterstellung sowie Kartenwerte und Listen bleiben erhalten.

Die Gast-Zugriffe wurden mit der anonymen Datenbankrolle im Zielprojekt für beide Schalterstellungen geprüft. Konto-/Listenoperationen sind weiterhin nicht anonym zugänglich. 21 Unit-Tests, alle Datenbanktests und der Build sind erfolgreich.

Diese Anleitung ersetzt die früheren Aussagen zur ausschließlich eingeloggten Anzeige der gemeinsamen Anzahlen.
