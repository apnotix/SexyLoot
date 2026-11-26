local ADDON, ns = ...
local T = ns.T

-- Kleiner Rahmen: aktuelles Geld und Verkaufswert aller Items in den Taschen.

local Wallet = {}
ns.Wallet = Wallet
table.insert(ns.modules, Wallet)

local panel, moneyText, sellText, sellLabel, moneyLabel
local pending = false

local function Coins(copper)
    return GetCoinTextureString and GetCoinTextureString(copper) or GetMoneyString(copper)
end

local function NumSlots(bag)
    local f = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    return f and f(bag) or 0
end

-- Liefert Link und Stapelgröße; die Rückgabe von GetContainerItemInfo ist je nach Client Tabelle oder Liste
local function SlotItem(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then return info.hyperlink, info.stackCount or 1 end
        return
    end
    local _, count, _, _, _, _, link = GetContainerItemInfo(bag, slot)
    return link, count or 1
end

local function BagValue()
    local sum = 0
    local last = (NUM_BAG_SLOTS or 4) + (NUM_REAGENTBAG_SLOTS or 0)
    for bag = 0, last do
        for slot = 1, NumSlots(bag) do
            local link, count = SlotItem(bag, slot)
            if link then
                sum = sum + ns.ItemPrice(link, select(11, ns.GetItemInfo(link))) * count
            end
        end
    end
    return sum
end

-- Geld aller Charaktere liegt account-weit in SexyLootDB.chars[GUID]. Name und Realm
-- taugen nicht als Schlüssel: Auf diesem Client können zwei Charaktere gleich heißen
-- und denselben GetRealmName() haben.
local function PlayerRealm()
    local _, realm = UnitFullName("player")
    if not realm or realm == "" then realm = GetNormalizedRealmName and GetNormalizedRealmName() end
    if not realm or realm == "" then realm = GetRealmName() end
    return realm
end

-- Eigener Tooltip mit kleinerer Schrift: die Zeilen von GameTooltip zu ändern würde alle anderen Tooltips treffen
local TIP_SIZE = 11
local tip
local function Tip()
    if not tip then tip = CreateFrame("GameTooltip", "SexyLootWalletTip", UIParent, "GameTooltipTemplate") end
    return tip
end

-- Gewinn pro Tag (account-weit): beim ersten Berechnen eines Tages wird die Gesamtsumme aller Charaktere als Ausgangswert in
-- SexyLootDB.moneyDays[Datum] gemerkt. Heute = Summe jetzt - Ausgangswert von heute; gestern = Ausgangswert von heute - der von gestern
-- (gibt es den nicht, entfällt die Zeile). Geld, das zwischen Charakteren wandert, hebt sich auf. Es werden die letzten 8 Tage behalten.
local function DayKey(offset) return date("%Y-%m-%d", time() - (offset or 0) * 86400) end

local function TotalMoney()
    local total = 0
    for _, c in pairs(SexyLootDB.chars) do total = total + (c.money or 0) end
    return total
end

local function NoteDay(total)
    local days = SexyLootDB.moneyDays
    local key = DayKey()
    if days[key] == nil then
        days[key] = total
        local keys = {}
        for k in pairs(days) do keys[#keys + 1] = k end
        table.sort(keys)
        for i = 1, #keys - 8 do days[keys[i]] = nil end
    end
end

-- Betrag mit Vorzeichen und Farbe (grün Plus, rot Minus)
local function Signed(copper)
    if copper == 0 then return "|cff9a9080" .. Coins(0) .. "|r" end
    local sign, color = copper > 0 and "+" or "-", copper > 0 and "|cff7ee08f" or "|cffff9a8f"
    return color .. sign .. "|r " .. Coins(math.abs(copper))
end

local function ShowTooltip(self)
    local list, total = {}, 0
    local names = {}
    for guid, c in pairs(SexyLootDB.chars) do
        list[#list + 1] = { guid = guid, name = c.name or "?", realm = c.realm, money = c.money or 0, class = c.class }
        total = total + (c.money or 0)
        names[c.name or "?"] = (names[c.name or "?"] or 0) + 1
    end
    table.sort(list, function(a, b)
        if a.money ~= b.money then return a.money > b.money end
        return a.guid < b.guid
    end)
    local tip = Tip()
    tip:SetOwner(self, "ANCHOR_LEFT")
    tip:ClearLines()
    tip:AddLine(T["Charaktere"], 1, 0.82, 0)
    local realm = PlayerRealm()
    for _, c in ipairs(list) do
        local name, r = c.name, c.realm
        local col = c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
        if col then name = ("|cff%02x%02x%02x%s|r"):format(col.r * 255, col.g * 255, col.b * 255, name) end
        -- Realm nur zeigen, wenn er sich unterscheidet oder der Name doppelt vorkommt
        if r and (r ~= realm or names[c.name] > 1) then name = name .. " |cff999999(" .. r .. ")|r" end
        tip:AddDoubleLine(name, Coins(c.money), 1, 1, 1, 1, 1, 1)
    end
    tip:AddLine(" ")
    tip:AddDoubleLine(T["Gesamtsumme"], Coins(total), 1, 0.82, 0, 1, 1, 1)
    local days = SexyLootDB.moneyDays
    NoteDay(total)
    tip:AddLine(" ")
    tip:AddDoubleLine(T["Gewinn heute"], Signed(total - days[DayKey()]), 0.7, 0.7, 0.7, 1, 1, 1)
    if days[DayKey(1)] then
        tip:AddDoubleLine(T["Gewinn gestern"], Signed(days[DayKey()] - days[DayKey(1)]), 0.7, 0.7, 0.7, 1, 1, 1)
    end
    for i = 1, tip:NumLines() do
        for _, side in ipairs({ "Left", "Right" }) do
            local fs = _G["SexyLootWalletTipText" .. side .. i]
            if fs then
                local path, _, flags = fs:GetFont()
                if path then fs:SetFont(path, TIP_SIZE, flags) end
            end
        end
    end
    tip:Show()
end

function Wallet:ResetChars()
    wipe(SexyLootDB.chars)
    wipe(SexyLootDB.moneyDays)
    self:Refresh()
end

function Wallet:Refresh()
    if not panel then return end
    local money = GetMoney() or 0
    local _, class = UnitClass("player")
    local guid = UnitGUID("player")
    if guid then
        SexyLootDB.chars[guid] = { name = UnitName("player"), realm = PlayerRealm(), money = money, class = class }
    end
    NoteDay(TotalMoney())
    moneyText:SetText(Coins(money))
    sellText:SetText(Coins(BagValue()))
end

-- Ereignisse kommen gehäuft; einmal kurz warten und dann neu rechnen
local function Queue()
    if pending then return end
    pending = true
    C_Timer.After(0.2, function()
        pending = false
        Wallet:Refresh()
    end)
end

ns.Apply.wallet = function()
    ns.ApplyStyle(panel, "wallet")
    local cfg = ns.cfg.wallet
    local show = cfg.showSell ~= false
    sellLabel:SetShown(show and cfg.showLabels ~= false)
    moneyLabel:SetShown(cfg.showLabels ~= false)
    sellText:SetShown(show)
    ns.frames.wallet:SetSize(cfg.width or 200, show and 44 or 28)
    if (cfg.fontSize or 0) > 0 then
        moneyText:SetFont(ns.FONT_TEXT, cfg.fontSize, "")
        sellText:SetFont(ns.FONT_TEXT, cfg.fontSize, "")
    end
    Wallet:Refresh()
end

function Wallet:Init()
    panel = ns.FramedPanel(ns.frames.wallet)
    ns.Panels = ns.Panels or {}
    ns.Panels.wallet = panel   -- für die Vorschau im Einstellungsfenster (Live.lua)
    panel:SetAllPoints(ns.frames.wallet)
    SexyLootDB.chars = SexyLootDB.chars or {}
    SexyLootDB.moneyDays = SexyLootDB.moneyDays or {}
    -- Einträge der ersten Version (Schlüssel "Name-Realm", ohne Namensfeld) verwerfen
    for key, c in pairs(SexyLootDB.chars) do
        if not c.name then SexyLootDB.chars[key] = nil end
    end
    panel:EnableMouse(true)
    panel:SetScript("OnEnter", ShowTooltip)
    panel:SetScript("OnLeave", function() if tip then tip:Hide() end end)

    local l1 = panel:CreateFontString(nil, "OVERLAY", "SexyLootDim")
    l1:SetPoint("TOPLEFT", 10, -7)
    l1:SetText(T["Geld"])
    moneyLabel = l1
    local l2 = panel:CreateFontString(nil, "OVERLAY", "SexyLootDim")
    l2:SetPoint("TOPLEFT", 10, -23)
    l2:SetText(T["Verkaufswert"])
    sellLabel = l2

    moneyText = panel:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    moneyText:SetPoint("TOPRIGHT", -10, -7)
    moneyText:SetJustifyH("RIGHT")
    sellText = panel:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    sellText:SetPoint("TOPRIGHT", -10, -23)
    sellText:SetJustifyH("RIGHT")
    sellText:SetTextColor(0.53, 0.8, 1)   -- Verkaufswert in Informationsblau, wie die Etiketten

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_MONEY")
    ev:RegisterEvent("BAG_UPDATE_DELAYED")
    ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")   -- Preise noch nicht gecachter Items
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", Queue)
end
