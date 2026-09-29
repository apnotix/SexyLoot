local ADDON, ns = ...
local lib = LibStub:GetLibrary("EditModeExpanded-1.0")

-- Standardoptionen, für jedes Fenster gleich
local function Standard(frame, key, title)
    lib:RegisterFrame(frame, title, SexyLootDB.frames[key])   -- Position, am Rand geklemmt
    lib:RegisterResizable(frame, 50, 200, 5)                  -- Skalierung in Prozent
    lib:RegisterHideable(frame)                               -- "Ausblenden"
    lib:RegisterToggleInCombat(frame)                         -- erst nach RegisterHideable
    lib:RegisterHiddenUntilMouseover(frame, "Nur bei Mouseover anzeigen")
    lib:RegisterCoordinates(frame)                            -- X/Y eintippen
end

-- Aus = Standard: onUnchecked läuft beim Laden immer einmal
local function Checkbox(frame, key, opt, label)
    lib:RegisterCustomCheckbox(frame, label,
        function() ns.cfg[key][opt] = true;  ns.Refresh(key) end,
        function() ns.cfg[key][opt] = false; ns.Refresh(key) end,
        opt)
end

local function Slider(frame, key, opt, label, min, max, step)
    lib:RegisterSlider(frame, label, opt, function(value)
        ns.cfg[key][opt] = value
        ns.Refresh(key)
    end, min, max, step)
end

-- Bewusst keine Auswahllisten (RegisterDropdown): Im Forever-Client sind
-- Addon-Frames mit UIDropDownMenuTemplate blockiert.

function ns.SetupEditMode()

    do  -- SexyLoot: Rollfenster
        local f = ns.frames.roll
        Standard(f, "roll", "SexyLoot: Rollfenster")
        Checkbox(f, "roll", "hideRolls", "Würfe am Item ausblenden")
        Checkbox(f, "roll", "growUp", "Neue Fenster nach oben wachsen lassen")
        Slider(f, "roll", "gap", "Abstand zwischen Fenstern", 0, 24, 2)
        lib:RegisterCustomButton(f, "Testwurf starten", ns.Actions.testRoll)
    end

    do  -- SexyLoot: Beutefenster
        local f = ns.frames.loot
        Standard(f, "loot", "SexyLoot: Beutefenster")
        Checkbox(f, "loot", "auto", "Graue Items automatisch einsammeln")
        Slider(f, "loot", "thr", "Gruppenloot-Markierung ab Qualität (2 grün, 3 blau, 4 episch)", 2, 4, 1)
        Slider(f, "loot", "icon", "Symbolgröße", 24, 48, 2)
        lib:RegisterCustomButton(f, "Testbeute öffnen", ns.Actions.openLoot)
    end

    do  -- SexyLoot: Gruppen-Feed
        local f = ns.frames.feed
        Standard(f, "feed", "SexyLoot: Gruppen-Feed")
        Checkbox(f, "feed", "hideStamp", "Zeitstempel ausblenden")
        Checkbox(f, "feed", "sortPlayers", "Wurfdetails nach Spielerreihenfolge sortieren")
        Slider(f, "feed", "lines", "Sichtbare Zeilen", 3, 15, 1)
        Slider(f, "feed", "size", "Schriftgröße", 12, 20, 1)
        lib:RegisterCustomButton(f, "Feed leeren", ns.Actions.clearFeed)
    end

    do  -- SexyLoot: Meine Beute
        local f = ns.frames.mine
        Standard(f, "mine", "SexyLoot: Meine Beute")
        Checkbox(f, "mine", "hideValue", "Verkaufswert ausblenden")
        Checkbox(f, "mine", "hideTime", "Zeitangabe ausblenden")
        Checkbox(f, "mine", "noStack", "Gleiche Items nicht stapeln")
        Slider(f, "mine", "rows", "Anzahl Einträge", 3, 10, 1)
        lib:RegisterCustomButton(f, "Liste leeren", ns.Actions.clearMine)
    end
end
