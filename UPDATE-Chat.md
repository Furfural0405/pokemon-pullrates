# Update: verschlüsselter Kontakt-Chat

## Installation

Die Chat-Datenbank und die automatische Bereinigung sind im bestehenden zugehörigen Supabase-Projekt bereits eingerichtet. SQL-Dateien nicht erneut ausführen.

1. ZIP entpacken. Die enthaltenen Dateien unter Beibehaltung der Ordnerstruktur im bestehenden Repository **Furfural0405/pokemon-pullrates** hochladen und vorhandene Dateien ersetzen. Insbesondere `app.js`, `index.html`, `style.css` und den neuen Ordner `chat` gemeinsam aktualisieren.
2. Vorhandene Karten-, Bild-, Konfigurations- und Hostingdateien beibehalten.
3. GitHub-Pages-Build abwarten und Webseite mit Strg+F5 neu laden.
4. Als Admin anmelden und gegebenenfalls einen Benutzernamen hinterlegen.
5. Den neuen Reiter „Chat“ öffnen. Regeln selbst lesen und bestätigen. Erst dabei wird der echte serverseitige Zustimmungsnachweis angelegt.
6. Chat-Schlüssel erstellen und die Wiederherstellungsdatei sicher außerhalb der Webseite aufbewahren. Erst nach ausdrücklicher Bestätigung wird die Identität gespeichert.
7. Andere freigegebene Nutzer können nun ebenfalls Regeln bestätigen und ihre Schlüssel einrichten. Erst danach sind sie über Kontaktanfragen erreichbar. Die vorherige Einrichtung des Admin-Schlüssels stellt sicher, dass Meldungen an den Admin möglich sind.

## Bedienung

- **Kontaktanfragen:** exakten Benutzernamen eingeben. Erst nach Annahme können Textnachrichten gesendet werden. Wer eine Anfrage abgelehnt hat, kann später selbst eine neue Anfrage an den ursprünglichen Absender senden. Ein abgelehnter Absender kann nicht einfach erneut anfragen.
- **Nachrichten:** maximal 4.000 Zeichen. Keine Datei-Anhänge, kein Verkaufssystem, keine Zahlungen. Versandzeitpunkte werden angezeigt; Lesebestätigungen lauten lediglich „Gelesen“.
- **Aufbewahrung:** keine automatische Löschung (Standard), 24 Stunden, 7, 30 oder 90 Tage. Änderungen müssen vom jeweils anderen Teilnehmer bestätigt werden und gelten nur für neu gesendete Nachrichten. Bereits gesendete Nachrichten behalten ihre Frist.
- **Löschung:** entfernt den Verlauf nur aus der eigenen Ansicht. Ein neuer Kontakt oder eine neue Nachricht kann die Unterhaltung wieder anzeigen; der zuvor ausgeblendete Verlauf bleibt in dieser Ansicht ausgeblendet. Blockieren verhindert weitere Nachrichten.
- **Weitere Geräte:** auf dem neuen Gerät Freigabe anfragen. Auf einem bereits entsperrten Gerät unter „Geräte und Sicherheit“ den vollständigen Gerätecode vergleichen und freigeben. Alternativ Wiederherstellungsschlüssel eingeben.
- **Lokales Vergessen:** „Chat auf diesem Gerät vergessen“ entfernt die lokalen Zugangsschlüssel. Das ist kein kryptografischer Rückruf eines verlorenen oder kompromittierten Geräts; bereits kopierte Schlüssel oder Nachrichten können dadurch nicht zurückgerufen werden.
- **Meldung:** Meldegrund wählen. Eine zusätzliche Bestätigung gibt den gesamten noch verfügbaren Verlauf zu diesem Zeitpunkt einschließlich eigener Nachrichten zur Prüfung frei. Der Server friert eine Meldungskopie ein; spätere Nachrichten bleiben ausgeschlossen. Die Kopie wird ausschließlich für den Admin-Schlüssel verschlüsselt. Bereits abgelaufene Nachrichten fehlen.
- **Admin:** unter Verwaltung erscheinen Regelbestätigungen mit Regelversion, serverseitigem Datum und Uhrzeit in Europe/Berlin. Frühere Versionen bleiben erhalten. Meldungen lassen sich erst nach Entsperren des Admin-Chats entschlüsseln. Chat-Zugänge können gesperrt oder freigegeben werden. Eine abgeschlossene Meldung bleibt als Prüfnachweis erhalten.

## Daten und Prüfungen

Die Chat-Änderungen schreiben keine Kartenwerte, Listen oder Pullraten um. Alle vorher gespeicherten Kartenwerte sind erhalten geblieben; während der Umsetzung regulär neu gespeicherte Werte wurden ebenfalls beibehalten. Die Testkonten und Testbestätigungen im Zielprojekt wurden vollständig zurückgerollt. Es wurde keine echte Regelbestätigung stellvertretend für einen Nutzer erzeugt.

- 16 bestandene Unit-/Kryptografie-Tests.
- Datenbanktests für bestehende Listen und für Chat-Berechtigungen, Zustimmungen, Kontaktanfragen, Verschlüsselung, beidseitige Aufbewahrung, Blockierung, Löschung und Meldungen.
- Zugriffsprüfungen mit der Rolle `authenticated` im Zielprojekt: kein Lesen durch Außenstehende oder Admins ohne Meldung, keine anonymen Aufrufe, kein direkter Tabellen- oder Hilfsfunktionszugriff.
- Build erfolgreich; statische HTML-/Modulziele geprüft.
- Cron-Bereinigung erfolgreich. Abgelaufene Nachrichten werden bei API-Aufrufen entfernt, zusätzlich läuft eine Bereinigung jede Minute. Meldungskopien bleiben davon ausgenommen.

**Offen:** Ein interaktiver Browser-/Mehrgeräte-Durchlauf und eine unabhängige Sicherheitsprüfung sind noch nicht erfolgt. Die Implementierung ist nicht als unabhängig auditiert zu verstehen. Details und Grenzen stehen in `chat/SECURITY.md`.

## Entwicklerprüfungen

`npm test`, `npm run test:db`, `npm run build`.

Die bisherigen Gesamtbackups betreffen weiterhin Kartenlisten; sie enthalten keine Chat-Schlüssel. Zur Chat-Wiederherstellung ist ausschließlich die persönliche Wiederherstellungsdatei oder ein freigegebenes Gerät geeignet.
