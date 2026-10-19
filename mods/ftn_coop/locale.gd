extends RefCounted

const SETTINGS := "user://ftn_coop/settings.cfg"
const EN := {
	"Gemeinsame Spieleinstellungen":"Shared gameplay settings",
	"Änderungen gelten für die gesamte Sitzung.":"Changes apply to the entire session.",
	"Vom Host vorgegeben. Deine eigenen Werte werden beim Verlassen wiederhergestellt.":"Set by the host. Your own values are restored when you leave.",
	"Vom Host vorgegeben":"Set by the host",
	"Lose Objekte: Maximum":"Loose object limit",
	"Lose Objekte automatisch entfernen":"Automatically remove loose objects",
	"Förderband-Objekte: Maximum":"Conveyor object limit",
	"Förderband-Objekte automatisch entfernen":"Automatically remove conveyor objects",
	"Automatisch aufräumen":"Automatic cleanup",
	"Aufräumintervall (Sekunden)":"Cleanup interval (seconds)",
	"Am Bauraster ausrichten":"Snap to the building grid",
	"Automatisch speichern (Host)":"Automatic saving (host)",
	"Speicherintervall (Sekunden)":"Save interval (seconds)",
	"Die gemeinsamen Spieleinstellungen sind ungültig. Tritt der Sitzung erneut bei.":"The shared gameplay settings are invalid. Join the session again.",
	"Nur der Host kann die gemeinsamen Spieleinstellungen ändern.":"Only the host can change shared gameplay settings.",
	"Installierte Mod-Version: %s":"Installed mod version: %s",
	"Installiert: %s · Lobby benötigt: %s":"Installed: %s · Lobby requires: %s",
	"Alle müssen dieselbe Mod-Version installieren und die Demo neu starten.":"Everyone must install the same mod version and restart the demo.",
	"Mod-Downloads öffnen":"Open mod downloads",
	"Lobby-Mod-Version: %s\n":"Lobby mod version: %s\n",
	"Sitzung erstellen":"Create session",
	"Freunde einladen":"Invite friends",
	"Gemeinsamen Fortschritt speichern":"Save shared progress",
	"Sitzung verlassen":"Leave session",
	"Fehlerbericht kopieren":"Copy error report",
	"Koop · F2":"Co-op · F2",
	"Find The Needle · Koop":"Find The Needle · Co-op",
	"F2 öffnet und schließt dieses Menü.\nEntwicklungsstand · Internettest ausstehend.":"Press F2 to open or close this menu.\nDevelopment build · Internet test pending.",
	"Lade einen Spielstand, um eine Sitzung zu erstellen.":"Load a save to create a session.",
	"Erstelle eine private Sitzung und lade bis zu drei Freunde ein.":"Create a private session and invite up to three friends.",
	"Die Sitzung ist voll. Maximal vier Spieler können gemeinsam spielen.":"The session is full. Up to four players can play together.",
	"Die Spiel-Version stimmt nicht überein. Alle benötigen dieselbe Demo-Version.":"The game versions do not match. Everyone needs the same demo version.",
	"Die Koop-Version stimmt nicht überein. Installiert dasselbe Mod-Paket.":"The co-op versions do not match. Install the same mod package.",
	"Die Spiel- oder Koop-Version stimmt nicht überein.":"The game or co-op versions do not match.",
	"Die Koop-Version stimmt nicht überein.":"The co-op versions do not match.",
	"Die Verbindung zum Host wurde beendet. Du kannst erneut beitreten.":"The connection to the host has ended. You can join again.",
	"Die vorherige Gastwelt wird noch geschlossen. Warte einen Moment.":"The previous guest world is still closing. Please wait a moment.",
	"Die Gastwelt konnte nicht geschlossen werden. Starte die Demo neu.":"The guest world could not be closed. Restart the demo.",
	"Temporäre Gastdateien konnten nicht entfernt werden. Beim nächsten Beitritt wird es erneut versucht.":"Temporary guest files could not be removed. Cleanup will be retried when you next join.",
	"Die Sicherung des letzten Spielstands konnte nicht erstellt werden. Es wurde nicht gespeichert.":"The last save could not be backed up. No save was written.",
	"Der Spielstand konnte nicht wiederhergestellt werden. Seine Sicherung liegt im Speicherordner.":"The save could not be restored. Its backup is in the save folder.",
	"Es besteht keine Verbindung zur Sitzung.":"You are not connected to a session.",
	"Die Verbindung hat zu lange gedauert. Versuche es erneut.":"The connection timed out. Try again.",
	"Steam hat nicht rechtzeitig geantwortet. Prüfe deine Verbindung und versuche es erneut. Bleibt das Problem bestehen, starte die Demo neu.":"Steam did not respond in time. Check your connection and try again. If the problem persists, restart the demo.",
	"Steam bearbeitet noch eine vorherige Anfrage. Warte kurz und versuche es erneut. Bleibt das Problem bestehen, starte die Demo neu.":"Steam is still processing an earlier request. Wait briefly and try again. If the problem persists, restart the demo.",
	"Die Steam-Sitzung konnte nicht erstellt werden. Prüfe deine Verbindung zu Steam und versuche es erneut.":"The Steam session could not be created. Check your connection to Steam and try again.",
	"Der Steam-Sitzung konnte nicht beigetreten werden. Bitte den Host um eine neue Einladung und versuche es erneut.":"The Steam session could not be joined. Ask the host for a new invitation and try again.",
	"Diese Sitzung existiert nicht mehr. Bitte den Host, eine neue Sitzung zu erstellen und dich erneut einzuladen.":"This session no longer exists. Ask the host to create a new session and invite you again.",
	"Steam erlaubt den Beitritt zu dieser Sitzung nicht. Bitte den Host um eine neue Einladung und prüfe deine Steam-Kontoeinstellungen.":"Steam does not allow you to join this session. Ask the host for a new invitation and check your Steam account settings.",
	"Steam hat den Beitritt wegen einer Kontoeinschränkung abgelehnt. Prüfe die Hinweise zu deinem Steam-Konto.":"Steam refused the join because of an account restriction. Check the notices for your Steam account.",
	"Steam hat den Beitritt wegen einer Blockierung zwischen Teilnehmern abgelehnt. Prüft eure Blockierlisten in Steam.":"Steam refused the join because a participant has blocked another participant. Check your blocked-user lists in Steam.",
	"Es gab zu viele Beitrittsversuche in kurzer Zeit. Warte etwas und nimm dann eine neue Einladung an.":"There have been too many join attempts in a short time. Wait a while, then accept a new invitation.",
	"Die Verbindung für deine Sitzung konnte nicht gestartet werden. Starte die Demo über Steam neu und versuche es erneut.":"The connection for your session could not be started. Restart the demo through Steam and try again.",
	"Die Verbindung zum Host konnte nicht gestartet werden. Starte die Demo über Steam neu und nimm eine neue Einladung an.":"The connection to the host could not be started. Restart the demo through Steam and accept a new invitation.",
	"Daten konnten nicht an die Sitzung gesendet werden. Prüfe deine Verbindung und tritt erneut bei.":"Data could not be sent to the session. Check your connection and join again.",
	"Der gemeinsame Fortschritt konnte auch nach mehreren Versuchen nicht abgeglichen werden. Tritt der Sitzung erneut bei.":"Shared progress could not be synchronized after several attempts. Join the session again.",
	"Die Welt konnte nicht rechtzeitig übertragen werden. Versuche es erneut.":"The world could not be transferred in time. Try again.",
	"Steam ist noch nicht bereit. Starte die Demo über Steam.":"Steam is not ready yet. Launch the demo through Steam.",
	"Die benötigte Steam-Anbindung ist in dieser Version nicht verfügbar.":"The required Steam integration is unavailable in this version.",
	"Die Steam-Verbindung konnte nicht vorbereitet werden.":"The Steam connection could not be prepared.",
	"Diese Spiel-Version wurde noch nicht geprüft.":"This game version has not been verified yet.",
	"Lade zuerst einen Spielstand und warte, bis die Welt bereit ist.":"Load a save first and wait until the world is ready.",
	"Das gemeinsame Geld reicht dafür nicht aus.":"There is not enough shared money for that.",
	"Der Kauf ist gerade nicht möglich.":"This purchase is currently unavailable.",
	"Gehe näher an das Ziel heran und schaue es an.":"Move closer to the target and look at it.",
	"Dieses Gebäude ist noch nicht freigeschaltet.":"This building has not been unlocked yet.",
	"Dieses Werkzeug ist noch nicht freigeschaltet.":"This tool has not been unlocked yet.",
	"An dieser Stelle kann das Gebäude nicht platziert werden.":"The building cannot be placed here.",
	"Nur der Host kann den gemeinsamen Spielstand speichern.":"Only the host can save shared progress.",
	"Der Spielstand konnte nicht gespeichert werden.":"The game could not be saved.",
	"Warte, bis die Welt vollständig abgeglichen ist.":"Wait until the world has finished synchronizing.",
	"Diese Aktion ist gerade nicht möglich.":"This action is currently unavailable.",
	"Die Aktion konnte nicht abgeschlossen werden. Versuche es erneut.":"The action could not be completed. Try again.",
	"Warte auf Weltdaten …":"Waiting for world data …",
	"Weltdaten werden empfangen …":"Receiving world data …",
	"Welt wird aufgebaut …":"Building world …",
	"Gemeinsamer Fortschritt wird abgeglichen …":"Synchronizing shared progress …",
	"Weltdaten empfangen: %d %%":"World data received: %d %%",
	"Gemeinsamer Fortschritt gespeichert um %s.":"Shared progress saved at %s.",
	"Fehlerbericht kopiert. Du kannst ihn vor dem Teilen prüfen.":"Error report copied. You can review it before sharing.",
	"Gemeinsam: %.0f $ · %d %s":"Shared: %.0f $ · %d %s",
	"Nadel":"needle", "Nadeln":"needles",
	"Koop · %.0f $ · F2":"Co-op · %.0f $ · F2",
	"Nicht verbunden":"Not connected",
	"Sitzung wird erstellt …":"Creating session …",
	"Verbindung wird hergestellt …":"Connecting …",
	"Welt wird vorbereitet …":"Preparing world …",
	"Welt wird geladen …":"Loading world …",
	"Gemeinsam spielbereit":"Ready to play together",
	"Du bist Host. Der gemeinsame Fortschritt gehört zu deinem Spielstand.":"You are the host. Shared progress belongs to your save.",
	"Du spielst in der Welt des Hosts. Dein Einzelspielerstand bleibt getrennt.":"You are playing in the host's world. Your single-player save stays separate.",
	"Mitspieler":"Player", "Verbinden …":"Connecting …",
	"Gastwelt wird geschlossen …":"Closing guest world …",
	"Warte, bis das Hauptmenü wieder bereit ist.":"Wait until the main menu is ready again.",
	"Gaststeuerung: WASD · Maus · Leertaste\n1–8 Werkzeug · E aufnehmen · G ablegen\nR werfen · Entf abbauen · Linksklick benutzen":"Guest controls: WASD · Mouse · Space\n1–8 tool · E pick up · G put down\nR throw · Delete dismantle · Left click use",
	"Werkzeug":"Tool", "Auswählen":"Select", "Am Laden kaufen":"Buy at the shop", "Kaufen":"Buy",
	"Gebäude":"Buildings", "Bauen":"Build", "Forschung":"Research", "Verbessern":"Upgrade",
	"Nadel im angeschauten Schrank ablegen":"Deposit needle in the cabinet you are looking at",
	"Maschine an":"Machine on", "Maschine aus":"Machine off",
	"Hand":"Hand", "Schaufel":"Shovel", "Heugabel":"Pitchfork", "Besen":"Broom", "Spielzeug":"Toy",
	"Metalldetektor":"Metal detector", "Hofsauger":"Yard vacuum", "Feuerzeug":"Lighter",
	"Schubkarre":"Wheelbarrow", "Spaten":"Spade", "Eimer":"Bucket", "Sandschaufel":"Sand shovel",
	"unbekannt":"unknown", "anderes":"other", "keine":"none", "Gast":"Guest",
	"FTN-Koop Fehlerbericht\nMod-Version: %s\nDemo-Build: %s\nGodot: %d.%d.%d\nSystem: %s\nSitzung: %s\nRolle: %s\nSpieler: %d / 4\nLadephase: %s\nEmpfangene Bytes: %d / %d\nFehler: %s\nInternettest: ausstehend\n":"FTN-Coop error report\nMod version: %s\nDemo build: %s\nGodot: %d.%d.%d\nSystem: %s\nSession: %s\nRole: %s\nPlayers: %d / 4\nLoad phase: %s\nReceived bytes: %d / %d\nError: %s\nInternet test: pending\n",
	"FTN Koop · eigener Entwicklungsstand %s\nStartkomponente geladen.\nTechnische Anbindung wird geprüft.\nKoop ist noch nicht freigeschaltet.":"FTN Co-op · development build %s\nBootstrap loaded.\nChecking game integration.\nCo-op is not enabled yet.",
	"FTN Koop · Startkomponente geladen\nDiagnose läuft …":"FTN Co-op · Bootstrap loaded\nRunning diagnostics …",
}

var language := default_language(OS.get_locale())

func default_language(locale_name: String) -> String:
	return "de" if locale_name.to_lower().split("_")[0].split("-")[0]=="de" else "en"

func set_language(value: String) -> bool:
	if value not in ["de","en"]: return false
	language = value
	return true

func text(key: String) -> String:
	return str(EN.get(key,key)) if language=="en" else key

func load_preferences(path: String=SETTINGS) -> void:
	var config := ConfigFile.new()
	if config.load(path)==OK:
		var saved: Variant = config.get_value("interface","language",language)
		if saved is String: set_language(saved)

func save_preferences(path: String=SETTINGS) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error!=OK: return error
	var config := ConfigFile.new()
	config.load(path)
	config.set_value("interface","language",language)
	return config.save(path)
