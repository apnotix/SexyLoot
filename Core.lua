local ADDON, ns = ...

-- Standardwerte. Sie stehen hier, weil Schieberegler ihr onChanged
-- beim Laden nur mit gespeicherten Werten aufrufen.
-- Checkboxen sind im Standard immer false.
-- Farben (r, g, b, Deckkraft). Sie stehen in ns.cfg[key].bg / .border und
-- werden zusätzlich in SexyLootDB.colors gespeichert, weil EditModeExpanded
-- Farbwahlen nicht ablegt.
local BORDER = { 0.42, 0.36, 0.25, 1 }
ns.defaults = {
    roll = { hideRolls = false, growUp = false, gap = 10, size = 14, hold = 12,
        bg = { 0.07, 0.05, 0.03, 0.92 }, border = BORDER },
    winner = { size = 28, hold = 6,
        bg = { 0.03, 0.02, 0.01, 0.85 }, border = BORDER },
    loot = { auto = false, thr = 2, icon = 34,
        bg = { 0.07, 0.05, 0.03, 0.92 }, border = BORDER },
    feed = { hideStamp = false, sortPlayers = false, noFade = false, fade = 20, width = 340, height = 160, size = 15,
        bg = { 0.03, 0.02, 0.01, 0.7 }, border = BORDER },
    mine = { hideValue = false, hideTime = false, noStack = false, rows = 7,
        bg = { 0.07, 0.05, 0.03, 0.92 }, border = BORDER },
}

ns.frames  = {}   -- Anker-Fenster, die im Edit Mode bewegt werden
ns.Apply   = {}   -- ns.Apply[key](cfg) wendet die Einstellungen an
ns.modules = {}   -- Module mit :Init()

-- roll: Platz für etwa vier Rollzeilen, damit der Edit-Mode-Rahmen alle Zeilen umfasst
local SIZES = { roll = { 300, 460 }, winner = { 480, 110 }, loot = { 250, 220 }, feed = { 340, 160 }, mine = { 230, 150 } }
local START = {
    roll = { 240, 520 },
    winner = { 720, 640 },      -- ungefähr Bildschirmmitte, oberhalb des Zentrums
    loot = { 900, 420 },
    feed = { 30, 190 },
    mine = { 900, 190 },
}

function ns.CreateFrames()
    for key, size in pairs(SIZES) do
        local f = CreateFrame("Frame", "SexyLoot" .. key .. "Anchor", UIParent)
        f:SetSize(size[1], size[2])
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", START[key][1], START[key][2])
        f:SetClampedToScreen(true)
        -- EME erwartet BOTTOMLEFT-Bildschirmkoordinaten in db.x / db.y. Ist die
        -- Tabelle leer, kann die Bibliothek das Fenster ohne Ankerpunkt zurücklassen
        -- (unsichtbar auch im Edit Mode). Darum die Startposition selbst eintragen.
        local db = SexyLootDB.frames[key]
        if not (db.x and db.y) then
            db.x, db.y = START[key][1], START[key][2]
        end
        ns.frames[key] = f
    end
end

-- Wendet ns.cfg[key] auf das Fenster an (Zoom, Zeilen, Symbolgröße ...)
function ns.Refresh(key)
    if ns.Apply[key] and ns.cfg then ns.Apply[key](ns.cfg[key]) end
end

ns.Actions = {
    testRoll  = function() ns.RollFrames:Test() end,
    openLoot  = function() ns.LootWindow:Test() end,
    testWinner = function() ns.Winner:Test() end,
    clearFeed = function() ns.Feed:Clear() end,
    clearMine = function() ns.MyLoot:Clear() end,
}

--------------------------------------------------------------------------
-- Hilfsfunktionen
--------------------------------------------------------------------------

function ns.Panel(parent)
    local f = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.07, 0.05, 0.03, 0.92)
    f:SetBackdropBorderColor(0.42, 0.36, 0.25, 1)
    return f
end

-- Auf dem Forever-Client fehlen manche Item-Globals, daher C_Item bevorzugen.
function ns.GetItemInfo(...)
    local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if f then return f(...) end
end

function ns.GetItemInfoInstant(...)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if f then return f(...) end
end

ns.qualityFallback = {
    [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 },
    [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 },
    [6] = { 0.9, 0.8, 0.5 }, [7] = { 0, 0.8, 1 },
}

-- Hintergrund- und Randfarbe des Fensters aus ns.cfg[key] auf ein Panel anwenden
function ns.ApplyStyle(panel, key)
    local cfg = ns.cfg and ns.cfg[key]
    if not (panel and cfg) then return end
    local bg, bd = cfg.bg, cfg.border
    panel:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    panel:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
end

function ns.QualityColor(q)
    q = q or 1
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    if C_Item and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(q)
        if r then return r, g, b end
    end
    if GetItemQualityColor then
        local r, g, b = GetItemQualityColor(q)
        if r then return r, g, b end
    end
    local fallback = ns.qualityFallback[q]
    if fallback then return fallback[1], fallback[2], fallback[3] end
    return 1, 1, 1
end

function ns.Short(name)
    if not name then return "?" end
    return Ambiguate and Ambiguate(name, "short") or name
end

ns.classByName = {}

local function AddUnit(list, unit)
    if not UnitExists(unit) then return end
    local name = UnitName(unit)
    if not name then return end
    local _, class = UnitClass(unit)
    ns.classByName[name] = class
    list[#list + 1] = name
end

-- Alle Gruppenmitglieder, du selbst zuerst
function ns.Roster()
    local list = {}
    AddUnit(list, "player")
    if IsInRaid and IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if not UnitIsUnit("raid" .. i, "player") then AddUnit(list, "raid" .. i) end
        end
    elseif IsInGroup and IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do AddUnit(list, "party" .. i) end
    end
    return list
end

function ns.ColorName(name)
    name = ns.Short(name)
    local class = ns.classByName[name]
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, name) end
    return name
end

function ns.ItemID(link)
    return link and tonumber(link:match("item:(%d+)"))
end

--------------------------------------------------------------------------
-- Demodaten im Edit Mode
--------------------------------------------------------------------------

-- Solange der Edit Mode offen ist, zeigt jedes Modul Beispielinhalte
-- (m:Preview(true)). Beim Verlassen räumt es sie wieder weg (m:Preview(false)).
function ns.SetEditMode(active)
    ns.editing = active and true or false
    for _, m in ipairs(ns.modules) do
        if m.Preview then m:Preview(ns.editing) end
    end
end

function ns.HookEditMode()
    if not EditModeManagerFrame then return end
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function() ns.SetEditMode(true) end)
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function() ns.SetEditMode(false) end)
    local active = EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive()
        or EditModeManagerFrame.editModeActive
    if active then ns.SetEditMode(true) end
end

--------------------------------------------------------------------------
-- Start
--------------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
    if name ~= ADDON then return end
    f:UnregisterEvent("ADDON_LOADED")

    SexyLootDB = SexyLootDB or {}
    SexyLootDB.frames = SexyLootDB.frames or {}
    ns.cfg = {}
    for key, def in pairs(ns.defaults) do
        -- EME braucht pro Fenster eine bereits vorhandene Tabelle
        SexyLootDB.frames[key] = SexyLootDB.frames[key] or {}
        ns.cfg[key] = CopyTable(def)
    end
    -- Gespeicherte Farben über die Standardfarben legen
    SexyLootDB.colors = SexyLootDB.colors or {}
    for key, saved in pairs(SexyLootDB.colors) do
        if ns.cfg[key] then
            for _, k in ipairs({ "bg", "border" }) do
                if type(saved[k]) == "table" and #saved[k] == 4 then ns.cfg[key][k] = CopyTable(saved[k]) end
            end
        end
    end

    ns.CreateFrames()
    for _, m in ipairs(ns.modules) do m:Init() end
    ns.SetupEditMode()
    for key in pairs(ns.defaults) do ns.Refresh(key) end
    ns.HookEditMode()
end)

SLASH_SEXYLOOT1 = "/sexyloot"
SLASH_SEXYLOOT2 = "/sl"
SlashCmdList.SEXYLOOT = function(msg)
    msg = (msg or ""):lower()
    if msg == "roll" then
        ns.Actions.testRoll()
    elseif msg == "loot" then
        ns.Actions.openLoot()
    elseif msg == "feed" then
        ns.Feed:Test()
    elseif msg == "mine" then
        ns.MyLoot:Test()
    elseif msg == "winner" then
        ns.Actions.testWinner()
    elseif msg == "test" then
        ns.Actions.testRoll(); ns.Actions.openLoot(); ns.Feed:Test(); ns.MyLoot:Test()
    else
        print("|cffe8c26aSexyLoot|r: /sexyloot test | roll | loot | feed | mine | winner")
        print("Positionen und Optionen: Edit Mode öffnen und ein SexyLoot-Fenster anklicken.")
    end
end
