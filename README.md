# FTN-Coop · 0.6.3

[English](#english) · [Deutsch](#deutsch)

## English

An independent, unofficial co-op mod for **Find The Needle Demo** (Windows; Linux installer for Steam Proton).
One host and up to three friends work in the same world. Money, research,
hay, buildings and needles belong to the shared session.

Version **0.6.3** reduces the cost of larger factory updates with compact record columns, earlier compression and one prepared broadcast for all guests. Native record values and validation remain intact. Hay in the guest's normal hand now follows the local camera; incoming host updates also preserve locally held tool loads and props. Guest quests replace a completed lesson even when the native completion timer is frozen. Everyone must update and restart. Internet latency in the affected saved world still needs a test on the affected PCs.

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

The easiest option is **FTN-Coop-0.6.3-Setup.exe**:

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

### Linux installation (Ubuntu / Mint)

New in **0.4.0**: download **FTN-Coop-0.6.3-Linux.run** from Releases.
This single file includes the installer and all mod files. It needs **Python 3.8
or later**, with **python3-tk** for the optional graphical window; no pip packages
are required. Close the demo before installing, updating or removing the mod.

1. Install the Windows demo through Steam and enable a Proton compatibility tool
   in the demo's Steam properties. This package does not contain a native Linux game.
2. In a terminal, change to the folder containing the downloaded file and run:

   ```sh
   python3 FTN-Coop-0.6.3-Linux.run
   ```

3. Check the detected demo folder, or select it using **Browse**. Click **Install**
   or **Update**. The same window offers **Remove mod**, language selection, GitHub
   and Buy me a Coffee links. Use your regular user account, without sudo.
4. Start the demo through Steam with Proton, then press **F2**.

If the graphical window is unavailable, use the terminal interface:

```sh
python3 FTN-Coop-0.6.3-Linux.run --cli
```

For a specific folder, use `--install --game-dir "/path/to/Find The Needle Demo"`;
use `--remove` instead of `--install` to uninstall, and `--language en` or
`--language de` to select a language. Steam libraries, additional library paths
and the standard Flatpak Steam folder are searched automatically. Flatpak must
already have access to the selected library.

Updates preserve the existing installation record and refuse to overwrite local
mod edits. Removal restores unchanged original configuration bytes or removes
only this mod's entry from a subsequently edited configuration. Original game
binaries, saves and unrelated mods are kept. The installer downloads nothing.

**Verification limit:** filesystem, package and GUI tests were run on the Windows
development computer. Execution on Ubuntu/Mint, the graphical desktop integration,
Proton gameplay and Windows/Linux multiplayer still require a real Linux test.
All participants must use **0.6.3** and demo build **25963876**. Internet play
between separate Steam accounts remains unverified.

### Play with friends

New in 0.1.4: A missing host response, missing initial world data or a stalled
final synchronization now ends with a clear timeout instead of an endless loading
screen. Steam errors explain closed/full lobbies, account restrictions and repeated
join attempts in both languages. The report preserves the specific error code.

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

Guests can use the native building catalog (**B**), research tree (**Tab / T**)
and pause menu (**Escape**). Movement and world actions stop for that player while
a menu is open. Research purchases and building actions are confirmed by the host;
guest save/load controls are disabled. F2 remains available for co-op controls.

Default guest controls: **WASD**, mouse, **Space** to jump, **Shift** to sprint
with native stamina, **left click** to use, **E** to pick up, **Q** to drop,
**F / right click** to throw, **X** to dismantle and **1–0** for the native hotbar.
These actions follow the game's personal input bindings. Purchased standard tools
are shared unlocks: everyone can select and use their own copy immediately.
Dropping or picking up a copy does not take the tool away from another player.
Containers such as buckets remain physical objects. F2 also offers shop purchases,
needle delivery and machine on/off controls.
Purchases require the usual proximity to the shop and enough shared money.
Deliver needles at the appropriate cabinet; machines and buildings must be
within reach.

All participants must use exactly the same mod version and demo build. An incompatible mod version is rejected before world loading. The F2 menu shows your installed version, the version required by the lobby and an **Open mod downloads** button. Everyone should install the same package, then restart the demo; this also applies if the host has an older version. Connections
are designed to use Steam relays; router port forwarding is not part of setup.

### Shared gameplay settings

New in **0.2.0**: F2 → **Shared gameplay settings** lets the host change the rules
for everyone in the session. Guests see the current values with **Set by the host**;
their controls are locked. Host changes are synchronized during play, and joining
guests receive the values before their world is constructed.

The shared values are loose/conveyor object limits and automatic removal,
automatic cleanup and its interval, building-grid snapping, and the host's
automatic-saving switch and interval. Only the host saves the shared world.

Guests' original gameplay values are restored on leave, cancellation or host loss.
Graphics, audio, language and controls remain personal. Changes to personal options
made as a guest are saved when leaving or closing the demo normally; forced
termination may lose those latest personal changes. Temporary host values are not
written into the guest's personal settings file.

### Markers, player status and rejoining

New in **0.3.0**: press **F8** during play to mark the surface under your crosshair,
up to 50 meters away. In F2, choose **Point**, **Build here**, **Needle here** or
**Help**. Each player has one marker, which lasts 20 seconds; a new one replaces
it. Markers, names and avatars use matching player colors. Menus, text input
and world loading block marker input.

F2 shows each player's loading/synchronization/play status and measured round-trip
delay. Missing measurements are shown as unavailable; the local host is labeled
**Host**. Measurements include game processing time.

After an unexpected disconnect, **Rejoin last session** starts a fresh join once
the old guest world has closed. The host must still have the same session open.
Voluntary leaving and closing the demo forget that target. Rejoining loads the
current host world and does not guarantee your previous position.

### Gameplay presets and update checking

The host can save, apply and delete up to 20 named presets under F2 → **Shared
gameplay settings**. They store only the nine shared gameplay values locally.
Guests receive applied values automatically; personal settings stay individual.

**Check for updates** contacts the public GitHub Releases service only when
clicked. A newer normal release offers a link to the project's download page;
nothing is downloaded or installed automatically. Checks are limited to once
per minute. Offline/rate-limit errors leave play available. Player names,
Steam IDs, lobby identifiers, local paths, reports and saves are not included.

0.6.3 is published as a normal GitHub release. Internet play between separate
Steam accounts remains unverified.

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
- Native guest building/research/pause menus are integrated; other special
  functions and decorative effects still need testing with friends.
- Mixed Windows/Linux joining has been reported, together with Linux host crashes.
  The Proton crash cause is still unconfirmed; 0.6.3 does not establish a crash fix.
- If guest movement is blocked immediately after joining, switching away with
  Alt+Tab and back has helped in a reported session. An automatic focus fix is unverified.
- The demo disables its leaderboards when mods are loaded.
- Invitations, Steam data transfer over the Internet and four separate accounts
  remain unverified. The steps are in the
  [playtest checklist](docs/playtest-checklist.en.md).

Source code: `mods/ftn_coop/`. Full terms: [LICENSE](LICENSE), with an
[English translation](LICENSE.en.txt). Notices concerning the game and other
rights holders: [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt).

---

## Deutsch

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

### Linux-Installation (Ubuntu / Mint)

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

### Mit Freunden spielen

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

### Gemeinsame Spieleinstellungen

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

### Markierungen, Spielerstatus und Wiederbeitritt

Neu in **0.3.0**: **F8** markiert beim Spielen die angeschaute Oberfläche in
höchstens 50 Metern Entfernung. In F2 wählst du **Markierung**, **Hier bauen**,
**Hier liegt eine Nadel** oder **Hilfe**. Jeder hat eine Markierung für 20 Sekunden;
eine neue ersetzt sie. Markierungen, Namen und Figuren verwenden passende
Spielerfarben. Menüs, Texteingaben und das Laden einer Welt sperren F8-Markierungen.

F2 zeigt Laden/Abgleichen/Spielen und die gemessene Antwortzeit. Fehlende Messungen
werden als nicht verfügbar angezeigt; der lokale Host steht als **Host** in der
Liste. Die Messung enthält auch die Verarbeitungszeit des Spiels.

Nach unerwartetem Verbindungsverlust startet **Letzter Sitzung erneut beitreten**
einen frischen Beitritt, sobald die alte Gastwelt geschlossen ist. Der Host muss
dieselbe Sitzung noch geöffnet haben. Bewusstes Verlassen und das Schließen der
Demo löschen das Ziel. Geladen wird die aktuelle Host-Welt; die alte Position
ist nicht garantiert.

### Einstellungsvorlagen und Updateprüfung

Der Host kann unter F2 → **Gemeinsame Spieleinstellungen** bis zu 20 benannte
Vorlagen speichern, anwenden und löschen. Sie enthalten nur die neun gemeinsamen
Spielwerte und bleiben lokal. Gäste übernehmen angewandte Werte automatisch;
persönliche Einstellungen bleiben getrennt.

**Nach Updates suchen** fragt erst beim Klick den öffentlichen GitHub-Releases-Dienst
ab. Bei einer neueren normalen Version führt ein Knopf zu den Mod-Downloads;
es wird nichts automatisch heruntergeladen oder installiert. Abfragen sind einmal
pro Minute möglich. Ohne Verbindung oder bei einem Anfragelimit bleibt das Spiel
benutzbar. Spielernamen, Steam-IDs, Lobbykennungen, lokale Pfade, Berichte und
Spielstände werden nicht mitgeschickt.

0.6.3 erscheint als normale GitHub-Veröffentlichung. Der Internetbetrieb mit
getrennten Steam-Konten bleibt unbestätigt.

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
