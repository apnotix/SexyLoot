local ADDON, ns = ...
local T = ns.T

-- Einblendung für gerade gelootete Items: Symbol, Name, Anzahl und Verkaufswert,
-- jede Zeile blendet nach einer einstellbaren Zeit aus. Gleiche Items innerhalb
-- der Anzeigedauer werden zusammengezählt.

local Toast = {}
ns.Toast = Toast
table.insert(ns.modules, Toast)

local WIDTH, ROWH, GAP, FADE = 300, 40, 2, 0.6
local entries, rows = {}, {}
local driver

local function Coins(copper)
    return GetCoinTextureString and GetCoinTextureString(copper) or GetMoneyString(copper)
end

function Toast:Add(link, count)
    if not link then return end
    count = count or 1
    local id = ns.ItemID(link)
    local hold = ns.cfg.toast.hold
    local e
    for _, x in ipairs(entries) do
        if x.id == id and not x.preview then e = x break end
    end
    if e then
        e.count = e.count + count
        e.link = link
        e.expire = GetTime() + hold
        for i, x in ipairs(entries) do
            if x == e then table.remove(entries, i) break end
        end
        table.insert(entries, 1, e)
    else
        table.insert(entries, 1, { id = id, link = link, count = count, expire = GetTime() + hold })
    end
    while #entries > 20 do table.remove(entries) end
    self:Layout()
end

local function MakeRow(i)
    local r = CreateFrame("Frame", nil, ns.frames.toast)
    r:SetSize(WIDTH, ROWH)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(0, 0, 0, 0.55)
    r.bar = r:CreateTexture(nil, "BORDER")
    r.bar:SetPoint("TOPLEFT")
    r.bar:SetPoint("BOTTOMLEFT")
    r.bar:SetWidth(3)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ROWH - 6, ROWH - 6)
    r.icon:SetPoint("LEFT", 6, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.value = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.value:SetPoint("RIGHT", -8, 0)
    r.value:SetWidth(80)
    r.value:SetJustifyH("RIGHT")
    r.count = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.count:SetPoint("RIGHT", r.value, "LEFT", -4, 0)
    r.count:SetJustifyH("RIGHT")
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
    r.name:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    -- Mouseover: Tooltip, und die Zeile bleibt eingeblendet (siehe OnUpdate)
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
        if not self.e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.e.link)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", GameTooltip_Hide)
    r:SetScript("OnMouseUp", function(self)
        if self.e then HandleModifiedItemClick(self.e.link) end
    end)
    rows[i] = r
    return r
end

-- Zeilen neu aufbauen (neue Items, Ablauf, Einstellungen)
function Toast:Layout()
    if not driver then return end
    local cfg = ns.cfg.toast
    local n = 0
    for _, e in ipairs(entries) do
        if n >= cfg.rows then break end
        n = n + 1
        local r = rows[n] or MakeRow(n)
        r.e = e
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", ns.frames.toast, "TOPLEFT", 0, -(n - 1) * (ROWH + GAP))
        local name, _, quality, _, _, _, _, _, _, _, price = ns.GetItemInfo(e.link)
        name = name or e.link:match("%[(.-)%]") or "?"
        local cr, cg, cb = ns.QualityColor(quality)
        r.bar:SetColorTexture(cr, cg, cb, 1)
        r.icon:SetTexture(select(5, ns.GetItemInfoInstant(e.link)))
        r.name:SetText(name)
        r.name:SetTextColor(cr, cg, cb)
        r.count:SetText(e.count > 1 and e.count or "")
        local value = (e.price or price or 0) * e.count
        r.value:SetText((cfg.hideValue or value == 0) and "" or Coins(value))
        r:Show()
    end
    for i = n + 1, #rows do
        rows[i].e = nil
        rows[i]:Hide()
    end
end

-- Blendet aus und entfernt Abgelaufenes
local function OnUpdate()
    local now, removed = GetTime(), false
    -- Unter der Maus bleibt die Zeile voll sichtbar; nach dem Verlassen läuft sie kurz aus
    for _, r in ipairs(rows) do
        if r.e and r:IsShown() and r:IsMouseOver() and r.e.expire < now + FADE + 1 then
            r.e.expire = now + FADE + 1
        end
    end
    for i = #entries, 1, -1 do
        if entries[i].expire <= now then
            table.remove(entries, i)
            removed = true
        end
    end
    if removed then Toast:Layout() end
    for _, r in ipairs(rows) do
        if r.e then r:SetAlpha(math.min(1, (r.e.expire - now) / FADE)) end
    end
end

function Toast:Preview(active)
    for i = #entries, 1, -1 do
        if entries[i].preview then table.remove(entries, i) end
    end
    if active then
        local function L(id, name) return "|cffffffff|Hitem:" .. id .. "::::::::1:::::|h[" .. name .. "]|h|r" end
        local sample = {
            { 118, T["Schwacher Heiltrank"], 1, 40 },
            { 2770, T["Kupfererz"], 2, 25 },
            { 2589, T["Leinenstoff"], 13, 13 },
        }
        for _, s in ipairs(sample) do
            table.insert(entries, 1, { id = s[1], link = L(s[1], s[2]), count = s[3], price = s[4],
                expire = math.huge, preview = true })
        end
    end
    self:Layout()
end

function Toast:Test()
    local function L(id, name)
        return select(2, ns.GetItemInfo(id)) or ("|cffffffff|Hitem:" .. id .. "::::::::1:::::|h[" .. name .. "]|h|r")
    end
    self:Add(L(2589, T["Leinenstoff"]), 3)
    self:Add(L(2770, T["Kupfererz"]), 2)
    self:Add(L(118, T["Schwacher Heiltrank"]), 1)
end

ns.Apply.toast = function()
    ns.frames.toast:SetHeight(ns.cfg.toast.rows * (ROWH + GAP))
    Toast:Layout()
end

function Toast:Init()
    driver = CreateFrame("Frame", nil, ns.frames.toast)
    driver:SetScript("OnUpdate", OnUpdate)
    -- Preise noch nicht gecachter Items nachtragen
    C_Timer.NewTicker(1, function() Toast:Layout() end)
end
