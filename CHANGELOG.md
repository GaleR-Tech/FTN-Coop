# Changelog / Änderungen

## 0.7.0 · 2026-10-23

### English

- Backported the proven shared server improvements to the normal Steam host/guest mod, retaining the playable host and four total players.
- Reuse native machine geometry, unchanged research and matching props; send changed building rows instead of entire factory inventories.
- Replace load-time event history with one current catch-up frame and require the final readiness acknowledgement before guest actions.
- Shared native quests observe guest movement, sprinting, actions and opened build/research menus while preserving host controls, menus and focus.
- Keep conveyor fallback visuals outside native props, run guest HUD timers, and omit out-of-range native loose bodies without disconnecting the lobby.
- Install 0.7.0 on every participant and restart. Packages are prepared locally; Steam Internet latency and graphical Linux/Proton still need affected-system testing.

### Deutsch

- Die bewährten gemeinsamen Serververbesserungen wurden in die normale Steam-Mod übertragen. Der Host bleibt spielbar; insgesamt passen vier Spieler in die Sitzung.
- Native Maschinengeometrie, unveränderte Forschung und passende Gegenstände werden weiterverwendet. Geänderte Gebäudezeilen ersetzen die Übertragung kompletter Fabriklisten.
- Ein aktueller Weltabgleich ersetzt den während des Ladens angesammelten Verlauf. Gastaktionen werden erst nach der abschließenden Bereitschaftsbestätigung freigegeben.
- Gemeinsame native Quests berücksichtigen Bewegung, Sprint, Aktionen und geöffnete Bau-/Forschungsmenüs der Gäste. Steuerung, Menüs und Eingabefokus des Hosts bleiben erhalten.
- Band-Ersatzdarstellungen bleiben außerhalb echter Gegenstände, Gastanzeigen laufen weiter und entfernte native Physikobjekte beenden nicht mehr den gesamten Abgleich.
- Alle Teilnehmer müssen 0.7.0 installieren und neu starten. Die Pakete liegen lokal bereit; Steam-Internetlatenz und grafisches Linux/Proton brauchen weiterhin Tests auf den betroffenen Systemen.

## 0.6.3 · 2026-10-22

### English

- Larger live events use compression from 2 KiB upward. The host prepares the compressed event once for all playing guests, preserving connection checks and reliable revision order.
- A bounded column format avoids repeating native record keys, constant values and transform tags. Numeric types, float64 precision and independently mutable records are retained. Expanded-size and depth checks reject malformed or excessive data.
- Native hand-held straw now has an owning peer and follows that guest's local camera. New host poses preserve locally held straw and props; confirmed releases restore their authoritative world positions.
- Guest quest displays clear an obsolete native completion hold before showing the host's current lesson. A stale main panel is retried even when the quest index has not changed.
- Install 0.6.3 on every participant and restart the demo. Controlled transfer and native-game tests do not establish the Internet ping of the affected saved world; Linux/Proton crashes and the reported pile appearance still require affected-system testing.

### Deutsch

- Größere laufende Änderungen werden ab 2 KiB komprimiert. Der Host bereitet die komprimierte Änderung einmal für alle spielenden Gäste auf. Verbindungsprüfung und Reihenfolge zuverlässiger Änderungen bleiben erhalten.
- Ein begrenztes Spaltenformat vermeidet wiederholte native Datensatzschlüssel, konstante Werte und Transformationsmarkierungen. Zahlentypen, Float64-Genauigkeit und unabhängig veränderbare Datensätze bleiben erhalten. Größen- und Tiefenprüfungen weisen fehlerhafte oder übermäßige Daten ab.
- Heu in der normalen Hand erhält eine Spielerzuordnung und folgt der lokalen Gastkamera. Neue Hostpositionen erhalten die lokale Darstellung getragenen Heus und getragener Gegenstände; nach bestätigtem Loslassen gilt wieder die Weltposition des Hosts.
- Die Gast-Questanzeige löst eine veraltete native Abschlussanzeige, bevor sie den aktuellen Host-Schritt zeigt. Ein veraltetes Hauptpanel wird auch bei unverändertem Questindex erneut aktualisiert.
- Alle müssen 0.6.3 installieren und die Demo neu starten. Kontrollierte Übertragungs- und Spieltests belegen noch keinen bestimmten Internet-Ping im betroffenen Spielstand. Linux-/Proton-Abstürze und die gemeldete Haufendarstellung brauchen weiterhin Tests auf den betroffenen Systemen.

## 0.6.2 · 2026-10-22

### English

- Fixed live building capture clearing robot-arm loads before belt delivery. Export copies preserve the native building format while leaving live arm payloads and normal save accounting intact.
- Guest belt updates replace previous loads on conveyors, lifts and hay stairs without spilling duplicate objects. Rendering waits for restored buildings and combines pending updates. Exact host records remain the authoritative state.
- Live updates send changed loose-straw IDs, transforms and tint plus removals instead of retransmitting the entire pool. Stable render slots update only the changed instances. Full join snapshots and bounded validation remain in use.
- Game-state updates omit unchanged fields, including large needle-position arrays. Guests merge validated changes into their existing state before native restoration.
- Guest number keys now use the native compact hotbar mapping, matching the visible symbols when locked tools are hidden.
- Host-confirmed shovel and pitchfork count/capacity and full status appear above the guest hotbar. Carried straw follows the guest's local tool pose; releasing ownership restores the authoritative world pose.
- Everyone must install 0.6.2 and restart. The new update format is incompatible with 0.6.1, so mixed versions are refused. Internet latency, the reported hay appearance and Linux/Proton crashes require testing on the affected systems.

### Deutsch

- Die laufende Gebäudeerfassung leert die Ladung der Roboterarme nicht mehr vor der Bandübergabe. Exportkopien erhalten das native Gebäudeformat; laufende Armladungen und die normale Speicherabrechnung bleiben erhalten.
- Bandaktualisierungen ersetzen beim Gast die bisherige Ladung auf Förderbändern, Aufzügen und Heutreppen, ohne zusätzliche Gegenstände auszuschütten. Die Darstellung wartet auf wiederhergestellte Gebäude und fasst ausstehende Aktualisierungen zusammen. Maßgeblich bleiben die exakten Host-Datensätze.
- Laufende Änderungen übertragen nur geänderte Halm-IDs, Positionen und Farben sowie entfernte IDs statt des gesamten Pools. Bei unveränderten Zeichenplätzen werden nur betroffene Instanzen aktualisiert. Vollständige Beitrittsdaten und begrenzte Datenprüfung bleiben erhalten.
- Spielstandänderungen lassen unveränderte Felder weg, darunter große Nadelpositionslisten. Gäste fügen geprüfte Änderungen vor der nativen Übernahme in ihren bestehenden Stand ein.
- Zahlentasten beim Gast verwenden die originale kompakte Schnellleistenbelegung und passen zu den sichtbaren Symbolen, wenn gesperrte Werkzeuge ausgeblendet sind.
- Vom Host bestätigte Ladung/Kapazität und Voll-Status von Schaufel und Heugabel stehen über der Gast-Schnellleiste. Getragenes Heu folgt der lokalen Werkzeugposition; nach dem Ablegen gilt wieder die Weltposition des Hosts.
- Alle müssen 0.6.2 installieren und neu starten. Das neue Änderungsformat ist mit 0.6.1 inkompatibel; gemischte Versionen werden abgewiesen. Internetlatenz, die gemeldete Heudarstellung und Linux-/Proton-Abstürze benötigen Tests auf den betroffenen Systemen.

## 0.6.1 · 2026-10-20

### English

- Surface markers move to F8. F3 remains the game's debug shortcut; an existing custom game binding on F8 takes priority over markers.
- Replacement guest hay fields now start with the simulation guard already enabled. In a saved modified-pile probe, local restoration changed 620 host height vertices with the late guard and zero with early protection. Native mesh workers and the renderer remain in use.
- Loose straw replicas use the game's runtime mesh and material plus the host's per-straw tint. They occupy their own render-only batch and do not borrow physical pool objects or create collectible copies. Needle shapes remain simplified.
- Identical poses are suppressed separately for each destination and actor, with a half-second keepalive. Changed positions, look and equipment still publish immediately at the existing movement tick.
- Latest movement is sent before bulk world data. Per-destination frame budgets prevent one joining guest from consuming all send attempts. Reliable packet ordering, checked Steam results and blocked-send timeouts are retained.
- These are independent changes informed by comparison with the alternative mod; no source code from it was copied. Install 0.6.1 on every participant and restart the demo. The exact reported orange pile-shell artifact, Linux/Proton crashes and a two-PC Steam Internet session still need validation on the affected systems.

### Deutsch

- Oberflächenmarkierungen liegen jetzt auf F8. F3 bleibt die Debugtaste des Spiels; eine bereits vorhandene eigene Spielbelegung auf F8 hat Vorrang vor Markierungen.
- Neue Gast-Heufelder starten bereits mit aktiver Simulationssperre. Beim Laden eines gespeicherten bearbeiteten Haufens veränderte die bisherige späte Sperre lokal 620 Host-Höhenpunkte; mit früher Sperre waren es null. Native Zeichenaufträge und Renderer bleiben erhalten.
- Lose Halme verwenden die Geometrie und Materialien des laufenden Spiels sowie die jeweilige Halmfarbe des Hosts. Sie liegen in einer eigenen reinen Zeicheninstanz und verwenden weder physische Poolobjekte noch einsammelbare Kopien. Nadelformen bleiben vereinfacht.
- Identische Positionen werden getrennt nach Empfänger und Spieler zurückgehalten und nach einer halben Sekunde erneut gesendet. Geänderte Position, Blickrichtung und Ausrüstung werden weiterhin im bisherigen Bewegungstakt übertragen.
- Aktuelle Bewegung hat Vorrang vor großen Weltdaten. Eigene Sendebudgets je Empfänger verhindern, dass ein neuer Gast alle Sendeversuche belegt. Reihenfolge zuverlässiger Pakete, geprüfte Steam-Ergebnisse und Zeitüberschreitungen bleiben erhalten.
- Die Änderungen wurden nach dem Vergleich mit der alternativen Mod eigenständig entwickelt; deren Quellcode wurde nicht kopiert. Alle müssen 0.6.1 installieren und die Demo neu starten. Die konkret gemeldete orange Haufenschicht, Linux-/Proton-Abstürze und eine Steam-Internetsitzung mit zwei PCs benötigen noch eine Prüfung auf den betroffenen Systemen.

## 0.6.0 · 2026-10-20

### English

- Reliable world packets now use Steam's checked send API. A full send buffer retains the packet for a later attempt in the same order; other guests can continue receiving. This addresses the reproduced missing-revision recovery loop under load.
- Movement uses actual unreliable Steam delivery. Waiting poses are coalesced separately for each player, and older reordered poses are discarded per player.
- Guest hay uses the complete native rendering scheduler. A subclass registered before fields are created blocks guest settling and last-of-pile simulation while retaining native mesh workers. Existing script instances are never replaced during play or reconnect.
- Full baselines dirty only genuinely changed height vertices. Unchanged restored geometry no longer queues a rebuild of the entire pile.
- Tests cover send saturation, large fragmented changes followed by small revisions, multiple player streams, native hay rendering, unchanged authoritative heights and repeated joins. Private probes and original game assets are excluded from every package.
- Everyone must install 0.6.0, restart the demo and use a fresh invitation if the host has recreated the lobby. LOBBY_NOT_FOUND means the old Steam lobby is no longer available. Linux/Proton crash resolution and Internet operation with separate accounts remain unverified.

### Deutsch

- Zuverlässige Weltmeldungen nutzen jetzt die Steam-Sendefunktion mit geprüftem Ergebnis. Bei vollem Sendepuffer bleibt das Paket bis zum nächsten Versuch in derselben Reihenfolge erhalten; andere Gäste können weiter Daten empfangen. Damit wird die nachgestellte Schleife aus fehlenden Änderungen und erneutem Weltladen unter Last behoben.
- Bewegungen verwenden tatsächlich unzuverlässige Steam-Übertragung. Wartende Positionen werden pro Spieler zusammengefasst; verspätete ältere Positionen werden pro Spieler verworfen.
- Gäste nutzen den vollständigen nativen Zeichenablauf für Heu. Eine vor dem Erzeugen der Felder registrierte Unterklasse sperrt Setzphysik und automatische Haufen-Endaktionen beim Gast und erhält die nativen Zeichenaufträge. Laufende Skriptinstanzen werden weder im Spiel noch beim Wiederbeitritt ersetzt.
- Vollständige Ausgangsdaten markieren nur tatsächlich geänderte Höhen. Unveränderte geladene Geometrie löst keinen unnötigen Neuaufbau des gesamten Haufens mehr aus.
- Prüfungen decken volle Sendepuffer, große aufgeteilte Änderungen vor kleinen Folgemeldungen, mehrere Spielerströme, native Heudarstellung, unveränderte Host-Höhen und wiederholte Beitritte ab. Private Diagnoseprogramme und Originalspieldateien bleiben aus allen Paketen ausgeschlossen.
- Alle müssen 0.6.0 installieren und die Demo neu starten. Hat der Host die Lobby neu erstellt, ist eine neue Einladung erforderlich. LOBBY_NOT_FOUND bedeutet, dass die alte Steam-Lobby nicht mehr verfügbar ist. Die Behebung von Linux-/Proton-Abstürzen und der Internetbetrieb mit getrennten Konten bleiben unbestätigt.

## 0.5.2 · 2026-10-20

### English

- Guest hay shell LOD and close straw detail now follow the local camera after joining and moving, while production and physics remain host-controlled.
- Right-click now uses the original secondary action: empty a loaded tool or throw held contents while keeping the equipped tool. F remains the separate whole-tool throw action; Q remains drop.
- The gate countdown displays the host's remaining time using the original digit geometry. It does not overwrite the guest's personal Profile countdown.
- Old regular and fragmented world events are ignored while a replacement baseline is being received or loaded. They can no longer repeatedly restart that recovery; fresh catch-up events apply after loading.
- Copied error reports now include an allowlisted recovery cause in English or German. No player names, account IDs, profile data or saves are added.
- The first trigger of the reported intermittent recovery, the reported unlimited tool duplication and native loading crashes on Windows or Linux/Proton are not confirmed resolved. All players must install 0.5.2 and restart the demo.

### Deutsch

- Heuschichten und nahe Strohdetails folgen nach dem Beitritt und beim Bewegen der Gastkamera; Produktion und Physik bleiben beim Host.
- Rechtsklick nutzt nun die originale Sekundäraktion: geladenes Werkzeug ausschütten beziehungsweise gehaltenen Inhalt werfen und das ausgerüstete Werkzeug behalten. F bleibt das getrennte Werfen des ganzen Werkzeugs; Q bleibt Ablegen.
- Die Toranzeige übernimmt die Restzeit des Hosts mit den Originalziffern. Der persönliche Profil-Countdown des Gasts wird dabei nicht überschrieben.
- Alte normale und aufgeteilte Weltmeldungen werden während Empfang und Laden einer Ersatzwelt verworfen. Sie können diesen Wiederabgleich nicht mehr wiederholt neu starten; neue Änderungen werden nach dem Laden übernommen.
- Kopierte Fehlerberichte enthalten jetzt einen fest definierten Abgleichgrund mit deutscher oder englischer Beschriftung. Spielernamen, Konto-IDs, Profildaten und Spielstände werden nicht ergänzt.
- Der erste Auslöser gelegentlicher Wiederabgleiche, die gemeldete unbegrenzte Werkzeugverdopplung und native Ladeabstürze unter Windows oder Linux/Proton sind noch nicht als behoben bestätigt. Alle Spieler müssen 0.5.2 installieren und die Demo neu starten.

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
