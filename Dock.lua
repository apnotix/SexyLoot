local ADDON, ns = ...
local T = ns.T

-- Andocken: Ein Fenster hängt mit festem Abstand an einer Seite eines anderen
-- (unten, oben, links, rechts) und wandert mit, wenn dieses verschoben wird oder
-- seine Größe ändert. Gewählt wird in den Einstellungen mit zwei Auswahlfeldern (Ziel und Seite);
-- Zustand: SexyLootDB.dock[key] = { target, side }.
-- Wer ein angedocktes Fenster im Edit Mode selbst zieht, löst es damit ab.
--
-- Die Bibliothek setzt Positionen bei Größenänderung und Zurücksetzen neu.
-- Darum prüft ein Treiber jedes Bild, ob der Ankerpunkt noch stimmt,
-- und setzt ihn bei Bedarf neu.

local Dock = {}
ns.Dock = Dock
table.insert(ns.modules, Dock)

local GAP = 6
local ORDER = { "roll", "freeroll", "winner", "loot", "feed", "mine", "toast", "wallet", "bags", "deButton" }
local SIDES = { "BOTTOM", "TOP", "LEFT", "RIGHT" }
local ALIGNS = { "START", "CENTER", "END" }
-- Ankerpunkt am angedockten Fenster, am Ziel, Abstand. Die Ausrichtung bestimmt, an welcher Kante die Fenster bündig
-- sind: unten/oben angedockt links, Mitte oder rechts; links/rechts angedockt oben, Mitte oder unten.
local GEOM = {
    BOTTOM = { START = { "TOPLEFT", "BOTTOMLEFT" }, CENTER = { "TOP", "BOTTOM" }, END = { "TOPRIGHT", "BOTTOMRIGHT" }, x = 0, y = -GAP },
    TOP    = { START = { "BOTTOMLEFT", "TOPLEFT" }, CENTER = { "BOTTOM", "TOP" }, END = { "BOTTOMRIGHT", "TOPRIGHT" }, x = 0, y = GAP },
    LEFT   = { START = { "TOPRIGHT", "TOPLEFT" }, CENTER = { "RIGHT", "LEFT" }, END = { "BOTTOMRIGHT", "BOTTOMLEFT" }, x = -GAP, y = 0 },
    RIGHT  = { START = { "TOPLEFT", "TOPRIGHT" }, CENTER = { "LEFT", "RIGHT" }, END = { "BOTTOMLEFT", "BOTTOMRIGHT" }, x = GAP, y = 0 },
}

-- { Punkt am Fenster, Punkt am Ziel, x, y } für Seite und Ausrichtung
local function Geom(d)
    local g = GEOM[d.side or "BOTTOM"]
    local p = g[d.align or "START"] or g.START
    return p[1], p[2], g.x, g.y
end

local function Name(key)
    local names = {
        roll = T["Rollfenster"], freeroll = T["Freie Würfe"], winner = T["Gewinner-Anzeige"],
        loot = T["Beutefenster"], feed = T["Gruppen-Feed"], mine = T["Meine Beute"],
        toast = T["Loot-Einblendung"], wallet = T["Geld"], bags = T["Taschen-Hinweis"], deButton = T["Entzauber-Knopf"],
    }
    return names[key] or key
end

local function SideName(side)
    local names = { BOTTOM = T["unten"], TOP = T["oben"], LEFT = T["links"], RIGHT = T["rechts"] }
    return names[side]
end

local function Say(msg) print("|cffe8c26aSexyLoot|r: " .. msg) end

-- Hängt target (direkt oder über Ketten) an key? Dann wäre ein Ring entstanden.
local function Leads(target, key)
    local seen = {}
    while target and not seen[target] do
        if target == key then return true end
        seen[target] = true
        local d = SexyLootDB.dock[target]
        target = d and d.target
    end
    return false
end

local function Place(key, d)
    local f, t = ns.frames[key], ns.frames[d.target]
    local point, relPoint, x, y = Geom(d)
    f:ClearAllPoints()
    f:SetPoint(point, t, relPoint, x, y)
end

-- Steht das Fenster schon richtig? (sonst jedes Bild neu setzen)
local function InPlace(key, d)
    local f, t = ns.frames[key], ns.frames[d.target]
    if f:GetNumPoints() ~= 1 then return false end
    local point, rel, relPoint, x, y = f:GetPoint(1)
    local gp, grel, gx, gy = Geom(d)
    return point == gp and rel == t and relPoint == grel
        and math.abs((x or 0) - gx) < 0.01 and math.abs((y or 0) - gy) < 0.01
end

local dragging = {}

local function OnUpdate()
    for key, d in pairs(SexyLootDB.dock) do
        if d.target and ns.frames[key] and ns.frames[d.target] and not dragging[key]
            and not InPlace(key, d) then
            Place(key, d)
        end
    end
end

-- Letzte freie Position wiederherstellen
local function Release(key)
    local d = SexyLootDB.dock[key]
    SexyLootDB.dock[key] = nil
    local f = ns.frames[key]
    if d and d.x and d.y and f then
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", d.x, d.y)
    end
end

-- Gewählte Seite, solange das Fenster noch nirgends angedockt ist
local pendingSide = {}
local pendingAlign = {}

-- Auswahl "Andocken an": Aus, dann jedes andere Fenster, das keinen Ring bildet
function Dock:TargetOptions(key)
    local list = { { value = "", label = T["Nicht angedockt"] } }
    for _, k in ipairs(ORDER) do
        if k ~= key and not Leads(k, key) then list[#list + 1] = { value = k, label = Name(k) } end
    end
    return list
end

function Dock:SideOptions()
    local list = {}
    for _, side in ipairs(SIDES) do list[#list + 1] = { value = side, label = (SideName(side):gsub("^%l", string.upper)) } end
    return list
end

-- Ausrichtung: Beschriftung hängt von der Seite ab (waagerecht: links/rechts, senkrecht: oben/unten)
function Dock:AlignOptions(key)
    local side = self:GetSide(key)
    local horizontal = side == "BOTTOM" or side == "TOP"
    return {
        { value = "START", label = horizontal and T["Links bündig"] or T["Oben bündig"] },
        { value = "CENTER", label = T["Zentriert"] },
        { value = "END", label = horizontal and T["Rechts bündig"] or T["Unten bündig"] },
    }
end

function Dock:GetAlign(key)
    local d = SexyLootDB.dock[key]
    return d and d.align or pendingAlign[key] or "START"
end

function Dock:SetAlign(key, align)
    local d = SexyLootDB.dock[key]
    if d and d.target then
        d.align = align
        Place(key, d)
    else
        pendingAlign[key] = align
    end
end

function Dock:GetTarget(key)
    local d = SexyLootDB.dock[key]
    return d and d.target or ""
end

function Dock:GetSide(key)
    local d = SexyLootDB.dock[key]
    return d and d.side or pendingSide[key] or "BOTTOM"
end

-- target leer oder nil: abdocken (die letzte freie Position kommt zurück)
function Dock:SetTarget(key, target)
    if not target or target == "" then
        Release(key)
        return
    end
    local d = SexyLootDB.dock[key]
    if not d then
        -- Position merken, um sie beim Abdocken zurückzugeben
        local left, bottom = ns.frames[key]:GetLeft(), ns.frames[key]:GetBottom()
        d = { x = left, y = bottom, side = pendingSide[key] or "BOTTOM", align = pendingAlign[key] }
        SexyLootDB.dock[key] = d
    end
    d.target = target
    Place(key, d)
end

function Dock:SetSide(key, side)
    local d = SexyLootDB.dock[key]
    if d and d.target then
        d.side = side
        Place(key, d)
    else
        pendingSide[key] = side
    end
end

-- Nach SEM:Register aufrufen: Ziehen im Edit Mode löst die Verbindung
function Dock:Hook(key)
    local sel = ns.frames[key].Selection
    if not sel then return end
    sel:HookScript("OnDragStart", function() dragging[key] = true end)
    sel:HookScript("OnDragStop", function()
        dragging[key] = nil
        if SexyLootDB.dock[key] then
            SexyLootDB.dock[key] = nil
            Say(T("%s abgedockt (verschoben)", Name(key)))
        end
    end)
end

function Dock:Init()
    SexyLootDB.dock = SexyLootDB.dock or {}
    -- Ziele, die es nicht mehr gibt, verwerfen
    for key, d in pairs(SexyLootDB.dock) do
        if not (ns.frames[key] and d.target and ns.frames[d.target]) then SexyLootDB.dock[key] = nil end
    end
    local driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", OnUpdate)
end
