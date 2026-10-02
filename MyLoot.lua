local ADDON, ns = ...
local T = ns.T

-- Kleine Liste der zuletzt gelooteten Items (beim Leveln: Stoff, Erz, graue Items ...)
-- mit Stapeln und Verkaufswert (pro Eintrag und gesamt).

local MyLoot = {}
ns.MyLoot = MyLoot
table.insert(ns.modules, MyLoot)

local WIDTH = 280
local MAXROWS = 10
local entries, rows = {}, {}
local panel, title, total, empty

function MyLoot:Add(link, count)
    count = count or 1
    local id = ns.ItemID(link)
    local cfg = ns.cfg.mine
    local e
    if not cfg.noStack then
        for _, x in ipairs(entries) do
            if x.id == id and not x.preview then e = x break end
        end
    end
    if e then
        e.count = e.count + count
        e.time = GetTime()
        e.link = link
        for i, x in ipairs(entries) do
            if x == e then table.remove(entries, i) break end
        end
        table.insert(entries, 1, e)
    else
        table.insert(entries, 1, { id = id, link = link, count = count, time = GetTime() })
    end
    while #entries > 30 do table.remove(entries) end
    self:Refresh()
end

function MyLoot:Clear()
    wipe(entries)
    self:Refresh()
end

function MyLoot:Test()
    local function L(id, name, color)
        return select(2, ns.GetItemInfo(id)) or ("|cff" .. color .. "|Hitem:" .. id .. "::::::::1:::::|h[" .. name .. "]|h|r")
    end
    self:Add(L(2589, T["Leinenstoff"], "ffffff"), 3)
    self:Add(L(2770, T["Kupfererz"], "ffffff"), 2)
    self:Add(L(2589, T["Leinenstoff"], "ffffff"), 2)
    self:Add(L(118, T["Schwacher Heiltrank"], "ffffff"), 1)
end

-- Im Edit Mode stehen Beispieleinträge in der Liste, beim Verlassen verschwinden sie
function MyLoot:Preview(active)
    for i = #entries, 1, -1 do
        if entries[i].preview then table.remove(entries, i) end
    end
    if active then
        local function L(id, name, color)
            return "|cff" .. color .. "|Hitem:" .. id .. "::::::::1:::::|h[" .. name .. "]|h|r"
        end
        local now = GetTime()
        local sample = {
            { 2589, T["Leinenstoff"], "ffffff", 5, 4, 13 },
            { 2770, T["Kupfererz"], "ffffff", 2, 40, 25 },
            { 118, T["Schwacher Heiltrank"], "ffffff", 1, 95, 40 },
            { 769, T["Zerrissene Wolfshaut"], "9d9d9d", 3, 200, 8 },
        }
        for i = #sample, 1, -1 do
            local s = sample[i]
            table.insert(entries, 1, { id = s[1], link = L(s[1], s[2], s[3]), count = s[4], time = now - s[5], price = s[6], preview = true })
        end
    end
    self:Refresh()
end

local function Coins(copper)
    return GetCoinTextureString and GetCoinTextureString(copper) or GetMoneyString(copper)
end

-- Verkaufspreis eines Stücks in Kupfer (Vorschau-Einträge bringen ihren eigenen mit)
local function UnitPrice(e)
    return e.price or select(11, ns.GetItemInfo(e.link)) or 0
end

local function MakeRow(i)
    local b = CreateFrame("Button", nil, panel)
    b:SetSize(WIDTH - 12, 20)
    b:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -(24 + (i - 1) * 20))
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", 0, 0)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.value = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.value:SetPoint("RIGHT", 0, 0)
    b.value:SetWidth(92)
    b.value:SetJustifyH("RIGHT")
    b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.count:SetPoint("RIGHT", b.value, "LEFT", -4, 0)
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.name:SetPoint("LEFT", b.icon, "RIGHT", 5, 0)
    b.name:SetPoint("RIGHT", b.count, "LEFT", -4, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", function(self) if self.link then HandleModifiedItemClick(self.link) end end)
    rows[i] = b
    return b
end

function MyLoot:Refresh()
    if not panel then return end
    local cfg = ns.cfg.mine
    local shown = math.min(cfg.rows, MAXROWS)
    local sum = 0
    for _, e in ipairs(entries) do
        sum = sum + UnitPrice(e) * e.count
    end
    if cfg.hideValue or sum == 0 then
        total:SetText("")
    else
        total:SetText(Coins(sum))
    end
    for i = 1, math.max(#rows, shown) do
        local row = rows[i] or MakeRow(i)
        local e = entries[i]
        if i <= shown and e then
            row.link = e.link
            row.icon:SetTexture(select(5, ns.GetItemInfoInstant(e.link)))
            row.name:SetText(e.link)
            row.count:SetText(e.count > 1 and ("x" .. e.count) or "")
            -- Wert des ganzen Stapels (Stückpreis mal Anzahl)
            local value = UnitPrice(e) * e.count
            row.value:SetText((cfg.hideItemValue or value == 0) and "" or Coins(value))
            row:Show()
        else
            row.link = nil
            row:Hide()
        end
    end
    empty:SetShown(#entries == 0)
    local n = math.max(1, math.min(shown, #entries))
    local height = 24 + n * 20 + 6
    panel:SetHeight(height)
    ns.frames.mine:SetHeight(height)
end

ns.Apply.mine = function()
    ns.ApplyStyle(panel, "mine")
    MyLoot:Refresh()
end

function MyLoot:Init()
    panel = ns.Panel(ns.frames.mine)
    panel:SetPoint("TOPLEFT", ns.frames.mine, "TOPLEFT")
    panel:SetPoint("TOPRIGHT", ns.frames.mine, "TOPRIGHT")

    title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 8, -7)
    title:SetText(T["Zuletzt gelootet"])
    total = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    total:SetPoint("TOPRIGHT", -8, -8)
    empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    empty:SetPoint("TOPLEFT", 8, -28)
    empty:SetText(T["Noch nichts gelootet."])

    C_Timer.NewTicker(5, function() MyLoot:Refresh() end)
end
