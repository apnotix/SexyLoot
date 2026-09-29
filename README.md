<div align="center">

# 🎲 SexyLoot

**Loot, Würfe und Beute auf einen Blick.**
Rollfenster mit den Würfen aller Spieler direkt am Item, ein Beutefenster im Stil von XLoot, ein Gruppen-Feed und eine Liste deiner letzten Funde. Alles frei einstellbar im Edit Mode.

![WoW Forever](https://img.shields.io/badge/WoW-Forever-e8c26a?style=for-the-badge)
![Interface](https://img.shields.io/badge/Interface-120100%20%7C%2016001-3b2b12?style=for-the-badge)
![Edit Mode](https://img.shields.io/badge/Edit%20Mode-ja-4fc16a?style=for-the-badge)

[🇬🇧 English version](README.en.md)

</div>

---

## ✨ Das kann SexyLoot

### 🎲 Rollfenster: Bedarf, Gier, Passen
Kein Rätselraten mehr, wer was gewürfelt hat.

- 🎯 **Würfe am Item:** Wahl und Wurf jedes Spielers stehen direkt unter dem Gegenstand, in Klassenfarben.
- 🏆 **Gewinner auf einen Blick:** Der Sieger bekommt einen Haken, Bedarf schlägt Gier.
- ⏱️ **Timer-Leiste:** Sie wird rot, wenn die Zeit knapp wird.
- 🔍 **Tooltips:** Fahr über das Item und sieh den normalen Item-Tooltip des Spiels.
- 🔒 **Ehrliche Buttons:** Sie sperren erst, wenn deine Wahl wirklich angekommen ist. Bricht du bei einem Bind-on-Pickup-Item die Nachfrage ab, kannst du noch einmal wählen.
- ⬆️ **Wachstumsrichtung** nach oben oder unten, mit einstellbarem Abstand.
- 📋 **Würfe untereinander:** Jeder Spieler steht in einer eigenen Zeile, bestes Ergebnis oben, Schriftgröße einstellbar.
- ⏳ **Bleibt nach dem Wurf stehen:** Das Fenster verschwindet erst nach einer einstellbaren Zeit (3 bis 30 Sekunden).
- 🔄 **Überlebt einen Reload:** Ein laufender Wurf wird danach wiederhergestellt.

### 🏆 Gewinner-Anzeige
Wer einen Wurf gewinnt, erscheint groß mitten auf dem Bildschirm.

- 🖼️ **Item mit Symbol und Qualitätsfarbe**, dazu Name, Bedarf/Gier und Wurf.
- 🙋 **„Du gewinnst!“**, wenn du es bist.
- 📏 **Schriftgröße** und **Anzeigedauer** einstellbar.

### 🎁 Beutefenster
Ersetzt das Standard-Beutefenster.

- 🌈 **Qualitätsfarben** für Rahmen und Namen, Menge am Symbol.
- 🖱️ **Klick zum Looten**, Shift-Klick verlinkt das Item im Chat.
- ✅ **„Alles nehmen“** mit einem Klick.
- 🪙 **Auto-Loot** wird unterstützt.
- 🩶 **Graue Items automatisch** einsammeln (optional).
- 🏷️ **Gruppenloot-Markierung:** Ab welcher Qualität ein Item als Gruppenloot beschriftet wird, stellst du selbst ein.
- 🔎 **Symbolgröße** von 24 bis 48 Pixel.

### 📜 Gruppen-Feed
Wer hat was bekommen?

- 👥 **Alle Funde der Gruppe** mit Itemlink und Klassenfarbe des Spielers.
- 🎲 **Würfel-Details im Tooltip:** Mit der Maus über eine Würfelzeile siehst du alle Wahlen und Würfe, sortiert nach Ergebnis oder Spielerreihenfolge.
- 🕐 **Zeitstempel** (abschaltbar), **Mausrad** zum Blättern.
- 🔤 **Breite**, **Höhe** und **Schriftgröße** einstellbar (die Zeilenzahl ergibt sich daraus).

### 🎒 Meine Beute
Perfekt beim Leveln: die kleine Liste deiner letzten Funde.

- 🧵 **Stapel:** Leinenstoff, Erz und Co. werden zusammengezählt („x5“).
- 🕒 **Zeitangabe** pro Eintrag („jetzt“, „40s“, „2m“).
- 💰 **Verkaufswert** der gesamten Liste in Gold, Silber und Kupfer.
- 🔢 **3 bis 10 Einträge**, alles abschaltbar.

---

## 🛠️ Alles im Edit Mode einstellbar

Öffne den **Edit Mode**, klicke ein SexyLoot-Fenster an und stell es ein. SexyLoot nutzt dafür die Bibliothek [EditModeExpanded](https://github.com/teelolws/EditModeExpanded).

**Jedes der fünf Fenster bietet:**

| Option | Wirkung |
| --- | --- |
| 📍 Position | Frei ziehen, am Bildschirmrand geklemmt |
| 🔍 Skalierung | 50 bis 200 % |
| 👁️ Ausblenden | Fenster dauerhaft aus |
| ⚔️ Im Kampf ausblenden | Nur außerhalb des Kampfs sichtbar |
| 🖱️ Nur bei Mouseover | Erscheint erst, wenn du mit der Maus darüberfährst |
| 🧭 Koordinaten | Bildschirmposition per Zahleneingabe |
| 🎨 Hintergrund- und Randfarbe | Beides mit Farbwähler und Deckkraft, dazu „Farben zurücksetzen“ |

**Dazu die eigenen Optionen jedes Fensters:**

| Fenster | Optionen |
| --- | --- |
| 🎲 Rollfenster | Würfe am Item ausblenden · Neue Fenster nach oben wachsen lassen · Abstand zwischen Fenstern · Schriftgröße der Würfe · Fenster nach dem Wurf anzeigen (Sekunden) · Testwurf starten |
| 🏆 Gewinner-Anzeige | Schriftgröße · Anzeigedauer · Test-Gewinner anzeigen |
| 🎁 Beutefenster | Graue Items automatisch einsammeln · Gruppenloot-Markierung ab Qualität · Symbolgröße · Testbeute öffnen |
| 📜 Gruppen-Feed | Zeitstempel ausblenden · Wurfdetails nach Spielerreihenfolge sortieren · Breite · Höhe · Schriftgröße · Feed leeren |
| 🎒 Meine Beute | Verkaufswert ausblenden · Zeitangabe ausblenden · Gleiche Items nicht stapeln · Anzahl Einträge · Liste leeren |

### 👀 Demodaten im Edit Mode
Solange der Edit Mode offen ist, zeigt jedes Fenster Beispielinhalte: zwei Würfe, eine Testbeute, Feed-Zeilen und gelootete Items. So siehst du sofort, wie Skalierung, Symbolgröße und Zeilenzahl aussehen. Beim Verlassen verschwinden sie wieder.

---

## 📥 Installation

1. Ordner `SexyLoot` in dein `Interface/AddOns`-Verzeichnis des Forever-Clients kopieren.
2. Spiel starten oder `/reload`.
3. Edit Mode öffnen und die Fenster nach Wunsch platzieren.

## ⌨️ Befehle

| Befehl | Wirkung |
| --- | --- |
| `/sexyloot test` | Testdaten in allen Fenstern |
| `/sexyloot roll` | Testwurf |
| `/sexyloot loot` | Testbeute |
| `/sexyloot feed` | Beispielzeilen im Feed |
| `/sexyloot mine` | Beispiele in „Meine Beute“ |

Kurzform: `/sl`

---

## ⚠️ Gut zu wissen

- 🧪 **Frühe Version.** Die Würfelerkennung liest die Loot-Chatnachrichten des Spiels. Zeigt dein Client andere Texte, erscheinen die Würfe nicht am Item. Melde dich dann mit einem Screenshot und dem Chat-Text.
- 👑 **Plündermeister** (Master Loot) wird vom Beutefenster nicht unterstützt.
- ⏳ Die **Wurfzeit** legt das Spiel fest, sie lässt sich nicht einstellen.
- 🏷️ Die **Gruppenloot-Markierung** ändert nur die Beschriftung im Beutefenster. Ab welcher Qualität gewürfelt wird, bestimmt der Gruppenleiter.
- 📋 Es gibt bewusst **keine Auswahllisten**, weil Addon-Frames mit `UIDropDownMenuTemplate` im Forever-Client blockiert sind. Stattdessen gibt es Schieberegler, Checkboxen und Schaltflächen.

## 🐞 Fehler melden

Fehler und Wünsche bitte als [Issue auf GitHub](https://github.com/apnotix/SexyLoot/issues) melden. Aktiviere vorher `/console scriptErrors 1` und schick die Lua-Fehlermeldung mit.

## 🙏 Danksagung

- [EditModeExpanded](https://github.com/teelolws/EditModeExpanded) von **Teelo** (Bibliothek `EditModeExpanded-1.0`, eingebettet, Autor wird wie in der Lizenz gefordert genannt)
- **LibStub** (gemeinfrei)
- Inspiriert von **XLoot**

---

<div align="center">

Gemacht von **apnotix** · Auch von mir: **SexyInterrupter**

</div>
