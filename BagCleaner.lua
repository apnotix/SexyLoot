local ADDON, ns = ...
local T = ns.T

-- Taschen aufräumen: Ist das Inventar fast voll, erscheint ein Hinweis. Darüber (oder mit /sl bags)
-- öffnet sich ein Dialog mit den günstigsten Items, die sich einzeln wegwerfen lassen.
-- Preise: Auktionspreis eines Preis-Addons oder Händlerpreis (ns.ItemPrice, Option "Preisquelle").

local Bags = {}
ns.Bags = Bags
table.insert(ns.modules, Bags)

local banner, dialog
local dismissed = false          -- Hinweis weggeklickt, gilt bis wieder Platz da ist
local previewing = false         -- Edit Mode: Beispielhinweis
local freeSlots, totalSlots = 0, 0
local rows = {}
local ScrollBy
local armed                      -- Zeile, deren Knopf auf die Bestätigung wartet
local ROW_H, DIALOG_W = 36, 460
local INFO_H, FOOT_H = 34, 30

local function Coins(copper)
    return GetCoinTextureString and GetCoinTextureString(copper, 11) or GetMoneyString(copper)
end

local function NumSlots(bag)
    local f = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    return f and f(bag) or 0
end

local function FreeSlots(bag)
    local f = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
    if not f then return 0, nil end
    return f(bag)
end

-- Link, Stapelgröße, Qualität, gesperrt (die Rückgabe ist je nach Client Tabelle oder Liste)
local function SlotInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then return info.hyperlink, info.stackCount or 1, info.quality, info.isLocked end
        return
    end
    local _, count, locked, quality, _, _, link = GetContainerItemInfo(bag, slot)
    return link, count or 1, quality, locked
end

local function LastBag()
    return (NUM_BAG_SLOTS or 4) + (NUM_REAGENTBAG_SLOTS or 0)
end

-- Für andere Module (Entzauber-Fenster)
ns.BagAPI = { NumSlots = NumSlots, SlotInfo = SlotInfo, LastBag = LastBag }

-- Freie Plätze der normalen Taschen (Spezialtaschen und Reagenzientasche zählen nicht)
local function CountSlots()
    local free, total = 0, 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local n = NumSlots(bag)
        if n > 0 then
            local f, family = FreeSlots(bag)
            if not family or family == 0 then
                free, total = free + (f or 0), total + n
            end
        end
    end
    return free, total
end

---------------------------------------------------------------------------
-- Hinweis
---------------------------------------------------------------------------

local function UpdateBanner()
    if not banner then return end
    local cfg = ns.cfg.bags
    if freeSlots > cfg.threshold then dismissed = false end
    local show = previewing or (not cfg.disabled and not dismissed and totalSlots > 0 and freeSlots <= cfg.threshold)
    banner:SetShown(show)
    if show then
        local n = previewing and 3 or freeSlots
        banner.pill:Set(n == 0 and "lack" or "warn", T("%d frei", n), nil, 16)
    end
end

local function Recount()
    freeSlots, totalSlots = CountSlots()
    UpdateBanner()
end

local function CreateBanner()
    local b = ns.FramedPanel(ns.frames.bags)
    b:SetAllPoints(ns.frames.bags)
    b:Hide()

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(28, 28)
    b.icon:SetPoint("LEFT", 12, 0)
    b.icon:SetTexture("Interface/Icons/INV_Misc_Bag_08")
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    b.text = b:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    b.text:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 8, 1)
    b.text:SetText(T["Inventar fast voll"])

    b.pill = ns.Pill(b)
    b.pill.tex:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 8, 0)

    b.open = ns.Button(b)
    b.open:SetSize(84, 22)
    b.open:SetPoint("RIGHT", -32, 0)
    b.open.text:SetText(T["Aufräumen"])
    b.open:SetScript("OnClick", function() Bags:Open() end)

    -- Schließen-Kreuz wie in den anderen Dialogen: blendet den Hinweis aus, bis wieder Platz da ist
    b.close = CreateFrame("Button", nil, b, "UIPanelCloseButton")
    b.close:SetSize(24, 24)
    b.close:SetPoint("TOPRIGHT", 1, 1)
    b.close:SetFrameLevel(b:GetFrameLevel() + 10)
    b.close:SetScript("OnClick", function()
        dismissed = true
        UpdateBanner()
    end)
    banner = b
end

---------------------------------------------------------------------------
-- Dialog
---------------------------------------------------------------------------

-- Sucht die günstigsten Items. Items, deren Daten noch nicht geladen sind, werden übersprungen
-- (ihr Preis wäre sonst 0 und sie stünden fälschlich ganz oben); GET_ITEM_INFO_RECEIVED lädt neu.
local function Scan()
    local cfg = ns.cfg.bags
    local list = {}
    for bag = 0, LastBag() do
        for slot = 1, NumSlots(bag) do
            local link, count, quality, locked = SlotInfo(bag, slot)
            if link and not locked then
                local name, _, q, _, _, _, _, _, _, icon, vendor, classID, _, bindType = ns.GetItemInfo(link)
                if name then
                    q = q or quality or 1
                    local isQuest = classID == (Enum and Enum.ItemClass and Enum.ItemClass.Questitem or 12) or bindType == 4
                    -- Berufs-Items: Handwerksmaterial, Rezepte, Reagenzien
                    local IC = Enum and Enum.ItemClass
                    local isProfession = classID == (IC and IC.Tradegoods or 7) or classID == (IC and IC.Recipe or 9)
                        or classID == (IC and IC.Reagent or 5)
                    local qualityOk = cfg.onlyJunk and q == 0 or (not cfg.onlyJunk and q <= cfg.maxQuality)
                    if qualityOk and not isQuest and not (cfg.ignoreProf and isProfession) then
                        local unit, auction = ns.ItemPrice(link, vendor or 0)
                        unit = unit or 0
                        if unit > 0 or cfg.showNoValue then
                            list[#list + 1] = { bag = bag, slot = slot, link = link, name = name, count = count or 1,
                                quality = q, icon = icon, unit = unit, value = unit * (count or 1), auction = auction,
                                vendorValue = (vendor or 0) * (count or 1) }
                        end
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.value ~= b.value then return a.value < b.value end
        if a.quality ~= b.quality then return a.quality < b.quality end
        return a.name < b.name
    end)
    return list
end

local function Disarm()
    if armed then
        armed.btn.text:SetText(T["Wegwerfen"])
        armed.btn.bg:SetColorTexture(ns.BTN[1], ns.BTN[2], ns.BTN[3], 1)
        armed = nil
    end
end

local function Destroy(item)
    if InCombatLockdown() then
        print("|cffe8c26aSexyLoot|r: " .. T["Im Kampf nicht möglich."])
        return
    end
    -- Es muss noch derselbe Gegenstand im Fach liegen, sonst nichts löschen
    local link = SlotInfo(item.bag, item.slot)
    if link ~= item.link then
        Bags:Refresh()
        return
    end
    local pickup = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
    ClearCursor()
    pickup(item.bag, item.slot)
    if CursorHasItem and CursorHasItem() then
        DeleteCursorItem()
        print("|cffe8c26aSexyLoot|r: " .. T("Weggeworfen: %s", item.link))
    end
    ClearCursor()
end

local function GetRow(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Frame", nil, dialog.content)
    r:SetHeight(ROW_H)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(26, 26)
    r.icon:SetPoint("LEFT", 8, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.border = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.border:SetPoint("TOPLEFT", r.icon, "TOPLEFT", -1, 1)
    r.border:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 1, -1)

    r.btn = ns.Button(r)
    r.btn:SetSize(76, 22)
    r.btn:SetPoint("RIGHT", -8, 0)
    r.btn.text:SetText(T["Wegwerfen"])
    r.btn:SetScript("OnClick", function()
        if not r.item then return end
        if armed == r then
            Disarm()
            Destroy(r.item)
            C_Timer.After(0.3, function() Bags:Refresh() end)
        else
            Disarm()
            armed = r
            r.btn.text:SetText(T["Sicher?"])
            r.btn.bg:SetColorTexture(0.62, 0.17, 0.14, 1)
            C_Timer.After(3, function() if armed == r then Disarm() end end)
        end
    end)

    r.value = r:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    r.value:SetPoint("RIGHT", r.btn, "LEFT", -8, 0)
    r.value:SetWidth(120)
    r.value:SetJustifyH("RIGHT")
    r.value:SetWordWrap(false)
    r.vendorLine = r:CreateFontString(nil, "OVERLAY", "SexyLootDim")
    r.vendorLine:SetPoint("RIGHT", r.btn, "LEFT", -8, -7)
    r.vendorLine:SetWidth(120)
    r.vendorLine:SetJustifyH("RIGHT")
    r.vendorLine:SetWordWrap(false)
    r.vendorLine:Hide()
    r.count = r:CreateFontString(nil, "OVERLAY", "SexyLootText")
    r.count:SetPoint("RIGHT", r.value, "LEFT", -6, 0)
    r.count:SetWidth(36)
    r.count:SetJustifyH("RIGHT")
    r.count:SetTextColor(0.61, 0.57, 0.5)
    r.name = r:CreateFontString(nil, "OVERLAY", "SexyLootText")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
    r.name:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)

    -- Mouseover: Item-Tooltip
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
        if not self.item then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(self.item.bag, self.item.slot)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", GameTooltip_Hide)
    -- Mausrad auch über den Zeilen scrollen lassen
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, delta) ScrollBy(delta) end)
    rows[i] = r
    return r
end

-- Position des Dialogs: frei (gespeichert) oder am Beutefenster angeheftet
local attached = false

local function PlaceDialog(toLoot)
    local d = dialog
    d:ClearAllPoints()
    attached = toLoot and true or false
    if toLoot then
        -- rechts neben dem Beutefenster, bei zu wenig Platz links davon
        local right = ns.frames.loot:GetRight() or 0
        if right + DIALOG_W + 12 > UIParent:GetWidth() then
            d:SetPoint("TOPRIGHT", ns.frames.loot, "TOPLEFT", -8, 0)
        else
            d:SetPoint("TOPLEFT", ns.frames.loot, "TOPRIGHT", 8, 0)
        end
        return
    end
    local pos = SexyLootDB.cleanPos
    if pos and pos.x then
        d:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    else
        d:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    end
end

local function CreateDialog()
    local d = ns.FramedPanel(UIParent, T["Taschen aufräumen"])
    d:SetFrameStrata("DIALOG")
    d:SetWidth(DIALOG_W)
    d:SetClampedToScreen(true)
    d:SetMovable(true)
    d:EnableMouse(true)
    d:RegisterForDrag("LeftButton")
    d:SetScript("OnDragStart", d.StartMoving)
    d:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        attached = false -- selbst verschoben: nicht mehr am Beutefenster
        SexyLootDB.cleanPos = { x = self:GetLeft(), y = self:GetBottom() }
    end)
    ns.ApplyStyle(d, "bags")
    d:Hide()
    d.badgeInset = 32

    dialog = d
    PlaceDialog(false)

    -- Schließen-Kreuz: eigenes Verhalten, statt sich auf HideUIPanel der Vorlage zu verlassen
    local close = CreateFrame("Button", nil, d, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetFrameLevel(d:GetFrameLevel() + 10)
    close:SetScript("OnClick", function() d:Hide() end)
    -- Esc schließt den Dialog ebenfalls
    _G.SexyLootBagCleaner = d
    tinsert(UISpecialFrames, "SexyLootBagCleaner")

    d.info = d:CreateFontString(nil, "OVERLAY", "SexyLootDim")
    d.info:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -(ns.HEAD + 8))
    d.info:SetPoint("RIGHT", d, "RIGHT", -12, 0)
    d.info:SetJustifyH("LEFT")
    d.info:SetText(T["Die günstigsten Items zuerst. Wegwerfen lässt sich nicht rückgängig machen."])

    -- Liste mit Scrollbereich (Mausrad); rechts ein schmaler Schieber
    local inset = ns.INSET + 4
    d.scroll = CreateFrame("ScrollFrame", nil, d)
    d.scroll:SetPoint("TOPLEFT", d, "TOPLEFT", inset, -(ns.HEAD + INFO_H))
    d.scroll:SetPoint("TOPRIGHT", d, "TOPRIGHT", -(inset + 10), -(ns.HEAD + INFO_H))
    d.scroll:SetHeight(2 * ROW_H)
    d.content = CreateFrame("Frame", nil, d.scroll)
    d.content:SetSize(DIALOG_W - 2 * inset - 10, 1)
    d.scroll:SetScrollChild(d.content)
    d.track = d:CreateTexture(nil, "ARTWORK")
    d.track:SetWidth(4)
    d.track:SetPoint("TOPLEFT", d.scroll, "TOPRIGHT", 4, 0)
    d.track:SetPoint("BOTTOMLEFT", d.scroll, "BOTTOMRIGHT", 4, 0)
    d.track:SetColorTexture(0.15, 0.12, 0.07, 1)
    d.thumb = d:CreateTexture(nil, "OVERLAY")
    d.thumb:SetWidth(4)
    d.thumb:SetColorTexture(0.42, 0.34, 0.15, 1)
    d.scroll:EnableMouseWheel(true)
    d.scroll:SetScript("OnMouseWheel", function(_, delta) ScrollBy(delta) end)
    d:EnableMouseWheel(true)
    d:SetScript("OnMouseWheel", function(_, delta) ScrollBy(delta) end)

    d.empty = d:CreateFontString(nil, "OVERLAY", "SexyLootText")
    d.empty:SetPoint("TOP", d, "TOP", 0, -(ns.HEAD + INFO_H + 18))
    d.empty:SetText(T["Nichts zum Aufräumen gefunden."])

    d.foot = d:CreateFontString(nil, "OVERLAY", "SexyLootDim")
    d.foot:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 12, 10)
    d.foot:SetJustifyH("LEFT")

    d:SetScript("OnHide", Disarm)
    dialog = d
end

-- Scrollbalken (Schieber) an die Liste anpassen
local function UpdateScroll()
    local d = dialog
    local viewH, contentH = d.scroll:GetHeight(), d.content:GetHeight()
    local maxScroll = math.max(0, contentH - viewH)
    local cur = math.min(d.scroll:GetVerticalScroll(), maxScroll)
    d.scroll:SetVerticalScroll(cur)
    d.thumb:SetShown(maxScroll > 0)
    d.track:SetShown(maxScroll > 0)
    if maxScroll > 0 then
        local h = math.max(20, viewH * viewH / contentH)
        d.thumb:SetHeight(h)
        d.thumb:ClearAllPoints()
        d.thumb:SetPoint("TOP", d.track, "TOP", 0, -(viewH - h) * (cur / maxScroll))
    end
end

function ScrollBy(delta)
    local d = dialog
    local maxScroll = math.max(0, d.content:GetHeight() - d.scroll:GetHeight())
    d.scroll:SetVerticalScroll(math.max(0, math.min(maxScroll, d.scroll:GetVerticalScroll() - delta * ROW_H)))
    UpdateScroll()
end

function Bags:Refresh()
    if not (dialog and dialog:IsShown()) then return end
    local cfg = ns.cfg.bags
    Disarm()
    Recount()
    local list = Scan()
    local n = #list
    local view = math.max(2, math.min(n, cfg.rows))   -- sichtbare Zeilen, der Rest wird gescrollt
    for i = 1, n do
        local item = list[i]
        local r = GetRow(i)
        r.item = item
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", dialog.content, "TOPLEFT", 0, -(i - 1) * ROW_H)
        r:SetPoint("TOPRIGHT", dialog.content, "TOPRIGHT", 0, -(i - 1) * ROW_H)
        r.bg:SetColorTexture(0.15, 0.12, 0.07, i % 2 == 1 and 0.55 or 0.25)
        local cr, cg, cb = ns.QualityColor(item.quality)
        r.border:SetColorTexture(cr, cg, cb, 1)
        r.icon:SetTexture(item.icon)
        r.name:SetText(item.name)
        r.name:SetTextColor(cr, cg, cb)
        r.count:SetText(item.count > 1 and ("×" .. item.count) or "")
        -- Auktionspreis oben, darunter klein der normale Händlerpreis (zwei Textzeilen: SetWordWrap(false)
        -- würde einen Zeilenumbruch im Text unterdrücken)
        local two = item.auction and item.vendorValue > 0
        r.value:ClearAllPoints()
        r.value:SetPoint("RIGHT", r.btn, "LEFT", -8, two and 7 or 0)
        r.value:SetText(item.value > 0 and Coins(item.value) or "-")
        r.vendorLine:SetShown(two and true or false)
        if two then r.vendorLine:SetText(Coins(item.vendorValue)) end
        -- Auktionspreise in Informationsblau, Händlerpreise in Standardfarbe
        if item.auction then r.value:SetTextColor(0.53, 0.8, 1) else r.value:SetTextColor(0.95, 0.92, 0.86) end
        r:Show()
    end
    for i = n + 1, #rows do
        rows[i].item = nil
        rows[i]:Hide()
    end
    dialog.content:SetHeight(math.max(1, n * ROW_H))
    dialog.scroll:SetHeight(view * ROW_H)
    dialog.empty:SetShown(n == 0)
    dialog.foot:SetText(T("Freie Plätze: %d von %d", freeSlots, totalSlots) .. "   |cff88ccff" .. T["Blau: Auktionspreis, darunter Händlerpreis"] .. "|r")
    dialog:SetHeight(ns.HEAD + INFO_H + view * ROW_H + FOOT_H)
    UpdateScroll()
end

function Bags:Open()
    if not dialog then CreateDialog() end
    if attached then PlaceDialog(false) end   -- normal geöffnet: wieder an die gespeicherte Stelle
    dialog:Show()
    self:Refresh()
end

-- Beim Looten "Inventar ist voll": Dialog direkt am Beutefenster öffnen
function Bags:OpenAtLoot()
    if not dialog then CreateDialog() end
    if dialog:IsShown() then return end
    PlaceDialog(true)
    dialog:Show()
    self:Refresh()
end

function Bags:Toggle()
    if dialog and dialog:IsShown() then dialog:Hide() else self:Open() end
end

-- Im Edit Mode: Beispielhinweis
function Bags:Preview(active)
    previewing = active and true or false
    UpdateBanner()
end

ns.Apply.bags = function()
    if banner then ns.ApplyStyle(banner, "bags") end
    if dialog then ns.ApplyStyle(dialog, "bags") end
    Recount()
    Bags:Refresh()
end

function Bags:Init()
    CreateBanner()
    local pending = false
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("BAG_UPDATE_DELAYED")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("UI_ERROR_MESSAGE")
    ev:SetScript("OnEvent", function(_, event, _, message)
        -- Beim Looten "Inventar ist voll": Hinweis sofort zeigen, auch wenn er weggeklickt war
        if event == "UI_ERROR_MESSAGE" then
            if message == ERR_INV_FULL and not ns.cfg.bags.noAutoOpen then
                Bags:OpenAtLoot()
            end
            return
        end
        if pending then return end
        pending = true
        C_Timer.After(0.3, function()
            pending = false
            Recount()
            Bags:Refresh()
        end)
    end)
end
