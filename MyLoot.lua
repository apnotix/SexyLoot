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
local FOOT = 24   -- Fußleiste mit dem Gesamtwert
local panel, total, empty, hover, footer, footerLabel
local log = {}   -- alles, was in dieser Sitzung gelootet wurde: { link, count }
local sessionStart = GetTime()   -- Beginn der Sitzung: Login oder letztes Leeren der Liste

function MyLoot:Add(link, count)
    count = count or 1
    log[#log + 1] = { link = link, count = count }
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
    wipe(log)
    sessionStart = GetTime()
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
            { 5, T["Questgegenstand"], "ffffff", 1, 300, 0, true },
        }
        for i = #sample, 1, -1 do
            local s = sample[i]
            table.insert(entries, 1, { id = s[1], link = L(s[1], s[2], s[3]), count = s[4], time = now - s[5], price = s[6], quest = s[7], preview = true })
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

-- Questitem: Klasse "Quest" oder Bindungsart "Quest" (bindType 4)
local function IsQuest(e)
    if e.quest then return true end
    local _, _, _, _, _, _, _, _, _, _, _, classID, _, bindType = ns.GetItemInfo(e.link)
    return classID == (Enum and Enum.ItemClass and Enum.ItemClass.Questitem or 12) or bindType == 4
end

local function MakeRow(i)
    local b = CreateFrame("Button", nil, panel)
    b:SetSize(WIDTH - 16, 20)
    b:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -(ns.HEAD + 2 + (i - 1) * 20))
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", 0, 0)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    -- Questitem: gelbes Ausrufezeichen an der Ecke des Symbols
    b.quest = b:CreateTexture(nil, "OVERLAY")
    b.quest:SetTexture("Interface/GossipFrame/AvailableQuestIcon")
    b.quest:SetSize(14, 14)
    b.quest:SetPoint("CENTER", b.icon, "TOPLEFT", 1, -1)
    b.quest:Hide()
    b.value = b:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    b.value:SetPoint("RIGHT", 0, 0)
    b.value:SetWidth(92)
    b.value:SetJustifyH("RIGHT")
    b.count = b:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    b.count:SetPoint("RIGHT", b.value, "LEFT", -4, 0)
    b.name = b:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
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

-- Dauer der Sitzung als H:MM:SS bzw. M:SS
local function UpdateTimer()
    if not panel then return end
    if ns.cfg.mine.hideTime then
        panel:SetBadge("")
        return
    end
    local s = math.floor(GetTime() - sessionStart)
    local h, m = math.floor(s / 3600), math.floor(s / 60) % 60
    panel:SetBadge(h > 0 and ("%d:%02d:%02d"):format(h, m, s % 60) or ("%d:%02d"):format(m, s % 60))
end

-- Tooltip über dem Gesamtwert: Beute der Sitzung, ihr Wert und die Werte pro Stunde
local function ShowTooltip()
    local seconds = GetTime() - sessionStart
    local items, value = 0, 0
    local best, bestPrice = nil, 0   -- teuerstes einzelnes Item (Stückpreis)
    for _, x in ipairs(log) do
        local price = select(11, ns.GetItemInfo(x.link)) or 0
        items = items + x.count
        value = value + price * x.count
        if price > bestPrice then best, bestPrice = x.link, price end
    end
    GameTooltip:SetOwner(hover, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:AddLine(T["Sitzung"], 1, 0.82, 0)
    local s = math.floor(seconds)
    GameTooltip:AddDoubleLine(T["Dauer"], ("%d:%02d:%02d"):format(math.floor(s / 3600), math.floor(s / 60) % 60, s % 60), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(T["Gelootete Items"], items, 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(T["Wert gesamt"], Coins(value), 1, 1, 1, 1, 1, 1)
    if best then GameTooltip:AddDoubleLine(T["Teuerstes Item"], best .. " " .. Coins(bestPrice), 1, 1, 1, 1, 1, 1) end
    -- Hochrechnung erst nach einer halben Minute, davor schwanken die Werte zu stark
    if seconds >= 30 then
        local perHour = 3600 / seconds
        GameTooltip:AddDoubleLine(T["Wert pro Stunde"], Coins(math.floor(value * perHour)), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(T["Items pro Stunde"], math.floor(items * perHour + 0.5), 1, 1, 1, 1, 1, 1)
    else
        GameTooltip:AddLine(T["Pro Stunde: erst nach 30 Sekunden"], 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

function MyLoot:Refresh()
    UpdateTimer()
    if not panel then return end
    local cfg = ns.cfg.mine
    local shown = math.min(cfg.rows, MAXROWS)
    local sum = 0
    for _, e in ipairs(entries) do
        sum = sum + UnitPrice(e) * e.count
    end
    local showTotal = not (cfg.hideValue or sum == 0)
    total:SetText(showTotal and Coins(sum) or "")
    footer:SetShown(showTotal)
    footerLabel:SetShown(showTotal)
    for i = 1, math.max(#rows, shown) do
        local row = rows[i] or MakeRow(i)
        local e = entries[i]
        if i <= shown and e then
            row.link = e.link
            row.icon:SetTexture(select(5, ns.GetItemInfoInstant(e.link)))
            row.quest:SetShown(IsQuest(e))
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
    panel:SetHeight(ns.HEAD + 4 + n * 20 + (showTotal and FOOT or 0))
    -- Der Anker behält die Höhe für alle Zeilen samt Fußleiste, das Fenster hängt oben
    -- (nach unten wachsen) oder steht unten (nach oben wachsen).
    ns.frames.mine:SetHeight(ns.HEAD + 4 + math.max(1, shown) * 20 + FOOT)
end

local function Place()
    local down = ns.cfg.mine.growDown
    local a = down and "TOP" or "BOTTOM"
    panel:ClearAllPoints()
    panel:SetPoint(a .. "LEFT", ns.frames.mine, a .. "LEFT")
    panel:SetPoint(a .. "RIGHT", ns.frames.mine, a .. "RIGHT")
end

ns.Apply.mine = function()
    Place()
    ns.ApplyStyle(panel, "mine")
    MyLoot:Refresh()
end

function MyLoot:Init()
    panel = ns.FramedPanel(ns.frames.mine, T["Zuletzt gelootet"])
    Place()

    -- Fußleiste: Gesamtwert aller Einträge
    footer = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    footer:SetPoint("BOTTOMLEFT", 2, 2)
    footer:SetPoint("BOTTOMRIGHT", -2, 2)
    footer:SetHeight(FOOT - 2)
    footer:SetColorTexture(0.15, 0.12, 0.07, 0.96)
    footerLabel = panel:CreateFontString(nil, "OVERLAY", "SexyLootDim")
    footerLabel:SetPoint("LEFT", footer, "LEFT", 8, 0)
    footerLabel:SetText(T["Wert gesamt"])
    total = panel:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    total:SetPoint("RIGHT", footer, "RIGHT", -8, 0)
    -- Über dem Titelband erscheint der Sitzungs-Tooltip
    hover = CreateFrame("Frame", nil, panel)
    hover:SetPoint("TOPLEFT", panel, "TOPLEFT")
    hover:SetPoint("TOPRIGHT", panel, "TOPRIGHT")
    hover:SetHeight(ns.HEAD)
    hover:SetScript("OnEnter", ShowTooltip)
    hover:SetScript("OnLeave", GameTooltip_Hide)
    empty = panel:CreateFontString(nil, "OVERLAY", "SexyLootDim")
    empty:SetPoint("TOPLEFT", 10, -(ns.HEAD + 6))
    empty:SetText(T["Noch nichts gelootet."])

    C_Timer.NewTicker(5, function() MyLoot:Refresh() end)
    C_Timer.NewTicker(1, function()
        UpdateTimer()
        if hover:IsMouseOver() and GameTooltip:GetOwner() == hover then ShowTooltip() end   -- Tooltip läuft mit
    end)
end
