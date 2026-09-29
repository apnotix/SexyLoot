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

-- Farbwahl über Blizzards ColorPickerFrame (kein Dropdown nötig). Edit Mode
-- Expanded speichert Farben nicht, darum liegen sie in SexyLootDB.colors.
local function SetColor(key, which, r, g, b, a)
    ns.cfg[key][which] = { r, g, b, a }
    SexyLootDB.colors = SexyLootDB.colors or {}
    SexyLootDB.colors[key] = SexyLootDB.colors[key] or {}
    SexyLootDB.colors[key][which] = { r, g, b, a }
    ns.Refresh(key)
end

local function PickColor(key, which)
    local c = ns.cfg[key][which]
    local r0, g0, b0, a0 = c[1], c[2], c[3], c[4]
    ColorPickerFrame:SetupColorPickerAndShow({
        r = r0, g = g0, b = b0, opacity = a0, hasOpacity = true,
        swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            SetColor(key, which, r, g, b, ColorPickerFrame:GetColorAlpha())
        end,
        opacityFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            SetColor(key, which, r, g, b, ColorPickerFrame:GetColorAlpha())
        end,
        cancelFunc = function() SetColor(key, which, r0, g0, b0, a0) end,
    })
end

local function Colors(frame, key)
    lib:RegisterCustomButton(frame, "Hintergrundfarbe wählen", function() PickColor(key, "bg") end)
    lib:RegisterCustomButton(frame, "Randfarbe wählen", function() PickColor(key, "border") end)
    lib:RegisterCustomButton(frame, "Farben zurücksetzen", function()
        if SexyLootDB.colors then SexyLootDB.colors[key] = nil end
        ns.cfg[key].bg = CopyTable(ns.defaults[key].bg)
        ns.cfg[key].border = CopyTable(ns.defaults[key].border)
        ns.Refresh(key)
    end)
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
        Slider(f, "roll", "size", "Schriftgröße der Würfe", 10, 20, 1)
        Slider(f, "roll", "hold", "Fenster nach dem Wurf anzeigen (Sekunden)", 3, 30, 1)
        Colors(f, "roll")
        lib:RegisterCustomButton(f, "Testwurf starten", ns.Actions.testRoll)
    end

    do  -- SexyLoot: Gewinner-Anzeige
        local f = ns.frames.winner
        Standard(f, "winner", "SexyLoot: Gewinner-Anzeige")
        Slider(f, "winner", "size", "Schriftgröße", 18, 40, 2)
        Slider(f, "winner", "hold", "Anzeigedauer (Sekunden)", 2, 15, 1)
        Colors(f, "winner")
        lib:RegisterCustomButton(f, "Test-Gewinner anzeigen", ns.Actions.testWinner)
    end

    do  -- SexyLoot: Beutefenster
        local f = ns.frames.loot
        Standard(f, "loot", "SexyLoot: Beutefenster")
        Checkbox(f, "loot", "auto", "Graue Items automatisch einsammeln")
        Slider(f, "loot", "thr", "Gruppenloot-Markierung ab Qualität (2 grün, 3 blau, 4 episch)", 2, 4, 1)
        Slider(f, "loot", "icon", "Symbolgröße", 24, 48, 2)
        Colors(f, "loot")
        lib:RegisterCustomButton(f, "Testbeute öffnen", ns.Actions.openLoot)
    end

    do  -- SexyLoot: Gruppen-Feed
        local f = ns.frames.feed
        Standard(f, "feed", "SexyLoot: Gruppen-Feed")
        Checkbox(f, "feed", "hideStamp", "Zeitstempel ausblenden")
        Checkbox(f, "feed", "sortPlayers", "Wurfdetails nach Spielerreihenfolge sortieren")
        Slider(f, "feed", "width", "Breite", 240, 700, 10)
        Slider(f, "feed", "height", "Höhe", 80, 500, 10)
        Slider(f, "feed", "size", "Schriftgröße", 8, 20, 1)
        Colors(f, "feed")
        lib:RegisterCustomButton(f, "Feed leeren", ns.Actions.clearFeed)
    end

    do  -- SexyLoot: Meine Beute
        local f = ns.frames.mine
        Standard(f, "mine", "SexyLoot: Meine Beute")
        Checkbox(f, "mine", "hideValue", "Verkaufswert ausblenden")
        Checkbox(f, "mine", "hideTime", "Zeitangabe ausblenden")
        Checkbox(f, "mine", "noStack", "Gleiche Items nicht stapeln")
        Slider(f, "mine", "rows", "Anzahl Einträge", 3, 10, 1)
        Colors(f, "mine")
        lib:RegisterCustomButton(f, "Liste leeren", ns.Actions.clearMine)
    end
end
