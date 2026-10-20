# FTN-Koop · Internettest noch offen

Version 0.4.0 · Demo-Build 25963876 · Stand 20.10.2026.
Lokale echte Demo-Prozesse sind getrennt vom folgenden Internetnachweis zu bewerten.
Niemand wurde automatisch angeschrieben oder eingeladen.

## Zuerst zwei Personen

- [ ] Beide verwenden denselben Demo-Build und dieselbe Mod-Version. Bei Linux zuerst den lokalen Proton-Test durchführen.
- [ ] Eine ältere Mod-Version wird mit installierter/benötigter Version und Download-Link abgewiesen; nach Installation von 0.4.0 bei beiden und einem Neustart lässt sich der Beitritt erneut versuchen.
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

- [ ] F3-Markierungen aller Teilnehmer erscheinen mit gewähltem Typ und passenden Namens-/Figurenfarben; Ersetzen, Ablauf und Entfernen beim Verlassen funktionieren.
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
ist, bleibt der Internetbetrieb unbestätigt, auch wenn 0.4.0 die normale GitHub-Release-Kennzeichnung verwendet.

## Linux-Prüfung für 0.4.0

- [ ] Heruntergeladenen Linux-Installer unter Ubuntu/Mint starten; beide Sprachen und einen Ordner mit Leerzeichen prüfen.
- [ ] Installation, Update einer bestehenden Version und Entfernung testen; Spielstände, andere Mods und Original-Spiel-Dateien prüfen.
- [ ] V66 über Steam Proton starten; F2, Steam-Overlay, Einladungen und Laden der Welt prüfen.
- [ ] Windows-Host/Linux-Gast und danach Linux-Host/Windows-Gast mit identischer Version 0.4.0 testen.
- [ ] Distribution, Python-Version, Proton-Version und Ergebnis festhalten. Diese Linux-Prüfungen sind noch offen.
