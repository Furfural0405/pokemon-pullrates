# Cardmarket-Richtwerte und Listenwerte

## Veröffentlichung

Der Serverteil ist bereits im bestehenden Pokémon-Projekt eingerichtet. Der geschützte Aktualisierungsdienst und der Zeitplan alle 30 Minuten sind aktiv. Der erste Abruf und ein regulärer Zeitplanlauf waren erfolgreich; 176 Set-Produkte wurden eingelesen.

Für die sichtbare Oberfläche die Dateien aus diesem ZIP mit unveränderter Ordnerstruktur im Repository pokemon-pullrates hochladen bzw. ersetzen. Bestehende andere Dateien beibehalten. Den bestehenden GitHub-Pages-Build abwarten. Die SQL-Dateien und den Worker nicht erneut ausführen/deployen: Sie sind als Quellcode zur Nachvollziehbarkeit enthalten.

## Verwendung

1. Als Eigentümer anmelden und eine Karte öffnen.
2. Unter Cardmarket-Preis den vollständigen Kartenlink aus dem Set 30th Celebration (Simplified Chinese) einfügen.
3. Ein eindeutiger Namens-Treffer wird vorgeschlagen. Bei mehreren Varianten die Produktlinks zum Vergleich öffnen und die korrekte Variante auswählen. Die offizielle Produktdatei enthält für manche Varianten identische Namen und keine Sammlernummer. Deshalb wird keine ungesicherte Variante automatisch gewählt.
4. Cardmarket-Link speichern. Die Preise aus dem zuletzt erfolgreich geladenen Preisverzeichnis stehen sofort zur Verfügung. Ein Link kann auch ohne Produktzuordnung gespeichert werden; dann bleibt die Karte unbewertet.
5. Name, Seltenheit und Kartenbilder werden weiterhin separat über die vorhandenen Funktionen bearbeitet.

Der Richtwert beträgt 90 % des Low-/Ab-Preises plus 10 % des 7-Tage-Durchschnitts, je Karte auf Cent gerundet. Preisstand der Quelle und letzter Abruf werden getrennt angezeigt. Die offiziellen Preisdateien werden üblicherweise täglich erneuert; ein Abruf alle 30 Minuten garantiert keine alle 30 Minuten neu berechneten Quellpreise. Gefilterte Angebote nach Zustand, Verkäufer oder Sprache und Versandkosten werden nicht separat ausgewertet. Die Produktzuordnung bezieht sich auf das ausdrücklich vereinfachte chinesische Set.

## Listenwerte

Pull-Listen bewerten alle erfassten Pulls. Bereits abgegebene Karten bleiben darin enthalten, weil Pull-Anzahlen unverändert bleiben. Angebotslisten bewerten die aktuell eingetragenen Angebotsmengen.

Unter den Listeneinstellungen gibt es eine eigene Auswahl „Listenwert für andere Nutzer“. Standard ist privat. Die Freigabe zeigt den Wert ausschließlich den ohnehin berechtigten Betrachtern der öffentlichen Liste. Besitzer und Admin sehen den Wert immer. Bei ausgeblendeten Kartenanzahlen werden auch keine bewerteten/unbewerteten Gesamtstückzahlen an andere Nutzer übertragen. Sichtbare Kartenmengen erlauben weiterhin eine eigene Wertberechnung.

Karten ohne beide nötigen Preise werden nicht als 0 Euro bewertet, sondern als unbewertet ausgewiesen. Die Gesamtsumme ist dann als unvollständig gekennzeichnet. Bei Aktualisierungsfehlern bleiben letzte bekannte Werte mit ihrem ursprünglichen Preisstand erhalten und werden entsprechend markiert.

## Validierung

27 Unit-Tests, sämtliche sieben Datenbank-Testprogramme und der Produktionsbuild bestanden. Zusätzlich live geprüft: erfolgreicher Preisdateiabruf, regulärer 30-Minuten-Zeitplanlauf, Abweisung nicht berechtigter Worker-Aufrufe, Gewichtung und Unterdrückung versteckter Mengen. Die fünf bestehenden Listen und ihre gespeicherten Kartenwerte, Versionsstände und Statistik-Snapshots blieben unverändert. Alle Listenwerte sind zunächst privat. Es wurden keine Kartenlinks ungeprüft vorausgefüllt.

Eine interaktive Prüfung der neuen Oberfläche im echten Browser steht noch aus. Nach Veröffentlichung bitte eine Karte öffnen, den Link speichern, den Listenwert prüfen und dessen Sichtbarkeit mit einem zweiten freigegebenen Konto vergleichen.

## Enthaltene technische Dateien

app.js, collections.js, infos.js, prices.js, index.html, style.css und package.json; Hilfe-SVGs; neue Preis-Tests; additive SQL-Erweiterung, Zeitplan und Worker-Quellcode. Die übrigen bereits vorhandenen App-Module werden weiterhin benötigt.
