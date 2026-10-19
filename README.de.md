# FTN-Koop · 0.1.3

[English](README.en.md) · Deutsch

Eigene, inoffizielle Koop-Mod für **Find The Needle Demo unter Windows**.
Ein Host und bis zu drei Freunde arbeiten in derselben Welt. Geld, Forschung,
Heu, Gebäude und Nadeln gehören zur gemeinsamen Sitzung.

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

Am einfachsten mit **FTN-Coop-0.1.3-Setup.exe**:

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

## Mit Freunden spielen

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

Der Host verwendet die normale Spielsteuerung. Für Gäste: **WASD**, Maus,
**Leertaste** zum Springen, **Linksklick** für das ausgewählte Werkzeug,
**E** aufnehmen, **G** ablegen, **R** werfen und **Entf** abbauen. Freigeschaltete
Werkzeuge wählen Gäste mit **1–8** oder im F2-Menü. Dort stehen außerdem Käufe,
Forschung, Bauauswahl, Nadelabgabe und Maschinen-Ein/Aus zur Verfügung.
Käufe erfordern die übliche Nähe zum Laden und genügend gemeinsames Geld.
Nadeln am passenden Schrank abgeben; Maschinen und Gebäude müssen in Reichweite sein.

Alle Teilnehmer müssen exakt dieselbe Mod-Version und denselben Demo-Build verwenden. Abweichende Mod-Versionen werden vor dem Laden der Welt abgewiesen. Im F2-Menü stehen die installierte und die von der Lobby benötigte Version sowie **Mod-Downloads öffnen**. Alle sollten dasselbe Paket installieren und die Demo neu starten; das gilt auch, wenn der Host eine ältere Version hat.
Verbindungen sind für Steam-Relays vorgesehen; eine Portfreigabe am Router
gehört nicht zur Einrichtung.

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
- Gäste steuern über die eigene Koop-Bedienung. Nicht jede native Sonderfunktion
  oder dekorative Wirkung ist bereits mit Freunden geprüft.
- Die Demo schaltet bei geladenen Mods ihre Bestenlisten ab.
- Einladung, Steam-Datenübertragung über das Internet und vier getrennte Konten
  sind noch offen. Die Schritte stehen in [der Testliste](docs/playtest-checklist.md).

Quellcode: `mods/ftn_coop/`. Vollständige Bedingungen: [LICENSE](LICENSE).
Englische Übersetzung: [LICENSE.en.txt](LICENSE.en.txt); bei Abweichungen gilt
die deutsche LICENSE.
Hinweise zum Spiel und anderen Rechteinhabern: [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt).
