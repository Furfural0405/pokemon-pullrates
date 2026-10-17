# Karten aus einer Pull-Liste in eine Angebotsliste kopieren

## Installation

`app.js`, `index.html`, `style.css` und die neue Datei `trade-transfer.js` mit gleicher Ordnerstruktur im bestehenden Repository **Furfural0405/pokemon-pullrates** hochladen. Bereits vorhandene Dateien und Module beibehalten. Danach den GitHub-Pages-Build abwarten und die Webseite neu laden.

Die SQL-Änderung ist bereits im zugehörigen Projekt angewendet. Die enthaltene SQL-Datei ist Dokumentation und soll dort nicht erneut ausgeführt werden.

## Bedienung

1. Unter „Meine Pulls“ eine eigene Pull-Liste öffnen. Etwaige Änderungen zuerst speichern.
2. Bei den gewünschten Karten „Für Angebotsliste auswählen“ markieren. Alternativ mit „Sichtbare Karten auswählen“ die derzeit sichtbaren, vorhandenen Karten markieren. Ausgewählte Karten bleiben bei Such- und Filterwechseln ausgewählt.
3. „In Angebotsliste übernehmen“ öffnen und eine eigene Angebots-/Tauschliste als Ziel wählen. Falls noch keine vorhanden ist, zuerst unter „Neue Liste anlegen“ eine solche Liste erstellen.
4. Vorschläge prüfen: bisherige Pull-Anzahl minus vier, mindestens null. Die neue Angebotsanzahl ist bereits in der Vorschau bearbeitbar. Die bisherige Zielanzahl wird daneben angezeigt.
5. „Ausgewählte Anzahlen ersetzen“ speichert ausschließlich diese Karten in der Ziel-Angebotsliste. Vorhandene Werte werden ersetzt, nicht addiert. Nicht ausgewählte Angebote bleiben unverändert. Null bedeutet, dass die Karte im sichtbaren Angebot nicht mehr vorkommt.
6. Die Angebotsanzahlen lassen sich später wie gewohnt in der Angebotsliste unabhängig bearbeiten.

Die Quell-Pull-Liste, ihre Kartenanzahlen, ihre Version und die Gesamtstatistik werden durch das Kopieren nicht geändert. Es findet keine dauerhafte automatische Synchronisierung statt. Eine erneute Übernahme aktualisiert nur die dann erneut ausgewählten Karten mit den ausdrücklich bestätigten Zahlen.

Schreibrechte gelten ausschließlich für eigene Quell-Pull- und Ziel-Angebotslisten. Bei zwischenzeitlichen Änderungen in einem anderen Fenster wird die Übernahme abgelehnt, statt Werte still zu überschreiben. Vorschau in diesem Fall schließen, Listen neu laden und erneut öffnen.

## Prüfung

23 Unit-Tests, alle Listen-/Chat-/Statistik-/Übernahme-Datenbanktests sowie Build erfolgreich. Zusätzlich im Zielprojekt mit der normalen angemeldeten Rolle geprüft: Ersetzen statt Addieren, unveränderte Quelle, veraltete Versionen und Ablehnung fremder Listen. Alle Testdaten wurden zurückgerollt.

Ein interaktiver Browsertest der neuen Auswahl und Vorschau steht noch aus.
