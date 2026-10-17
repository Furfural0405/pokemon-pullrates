# Update: Pullraten nach Seltenheitsklasse

Die Datenbankänderungen sind bereits im bestehenden Supabase-Projekt eingespielt. Die SQL-Dateien dienen der Dokumentation und sollen dort nicht erneut ausgeführt werden.

## Oberfläche aktualisieren

ZIP entpacken und die enthaltenen Dateien mit gleicher Ordnerstruktur im Repository **Furfural0405/pokemon-pullrates** ersetzen bzw. hinzufügen. `rarity-stats.js` ist neu. Insbesondere `app.js`, `index.html`, `style.css`, `collections.js` und `rarity-stats.js` gemeinsam aktualisieren. Enthaltene bisherige Module, einschließlich des Chat-Ordners, beibehalten. Bestehende Karten-, Bild-, Konfigurations- und Hostingdateien nicht löschen. Danach GitHub-Pages-Build abwarten und Seite mit Strg+F5 neu laden.

## Anzeigen

- In „Alle Pullraten“ und „Meine Pulls“ steht oberhalb der Karten die Statistik jeder Seltenheitsklasse.
- Pro Klasse: Summe aller Exemplare dieser Klasse geteilt durch die Boosterzahl; angezeigt als 1/x und Prozentwert. Der Kehrwert x bedeutet durchschnittliche Booster je Klassenexemplar.
- Pro Karte zusätzlich: Anteil innerhalb ihrer aktuellen Seltenheitsklasse, berechnet als Kartenanzahl geteilt durch Klassenanzahl; angezeigt als 1/x und Prozentwert. Hier bedeutet x durchschnittliche Klassenexemplare je Exemplar dieser Karte.
- Die bisherige Karten-Pullrate bezogen auf Booster bleibt erhalten.
- Im Detaildialog und in fremden öffentlichen Listen stehen die zusätzlichen Kennzahlen ebenfalls zur Verfügung.
- Korrekturen der aktuellen Seltenheit werden rückwirkend auf die gespeicherten Kartenwerte angewendet. Es werden keine Kartenwerte umgeschrieben. Eigene gültige ungespeicherte Eingaben werden lokal sofort berücksichtigt.
- Die Klassenübersicht umfasst stets die gesamte jeweilige Liste/Statistik; Suchfilter begrenzen nur die angezeigten Karten.
- Angebots-/Tauschlisten haben keine Seltenheits-Pullraten.

## Sichtbarkeit

- „Alles anzeigen“: beide Kennzahlen, Karten- und Klassenanzahlen sowie Boosterzahl.
- „Nur Boosterzahl ausblenden“: beide Kennzahlen, Karten- und Klassenanzahlen; keine Boosterzahl.
- „Nur Pullraten anzeigen“: beide Kennzahlen; keine Karten-/Klassenanzahlen und keine Boosterzahl.
- Besitzer und Admin erhalten alle Werte.
- In der Gesamtstatistik steuert der vorhandene Admin-Schalter weiterhin die Sichtbarkeit der Anzahlen für andere eingeloggte Nutzer. Gäste sehen keine Anzahlen.
- Ausgeblendete Anzahlen werden bereits vor der API-Antwort entfernt. Ein Abmelden entfernt auch zuvor sichtbare Klassenanzahlen aus der Ansicht.

## Mathematische Grenzen

Klassenexemplare geteilt durch Booster beschreiben die durchschnittliche Menge je Booster. Wenn mehrere Karten derselben Klasse in einem Booster vorkommen können, ist das keine Wahrscheinlichkeit für mindestens einen Treffer; Werte über 100 % sind deshalb möglich. Die Oberfläche erklärt dies ausdrücklich. Ohne Boosterbasis ist keine Booster-Pullrate berechenbar; ein Anteil innerhalb einer bereits erfassten Klasse kann trotzdem berechnet werden. Null Treffer werden nicht als 1/0 dargestellt.

## Prüfung

21 bestandene automatisierte Tests; Listen-, Chat- und Seltenheits-Datenbanktests; Build erfolgreich. Im Zielprojekt zusätzlich mit normalen angemeldeten Konten und mit der anonymen Rolle geprüft: Berechnung, versteckte Mengen, Admin-Zugriff und fehlender direkter Tabellenzugriff. Alle Teständerungen wurden zurückgerollt. Bestandsvergleich von Kartenwerten, Listen-Versionen, geprüften Beiträgen und bisherigen Pullraten: unverändert.

Ein interaktiver Browsertest der neuen Anzeige steht noch aus. Die früher dokumentierten Grenzen der Chat-Implementierung bleiben unverändert.
