# FTN-Koop · 0.6.3

[English](README.en.md) · Deutsch

Eigene, inoffizielle Koop-Mod für **Find The Needle Demo** (Windows; Linux-Installer für Steam Proton).
Ein Host und bis zu drei Freunde arbeiten in derselben Welt. Geld, Forschung,
Heu, Gebäude und Nadeln gehören zur gemeinsamen Sitzung.

Version **0.6.3** verringert den Aufwand größerer Fabrikupdates durch kompakte Datenspalten, frühere Komprimierung und einmaliges Aufbereiten für alle Gäste. Native Spielwerte und Datenprüfungen bleiben erhalten. Heu in der normalen Gasthand folgt jetzt der eigenen Kamera; neue Hostdaten erhalten auch die lokale Darstellung getragener Werkzeugladungen und Gegenstände. Gastquests ersetzen einen abgeschlossenen Schritt auch bei angehaltenem Anzeige-Timer. Alle müssen aktualisieren und neu starten. Die Internetlatenz im betroffenen Spielstand braucht weiterhin einen Test auf den betroffenen PCs.

**Entwicklungsstand: Internetbetrieb zwischen verschiedenen Steam-Konten ist
noch unbestätigt.** Die lokalen Prüfungen verwenden echte Demo-Instanzen,
ersetzen aber keinen Test mit Freunden über Steam. Derzeit ist ausschließlich
Demo-Build **25963876 (V66)** freigeschaltet. Die Vollversion und spätere
Spielupdates benötigen eine erneute Prüfung.

**Download:** [Installer und ZIP unter Releases](https://github.com/GaleR-Tech/FTN-Coop/releases).
Zum Spielen ist kein Umgang mit dem Quellcode nötig.

Wenn dir die Mod gefällt, kannst du die Entwicklung mit einem Kaffee unterstützen:

<a href="https://buymeacoffee.com/galertech"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me a Coffee – GaleR Tech unterstützen" width="217" height="60"></a>

**Nutzungsbedingungen:** Der Quellcode ist öffentlich einsehbar, aber keine
Open-Source-Freigabe. Unverändertes privates, nichtkommerzielles Spielen ist
kostenlos erlaubt. Änderungen am Mod-Code, Übernahme in andere Projekte und
weitere Veröffentlichungen benötigen vorherige schriftliche Zustimmung,
soweit die [LICENSE](LICENSE) oder zwingendes Recht nichts anderes erlauben.
GitHub-Plattformrechte, insbesondere das Ansehen und Forken, bleiben bestehen.

## Was muss installiert sein?

Jeder braucht Steam, die kostenlose **Find The Needle Demo** und dasselbe
FTN-Koop-Paket. Godot-Editor, Programmierwerkzeuge, zusätzliche Steam-Bibliotheken
und PowerShell 7 sind nicht nötig. Das Paket nutzt die mit Windows gelieferte
PowerShell. Steam muss laufen; das Steam-Overlay muss für Einladungen verfügbar sein.

## Sprache auswählen

Neu in 0.1.2: Die Setup-EXE und das F2-Koop-Menü sind auf **Deutsch und Englisch**
verfügbar. In beiden kannst du die Sprache auswählen. Ohne manuelle Auswahl wird
bei deutscher Betriebssystemsprache Deutsch verwendet, sonst Englisch.
Die Sprachwahl im F2-Menü wird für spätere Spielstarts gespeichert. Die Inhalte
der Demo selbst folgen weiterhin deren eigenen Spracheinstellungen.

## Installation

Neu in 0.1.3: Der Installer hat eine dunkle Oberfläche mit goldenen Akzenten. Er zeigt installierte und enthaltene Version sowie die passende Hauptaktion. Die Fortschrittsanzeige bleibt während der Verarbeitung unbestimmt; ein Abschluss erscheint erst nach dem tatsächlichen Ergebnis. **GitHub-Projekt** öffnet das Quellcode-Repository im Browser.

Am einfachsten mit **FTN-Coop-0.6.3-Setup.exe**:

1. Das Spiel schließen und die EXE doppelklicken.
2. Den automatisch gefundenen Demo-Ordner prüfen oder über **Ordner …** auswählen.
3. **Installieren** / **Aktualisieren** anklicken und die Erfolgsmeldung abwarten.
4. Die Demo normal über Steam starten und mit **F2** das Koop-Menü öffnen.

Die einzelne EXE enthält alle Mod-Dateien und benötigt keinen zusätzlichen
Download während der Installation. Sie verwendet die vorhandenen Windows-Komponenten
(.NET Framework und Windows PowerShell). Die EXE ist nicht digital signiert.
Zum Entfernen dieselbe EXE erneut öffnen und **Mod entfernen** wählen.

Alternativ funktioniert weiterhin das ZIP-Paket:

1. Das Spiel schließen und das ZIP vollständig in einen eigenen Ordner entpacken.
2. **Installieren.cmd** doppelklicken. Die installierte Demo wird in den
   Steam-Bibliotheken gesucht. Falls sie nicht gefunden wird, den Demo-Ordner
   einfügen: Steam → Demo → Eigenschaften → Installierte Dateien → Durchsuchen.
3. Die Demo **normal über Steam** starten. Keine zusätzlichen Test-Startparameter setzen.
4. Mit **F2** das Koop-Menü öffnen.

Die Installation ergänzt eigene Dateien unter `mods/ftn_coop` und einen Eintrag
in `override.cfg`. Originale EXE/PCK bleiben unverändert. Bestehende Einstellungen
und andere Mod-Dateien werden bei der Entfernung berücksichtigt.

## Linux-Installation (Ubuntu / Mint)

Neu in **0.4.0**: **FTN-Coop-0.6.3-Linux.run** unter Releases herunterladen.
Die einzelne Datei enthält den Installer und alle Mod-Dateien. Benötigt werden
**Python 3.8 oder neuer** und für das optionale Fenster **python3-tk**; zusätzliche
pip-Pakete sind nicht nötig. Demo vor Installation, Update oder Entfernung schließen.

1. Windows-Demo über Steam installieren und in den Steam-Eigenschaften der Demo
   ein Proton-Kompatibilitätswerkzeug aktivieren. Das Paket enthält kein natives Linux-Spiel.
2. Im Terminal in den Download-Ordner wechseln und starten:

   ```sh
   python3 FTN-Coop-0.6.3-Linux.run
   ```

3. Erkannten Demo-Ordner prüfen oder über **Ordner auswählen** ändern. **Installieren**
   bzw. **Aktualisieren** anklicken. Das Fenster bietet auch **Mod entfernen**,
   Sprachwahl sowie GitHub- und Buy-me-a-Coffee-Links. Mit dem normalen Benutzerkonto
   ausführen, ohne sudo.
4. Demo über Steam mit Proton starten und **F2** drücken.

Ohne grafisches Fenster steht die Terminal-Oberfläche bereit:

```sh
python3 FTN-Coop-0.6.3-Linux.run --cli
```

Einen bestimmten Ordner mit `--install --game-dir "/pfad/zu/Find The Needle Demo"`
angeben; zum Entfernen `--remove` anstelle von `--install` verwenden. Die Sprache
lässt sich mit `--language de` oder `--language en` wählen. Steam-Bibliotheken,
weitere Bibliothekspfade und der übliche Flatpak-Steam-Ordner werden automatisch
gesucht. Flatpak muss bereits Zugriff auf die ausgewählte Bibliothek haben.

Updates behalten die bisherige Installationsdatei und überschreiben keine lokal
geänderten Mod-Dateien. Beim Entfernen wird die unveränderte ursprüngliche
Konfiguration bytegenau wiederhergestellt oder nur der eigene Eintrag aus einer
später bearbeiteten Konfiguration entfernt. Original-Spiel-Dateien, Spielstände
und andere Mods bleiben erhalten. Der Installer lädt nichts nach.

**Prüfgrenze:** Datei-, Paket- und Oberflächentests liefen auf dem Windows-
Entwicklungsrechner. Ausführung unter Ubuntu/Mint, Desktop-Integration,
Proton-Spielbetrieb und gemeinsame Windows/Linux-Sitzungen benötigen noch einen
echten Linux-Test. Alle Teilnehmer brauchen **0.6.3** und Demo-Build **25963876**.
Internetspiel zwischen getrennten Steam-Konten bleibt unbestätigt.

## Mit Freunden spielen

Neu in 0.1.4: Eine fehlende Host-Antwort, ausbleibende erste Weltdaten oder ein
festhängender abschließender Abgleich enden jetzt mit einer klaren Zeitüberschreitung
statt eines endlosen Ladebildschirms. Steam-Fehler erklären geschlossene/volle
Lobbys, Kontoeinschränkungen und zu viele Beitrittsversuche in beiden Sprachen.
Der Fehlerbericht behält den konkreten Fehlercode.

Beim Beitritt zeigt das F2-Menü den tatsächlich empfangenen Anteil
der Weltdaten und anschließend getrennt den Weltaufbau und Fortschrittsabgleich.
Die Prozentzahl beschreibt den Datenempfang. Erst nach dem anschließenden Aufbau
und Abgleich ist die Sitzung spielbereit.

Nach erfolgreichem Speichern erscheint eine Bestätigung mit Uhrzeit.
**Fehlerbericht kopieren** legt einen kurzen technischen Bericht in die
Zwischenablage. Er enthält Mod-/Demo-Version, Engine-Version, Sitzungsstatus,
Spielerzahl, Ladephase und einen bekannten Fehlercode. Spielernamen, Steam-IDs,
Pfade, Sitzungskennungen und Spielstände werden nicht aufgenommen. Der Bericht
wird nicht automatisch versendet; du kannst ihn vor dem Teilen prüfen.

1. Der **Host** lädt oder beginnt zuerst seinen normalen Spielstand.
2. F2 → **Sitzung erstellen** → **Freunde einladen** öffnet die Steam-Einladung.
3. Freunde starten ihre Demo über Steam und nehmen die Einladung an. Eine
   private Sitzung hat höchstens **vier Spieler einschließlich Host**.
4. Während „Welt wird geladen“ auf den Abschluss warten. Erst danach sind
   Gastaktionen freigegeben. F2 schließt das Menü und gibt die Maus frei zum Spielen.

Gäste öffnen den originalen Baukatalog mit **B**, den Forschungsbaum mit
**Tab / T** und das Pausemenü mit **Escape**. Im geöffneten Menü ruhen Bewegung
und Weltaktionen dieses Spielers. Forschungskäufe und Bauaktionen bestätigt der
Host; Speichern und Laden sind für Gäste gesperrt. F2 bleibt für die Koop-Bedienung.

Standardsteuerung für Gäste: **WASD**, Maus, **Leertaste** springen,
**Umschalt** sprinten mit der normalen Ausdauer, **Linksklick** benutzen,
**E** aufnehmen, **Q** ablegen, **F / Rechtsklick** werfen, **X** abbauen und
**1–0** für die normale Schnellleiste. Diese Aktionen folgen der persönlichen
Tastenbelegung des Spiels. Gekaufte Standardwerkzeuge werden gemeinsam
freigeschaltet: Jeder kann sofort eine eigene Kopie auswählen und benutzen.
Ablegen oder Aufnehmen nimmt anderen Spielern ihr Werkzeug nicht weg.
Behälter wie Eimer bleiben einzelne physische Objekte. F2 bietet außerdem
Ladenkäufe, Nadelabgabe und Maschinen-Ein/Aus.
Käufe erfordern die übliche Nähe zum Laden und genügend gemeinsames Geld.
Nadeln am passenden Schrank abgeben; Maschinen und Gebäude müssen in Reichweite sein.

Alle Teilnehmer müssen exakt dieselbe Mod-Version und denselben Demo-Build verwenden. Abweichende Mod-Versionen werden vor dem Laden der Welt abgewiesen. Im F2-Menü stehen die installierte und die von der Lobby benötigte Version sowie **Mod-Downloads öffnen**. Alle sollten dasselbe Paket installieren und die Demo neu starten; das gilt auch, wenn der Host eine ältere Version hat.
Verbindungen sind für Steam-Relays vorgesehen; eine Portfreigabe am Router
gehört nicht zur Einrichtung.

## Gemeinsame Spieleinstellungen

Neu in **0.2.0**: Über F2 → **Gemeinsame Spieleinstellungen** ändert der Host die
Werte für die gesamte Sitzung. Gäste sehen die aktuellen Werte mit **Vom Host
vorgegeben**; ihre Bedienelemente sind gesperrt. Änderungen werden während des
Spielens abgeglichen, beim Beitritt bereits vor dem Weltaufbau übernommen.

Gemeinsam gelten Objektgrenzen und automatisches Entfernen für lose Objekte und
Förderband-Inhalte, automatisches Aufräumen samt Intervall, das Ausrichten am
Bauraster und das automatische Speichern samt Intervall beim Host. Nur der Host
speichert die gemeinsame Welt.

Die eigenen Spielwerte des Gastes werden beim Verlassen, Abbrechen und Host-Verlust
wiederhergestellt. Grafik, Ton, Sprache und Steuerung bleiben individuell. Während
der Gastsitzung geänderte persönliche Optionen werden beim normalen Verlassen oder
Schließen der Demo gespeichert; bei erzwungenem Beenden können diese letzten
persönlichen Änderungen verloren gehen. Vorübergehende Host-Werte werden nicht in
die persönliche Einstellungsdatei des Gastes geschrieben.

## Markierungen, Spielerstatus und Wiederbeitritt

Neu in **0.3.0**: **F8** markiert beim Spielen die angeschaute Oberfläche in
höchstens 50 Metern Entfernung. In F2 wählst du **Markierung**, **Hier bauen**,
**Hier liegt eine Nadel** oder **Hilfe**. Jeder Spieler hat eine Markierung,
die 20 Sekunden sichtbar bleibt; eine neue ersetzt die vorherige. Markierungen,
Spielernamen und Figuren verwenden passende Spielerfarben. In Menüs, bei
Texteingaben und beim Laden einer Welt setzt F8 keine Markierung.

Die F2-Spielerliste zeigt Laden/Abgleichen/Spielen und die gemessene Antwortzeit
in Millisekunden. Fehlende Messungen werden als nicht verfügbar angezeigt;
der lokale Host steht als **Host** in der Liste. Die Messung enthält auch die
Verarbeitungszeit des Spiels.

Nach einem unerwarteten Abbruch bietet **Letzter Sitzung erneut beitreten** einen
frischen Beitritt an, sobald die alte Gastwelt geschlossen ist. Der Host muss
dieselbe Sitzung noch geöffnet haben. Bewusstes Verlassen und das Schließen der
Demo löschen das gemerkte Ziel. Beim Wiederbeitritt wird die aktuelle Host-Welt
geladen; deine vorherige Position ist nicht garantiert.

## Einstellungsvorlagen und Updateprüfung

Der Host kann unter F2 → **Gemeinsame Spieleinstellungen** benannte Vorlagen
speichern, anwenden und löschen. Bis zu 20 Vorlagen speichern ausschließlich
die neun gemeinsamen Spielwerte lokal auf diesem Rechner. Beim Anwenden übernehmen
alle Gäste die Werte; persönliche Grafik-, Ton- und Steuerungswerte bleiben getrennt.

**Nach Updates suchen** fragt erst nach deinem Klick den öffentlichen
GitHub-Releases-Dienst ab. Bei einer neueren normalen Veröffentlichung führt
ein Knopf zu den Mod-Downloads. Die Prüfung lädt oder installiert nichts.
Abfragen sind einmal pro Minute möglich; ohne Verbindung oder bei einem
Anfragelimit bleibt das Spiel benutzbar. Spielernamen, Steam-IDs, Lobbykennungen,
lokale Pfade, Fehlerberichte und Spielstände werden nicht mitgeschickt.

0.6.3 erscheint als normale GitHub-Veröffentlichung. Der Internetbetrieb mit
getrennten Steam-Konten bleibt unbestätigt.

## Speichern und Verlassen

Der gemeinsame Fortschritt liegt **beim Host**. Dieser kann im F2-Menü speichern;
beim Beenden der Host-Sitzung wird ebenfalls gespeichert. Vor einem Mod-Speichern
wird ein vorhandener Slot als `.ftn-coop-last-good` gesichert. Fehler beim Schreiben
werden gemeldet; der letzte gültige Stand wird wiederhergestellt.

Gäste laden eine temporäre Welt unter `user://ftn_coop/sessions/`. Ihre eigenen
Einzelspielerstände werden nicht als Koop-Speicher verwendet. **Verlassen** führt
zum Hauptmenü zurück und entfernt das eigene temporäre Sitzungsverzeichnis.
Ein Abbruch während des Ladens kann warten, bis der native
Ladevorgang sicher beendet und die temporäre Welt abgebaut ist. Danach kann eine
neue Einladung angenommen werden. Verlässt der Host die Sitzung, endet sie für alle;
es gibt keinen Host-Wechsel.

## Entfernen und Aktualisieren

Spiel schließen und in der Setup-EXE **Mod entfernen** wählen oder **Entfernen.cmd**
aus dem ZIP ausführen. Eigene veränderte Mod-Dateien
werden zur Sicherheit behalten; spätere fremde Konfigurationsänderungen bleiben
erhalten. Spielstände werden nicht gelöscht. Zum Aktualisieren dasselbe Verfahren
mit **Installieren** / **Aktualisieren** der neuen EXE oder **Installieren.cmd** des
neuen ZIP-Pakets verwenden. Lokal geänderte Mod-Dateien
müssen vorher gesichert werden, andernfalls verweigert das Update die Überschreibung.

Bei einer Fehlermeldung zuerst Spiel schließen und prüfen, ob wirklich der
Demo-Ordner gewählt wurde. „Nicht unterstützte Version“ bedeutet, dass der
installierte Spiel-Build noch nicht freigegeben ist. Nach einem Spielupdate
die Mod entfernen und auf eine geprüfte Fassung warten.

## Bekannte Grenzen und Teststatus

- Eigene Mitspielerfiguren und die Gastdarstellung loser Ressourcen sind vereinfacht.
- Vier echte Demo-Instanzen auf diesem Rechner bestanden den gemeinsamen
  Weltabgleich einschließlich Förderbandbau, Nadelabgabe, Werkzeugen,
  Abbruch/Wiederbeitritt und Speichern/Neuladen. Die lokalen Prüfsuiten decken
  außerdem Sitzungsabläufe, Weltabgleich, Speichern und Installation ab.
- Die originalen Bau-, Forschungs- und Pausemenüs sind für Gäste eingebunden;
  weitere Sonderfunktionen und dekorative Effekte benötigen Tests mit Freunden.
- Gemeinsame Windows/Linux-Beitritte wurden gemeldet, ebenso Linux-Host-Abstürze.
  Die Proton-Absturzursache ist ungeklärt; 0.6.3 bestätigt keine Absturzbehebung.
- Falls Gäste direkt nach dem Beitritt nicht laufen können, half in einer
  gemeldeten Sitzung Alt+Tab und Zurückwechseln. Eine automatische Fokuskorrektur ist unbestätigt.
- Die Demo schaltet bei geladenen Mods ihre Bestenlisten ab.
- Einladung, Steam-Datenübertragung über das Internet und vier getrennte Konten
  sind noch offen. Die Schritte stehen in [der Testliste](docs/playtest-checklist.md).

Quellcode: `mods/ftn_coop/`. Vollständige Bedingungen: [LICENSE](LICENSE).
Englische Übersetzung: [LICENSE.en.txt](LICENSE.en.txt); bei Abweichungen gilt
die deutsche LICENSE.
Hinweise zum Spiel und anderen Rechteinhabern: [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt).
