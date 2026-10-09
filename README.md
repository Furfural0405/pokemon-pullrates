# Pokémon Pullrates

Dunkle, responsive Kartenübersicht für **30th Celebration / 30th C auf vereinfachtem Chinesisch**. Statisches Frontend für GitHub Pages, Supabase Auth und PostgreSQL. Aktuell vorbereitet und lokal getestet, noch nicht mit einem neuen Live-Projekt verbunden.

## Verhalten

- Öffentliche Ansicht: Kartenbilder und gerundete Pullraten im Format `1 / x`. Keine Rohzahlen, Nutzerlisten oder Boosterbasis in der öffentlichen API.
- Registrierung mit E-Mail/Passwort. Neue Konten erhalten `pending`; ein Admin muss sie freigeben. Eine Anmeldung allein erteilt keine Schreibrechte.
- Freigegebene Nutzer bearbeiten nur ihren eigenen Datensatz. Alle Karten werden als absolute Stückzahlen erfasst; Speichern erfolgt gemeinsam und mit Versionsprüfung.
- Boosterbasis: Summe der Stückzahlen für 017/103 bis 046/103. Pokémon China bestätigt genau eine dieser Pikachu-Karten pro Booster.
- Eigene Admin-Werte fließen live in die öffentliche Statistik ein. Der Admin übernimmt bei Bedarf eine **Momentaufnahme** eines Nutzer-Datensatzes. Erneutes Übernehmen ersetzt die vorherige Momentaufnahme und verhindert doppelte Anrechnung. Spätere Nutzeränderungen benötigen eine erneute Übernahme. Beiträge sind wieder entfernbar.
- Supabase Realtime veröffentlicht ausschließlich `public.pull_rates`. Bei Verbindungsproblemen wird alle 30 Sekunden aktualisiert.
- Persönliches JSON-Backup mit Importvorschau. Export enthält den aktuellen Formularstand, auch ungespeicherte Eingaben. Import ersetzt den eigenen Datensatz vollständig.
- Admin-Gesamtbackup: eigene Werte aller Nutzer und geprüfte öffentliche Momentaufnahmen. Wiederherstellung ist atomar, prüft Versionen und übernimmt keine Rollen oder Freigaben aus der Datei. Nutzerkonten müssen bereits vorhanden sein; Supabase-Auth-Passwörter sind nicht enthalten.
- Passwort vergessen / Wiederherstellung enthalten.

## Einrichtung in Supabase

1. Neues Projekt `pokemon-pullrates` in der vom Eigentümer bestätigten Organisation anlegen. Region beispielsweise Frankfurt `eu-central-1`. Kosten vor Erstellung bestätigen.
2. `supabase/schema.sql` einmal im neuen Projekt ausführen. Das bestehende Projekt wird nicht verändert.
3. In Auth: E-Mail-Anmeldung aktivieren, E-Mail-Bestätigung aktivieren, anonyme Anmeldung deaktivieren. Site URL und zulässige Redirect URL auf `https://Furfural0405.github.io/pokemon-pullrates/` setzen (bei anderer Domain entsprechend anpassen).
4. URL und **publishable key** in `config.js` eintragen. Niemals `service_role` oder einen Secret Key im Frontend verwenden.
5. Eigentümer registriert sich mit seiner bestätigten Admin-E-Mail und bestätigt diese. Die bestätigte Eigentümer-E-Mail wird bei der Einrichtung im privaten Schema konfiguriert; nach E-Mail-Bestätigung erhält nur dieses Konto automatisch Admin-Rechte. Bei manueller Einrichtung das Konto gezielt im SQL Editor zum Admin ernennen. Die erste beliebige Registrierung wird ausdrücklich **nicht** automatisch Admin.

```sql
-- Nur nach Prüfung und mit der ausdrücklich bestätigten Eigentümer-E-Mail.
begin;
update pull_private.profiles
set role = 'admin', status = 'approved'
where id = (
  select id from auth.users
  where lower(email) = lower('HIER_BESTAETIGTE_ADMIN_EMAIL')
    and email_confirmed_at is not null
);
select pull_private.refresh_rates();
commit;
```

Das Update muss genau ein Konto treffen. Nach Live-Einrichtung Supabase Security Advisors und die realen API/Realtimeschnittstellen prüfen. Auth-Einstellungen und Live-WebSocket-Funktion wurden bislang noch nicht in einem neu angelegten Projekt geprüft.

## GitHub Pages

Repository `Furfural0405/pokemon-pullrates` erstellen und diese Dateien auf `main` übertragen. In **Settings → Pages → Source** `GitHub Actions` auswählen. `.github/workflows/pages.yml` baut und veröffentlicht die statische Webseite nach erfolgreichem Testlauf. GitHub Pages erfordert eine passende Repository-Sichtbarkeit bzw. einen dafür geeigneten GitHub-Tarif.

```sh
npm ci
npm test
npm run test:db
npm run build
```

`dist/` enthält die statische Webseite. Alle Pfade sind relativ und für den Repository-Unterpfad geeignet. Abhängigkeiten sind fest versioniert, `package-lock.json` ist enthalten. Die Entwicklungstests verwenden PGlite (PostgreSQL im lokalen Prozess) mit simulierten Supabase-Rollen und Auth-Identitäten.

## Datenzugriff

Alle Profile, Counts, Snapshots und Änderungsstände liegen im nicht exponierten Schema `pull_private`. Basis-Tabellen sind mit RLS versehen und für `anon` / `authenticated` gesperrt. Ein explizit freigegebener RPC `public.pull_app` führt einen Aufruf der privaten Funktion aus. Diese prüft bei **jedem** Aufruf `auth.uid()` und die aktuelle Freigabe/Rolle aus der Datenbank. Nutzer können keine Freigaben oder Rollen über Metadaten ändern. Mutationen sind serialisiert, versioniert und in einer privaten Historie protokolliert.

Die öffentlichen gerundeten Werte verhindern einen direkten Abruf der Boosterbasis. Öffentliche Verhältnisse können jedoch mathematische Rückschlüsse ermöglichen, insbesondere wenn zusätzliche Informationen bekannt sind; eine absolute Unerschließbarkeit der Stichprobengröße ist bei veröffentlichten Statistiken nicht zugesichert.

## Karten und Bilder

169 Einträge entsprechend der gelieferten Übersicht; Karten 119, 128, 129 und 131 fehlen bereits in dieser Quelle. Energiekarten bekommen eigene interne IDs statt erfundener `/103`-Nummern. `cards.json` dokumentiert Bildquellen, Maße und Prüfstatus.

- [Pokémon China: offizielle Produktinformationen](https://www.pokemon.cn/tcg/product/22237.html)
- [PokiPair: Simplified Chinese Kartenreferenz](https://www.pokipair.com/30th-anniversary-30thc-card-list/)
- 8 lokal gespeicherte offizielle HD-Bilder mit ca. 868 × 1210 px: 058, 077, 078, 093, 137, 160, 163, 165. Bei offiziellen Sammelgrafiken wurde nur das Kartenrechteck ausgeschnitten.
- Die übrigen Originalbilder haben 350 × 482 px und werden in der Oberfläche **nicht als HD** bezeichnet.
- Alle Bilder in Kontaktübersichten auf Sprache und Kartenmotiv geprüft; Kartennummern zusätzlich soweit lesbar abgeglichen. Korrekturen: Mewtwo FUR = 134/103; Unown-Schreibweise; Trainerkarten 101 = Ultra Ball, 102 = Poke Pad, 103 = Switch; Energien nach dem tatsächlichen Symbol benannt.
- Weitergehende Bildprüfung und fehlende Karten stehen noch aus; keine japanischen oder traditionell chinesischen Ersatzbilder verwendet.

Inoffizielles Fanprojekt. Pokémon und Kartenabbildungen gehören ihren jeweiligen Rechteinhabern. Die Webseite dokumentiert Quellen und behauptet keine Verbindung zu The Pokémon Company.

## Noch offen vor Live-Betrieb

- GitHub-Veröffentlichung abschließen und den veröffentlichten Build prüfen.
- Supabase-Organisation und Kosten bestätigen; Projekt erstellen, SQL einspielen und Auth konfigurieren.
- Bestätigte Admin-E-Mail im neuen privaten Schema konfigurieren und das verifizierte Konto zuordnen.
- Vollständiger Browser-Funktionstest und Live-Realtime-Test nach Verbindung des Projekts. Lokaler Build und PostgreSQL-Sicherheitstests bestanden; die Live-Integration erfordert das neue Supabase-Projekt.
