# SexyLoot

Lootaddon für World of Warcraft: Forever im Stil von XLoot.

- **Rollfenster** mit Bedarf, Gier und Passen. Wahl und Würfe aller Spieler stehen direkt am Item, in Klassenfarben. Der Gewinner bekommt einen Haken.
- **Beutefenster** ersetzt das Blizzard-LootFrame (Qualitätsfarben, Tooltips, Shift-Klick verlinkt, „Alles nehmen“).
- **Gruppen-Feed** zeigt, wer welches Item bekommen hat. Der Tooltip einer Würfelzeile listet alle Würfe. Mausrad blättert.
- **Meine Beute** ist eine kleine Liste der zuletzt gelooteten Items mit Stapeln, Zeitangabe und Verkaufswert.

## Installation

Den Addon-Ordner (der mit der `SexyLoot.toc`) unter dem Namen `SexyLoot` nach `Interface/AddOns/` des Forever-Clients kopieren oder verlinken. Die TOC führt wie bei SexyInterrupter `## Interface: 120100, 16001`.

## Einstellungen

Alles wird im Edit Mode eingestellt. Edit Mode öffnen und ein SexyLoot-Fenster anklicken.

Solange der Edit Mode offen ist, zeigt jedes Fenster Beispieldaten (zwei Würfe, eine Testbeute, Feed-Zeilen, gelootete Items). Beim Verlassen verschwinden sie wieder.

Jedes Fenster hat: Position, Skalierung (50 bis 200 %), Ausblenden, Im Kampf ausblenden, Nur bei Mouseover anzeigen und Koordinaten.

| Fenster | Eigene Optionen |
| --- | --- |
| Rollfenster | Würfe am Item ausblenden, Neue Fenster nach oben wachsen lassen, Abstand zwischen Fenstern, Testwurf starten |
| Beutefenster | Graue Items automatisch einsammeln, Gruppenloot-Markierung ab Qualität (2 grün, 3 blau, 4 episch), Symbolgröße, Testbeute öffnen |
| Gruppen-Feed | Zeitstempel ausblenden, Wurfdetails nach Spielerreihenfolge sortieren, Sichtbare Zeilen, Schriftgröße, Feed leeren |
| Meine Beute | Verkaufswert ausblenden, Zeitangabe ausblenden, Gleiche Items nicht stapeln, Anzahl Einträge, Liste leeren |

Checkboxen sind im Standardzustand immer aus, weil EditModeExpanded beim Laden `onUnchecked` aufruft. Darum heißen aktive Optionen „… ausblenden“.

## Befehle

`/sexyloot test` zeigt Testdaten in allen Fenstern. Einzeln: `/sexyloot roll`, `loot`, `feed`, `mine`.

## Aufbau

| Datei | Inhalt |
| --- | --- |
| `Core.lua` | Standardwerte, Anker-Fenster, Hilfsfunktionen, Start |
| `RollFrames.lua` | START_LOOT_ROLL, Chat-Parsing der Würfe, Zeilen mit Timer |
| `LootWindow.lua` | LOOT_OPENED und Slots |
| `Feed.lua` | Gruppen-Feed, Parsing der Lootnachrichten |
| `MyLoot.lua` | Liste der eigenen Beute |
| `EditMode.lua` | Registrierung bei EditModeExpanded |
| `lib/` | LibStub, EditModeExpanded-1.0 |

## Bekannte Grenzen

- Nicht im Spiel getestet. Die Würfelerkennung liest die Loot-Chatnachrichten über die Blizzard-Globalstrings (`LOOT_ROLL_*`). Falls ein Client andere Texte nutzt oder die Nachrichten als geschützte Werte liefert, erscheinen die Würfe nicht am Item.
- Plündermeister (Master Loot) wird vom Beutefenster nicht unterstützt.
- Die Wurfzeit im Rollfenster kommt aus dem Spiel, sie lässt sich nicht einstellen.
- „Gruppenloot-Markierung“ ändert nur die Beschriftung im Beutefenster. Ab welcher Qualität gewürfelt wird, legt der Gruppenleiter fest.
- Keine Auswahllisten: Im Forever-Client sind Addon-Frames mit `UIDropDownMenuTemplate` blockiert (siehe SexyInterrupter). Darum gibt es nur Checkboxen, Schieberegler und Schaltflächen.

## Lizenz und Danksagung

`lib/EditModeExpanded-1.0` stammt von Teelo (https://github.com/teelolws/EditModeExpanded). Die Bibliothek darf in Addons eingebunden werden, wenn der Autor genannt wird. `LibStub` ist gemeinfrei.
