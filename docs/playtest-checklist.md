# FTN-Koop · Internettest noch offen

Version 0.6.3 · Demo-Build 25963876 · Stand 22.10.2026.
Lokale echte Demo-Prozesse sind getrennt vom folgenden Internetnachweis zu bewerten.
Niemand wurde automatisch angeschrieben oder eingeladen.

## Zuerst zwei Personen

- [ ] Beide verwenden denselben Demo-Build und dieselbe Mod-Version. Bei Linux zuerst den lokalen Proton-Test durchführen.
- [ ] Eine ältere Mod-Version wird mit installierter/benötigter Version und Download-Link abgewiesen; nach Installation von 0.6.3 bei beiden und einem Neustart lässt sich der Beitritt erneut versuchen.
- [ ] Beide starten über Steam mit verschiedenen Konten an verschiedenen Rechnern
      und Internetanschlüssen; Steam-Overlay ist verfügbar.
- [ ] Host lädt einen eigenen Teststand, erstellt eine private Sitzung und lädt ein.
- [ ] Gast nimmt an; Name, Status und Welt erscheinen nach dem Laden korrekt.
- [ ] Beide bewegen sich sichtbar; Gast gräbt, nimmt Ressourcen auf und legt sie ab.
- [ ] Gemeinsames Geld/Forschung, Kauf, Bau, Maschinenzufuhr und Nadelabgabe gleichen sich ab.
- [ ] Derselbe Nadelgegenstand wird bei erneutem Versuch nicht doppelt gezählt.
- [ ] Gast verlässt und tritt erneut bei; aktueller Fortschritt ist da.
- [ ] Gast bricht auch einmal während des Ladens ab und erreicht wieder das Menü.
- [ ] Host speichert, beendet und lädt neu; Fortschritt bleibt erhalten.
- [ ] Der vorherige Einzelspielerstand des Gastes bleibt unverändert.
- [ ] Host schließt die Sitzung; Gast erhält eine verständliche Meldung und kommt ins Menü.
- [ ] Eine abgelaufene Einladung und eine volle Lobby zeigen den passenden Grund auf Deutsch und Englisch. Im kopierten Fehlerbericht steht der passende Fehlercode.

## Danach vier Personen

- [ ] F8-Markierungen aller Teilnehmer erscheinen mit gewähltem Typ und passenden Namens-/Figurenfarben; Ersetzen, Ablauf und Entfernen beim Verlassen funktionieren.
- [ ] F2 zeigt tatsächlichen Lade-/Spielstatus und gemessene Antwortzeiten; Menüs und Texteingaben lösen keine Markierungen aus.
- [ ] Host speichert eine Vorlage, ändert Spielwerte und wendet sie wieder an; alle Gäste folgen. Neustart erhält die Vorlage, Löschen entfernt sie.
- [ ] Nach unerwartetem Gast-Verbindungsabbruch wartet der Wiederbeitritt auf das Schließen der alten Gastwelt und lädt genau einmal die aktuelle Host-Welt. Bewusstes Verlassen entfernt das Ziel.
- [ ] Updateprüfung startet nur auf Wunsch, zeigt die veröffentlichte Version und lässt ohne Internet weiter spielen. Sie installiert nichts automatisch.
- [ ] Gäste beginnen mit unterschiedlichen eigenen Spieleinstellungen. Nach dem Beitritt stimmen alle neun gemeinsamen F2-Werte mit dem Host überein; Gast-Bedienelemente sind gesperrt.
- [ ] Host ändert Objektgrenze und Aufräumintervall in F2; alle Gäste erhalten die neuen Werte ohne erneuten Beitritt.
- [ ] Grafik, Ton, Sprache und Steuerung bleiben persönlich. Nach normalem Verlassen oder Host-Verlust werden eigene Spielwerte wiederhergestellt und persönliche Änderungen gespeichert.
- [ ] Beitritt während des Ladens abbrechen und erneut versuchen; gemeinsame Werte werden wieder übernommen, eigene Werte bleiben wiederherstellbar.

- [ ] Drei Gäste treten über Steam bei; alle vier sehen die richtigen Mitspieler.
- [ ] Gleichzeitige Arbeit und Maschinenproduktion bleiben über mehrere Minuten synchron.
- [ ] Zwei Käufe bei Geld für nur einen Kauf ergeben genau einen Erfolg.
- [ ] Ein fünfter Teilnehmer kann nicht beitreten.
- [ ] Verbindungsabbruch eines Gastes entfernt nur dessen Figur; Wiederbeitritt funktioniert.
- [ ] Gemeinsames Speichern/Neuladen und unveränderte Gaststände nochmals prüfen.

## Ergebnis eintragen

Datum, Demo-Build, Mod-Version, Teilnehmerzahl, Internetanschlüsse und genaue Schritte
bei einem Fehler festhalten. Keine Kontozugangsdaten oder vollständigen Spielstände
in einen öffentlichen Bericht kopieren. Bis diese Liste mit echten Konten bestanden
ist, bleibt der Internetbetrieb unbestätigt, auch wenn 0.6.3 die normale GitHub-Release-Kennzeichnung verwendet.

## Linux-Prüfung für 0.6.3

- [ ] Heruntergeladenen Linux-Installer unter Ubuntu/Mint starten; beide Sprachen und einen Ordner mit Leerzeichen prüfen.
- [ ] Installation, Update einer bestehenden Version und Entfernung testen; Spielstände, andere Mods und Original-Spiel-Dateien prüfen.
- [ ] V66 über Steam Proton starten; F2, Steam-Overlay, Einladungen und Laden der Welt prüfen.
- [ ] Windows-Host/Linux-Gast und danach Linux-Host/Windows-Gast mit identischer Version 0.6.3 testen.
- [ ] Distribution, Python-Version, Proton-Version und Ergebnis festhalten. Diese Linux-Prüfungen sind noch offen.

## Gaststeuerung und Weltabgleich in 0.6.3

- [ ] Mit Umschalt bis zur leeren Ausdauer sprinten, loslassen und erholen; auch eine eigene Tastenbelegung testen.
- [ ] Originalmenüs mit B / Tab / T / Escape öffnen: Bewegung ruht, Käufe belasten den Host genau einmal, Verlassen räumt die Sitzung auf.
- [ ] Als Host oder Gast ein Standardwerkzeug kaufen. Beide wählen es sofort; Kopien ablegen, aufnehmen und werfen, ohne die Hand des anderen zu verändern.
- [ ] Getrennte Eimer tragen, drehen und laufen, dann ablegen/werfen; Zuordnung und Handposition bleiben richtig.
- [ ] Host-Aufgabe abschließen: Gasttitel und Fortschritt folgen. Auf wiederholten Oberflächenaufbau und verzögerte Aktionen achten.
- [ ] Hosting mit ausgerüstetem Gastwerkzeug beenden; Host speichern und neu laden, Freischaltung bleibt vorhanden.
- [ ] Bei Linux-Host-Absturz Proton-/Distributionsversion festhalten und lokal ein Proton-Protokoll erzeugen. Vor Weitergabe auf private Daten prüfen.

## Rückfallprüfungen für 0.6.3

- [ ] Host und Gast tragen gleichzeitig Heu mit getrennten Schaufeln/Mistgabeln; auf beiden Seiten ablegen und werfen, ohne die Last des anderen zu verändern.
- [ ] Leeres Werkzeug ablegen: Die Kopie liegt am Boden, die Hand bleibt bis zur bewussten neuen Auswahl leer, auch bei Internetverzögerung.
- [ ] Förderband im originalen Gast-Baukatalog wählen, ersten Punkt setzen, Längenvorschau sehen und das fertige Band sichtbar erstellen.
- [ ] Bei erneutem normalen Ladebildschirm Host/Gast und lokale FTN-Coop-Protokollmeldungen zum Neuabgleich/Laden festhalten; dieser Fehler ist noch unbestätigt.

- [ ] Direkt nach dem Beitritt und beim Gehen um den Haufen folgen nahe Strohdetails der Gastkamera ohne eingefrorenen Bereich.
- [ ] Geladene Schaufel/Mistgabel per Rechtsklick leeren: Nur der Inhalt geht ab, das Werkzeug bleibt ausgerüstet. F und Q getrennt testen, auch mehrere schnelle Betätigungen ohne erneute Werkzeugauswahl.
- [ ] Tor-Restzeit bei Host und Gast nach dem Beitritt und nach Host-Pause/Fortsetzen vergleichen. Die eigene Profilzeit des Gasts darf nicht überschrieben werden.
- [ ] Beim Wiederabgleich dürfen alte unterwegs befindliche Weltmeldungen das normale Laden nicht neu starten. Fehlerbericht kopieren und den Abgleichgrund vor dem Teilen prüfen.

## 0.6.3: Sendepuffer und native Heudarstellung

- [ ] Der Host bewegt sich während des Gastbeitritts; der Gast erreicht das Spiel ohne erneuten normalen Ladebildschirm.
- [ ] Mit langsamer Verbindung oder ungefähr 500 ms Verzögerung wiederholen; Käufe und Heuänderungen bleiben in Reihenfolge.
- [ ] Haufen direkt nach Beitritt, nach Heuabbau und nach Wiederbeitritt vergleichen; über entferntem Heu bleibt keine dauerhafte schwebende Strohschicht.
- [ ] In einer Vier-Spieler-Lobby bewegen sich alle; ein langsamer Gast blockiert weder andere Gäste noch die Bewegungen einzelner Spieler.
- [ ] Host-Lobby neu erstellen und mit neuer Einladung beitreten. Eine alte geschlossene Lobby darf LOBBY_NOT_FOUND melden.
- [ ] Mit Linux-/Proton-Host und getrennten Steam-Konten über das Internet wiederholen; diese Umgebungen sind durch die lokalen Windows-Prüfungen nicht bestätigt.

## 0.6.3: Leistung, Schnellleiste und Werkzeugladung

- [ ] Bei gesperrten ausgeblendeten Werkzeugen wählen Zahlentasten das angezeigte Symbol, auch Förderband und Arm.
- [ ] Schaufel und Heugabel zeigen bestätigte Menge/Kapazität und Voll-Hinweis; Leeren setzt die Anzeige zurück. Getragenes Heu folgt dem eigenen Werkzeug, abgelegtes Heu der Weltposition des Hosts.
- [ ] Aktionsverzögerung und Ping mit laufender Fabrik und vielen losen Halmen vergleichen. Kleinere Pakete belegen noch keine niedrige Internetlatenz.
- [ ] Ohne Gast Heuaufnahme und Bandausgabe der Arme vor/nach Sitzungsstart vergleichen, mit offenem/geschlossenem F2. Stromversorgung und originalen Arm-Fehlerhinweis festhalten; prüfen, dass beladene Arme ihr Heu während der Sitzung bis zur Übergabe behalten.
- [ ] Alle Gäste sehen die Ladung auf Förderbändern, Aufzügen und Heutreppen weiterwandern und nach dem Entfernen verschwinden. Dabei entstehen keine zusätzlichen Gegenstände neben der Maschine. Nach Umbau und Wiederbeitritt erneut prüfen.

## 0.6.3: bestehende Welten, Heu in der Hand und Quests

- [ ] Im betroffenen Spielstand Gast-Ping und Aktionsverzögerung mindestens eine Minute nach Beitritt vergleichen, mit denselben Spielern und laufender Fabrik. Gegenprobe in neuer Welt. Ein künstlicher Übertragungstest ist kein Internet-Ping-Ergebnis.
- [ ] Heu in der normalen Hand tragen, laufen und drehen, danach werfen und ablegen. Hand, Schaufel, Gabel und getragene Gegenstände bei eingehenden Hostdaten auf Sprünge prüfen. Nach Loslassen müssen Besitzer und Weltposition eindeutig sein.
- [ ] Heuwerfen-Quest abschließen, beitreten und erneut verbinden, danach Welt wechseln. Beide Gast-Questanzeigen müssen den aktuellen Host-Schritt zeigen, ohne lokal gemeinsame Belohnungen zu ändern.
