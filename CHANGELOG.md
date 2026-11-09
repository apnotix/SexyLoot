# Changelog

## 0.1.15

- Release-Workflow repariert: Der Packager brach bei jedem Lauf mit "Found future tag" ab, darum wurde nichts gepackt oder hochgeladen. Der Push-Lauf startet den Paketbau jetzt per workflow_dispatch auf dem Tag.

## 0.1.14

- Behoben: Seit dem flachen Look fehlte die Edit-Mode-Vorschau in den meisten Fenstern, und Rollfenster und Freie Würfe lösten Lua-Fehler aus (das Feld "bar" des Panels kollidierte mit der Zeitleiste). Der Balken links heißt jetzt "accent". Ein Fehler in einer Vorschau blockiert die anderen nicht mehr.
- "Zuletzt gelootet": Tooltip über dem Gesamtwert mit Dauer, Anzahl und Wert der gelooteten Items der Sitzung, das teuerste Item sowie Wert und Items pro Stunde (Hochrechnung ab 30 Sekunden). Die Zahlen gelten für die ganze Sitzung, auch für Einträge, die nicht mehr in der Liste stehen.
- "Zuletzt gelootet": Links neben dem Gesamtwert steht die Dauer der Sitzung (seit Login oder dem letzten Leeren der Liste), abschaltbar mit "Sitzungsdauer ausblenden".
- Loot-Einblendung und "Zuletzt gelootet": Questitems tragen ein gelbes Ausrufezeichen am Symbol.
- Neu: Fenster lassen sich aneinander andocken. Im Edit Mode gibt es pro Fenster "Andocken: Ziel wechseln" (schaltet durch Aus und die anderen Fenster) und "Andocken: Seite wechseln" (unten, oben, links, rechts). Das angedockte Fenster wandert mit; wer es im Edit Mode selbst zieht, löst es ab.
- Neuer Look für alle Fenster im Stil der Loot-Einblendung: flache, dunkle, leicht durchsichtige Fläche mit schmalem Balken links (Randfarbe) statt des eckigen Tooltip-Rahmens. Eigene Farben bleiben erhalten, "Farben zurücksetzen" setzt auf den neuen Standard.
- Rollfenster und Beutefenster blenden weich ein.
- Geld-Rahmen: Tooltip mit dem Geld aller Charaktere deines Accounts (nach Geld sortiert, mit Gesamtsumme). Ein Charakter erscheint, sobald du ihn einmal gespielt hast. Neuer Button "Gespeicherte Charaktere zurücksetzen".
- Loot-Einblendung: Mit der Maus über einer Zeile bleibt sie eingeblendet und zeigt den Item-Tooltip (Shift-Klick verlinkt das Item im Chat).
- Neu: Loot-Einblendung (Symbol, Name, Anzahl, Verkaufswert) für gerade gelootete Items. Zeilen blenden nach einstellbarer Zeit aus, gleiche Items werden zusammengezählt (`/sexyloot toast` zum Testen).
- "Zuletzt gelootet": Button "Wachstumsrichtung wechseln (oben/unten)" (Standard: nach oben). Die Einstellung gilt für alle Edit-Mode-Layouts.
- Neu: Kleiner Rahmen "Geld" mit aktuellem Geld und Verkaufswert aller Items in den Taschen (Position und Farben im Edit Mode).

## 0.1.9

- Beutefenster: Geld (und Währung) wird automatisch eingesammelt, abschaltbar mit "Geld nicht automatisch einsammeln". Erkannt über GetLootSlotType, denn LootSlotHasItem meldet auch bei Geld "ja".
- Beutefenster-Hotkey: Das Loslassen anderer Tasten wird nach einem Hotkey-Druck nicht mehr verschluckt (der Charakter lief sonst weiter).
- Gewinner-Anzeige: Abgerundete Karte mit rundem, weichem Schein, abgerundetem Symbol mit Qualitätsring (eigene Texturen in media/, erzeugt mit tools/make_textures.py).
- Gewinner-Anzeige: Pulsierender Schein in Qualitätsfarbe, glühendes Symbol mit Stern, Zierlinie, Ein- und Ausblend-Animation.
- Gewinner-Anzeige: Gewinnen mehrere kurz hintereinander, stehen die Karten untereinander (neueste oben), jede mit eigenem Timer. Neuer Regler "Gleichzeitig angezeigte Gewinner" (1 bis 5, Standard 3).
- Freie Würfe: Schaltfläche "Gewinner ansagen" schreibt den Gewinner in einen einstellbaren Kanal (Automatisch, Sagen, Gruppe, Schlachtzug, Instanz, Gilde, Schreien, Chatkanal-Nummer).
- Neu: Fenster "Freie Würfe" für manuelle /roll-Würfe (z. B. bei Kisten). Ab zwei Würflern erscheint die Liste, der höchste Wurf steht oben. Nach einer einstellbaren Zeit ohne neuen Wurf wird sie geleert und ausgeblendet (`/sexyloot freeroll` zum Testen).
- Rollfenster: Nach dem Wurf zeigt die Leiste einen Countdown bis zum Verschwinden, dazu steht "Schließt in Ns" im Kopf.

## 0.1.8

- Behoben: Bedarf/Gier/Passen reagierten bei echten Würfen nicht, wenn die Zeile vorher als Edit-Mode-Vorschau gedient hatte (altes preview-Flag blieb im Pool stehen). Danach funktionierte auch die Gewinner-Anzeige für diese Zeile nicht.
- Rollfenster: Jede Zeile lässt sich per Klick auf den Kopf ein- und ausklappen (Plus/Minus-Symbol).
- Rollfenster: Bei vielen Items gleichzeitig klappen ältere Zeilen ein, sobald die einstellbare Maximalhöhe überschritten wird (Kurzzeile mit Tooltip). Die Liste ragt nicht mehr aus dem Bildschirm.
- Rollfenster: Neue Darstellung der einzelnen Würfe als Tabelle (Symbol, Name, Wurf rechts, Gewinner golden mit Haken, gedimmtes Passen; ein Ergebnisstreifen erscheint nur, wenn alle gepasst haben).
- Behoben: Das Rollfenster verschwand manchmal, obwohl andere noch würfelten (Cancel-Ereignis nach der eigenen Wahl). Es bleibt jetzt, solange der Wurf läuft.
- Rollfenster: Transmog-Würfe werden unterstützt (der Gier-Button würfelt dann auf Transmog). Gesperrte Buttons zeigen jetzt ihren Tooltip mit dem Grund.
- Behoben: Nach einem Reload fehlten die schon gefallenen Wahlen und Würfe eines laufenden Wurfs. Sie werden jetzt aus der Loot-Historie des Clients geladen, auch die eigene Wahl.
- Beutefenster: Für "Alles nehmen" lässt sich im Edit Mode ein Hotkey festlegen (und wieder entfernen). Er gilt, solange das Beutefenster offen ist. Der Hotkey läuft über einen eigenen Tastatur-Frame, der nur die Hotkey-Taste abfängt und alle anderen Tasten weiterreicht (wie bei Dialogue UI), auch im Kampf (dort geht die Taste zusätzlich ans Spiel, weil sich die Weitergabe im Kampf nicht ändern lässt). Auch Leertaste ist möglich.

## 0.1.7

- Meine Beute: Statt der Zeit steht jetzt der Verkaufswert pro Eintrag da, bei Stapeln für den ganzen Stapel. Die Option "Zeitangabe ausblenden" heißt jetzt "Wert pro Eintrag ausblenden", der Gesamtwert "Gesamtwert ausblenden".
- Behoben: Mitspieler standen beim Würfeln doppelt in der Liste (mit und ohne Realm-Namen, kurzer und langer Name wie "Arak" und "Arak Ragerunner").
- Übersetzung: Deutsch und Englisch. Nicht-deutsche Clients zeigen Englisch, Bedarf/Gier/Passen kommen aus dem Spiel.

## 0.1.5

- Neu: Gewinner-Anzeige mitten auf dem Bildschirm (Größe und Dauer im Edit Mode einstellbar, `/sexyloot winner` zum Testen).
- Rollfenster: Würfe stehen untereinander, sortiert, mit einstellbarer Schriftgröße.
- Rollfenster bleibt nach dem Wurf einstellbar lange stehen (Standard 12 Sekunden).
- Ein laufender Wurf wird nach einem Reload wiederhergestellt.
- Jedes Fenster: Hintergrund- und Randfarbe (mit Deckkraft) per Farbwähler im Edit Mode wählbar, dazu "Farben zurücksetzen".
- Gruppen-Feed: Nachrichten blenden nach einstellbarer Zeit aus (Standard 20 Sekunden, abschaltbar). Scrollen blendet sie wieder ein.
- Gruppen-Feed: Tooltip und Klick gelten nur noch über dem Item-Link, nicht mehr über der ganzen Zeile.
- Gruppen-Feed: Breite und Höhe sind einstellbar (ersetzt den Regler "Sichtbare Zeilen").
- Der Edit-Mode-Rahmen des Rollfensters umfasst jetzt mehrere Zeilen.
- Behoben: Fehler beim Auswerten der Würfe (führender Link `|Hlootroll`).
- Behoben: Eigener Gewinn stand doppelt im Feed ("You" und der eigene Name).

## 0.1.4

- Behoben: Lua-Fehler im Edit Mode und bei `/sexyloot test` auf dem Forever-Client (fehlende Globals `GetItemQualityColor`, `GetItemInfo`, `GetItemInfoInstant`; jetzt Zugriff über `C_Item` mit Fallback).

## 0.1.0

- Erste Version: Rollfenster mit Würfen am Item, Beutefenster, Gruppen-Feed und Liste „Meine Beute“.
- Alle Fenster über den Edit Mode einstellbar (EditModeExpanded-1.0).
