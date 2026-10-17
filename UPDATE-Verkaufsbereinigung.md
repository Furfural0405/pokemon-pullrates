# Übernahme unter Berücksichtigung bereits verkaufter Exemplare

`app.js`, `index.html` und `trade-transfer.js` im bestehenden Repository Furfural0405/pokemon-pullrates ersetzen. Weitere enthaltene Dateien dienen Tests und Dokumentation. Danach den Build abwarten und Seite neu laden. Die Datenbankänderung ist bereits eingespielt. Die SQL-Datei nicht erneut ausführen.

## Neues Verhalten

- Erste Übernahme einer Karte in eine neue Ziel-Angebotsliste: Vorschlag Pull-Anzahl minus vier, mindestens null.
- Nach der Übernahme merkt sich die Webseite die aktuelle Pull-Anzahl pro Karte und Kombination aus Quell-/Ziel-Liste.
- Weitere Übernahmen schlagen vor: aktuelle Angebotsanzahl plus seitdem neu hinzugekommene Pulls.
- Manuelle Reduzierungen der Angebotsanzahl, beispielsweise nach Verkäufen, bleiben damit berücksichtigt.
- Ohne neue Pulls wird die Angebotsanzahl nicht erhöht.
- Alle Vorschläge bleiben vor und nach der Übernahme bearbeitbar. Nur ausdrücklich bestätigte Zielwerte werden gespeichert. Eine Übernahme bestätigt zugleich den aktuellen Pull-Stand als verarbeitet – auch wenn du den Vorschlag bewusst reduzierst.
- Pull-Liste und Gesamtstatistik werden durch die Übernahme nicht verändert.

Beispiel: 20 Pulls → erstmals 16 anbieten; drei verkauft → Angebot manuell auf 13 reduzieren; Pulls später auf 25 erhöhen → fünf neue Exemplare, daher Vorschlag 18. Danach gilt 25 als neuer Übernahmestand. Erneut ohne neue Pulls übernehmen: weiterhin 18.

## Bereits vorhandene Angebotskarten

Frühere Übernahmen hatten keinen gesonderten Übernahmestand. Es wird deshalb kein Stand automatisch geschätzt und keine vorhandene Anzahl umgeschrieben.

Beim ersten Öffnen einer solchen Karte ist als Ausgangsstand die aktuelle Pull-Anzahl vorausgefüllt. Dadurch bleibt die aktuelle Angebotsanzahl zunächst erhalten. Wenn du den früheren Stand kennst, trage ihn ein: Im Beispiel Pulls 25, Angebot 13, früherer Stand 20 ergibt den Vorschlag 18. Den Ausgangsstand und die neue Zielanzahl ausdrücklich prüfen und per Kontrollkästchen bestätigen.

Bei gesunkenen Pull-Zahlen bleibt das Angebot zunächst unverändert; die Korrektur und Zielanzahl müssen bestätigt werden. Anschließend wird der aktuelle Pull-Stand als neue Basis gespeichert. Spätere Erhöhungen gelten wieder als neue Pulls.

Die bisherigen Ansichten ohne Vorschau-Protokoll werden serverseitig vom Kopieren ausgeschlossen, damit sie Verkäufe nicht mit der alten Formel überschreiben. Deshalb vor der nächsten Übernahme unbedingt die aktualisierten Oberflächendateien hochladen.

## Prüfung

24 bestandene Unit-Tests. Alle bisherigen Datenbanktests sowie ein neuer Integrationstest für das vollständige Zahlenbeispiel, Wiederholung, Verkäufe, unabhängige Ziel-Listen, Ausgangsstand-Bestätigung, Korrekturen und veraltete Versionen sind erfolgreich. Zusätzlich mit normalem angemeldetem Zugriff im Zielprojekt geprüft; alle Testdaten zurückgerollt. Build erfolgreich. Ein interaktiver Browsertest der neuen Vorschau steht noch aus.
