local ADDON, ns = ...
local T = ns.T
local lib = LibStub:GetLibrary("EditModeExpanded-1.0")

-- Standardoptionen, für jedes Fenster gleich
local function Standard(frame, key, title)
    lib:RegisterFrame(frame, title, SexyLootDB.frames[key])   -- Position, am Rand geklemmt
    lib:RegisterResizable(frame, 50, 200, 5)                  -- Skalierung in Prozent
    lib:RegisterHideable(frame)                               -- "Ausblenden"
    lib:RegisterToggleInCombat(frame)                         -- erst nach RegisterHideable
    lib:RegisterHiddenUntilMouseover(frame, T["Nur bei Mouseover anzeigen"])
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
    lib:RegisterCustomButton(frame, T["Hintergrundfarbe wählen"], function() PickColor(key, "bg") end)
    lib:RegisterCustomButton(frame, T["Randfarbe wählen"], function() PickColor(key, "border") end)
    lib:RegisterCustomButton(frame, T["Farben zurücksetzen"], function()
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
        Standard(f, "roll", T["SexyLoot: Rollfenster"])
        Checkbox(f, "roll", "hideRolls", T["Würfe am Item ausblenden"])
        Checkbox(f, "roll", "growUp", T["Neue Fenster nach oben wachsen lassen"])
        Slider(f, "roll", "gap", T["Abstand zwischen Fenstern"], 0, 24, 2)
        Slider(f, "roll", "size", T["Schriftgröße der Würfe"], 10, 20, 1)
        Slider(f, "roll", "hold", T["Fenster nach dem Wurf anzeigen (Sekunden)"], 3, 30, 1)
        Colors(f, "roll")
        lib:RegisterCustomButton(f, T["Testwurf starten"], ns.Actions.testRoll)
    end

    do  -- SexyLoot: Gewinner-Anzeige
        local f = ns.frames.winner
        Standard(f, "winner", T["SexyLoot: Gewinner-Anzeige"])
        Slider(f, "winner", "size", T["Schriftgröße"], 18, 40, 2)
        Slider(f, "winner", "hold", T["Anzeigedauer (Sekunden)"], 2, 15, 1)
        Colors(f, "winner")
        lib:RegisterCustomButton(f, T["Test-Gewinner anzeigen"], ns.Actions.testWinner)
    end

    do  -- SexyLoot: Beutefenster
        local f = ns.frames.loot
        Standard(f, "loot", T["SexyLoot: Beutefenster"])
        Checkbox(f, "loot", "auto", T["Graue Items automatisch einsammeln"])
        Slider(f, "loot", "thr", T["Gruppenloot-Markierung ab Qualität (2 grün, 3 blau, 4 episch)"], 2, 4, 1)
        Slider(f, "loot", "icon", T["Symbolgröße"], 24, 48, 2)
        Colors(f, "loot")
        lib:RegisterCustomButton(f, T["Testbeute öffnen"], ns.Actions.openLoot)
    end

    do  -- SexyLoot: Gruppen-Feed
        local f = ns.frames.feed
        Standard(f, "feed", T["SexyLoot: Gruppen-Feed"])
        Checkbox(f, "feed", "hideStamp", T["Zeitstempel ausblenden"])
        Checkbox(f, "feed", "sortPlayers", T["Wurfdetails nach Spielerreihenfolge sortieren"])
        Checkbox(f, "feed", "noFade", T["Nachrichten nicht ausblenden"])
        Slider(f, "feed", "fade", T["Nachrichten ausblenden nach (Sekunden)"], 5, 120, 5)
        Slider(f, "feed", "width", T["Breite"], 240, 700, 10)
        Slider(f, "feed", "height", T["Höhe"], 80, 500, 10)
        Slider(f, "feed", "size", T["Schriftgröße"], 8, 20, 1)
        Colors(f, "feed")
        lib:RegisterCustomButton(f, T["Feed leeren"], ns.Actions.clearFeed)
    end

    do  -- SexyLoot: Meine Beute
        local f = ns.frames.mine
        Standard(f, "mine", T["SexyLoot: Meine Beute"])
        Checkbox(f, "mine", "hideValue", T["Gesamtwert ausblenden"])
        Checkbox(f, "mine", "hideItemValue", T["Wert pro Eintrag ausblenden"])
        Checkbox(f, "mine", "noStack", T["Gleiche Items nicht stapeln"])
        Slider(f, "mine", "rows", T["Anzahl Einträge"], 3, 10, 1)
        Colors(f, "mine")
        lib:RegisterCustomButton(f, T["Liste leeren"], ns.Actions.clearMine)
    end
end
