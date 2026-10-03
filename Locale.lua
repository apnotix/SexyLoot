local ADDON, ns = ...

-- Übersetzungen. Deutsch ist die Quellsprache: der Schlüssel ist der deutsche
-- Text, auf deutschen Clients kommt er unverändert zurück. Alle anderen Clients
-- bekommen Englisch. Fehlt eine Übersetzung, wird der Schlüssel angezeigt.
-- Aufruf: T["Text"] oder T("Text mit %s", wert)
local T = setmetatable({}, {
    __index = function(_, key) return key end,
    __call = function(t, key, ...) return t[key]:format(...) end,
})
ns.T = T

if GetLocale() == "deDE" then return end

local en = {
    -- Feed / Rollfenster / Gewinner-Anzeige
    ["%s gewinnt %s"] = "%s wins %s",
    ["%s erhält %s"] = "%s receives %s",
    ["Alle passen auf %s"] = "Everyone passed on %s",
    ["Würfe"] = "Rolls",
    ["Klick: Zeile ein- oder ausklappen"] = "Click: collapse or expand row",
    ["%d von %d haben gewählt"] = "%d of %d have chosen",
    ["keine Wahl"] = "no choice",
    ["%s gewinnt (%s)"] = "%s wins (%s)",
    ["Alle haben gepasst"] = "Everyone passed",
    ["Du gewinnst!"] = "You win!",
    ["%s gewinnt!"] = "%s wins!",

    -- Beutefenster
    ["Gruppenloot"] = "Group loot",
    ["Freie Beute"] = "Free loot",
    ["Testbeute"] = "Test loot",
    ["Alles nehmen"] = "Take all",
    ["1 Silber 24 Kupfer"] = "1 Silver 24 Copper",

    -- Meine Beute
    ["Zuletzt gelootet"] = "Recently looted",
    ["Noch nichts gelootet."] = "Nothing looted yet.",

    -- Beispielgegenstände (Vorschau und Tests)
    ["Ring des Glutkerns"] = "Molten Core Ring",
    ["Kettenkappe der Wachsamkeit"] = "Chain Cap of Vigilance",
    ["Kappe der Wachsamkeit"] = "Cap of Vigilance",
    ["Mondstoffhandschuhe"] = "Mooncloth Gloves",
    ["Leinenstoff"] = "Linen Cloth",
    ["Kupfererz"] = "Copper Ore",
    ["Schwacher Heiltrank"] = "Minor Healing Potion",
    ["Zerrissene Wolfshaut"] = "Torn Wolf Pelt",

    -- Slash-Befehl
    ["Positionen und Optionen: Edit Mode öffnen und ein SexyLoot-Fenster anklicken."] =
        "Positions and options: open Edit Mode and click a SexyLoot window.",

    -- Edit Mode: Standardoptionen
    ["Nur bei Mouseover anzeigen"] = "Hide until mouseover",
    ["Hintergrundfarbe wählen"] = "Choose background color",
    ["Randfarbe wählen"] = "Choose border color",
    ["Farben zurücksetzen"] = "Reset colors",

    -- Edit Mode: Rollfenster
    ["SexyLoot: Rollfenster"] = "SexyLoot: Roll window",
    ["Würfe am Item ausblenden"] = "Hide rolls on the item",
    ["Neue Fenster nach oben wachsen lassen"] = "Let new windows grow upward",
    ["Abstand zwischen Fenstern"] = "Spacing between windows",
    ["Schriftgröße der Würfe"] = "Font size of rolls",
    ["Fenster nach dem Wurf anzeigen (Sekunden)"] = "Show window after the roll (seconds)",
    ["Testwurf starten"] = "Start test roll",
    ["Maximale Höhe der Liste (darüber klappen Zeilen ein)"] = "Maximum list height (rows collapse above it)",

    -- Edit Mode: Gewinner-Anzeige
    ["SexyLoot: Gewinner-Anzeige"] = "SexyLoot: Winner announcement",
    ["Schriftgröße"] = "Font size",
    ["Anzeigedauer (Sekunden)"] = "Display time (seconds)",
    ["Test-Gewinner anzeigen"] = "Show test winner",

    -- Edit Mode: Beutefenster
    ["SexyLoot: Beutefenster"] = "SexyLoot: Loot window",
    ["Graue Items automatisch einsammeln"] = "Auto-loot grey items",
    ["Gruppenloot-Markierung ab Qualität (2 grün, 3 blau, 4 episch)"] = "Group loot label from quality (2 green, 3 blue, 4 epic)",
    ["Symbolgröße"] = "Icon size",
    ["Testbeute öffnen"] = "Open test loot",
    ["Hotkey für „Alles nehmen“ festlegen"] = "Set hotkey for \"Take all\"",
    ["Hotkey entfernen"] = "Remove hotkey",
    ["Drücke die gewünschte Taste (Esc bricht ab) …"] = "Press the desired key (Esc cancels) …",
    ["Hotkey für „Alles nehmen“: %s"] = "Hotkey for \"Take all\": %s",
    ["Hotkey entfernt."] = "Hotkey removed.",

    -- Edit Mode: Gruppen-Feed
    ["SexyLoot: Gruppen-Feed"] = "SexyLoot: Group feed",
    ["Zeitstempel ausblenden"] = "Hide timestamps",
    ["Wurfdetails nach Spielerreihenfolge sortieren"] = "Sort roll details by player order",
    ["Nachrichten nicht ausblenden"] = "Do not fade out messages",
    ["Nachrichten ausblenden nach (Sekunden)"] = "Fade out messages after (seconds)",
    ["Breite"] = "Width",
    ["Höhe"] = "Height",
    ["Feed leeren"] = "Clear feed",

    -- Edit Mode: Meine Beute
    ["SexyLoot: Meine Beute"] = "SexyLoot: My loot",
    ["Gesamtwert ausblenden"] = "Hide total value",
    ["Wert pro Eintrag ausblenden"] = "Hide value per entry",
    ["Gleiche Items nicht stapeln"] = "Do not stack identical items",
    ["Anzahl Einträge"] = "Number of entries",
    ["Liste leeren"] = "Clear list",
}

for k, v in pairs(en) do rawset(T, k, v) end
