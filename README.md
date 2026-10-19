# FTN-Coop · 0.1.3

[English](#english) · [Deutsch](#deutsch)

## English

An independent, unofficial co-op mod for **Find The Needle Demo on Windows**.
One host and up to three friends work in the same world. Money, research,
hay, buildings and needles belong to the shared session.

**Development status: Internet play between different Steam accounts is still
unverified.** Local checks use real demo instances, but do not replace a test
with friends over Steam. Only demo build **25963876 (V66)** is currently
supported. The full game and later game updates require a new compatibility check.

**Download:** [Installer and ZIP on the Releases page](https://github.com/GaleR-Tech/FTN-Coop/releases).
You do not need to work with source code to play.

If you enjoy the mod, you can support its development with a coffee:

<a href="https://buymeacoffee.com/galertech"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me a Coffee – support GaleR Tech" width="217" height="60"></a>

**Terms of use:** The source code is publicly available for inspection, but is
not licensed as open source. Playing the unmodified mod for your own private,
non-commercial use is permitted free of charge. Modifying the mod code, reusing
it in other projects and further distribution require prior written permission,
except as permitted by the [LICENSE](LICENSE) or mandatory law. GitHub platform
rights, particularly viewing and forking, remain unaffected. An
[English translation](LICENSE.en.txt) is available; the German LICENSE takes
precedence in case of discrepancies.

### What do I need?

Every player needs Steam, the free **Find The Needle Demo** and the same FTN-Coop
package. You do not need the Godot editor, programming tools, additional Steam
libraries or PowerShell 7. The package uses the PowerShell included with Windows.
Steam must be running, and the Steam overlay must be available for invitations.

### Choose a language

New in 0.1.2: The setup EXE and the F2 co-op menu are available in **German and
English**. You can select the language in each. Unless you choose a language
manually, a German operating system language selects German; all other operating
system languages select English.
Your F2 menu language preference is saved for later game launches. The demo's own
content continues to use its own language settings.

### Installation

New in 0.1.3: The installer has a dark interface with gold accents. It shows the installed and package versions and selects the matching action. The progress indicator stays indeterminate while files are being processed; completion is only shown after the result is known. The **GitHub project** link opens the source repository in your browser.

The easiest option is **FTN-Coop-0.1.3-Setup.exe**:

1. Close the game and double-click the EXE.
2. Check the automatically detected demo folder, or select it using **Browse…**.
3. Click **Install** / **Update** and wait for the success message.
4. Start the demo normally through Steam and press **F2** to open the co-op menu.

The single EXE contains all mod files and requires no additional download during
installation. It uses existing Windows components (.NET Framework and Windows
PowerShell). The EXE is not digitally signed. To remove the mod, open the same EXE
again and choose **Remove mod**.

The ZIP package also remains available:

1. Close the game and fully extract the ZIP to its own folder.
2. Double-click **Install.cmd**. The installer searches your Steam libraries
   for the installed demo. If it cannot find it, enter the demo folder:
   Steam → Demo → Properties → Installed Files → Browse.
3. Start the demo **normally through Steam**. Do not add test launch options.
4. Press **F2** to open the co-op menu.

The German launcher names **Installieren.cmd** and **Entfernen.cmd** remain
available as aliases for **Install.cmd** and **Remove.cmd**.

Installation adds the mod's own files under `mods/ftn_coop` and an entry in
`override.cfg`. The original EXE/PCK files remain unchanged. Removal takes existing
settings and other mod files into account.

### Play with friends

When you join, the F2 menu shows the actual proportion of world data received,
followed by separate world construction and progress synchronization stages.
The percentage describes data reception. The session becomes playable only
after world construction and synchronization are complete.

A successful save displays a confirmation with the time. **Copy error report**
copies a short technical report to your clipboard. It includes the mod and demo
versions, engine version, session status, player count, loading stage and a known
error code. Player names, Steam IDs, paths, session identifiers and save files are
excluded. The report is not sent automatically; you can review it before sharing.

1. The **host** first loads or starts their normal save.
2. F2 → **Create session** → **Invite friends** opens the Steam invitation.
3. Friends start their demo through Steam and accept the invitation. A private
   session supports up to **four players including the host**.
4. Wait for loading to finish while the world is loading. Guest actions become
   available after that. F2 closes the menu and releases the mouse for gameplay.

The host uses the normal game controls. Guests use **WASD**, the mouse,
**Space** to jump, **left click** for the selected tool, **E** to pick up,
**G** to put down, **R** to throw and **Delete** to dismantle. Guests can select
unlocked tools with **1–8** or in the F2 menu. That menu also provides purchases,
research, building selection, needle delivery and machine on/off controls.
Purchases require the usual proximity to the shop and enough shared money.
Deliver needles at the appropriate cabinet; machines and buildings must be
within reach.

All participants must use exactly the same mod version and demo build. An incompatible mod version is rejected before world loading. The F2 menu shows your installed version, the version required by the lobby and an **Open mod downloads** button. Everyone should install the same package, then restart the demo; this also applies if the host has an older version. Connections
are designed to use Steam relays; router port forwarding is not part of setup.

### Save and leave

The shared progress is stored **by the host**. The host can save in the F2 menu;
ending the host session also saves progress. Before the mod saves, an existing
slot is backed up as `.ftn-coop-last-good`. Write failures are reported, and the
last valid save is restored.

Guests load a temporary world under `user://ftn_coop/sessions/`. Their own
single-player saves are not used as co-op saves. **Leave session** returns to the
main menu and removes that guest's temporary session directory. Canceling while
loading may wait until the native loading process has safely completed and the
temporary world has been closed. A new invitation can then be accepted. When the
host leaves, the session ends for everyone; there is no host migration.

### Remove or update

Close the game and choose **Remove mod** in the setup EXE, or run **Remove.cmd**
from the ZIP. Locally modified mod files are retained as a precaution, and later
configuration changes made by other software remain intact. Save files are not
deleted. To update, use **Install** / **Update** in the new EXE or **Install.cmd**
from the new ZIP package. Back up locally modified mod files first; otherwise,
the update refuses to overwrite them.

If you receive an error, first close the game and check that you selected the
demo folder. “Unsupported version” means that the installed game build has not
yet been approved for the mod. After a game update, remove the mod and wait for
a verified version.

### Known limitations and test status

- Custom player characters and the guest display of loose resources are simplified.
- Four real demo instances on this computer passed shared world synchronization,
  including conveyor construction, needle delivery, tools, cancel/rejoin and
  save/reload. Local test suites also cover session behavior, world
  synchronization, saving and installation.
- Guests use the mod's own co-op controls. Not every native special function or
  decorative effect has been tested with friends.
- The demo disables its leaderboards when mods are loaded.
- Invitations, Steam data transfer over the Internet and four separate accounts
  remain unverified. The steps are in the
  [playtest checklist](docs/playtest-checklist.en.md).

Source code: `mods/ftn_coop/`. Full terms: [LICENSE](LICENSE), with an
[English translation](LICENSE.en.txt). Notices concerning the game and other
rights holders: [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt).

---

## Deutsch

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

### Was muss installiert sein?

Jeder braucht Steam, die kostenlose **Find The Needle Demo** und dasselbe
FTN-Koop-Paket. Godot-Editor, Programmierwerkzeuge, zusätzliche Steam-Bibliotheken
und PowerShell 7 sind nicht nötig. Das Paket nutzt die mit Windows gelieferte
PowerShell. Steam muss laufen; das Steam-Overlay muss für Einladungen verfügbar sein.

### Sprache auswählen

Neu in 0.1.2: Die Setup-EXE und das F2-Koop-Menü sind auf **Deutsch und Englisch**
verfügbar. In beiden kannst du die Sprache auswählen. Ohne manuelle Auswahl wird
bei deutscher Betriebssystemsprache Deutsch verwendet, sonst Englisch.
Die Sprachwahl im F2-Menü wird für spätere Spielstarts gespeichert. Die Inhalte
der Demo selbst folgen weiterhin deren eigenen Spracheinstellungen.

### Installation

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

### Mit Freunden spielen

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

### Speichern und Verlassen

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

### Entfernen und Aktualisieren

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

### Bekannte Grenzen und Teststatus

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
