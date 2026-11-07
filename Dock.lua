local ADDON, ns = ...
local T = ns.T

-- Andocken: Ein Fenster hängt mit festem Abstand an einer Seite eines anderen
-- (unten, oben, links, rechts) und wandert mit, wenn dieses verschoben wird oder
-- seine Größe ändert. Gewählt wird im Edit Mode per Button (Auswahllisten sind auf
-- diesem Client blockiert); Zustand: SexyLootDB.dock[key] = { target, side }.
-- Wer ein angedocktes Fenster im Edit Mode selbst zieht, löst es damit ab.
--
-- Edit Mode Expanded setzt Positionen bei Layoutwechsel, Größenänderung und
-- Zurücksetzen. Darum prüft ein Treiber jedes Bild, ob der Ankerpunkt noch stimmt,
-- und setzt ihn bei Bedarf neu.

local Dock = {}
ns.Dock = Dock
table.insert(ns.modules, Dock)

local GAP = 6
local ORDER = { "roll", "freeroll", "winner", "loot", "feed", "mine", "toast", "wallet" }
local SIDES = { "BOTTOM", "TOP", "LEFT", "RIGHT" }
-- Ankerpunkt am angedockten Fenster, am Ziel, Abstand
local GEOM = {
    BOTTOM = { "TOPLEFT", "BOTTOMLEFT", 0, -GAP },
    TOP    = { "BOTTOMLEFT", "TOPLEFT", 0, GAP },
    LEFT   = { "TOPRIGHT", "TOPLEFT", -GAP, 0 },
    RIGHT  = { "TOPLEFT", "TOPRIGHT", GAP, 0 },
}

local function Name(key)
    local names = {
        roll = T["Rollfenster"], freeroll = T["Freie Würfe"], winner = T["Gewinner-Anzeige"],
        loot = T["Beutefenster"], feed = T["Gruppen-Feed"], mine = T["Meine Beute"],
        toast = T["Loot-Einblendung"], wallet = T["Geld"],
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
    local g = GEOM[d.side or "BOTTOM"]
    f:ClearAllPoints()
    f:SetPoint(g[1], t, g[2], g[3], g[4])
end

-- Steht das Fenster schon richtig? (sonst jedes Bild neu setzen)
local function InPlace(key, d)
    local f, t = ns.frames[key], ns.frames[d.target]
    if f:GetNumPoints() ~= 1 then return false end
    local point, rel, relPoint, x, y = f:GetPoint(1)
    local g = GEOM[d.side or "BOTTOM"]
    return point == g[1] and rel == t and relPoint == g[2]
        and math.abs((x or 0) - g[3]) < 0.01 and math.abs((y or 0) - g[4]) < 0.01
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

-- Schaltet durch: Aus, dann jedes andere Fenster, das keinen Ring bildet
function Dock:NextTarget(key)
    local d = SexyLootDB.dock[key]
    local current = d and d.target
    local list = {}
    for _, k in ipairs(ORDER) do
        if k ~= key and not Leads(k, key) then list[#list + 1] = k end
    end
    local idx = 0
    for i, k in ipairs(list) do if k == current then idx = i end end
    local nextKey = list[idx + 1]
    if not nextKey then
        Release(key)
        Say(T("%s: nicht angedockt", Name(key)))
        return
    end
    if not d then
        -- Position merken, um sie beim Abdocken zurückzugeben
        local left, bottom = ns.frames[key]:GetLeft(), ns.frames[key]:GetBottom()
        d = { x = left, y = bottom, side = "BOTTOM" }
        SexyLootDB.dock[key] = d
    end
    d.target = nextKey
    Place(key, d)
    Say(T("%s dockt an %s an (%s)", Name(key), Name(nextKey), SideName(d.side)))
end

function Dock:NextSide(key)
    local d = SexyLootDB.dock[key]
    if not (d and d.target) then
        Say(T("%s ist nicht angedockt. Erst ein Ziel wählen.", Name(key)))
        return
    end
    local idx = 1
    for i, s in ipairs(SIDES) do if s == d.side then idx = i end end
    d.side = SIDES[idx % #SIDES + 1]
    Place(key, d)
    Say(T("%s dockt an %s an (%s)", Name(key), Name(d.target), SideName(d.side)))
end

-- Nach lib:RegisterFrame aufrufen: Ziehen im Edit Mode löst die Verbindung
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
