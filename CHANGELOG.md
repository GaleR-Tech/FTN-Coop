# Changelog / Änderungen

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
