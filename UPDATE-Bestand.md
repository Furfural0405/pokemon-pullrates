# Neues Zählsystem für Pull-Listen

## Einspielen

Der Datenbankteil wurde bereits im bestehenden Pokémon-Projekt eingespielt und geprüft. Alle fünf vorhandenen Listen, Gesamtpulls, Angebotsmengen, Versionsstände und Statistik-Snapshots sind unverändert. Die neuen privaten Bestandsfelder beginnen bei 0.

Für die Oberfläche die Dateien dieses ZIP mit der vorhandenen Ordnerstruktur im Repository pokemon-pullrates hochladen bzw. ersetzen. Andere Dateien beibehalten. Anschließend den GitHub-Pages-Build abwarten und die Seite neu laden. Die enthaltene SQL-Datei dient der Dokumentation und darf im bereits aktualisierten Projekt nicht erneut ausgeführt werden.

Die alte Angebotsübernahme wird serverseitig nicht mehr angenommen. Bitte die neue Oberfläche vor der nächsten Übernahme veröffentlichen; bereits gespeicherte Angebote bleiben erhalten.

## Die sechs Werte

- Gesamtpulls: bisher gespeicherte Pulls plus vorgemerkte neue Pulls als Vorschau. Die Anzeige ist berechnet; Korrekturen sind weiterhin über einen geprüften Import möglich.
- Neue Pulls: zusätzliche Exemplare eintragen und „Änderungen speichern“ wählen. Erst dann werden sie addiert; danach steht das Eingabefeld auf 0.
- Masterset gebunden: reservierte Exemplare pro Karte, einzeln bearbeitbar.
- Bindergebunden: separate Exemplare im Binder. Sie werden zusätzlich zur Masterset-Bindung abgezogen.
- Vergeben: verkaufte, vertauschte, verschenkte und sonst abgegebene Exemplare.
- Verfügbar: Gesamtpulls − Masterset gebunden − Bindergebunden − Vergeben.

Nach der Umstellung gebundene Exemplare und frühere Abgaben einmal nachtragen und speichern. Sonst kann „Verfügbar“ zunächst zu hoch ausfallen. Negative verfügbare Mengen werden beim Speichern abgelehnt.

## Mastersets und Binder

Ein vollständiges Set umfasst alle 173 Karten außer den drei RGB-Mews. Die acht Energien zählen mit.

Im privaten Bestandsbereich die gewünschte Masterset-Anzahl eingeben und „Masterset-Anzahl übernehmen“ wählen. Die Differenz erhöht oder reduziert die bisherige Masterset-Bindung jeder erforderlichen Karte gleichmäßig; individuelle Unterschiede bleiben erhalten. Bei Bedarf vorher andere Eingaben speichern.

Reicht der verfügbare Bestand auch nur einer erforderlichen Karte nicht aus, erscheint ein Popup mit Bildern und Fehlmengen. Die gesamte Änderung wird abgebrochen, auch nach dem Schließen bzw. Bestätigen des Hinweises. Es gibt keine Teilreservierung. RGB-Bindungen werden von der Sammelaktion nicht verändert.

Die Zahl vollständiger Binder-Mastersets entspricht dem kleinsten Binderwert unter den 173 erforderlichen Karten. Steigt diese Zahl nach erfolgreichem Speichern, erscheint das Binder-Popup. Masterset-Bindungen werden nicht mitgezählt.

## Angebote

Die Übernahme schlägt für ausgewählte Karten direkt die gespeicherte Menge „Verfügbar“ vor. Bestehende Angebotsmengen werden ersetzt, nicht addiert. In der Vorschau können kleinere Mengen gewählt werden; 0 entfernt ein bisheriges sichtbares Angebot. Nicht ausgewählte Karten bleiben erhalten. Die Angebote lassen sich danach weiterhin direkt bearbeiten.

Das Einstellen eines Angebots bindet keine Karten und ändert die Pull-Liste nicht. Tatsächliche Abgaben unter „Vergeben“ erfassen und speichern. Danach bei Bedarf erneut übernehmen. Mehrere Angebotslisten reservieren nicht gegeneinander.

Beispiel: 20 Gesamtpulls − 4 Masterset − 0 Binder − 3 vergeben = 13 verfügbar. Fünf neue Pulls eingeben und speichern: 25 − 4 − 0 − 3 = 18 verfügbar.

## Datenschutz und Statistik

Die zusätzlichen Bestandsfelder sind ausschließlich dem jeweiligen Listenbesitzer zugänglich, auch nicht dem Admin. Sie werden getrennt gespeichert und sind nicht Bestandteil öffentlicher Listen, der Admin-Listenansicht oder der Admin-Gesamtbackups. Öffentliche Listen behalten ihre bisherigen Anzeigeoptionen. Die Gesamtstatistik und Preisbewertung der Pull-Liste verwenden weiterhin Gesamtpulls. Reine Bestandsänderungen verändern keine Pullraten und machen einen übernommenen Statistikstand nicht veraltet.

## Sicherung und gleichzeitige Änderungen

Persönliche Pull-Listen-Backups enthalten nun auch private Bindungen, Abgaben und vorgemerkte neue Pulls. Beim Wiederherstellen werden neue Pulls einmal addiert und zurückgesetzt. Alte Kartenbackups behalten die vorhandenen privaten Bindungen; widersprüchliche Mengen werden abgelehnt. Admin-Gesamtbackups ersetzen keine privaten Bestandsfelder.

Veraltete Speicherversuche werden über Listen- und Bestandsversionen abgelehnt. Wiederholungen desselben erfolgreich verarbeiteten Neue-Pulls-Speicherversuchs addieren die Karten nicht doppelt. Bei einem Konflikt gegebenenfalls ein persönliches Backup sichern und „Gespeicherten Stand neu laden“ verwenden.

## Prüfung

Bestehende und neue Unit-Tests, alle acht Datenbank-Testprogramme sowie Produktionsbuild erfolgreich. Zusätzlich bestand ein DOM-Integrationstest der echten Oberflächenmodule mit kontrollierter Schnittstelle: private Felder, Vorschau, Speichern/Zurücksetzen, fehlende Karten mit Bild, Binder-Popup und öffentliche Ansicht. Live wurden Addition, Wiederholungsschutz und Zugriffsrechte in einer anschließend zurückgerollten Testtransaktion geprüft. Die Originaldaten sind unverändert.

Eine visuelle Prüfung im echten Browser steht noch aus. Nach Veröffentlichung bitte zunächst eine kleine Neue-Pulls-Eingabe speichern und die Bestandsfelder prüfen. Die Infos-Texte wurden dem neuen System angepasst.
