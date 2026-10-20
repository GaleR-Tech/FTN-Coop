# Changelog / Änderungen

## 0.5.2 · 2026-10-20

### English

- Guest hay shell LOD and close straw detail now follow the local camera after joining and moving, while production and physics remain host-controlled.
- Right-click now uses the original secondary action: empty a loaded tool or throw held contents while keeping the equipped tool. F remains the separate whole-tool throw action; Q remains drop.
- The gate countdown displays the host's remaining time using the original digit geometry. It does not overwrite the guest's personal Profile countdown.
- Old regular and fragmented world events are ignored while a replacement baseline is being received or loaded. They can no longer repeatedly restart that recovery; fresh catch-up events apply after loading.
- Copied error reports now include an allowlisted recovery cause in English or German. No player names, account IDs, profile data or saves are added.
- The first trigger of the reported intermittent recovery, the reported unlimited tool duplication and Linux/Proton host crashes are not confirmed resolved. All players must install 0.5.2 and restart the demo.

### Deutsch

- Heuschichten und nahe Strohdetails folgen nach dem Beitritt und beim Bewegen der Gastkamera; Produktion und Physik bleiben beim Host.
- Rechtsklick nutzt nun die originale Sekundäraktion: geladenes Werkzeug ausschütten beziehungsweise gehaltenen Inhalt werfen und das ausgerüstete Werkzeug behalten. F bleibt das getrennte Werfen des ganzen Werkzeugs; Q bleibt Ablegen.
- Die Toranzeige übernimmt die Restzeit des Hosts mit den Originalziffern. Der persönliche Profil-Countdown des Gasts wird dabei nicht überschrieben.
- Alte normale und aufgeteilte Weltmeldungen werden während Empfang und Laden einer Ersatzwelt verworfen. Sie können diesen Wiederabgleich nicht mehr wiederholt neu starten; neue Änderungen werden nach dem Laden übernommen.
- Kopierte Fehlerberichte enthalten jetzt einen fest definierten Abgleichgrund mit deutscher oder englischer Beschriftung. Spielernamen, Konto-IDs, Profildaten und Spielstände werden nicht ergänzt.
- Der erste Auslöser gelegentlicher Wiederabgleiche, die gemeldete unbegrenzte Werkzeugverdopplung und Linux-/Proton-Host-Abstürze sind noch nicht als behoben bestätigt. Alle Spieler müssen 0.5.2 installieren und die Demo neu starten.

## 0.5.1 · 2026-10-20

### English

- Fixed remote tools sharing the host's shovel/pitchfork collision bodies, hay basins and effects. Native tool setup now creates independent per-player parts; removing a player cleans up those generated parts.
- Fixed guest conveyor construction previews: the host returns the confirmed build stage and starting point, so the guest sees the multi-step run without creating buildings or spending money locally.
- Prevented delayed movement packets from re-equipping a tool after a confirmed drop. New deliberate selections remain available after confirmation; leaving clears the equipment ordering state.
- Added local log messages showing when a guest world is loaded or replaced and the reason for automatic world recovery. No player names, account IDs or saves are included in these messages.
- The reported intermittent native loading screen is not confirmed fixed. Linux/Proton host crashes remain unconfirmed. All players must install 0.5.1 and restart the demo.

### Deutsch

- Gemeinsame Schaufel-/Mistgabel-Kollisionskörper, Heu-Auffangbereiche und Effekte zwischen Host und Gast korrigiert. Die normale Werkzeuginitialisierung erzeugt nun eigene Teile pro Spieler; beim Verlassen werden diese aufgeräumt.
- Förderband-Bauvorschau für Gäste korrigiert: Der Host meldet den bestätigten Bauschritt und Startpunkt zurück. Gäste sehen den mehrstufigen Verlauf, ohne lokal Gebäude zu erzeugen oder Geld auszugeben.
- Verspätete Bewegungsnachrichten können abgelegte Werkzeuge nicht mehr automatisch ausrüsten. Bewusste neue Auswahlen nach Bestätigung bleiben möglich; beim Verlassen wird die Reihenfolgeverwaltung zurückgesetzt.
- Lokale Protokollmeldungen zeigen das Laden/Ersetzen einer Gastwelt und den Grund eines automatischen Welt-Neuabgleichs. Diese Meldungen enthalten keine Spielernamen, Konto-IDs oder Spielstände.
- Der gemeldete gelegentliche normale Ladebildschirm ist noch nicht als behoben bestätigt. Linux-/Proton-Host-Abstürze bleiben ungeklärt. Alle Spieler müssen 0.5.1 installieren und die Demo neu starten.

## 0.5.0 · 2026-10-20

### English

- Guest controls and shared tools update: native B building catalog, Tab / T research and Escape pause menu; host-confirmed purchases and building actions.
- Guest Shift sprint uses native stamina. Native drop, pick up, right-click throw, action bindings and hotbar selection are supported.
- Purchased standard tools unlock for everyone independently; dropping, picking up and ending the session preserve shared unlocks. Physical containers keep separate ownership and improved carried-object visuals.
- Quest title/progress follow the host. Status updates avoid rebuilding unrelated collection UI; position-only prop updates reuse existing objects.
- Windows Setup, ZIP and Linux installer use version 0.5.0. All participants must update and restart the demo. English documentation and release notes precede German.
- Functional verification covers 30 mod test groups, targeted two-instance controls and four-instance shared-world/save checks on Windows. Linux/Proton host crashes and the initial guest-focus issue remain unconfirmed; no Linux crash fix is claimed.

### Deutsch

- Update für Gaststeuerung und gemeinsame Werkzeuge: originaler Baukatalog mit B, Forschung mit Tab / T und Pausemenü mit Escape; Käufe und Bauaktionen bestätigt der Host.
- Gastsprint mit Umschalt verwendet die normale Ausdauer. Ablegen, Aufnehmen, Rechtsklick-Werfen, Aktionsbelegung und Schnellleiste werden unterstützt.
- Gekaufte Standardwerkzeuge sind für alle unabhängig freigeschaltet; Ablegen, Aufnehmen und Sitzungsende erhalten diese Freischaltungen. Physische Behälter behalten getrennte Besitzer und eine verbesserte Tragedarstellung.
- Aufgabentitel und Fortschritt folgen dem Host. Statusupdates bauen die Sammlung nicht unnötig neu auf; reine Positionsupdates verwenden vorhandene Objekte weiter.
- Windows-Setup, ZIP und Linux-Installer verwenden 0.5.0. Alle Teilnehmer müssen aktualisieren und die Demo neu starten. Englische Anleitungen und Release-Hinweise stehen vor Deutsch.
- Die Funktionsprüfung umfasst 30 Mod-Testgruppen, gezielte Steuerungstests mit zwei sowie Welt-/Speichertests mit vier Spielinstanzen unter Windows. Linux-/Proton-Host-Abstürze und das anfängliche Gast-Fokusproblem bleiben ungeklärt; eine Linux-Absturzbehebung wird nicht bestätigt.

## 0.4.1 · 2026-10-20

### English

- Added native guest building (B), research (Tab / T) and pause (Escape) menus. Menu input suspends that guest's movement; purchases and building actions remain host-authoritative. Guest save/load actions are disabled.
- Fixed guest sprinting with native speeds and stamina, right-click throwing, native drop/throw keys, personal action remapping and hotbar selection.
- Purchased standard tools now unlock for everyone independently. Drop/pickup and session teardown preserve shared unlocks; purchase results equip the buyer without changing the host's hands.
- Stopped copying held physical objects into new guest actors. Guest carried-object visuals follow the local camera; position-only prop updates reuse existing objects.
- Synchronize quest title and host progress. Money-only updates no longer rebuild unrelated collection UI. A local status-update probe fell from about 52 ms to 0.9 ms; this is not a full Internet performance measurement.
- Hardened malformed update rejection and repeated equipment results. Windows Setup, ZIP and Linux installer all require 0.4.1; everyone must update and restart.
- Linux/Proton host crashes and the reported initial guest-focus issue remain unconfirmed. The reported Alt+Tab workaround may restore movement. No Linux crash fix is claimed.

### Deutsch

- Originalen Baukatalog (B), Forschungsbaum (Tab / T) und Pausemenü (Escape) für Gäste eingebunden. Im Menü ruht die eigene Bewegung; Käufe und Bauaktionen bestätigt der Host. Gastaktionen zum Speichern/Laden sind gesperrt.
- Gastsprint mit normalen Geschwindigkeiten und Ausdauer, Rechtsklick-Werfen, normale Ablegen-/Werfen-Tasten, persönliche Aktionsbelegung und Schnellleiste korrigiert.
- Gekaufte Standardwerkzeuge sind für alle unabhängig freigeschaltet. Ablegen/Aufnehmen und das Sitzungsende erhalten diese Freischaltungen; die Kaufbestätigung rüstet den Käufer aus und lässt die Host-Hand unabhängig.
- Getragene physische Objekte werden nicht mehr in neue Gastfiguren kopiert. Die Gastdarstellung getragener Objekte folgt der eigenen Kamera; reine Positionsupdates verwenden vorhandene Objekte weiter.
- Aufgabentitel und Host-Fortschritt werden abgeglichen. Reine Geldänderungen bauen die Sammlungsoberfläche nicht mehr neu auf. Eine lokale Statusaktualisierung sank im Messlauf von etwa 52 ms auf 0,9 ms; das ist keine vollständige Internet-Performancemessung.
- Ungültige Updates und wiederholte Ausrüstungsbestätigungen abgesichert. Windows-Setup, ZIP und Linux-Installer verwenden 0.4.1; alle müssen aktualisieren und neu starten.
- Linux-/Proton-Host-Abstürze und das gemeldete anfängliche Gast-Fokusproblem bleiben ungeklärt. Alt+Tab und Zurückwechseln half in der gemeldeten Sitzung beim Bewegen. Eine Linux-Absturzbehebung wird nicht bestätigt.

## 0.4.0 · 2026-10-20

### English

- Added a single-file Linux installer for Ubuntu/Mint with Steam Proton, automatic Steam/additional-library/Flatpak folder discovery and manual folder selection.
- Added optional English/German graphical controls plus a terminal interface for installation, updates and removal. Python 3.8+ is required; python3-tk enables the window. All mod files are included; no pip packages or installer downloads are needed.
- Preserved installation records, original configuration bytes, later unrelated config edits, other mods and local mod edits. Linked target paths and malformed records are rejected; ordinary failed writes are rolled back.
- Added GitHub and Buy me a Coffee links to the Linux interface. The Windows installer and runtime use the same 0.4.0 version; every participant must update and restart.
- Verified the Python filesystem, package and GUI tests on Windows. Actual Linux execution, Proton gameplay and Windows/Linux multiplayer remain unverified. Internet play between different Steam accounts remains unverified.

### Deutsch

- Einzelnen Linux-Installer für Ubuntu/Mint mit Steam Proton, automatischer Suche in Steam-/Zusatz-/Flatpak-Bibliotheken und manueller Ordnerauswahl ergänzt.
- Optionale grafische Bedienung auf Englisch/Deutsch und Terminal-Oberfläche für Installation, Update und Entfernung ergänzt. Python 3.8+ wird benötigt; python3-tk ermöglicht das Fenster. Alle Mod-Dateien sind enthalten; keine pip-Pakete oder Downloads während der Installation nötig.
- Installationsdateien, ursprüngliche Konfigurationsbytes, spätere fremde Konfigurationseinträge, andere Mods und lokale Mod-Änderungen werden erhalten. Verknüpfte Zielpfade und ungültige Installationsdateien werden abgewiesen; gewöhnliche Schreibfehler werden zurückgerollt.
- GitHub- und Buy-me-a-Coffee-Links in der Linux-Oberfläche ergänzt. Windows-Installer und Mod verwenden dieselbe Version 0.4.0; alle Teilnehmer müssen aktualisieren und neu starten.
- Python-Datei-, Paket- und Oberflächentests unter Windows geprüft. Echte Linux-Ausführung, Proton-Spielbetrieb und gemeinsame Windows/Linux-Sitzungen sind noch unbestätigt. Internetspiel mit getrennten Steam-Konten bleibt unbestätigt.

## 0.3.0 · 2026-10-20

### English

- Added F3 world markers with Point, Build here, Needle here and Help types, matching player/avatar colors, a 50-meter reach, per-player replacement and automatic expiry after 20 seconds.
- Added player loading/synchronization/play status and authenticated round-trip measurements in the F2 list. Invalid and excessive announcements are bounded; markers and measurements stay outside saved world state.
- Added up to 20 local named presets for the nine shared gameplay settings. The host can save, apply and delete presets; complete validation and safe replacement protect existing values and files.
- Added optional, manually requested GitHub update checks. A newer normal release offers the fixed project download page; no automatic downloads or installation, and no player/session/save data in the request.
- Added Rejoin last session after unexpected guest disconnection. Rejoining waits for native guest cleanup, uses a fresh authenticated connection and repeats the normal compatibility checks. Voluntary leaving forgets the target.
- Kept all new controls, feedback and documentation available in German and English. The existing installer retains its project and Buy me a Coffee links.
- Version 0.3.0 is a normal GitHub release without the Pre-release label. No guest permissions system was added. Everyone must install 0.3.0 and restart the demo.

Only Find The Needle Demo V66 / build 25963876 on Windows is supported. Internet play between different Steam accounts remains unverified.

### Deutsch

- F3-Weltmarkierungen für Markierung, Hier bauen, Hier liegt eine Nadel und Hilfe ergänzt: passende Spieler-/Figurenfarben, 50 Meter Reichweite, eine Markierung pro Spieler und automatisches Verschwinden nach 20 Sekunden.
- Spielerstatus für Laden/Abgleichen/Spielen und authentifizierte Antwortzeit-Messungen in F2 ergänzt. Ungültige und übermäßige Meldungen werden begrenzt; Markierungen und Messungen gehören nicht zum gespeicherten Weltzustand.
- Bis zu 20 lokale benannte Vorlagen für die neun gemeinsamen Spielwerte ergänzt. Der Host kann speichern, anwenden und löschen; vollständige Prüfung und sicheres Ersetzen schützen bisherige Werte und Dateien.
- Freiwillige, manuell gestartete GitHub-Updateprüfung ergänzt. Bei einer neueren normalen Veröffentlichung führt ein Knopf zu den festen Projekt-Downloads; kein automatischer Download oder Einbau und keine Spieler-/Sitzungs-/Speicherdaten in der Anfrage.
- Wiederbeitritt zur letzten Sitzung nach unerwartetem Gast-Verbindungsabbruch ergänzt. Zuerst wird die native Gastwelt geschlossen, dann folgen ein frischer authentifizierter Beitritt und die üblichen Versionsprüfungen. Bewusstes Verlassen löscht das Ziel.
- Alle neuen Bedienelemente, Hinweise und Anleitungen bleiben auf Deutsch und Englisch verfügbar. Der Installer behält Projekt- und Buy-me-a-Coffee-Link.
- 0.3.0 erscheint als normale GitHub-Veröffentlichung ohne Pre-release-Kennzeichnung. Ein Rechtesystem wurde nicht ergänzt. Alle müssen 0.3.0 installieren und die Demo neu starten.

Unterstützt wird ausschließlich Find The Needle Demo V66 / Build 25963876 unter Windows. Internetspiel zwischen getrennten Steam-Konten bleibt unbestätigt.

## 0.2.0 · 2026-10-20

### English

- Added a Buy me a Coffee link to the Windows installer.
- Added shared gameplay settings in F2. The host controls nine values: loose/conveyor object limits and removal, cleanup and its interval, building-grid snapping, and host autosaving and its interval.
- Joining guests receive the host values before native world construction. Later changes use the existing authenticated world synchronization.
- Guests see read-only controls and a host-ownership notice. Local gameplay changes are reset to the shared values; personal graphics, audio, language and controls stay individual.
- Original guest gameplay values are restored after leave, cancellation, host loss or normal shutdown. Native settings writes are deferred during the session, then personal changes are saved after restoration. Forced termination can lose those latest personal changes.
- Added strict value validation, atomic patch rejection and automated settings, persistence, UI and network coverage. German and English remain selectable. Everyone must update to 0.2.0 and restart the demo.

Only Find The Needle Demo V66 / build 25963876 on Windows is supported. Internet play between different Steam accounts remains unverified.

### Deutsch

- Buy-me-a-Coffee-Link im Windows-Installer ergänzt.
- Gemeinsame Spieleinstellungen in F2 ergänzt. Der Host steuert neun Werte: Objektgrenzen und Entfernen für lose Objekte/Förderband-Inhalte, Aufräumen samt Intervall, Bauraster sowie Host-Autospeichern samt Intervall.
- Beitretende Gäste übernehmen die Host-Werte vor dem nativen Weltaufbau. Spätere Änderungen nutzen den vorhandenen authentifizierten Weltabgleich.
- Gäste sehen gesperrte Bedienelemente und den Hinweis auf die Host-Vorgabe. Lokale Änderungen an Spielwerten werden zurückgesetzt; Grafik, Ton, Sprache und Steuerung bleiben persönlich.
- Eigene Spielwerte des Gastes werden nach Verlassen, Abbrechen, Host-Verlust und normalem Beenden wiederhergestellt. Einstellungen werden während der Sitzung erst später gespeichert; nach der Wiederherstellung bleiben persönliche Änderungen erhalten. Erzwungenes Beenden kann diese letzten persönlichen Änderungen verlieren.
- Strenge Werteprüfung, vollständiges Abweisen fehlerhafter Aktualisierungen und automatische Einstellungen-, Speicher-, Oberflächen- und Netzwerkprüfungen ergänzt. Deutsch und Englisch bleiben auswählbar. Alle müssen auf 0.2.0 aktualisieren und die Demo neu starten.

Unterstützt wird ausschließlich Find The Needle Demo V66 / Build 25963876 unter Windows. Internetspiel zwischen getrennten Steam-Konten bleibt unbestätigt.

## 0.1.4 · 2026-10-19

### English

- Fixed a disconnect crash: a native network peer is now closed after its active poll has returned. Covered by real four-participant socket leave/rejoin and host-departure checks.
- Guests time out when the host never sends a welcome, initial world data or final synchronization confirmation. Valid received data and confirmed catch-up events renew the new wait budget; native world construction is excluded from it. Existing world-transfer limits remain unchanged.
- Steam lobby failures now distinguish closed, full, restricted and blocked sessions, account limitations and too many join attempts.
- Added German/English messages for connection, Steam, send and synchronization failures. Copied reports retain the specific known error code.
- Expanded automated recovery, retry, synchronization and disconnect coverage. Everyone must install 0.1.4 together; exact mod-version checks remain in place.

Only Find The Needle Demo V66 / build 25963876 on Windows is supported. Internet play between different Steam accounts remains unverified.

### Deutsch

- Absturz beim Verbindungsabbau behoben: Eine native Netzwerkverbindung wird erst geschlossen, nachdem ihre laufende Verarbeitung zurückgekehrt ist. Durch lokale Socket-Prüfungen mit vier Teilnehmern für Verlassen, Wiederbeitritt und Host-Ende abgedeckt.
- Gäste erhalten eine Zeitüberschreitung, wenn der Host keine Begrüßung, ersten Weltdaten oder abschließende Abgleichbestätigung sendet. Gültige empfangene Daten und bestätigte Abgleichereignisse erneuern die neue Wartefrist; der native Weltaufbau wird darin nicht mitgezählt. Bestehende Übertragungsgrenzen bleiben unverändert.
- Steam-Lobbyfehler unterscheiden jetzt geschlossene, volle, eingeschränkte und blockierte Sitzungen, Kontoeinschränkungen und zu viele Beitrittsversuche.
- Deutsche/englische Meldungen für Verbindungs-, Steam-, Sende- und Abgleichfehler ergänzt. Kopierte Berichte behalten den konkreten bekannten Fehlercode.
- Automatische Prüfungen für Wiederherstellung, erneute Versuche, Synchronisierung und Verbindungsabbrüche erweitert. Alle müssen gemeinsam 0.1.4 installieren; die exakte Mod-Versionsprüfung bleibt bestehen.

Unterstützt wird ausschließlich Find The Needle Demo V66 / Build 25963876 unter Windows. Internetspiel zwischen getrennten Steam-Konten bleibt unbestätigt.

## 0.1.3 · 2026-10-19

### English

- Redesigned Windows installer with a dark interface, gold accents and GaleR-Tech branding.
- Installed and package versions appear together. The main action adapts to the selected installation; removing the mod is a smaller, separate action.
- Clear operation stages and indeterminate progress during installation/removal, followed by the actual result.
- Removed the Internet-test notice from the installer, as requested. The documented test status is unchanged.
- New installations record their mod version; the installer also recognizes older installations without this metadata.
- A GitHub project link opens the source repository directly from the installer.

Only Find The Needle Demo V66 / build 25963876 on Windows is supported. Internet play between different Steam accounts remains unverified.

### Deutsch

- Windows-Installer mit dunkler Oberfläche, goldenen Akzenten und GaleR-Tech-Branding überarbeitet.
- Installierte und enthaltene Version werden gemeinsam angezeigt. Die Hauptaktion richtet sich nach der ausgewählten Installation; das Entfernen ist eine kleinere, getrennte Aktion.
- Klare Arbeitsschritte und unbestimmte Fortschrittsanzeige während Installation/Entfernen, danach das tatsächliche Ergebnis.
- Internettest-Hinweis wie gewünscht aus dem Installer entfernt. Der dokumentierte Teststatus bleibt unverändert.
- Neue Installationen hinterlegen ihre Mod-Version; der Installer erkennt auch ältere Installationen ohne diese Angabe.
- Ein GitHub-Projektlink öffnet das Quellcode-Repository direkt aus dem Installer.

Unterstützt wird ausschließlich Find The Needle Demo V66 / Build 25963876 unter Windows. Internetspiel zwischen getrennten Steam-Konten bleibt unbestätigt.

## 0.1.2 · 2026-10-19

### English

- German and English can be selected in the F2 co-op menu and Windows installer.
  Unless chosen manually, the default is German for a German operating system
  language, English otherwise.
- Full English instructions and Internet playtest checklist, plus a convenience
  translation of the terms of use. The German LICENSE takes precedence in case
  of discrepancies; existing permissions are unchanged.
- Exact mod-version checks at Steam lobby entry and the connection handshake.
  Mismatches show the installed and required versions, plus a mod-download button.
  Incompatible guests cannot load the world; the host session stays running.
- Updates preserve untracked local files when a new mod file uses the same name.
- Move the F2 badge to the bottom right to keep the game's money display clear.

Test release. Only Find The Needle Demo V66 / build 25963876 remains supported.
Internet play with different Steam accounts remains unverified.

### Deutsch

- Deutsch und Englisch im F2-Koop-Menü und Windows-Installer auswählbar.
  Ohne manuelle Auswahl gilt Deutsch bei deutscher Betriebssystemsprache,
  sonst Englisch.
- Vollständige englische Anleitung und Internettest-Checkliste sowie eine
  englische Übersetzung der Nutzungsbedingungen. Bei Abweichungen gilt die
  deutsche LICENSE; die bestehenden Nutzungsrechte bleiben unverändert.
- Exakte Mod-Versionsprüfung beim Steam-Lobbybeitritt und Verbindungsaufbau.
  Bei Abweichungen erscheinen installierte und benötigte Version sowie ein
  Download-Button. Inkompatible Gäste laden keine Welt; die Host-Sitzung bleibt aktiv.
- Updates schützen unverwaltete lokale Dateien bei Namenskonflikten mit neuen Mod-Dateien.
- F2-Hinweis nach unten rechts verschoben, damit die Geldanzeige des Spiels frei bleibt.

Testversion. Unterstützt weiterhin ausschließlich Find The Needle Demo V66 /
Build 25963876. Der Internettest mit verschiedenen Steam-Konten steht weiterhin aus.

## 0.1.1 · 2026-10-19

### English

- Actual progress during world-data reception; repeated data packets do not
  increase the percentage more than once.
- Separate messages for data reception, world construction and final synchronization.
- Save confirmation with the time after a successful save. A save failure does
  not display a success message.
- “Copy error report” in the F2 menu: fixed technical information without player
  names, Steam IDs, paths, session identifiers or save files. The report is only
  copied to the clipboard, not uploaded.
- Buy Me a Coffee button in the GitHub instructions and GitHub funding link.
- Consistent version 0.1.1 for the mod and Windows installer.

Test release. Only Find The Needle Demo V66 / build 25963876 is supported.
Internet play with different Steam accounts remains unverified.

### Deutsch

- Tatsächlicher Fortschritt beim Empfang der Weltdaten; wiederholte Datenpakete
  erhöhen die Prozentzahl nicht mehrfach.
- Getrennte Meldungen für Datenempfang, Weltaufbau und abschließenden Abgleich.
- Speicherbestätigung mit Uhrzeit nach erfolgreichem Speichern. Bei einem
  Speicherfehler erscheint keine Erfolgsmeldung.
- „Fehlerbericht kopieren“ im F2-Menü: feste technische Angaben ohne
  Spielernamen, Steam-IDs, Pfade, Sitzungskennungen oder Spielstände.
  Der Bericht wird nur in die Zwischenablage kopiert, nicht hochgeladen.
- Buy-Me-a-Coffee-Button in der GitHub-Anleitung und GitHub-Funding-Link.
- Einheitliche Versionsnummer 0.1.1 für Mod und Windows-Installer.

Testversion. Unterstützt ausschließlich Find The Needle Demo V66 /
Build 25963876. Der Internettest mit verschiedenen Steam-Konten steht weiterhin aus.

## 0.1.0-dev · 2026-10-19

### English

First public test version with original co-op code, a private Steam session for
up to four players, shared progress and a Windows installer.

### Deutsch

Erste öffentliche Testversion mit eigenem Koop-Code, privater Steam-Sitzung
für bis zu vier Spieler, gemeinsamem Fortschritt und Windows-Installer.
