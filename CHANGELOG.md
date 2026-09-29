# Changelog

## 0.1.5

- Neu: Gewinner-Anzeige mitten auf dem Bildschirm (Größe und Dauer im Edit Mode einstellbar, `/sexyloot winner` zum Testen).
- Rollfenster: Würfe stehen untereinander, sortiert, mit einstellbarer Schriftgröße.
- Rollfenster bleibt nach dem Wurf einstellbar lange stehen (Standard 12 Sekunden).
- Ein laufender Wurf wird nach einem Reload wiederhergestellt.
- Jedes Fenster: Hintergrund- und Randfarbe (mit Deckkraft) per Farbwähler im Edit Mode wählbar, dazu "Farben zurücksetzen".
- Gruppen-Feed: Breite und Höhe sind einstellbar (ersetzt den Regler "Sichtbare Zeilen").
- Der Edit-Mode-Rahmen des Rollfensters umfasst jetzt mehrere Zeilen.
- Behoben: Fehler beim Auswerten der Würfe (führender Link `|Hlootroll`).
- Behoben: Eigener Gewinn stand doppelt im Feed ("You" und der eigene Name).

## 0.1.4

- Behoben: Lua-Fehler im Edit Mode und bei `/sexyloot test` auf dem Forever-Client (fehlende Globals `GetItemQualityColor`, `GetItemInfo`, `GetItemInfoInstant`; jetzt Zugriff über `C_Item` mit Fallback).

## 0.1.0

- Erste Version: Rollfenster mit Würfen am Item, Beutefenster, Gruppen-Feed und Liste „Meine Beute“.
- Alle Fenster über den Edit Mode einstellbar (EditModeExpanded-1.0).
