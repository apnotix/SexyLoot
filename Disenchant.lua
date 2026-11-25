local ADDON, ns = ...
local T = ns.T

-- Entzauber-Fenster: listet die Items in deinen Taschen, die sich entzaubern lassen. Ein Klick auf
-- "Entzaubern" wirkt den Zauber auf genau dieses Item (gesicherter Makroknopf: /cast + /use Tasche Fach).
-- Gesicherte Knöpfe dürfen im Kampf weder angelegt noch geändert werden; darum öffnet und aktualisiert sich
-- das Fenster nur außerhalb des Kampfes.

local DE = {}
ns.Disenchant = DE
table.insert(ns.modules, DE)

local SPELL_ID = 13262            -- Entzaubern
local dialog
local rows = {}
local pending = false             -- Aktualisierung nach dem Kampf nötig
local bindPending = false         -- Taste für "Alle entzaubern" nach dem Kampf neu belegen

-- Standard: STRG + D. Wer die Taste entfernt, behält "keine" (false); nil heißt "nie gesetzt" = Standard.
local DEFAULT_KEY = "CTRL-D"
local function Hotkey()
    local key = SexyLootDB.deHotkey
    if key == nil then return DEFAULT_KEY end
    return key or nil
end

local ROW_H, DIALOG_W = 34, 460
local INFO_H, FOOT_H = 34, 62
local HEAD_H, ROW_GAP, GROUP_GAP = 26, 2, 8   -- Gruppenzeile (Qualität), Abstand der Zeilen, Abstand der Gruppen
local STEP = ROW_H + ROW_GAP
local strip                       -- Fenster "Als Nächstes" (nach "Alle entzaubern")
local skipped = {}                -- [Schlüssel] = true: in dieser Runde übersprungene Items
local stripTotal                  -- Zahl der Items beim Start der Runde (für den Fortschrittsbalken)
local noDE = {}                   -- [Link] = true: Tooltip sagt "nicht entzauberbar"

-- Items, die sich nicht entzaubern lassen, obwohl sie wie Ausrüstung aussehen: die vom Verzauberer
-- hergestellten Zauberstäbe (Lesser/Greater Magic Wand, Lesser/Greater Mystic Wand)
local NEVER = { [11287] = true, [11288] = true, [11289] = true, [11290] = true }

-- Vom Spieler ausgeblendete Items (Rechtsklick auf die Zeile), gespeichert nach Item-ID
local function Ignored(itemID)
    return itemID and SexyLootDB.deIgnore and SexyLootDB.deIgnore[itemID]
end

-- Fach und Link bestimmen ein Item für "Überspringen" (Fächer rücken beim Entzaubern nicht nach)
local function ItemKey(item)
    return item.bag .. ":" .. item.slot .. ":" .. item.link
end

local function Coins(copper)
    return GetCoinTextureString and GetCoinTextureString(copper, 11) or GetMoneyString(copper)
end

local function KnowsDisenchant()
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, SPELL_ID)
        if ok then return known and true or false end
    end
    if IsPlayerSpell then return IsPlayerSpell(SPELL_ID) and true or false end
    return IsSpellKnown and IsSpellKnown(SPELL_ID) and true or false
end

local function SpellName()
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(SPELL_ID)
    if info and info.name then return info.name end
    return GetSpellInfo and (GetSpellInfo(SPELL_ID)) or "Disenchant"
end

-- Items aus Ausrüstungssets (nach Item-ID, soweit der Client Sets kennt)
local function SetItemIDs()
    local ids = {}
    if not (C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs and C_EquipmentSet.GetItemIDs) then return ids end
    pcall(function()
        for _, setID in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
            for _, itemID in pairs(C_EquipmentSet.GetItemIDs(setID)) do
                if itemID and itemID > 0 then ids[itemID] = true end
            end
        end
    end)
    return ids
end

local tip
-- Der Tooltip nennt "Kann nicht entzaubert werden", wenn der Client das Item so kennzeichnet
local function TooltipSaysNo(bag, slot, link)
    if noDE[link] ~= nil then return noDE[link] end
    local text = _G.ITEM_DISENCHANT_NOT_DISENCHANTABLE
    local result = false
    if text then
        tip = tip or CreateFrame("GameTooltip", "SexyLootDETooltip", UIParent, "GameTooltipTemplate")
        tip:SetOwner(UIParent, "ANCHOR_NONE")
        if pcall(tip.SetBagItem, tip, bag, slot) then
            for i = 2, tip:NumLines() do
                local line = _G["SexyLootDETooltipTextLeft" .. i]
                if line and line:GetText() == text then result = true break end
            end
        end
        tip:Hide()
    end
    noDE[link] = result
    return result
end

-- Waffen und Rüstung der gewählten Qualitäten; Hemden, Wappenröcke, Schmuck und Angelruten nie
local function IsCandidate(classID, subclassID, quality, equipLoc)
    local IC = Enum and Enum.ItemClass
    local isGear = classID == (IC and IC.Weapon or 2) or classID == (IC and IC.Armor or 4)
    if not isGear then return false end
    if quality < 2 or quality > 4 then return false end
    if equipLoc == "INVTYPE_BODY" or equipLoc == "INVTYPE_TABARD" or equipLoc == "INVTYPE_TRINKET"
        or equipLoc == "INVTYPE_BAG" or equipLoc == "" then return false end
    if classID == (IC and IC.Weapon or 2) and subclassID == 20 then return false end   -- Angelruten
    return true
end

local function Scan()
    local cfg = ns.cfg.disenchant
    local bagAPI = ns.BagAPI
    local protected = cfg.protectSets and SetItemIDs() or {}
    local list = {}
    for bag = 0, bagAPI.LastBag() do
        for slot = 1, bagAPI.NumSlots(bag) do
            local link, count, quality, locked = bagAPI.SlotInfo(bag, slot)
            if link and not locked then
                local name, _, q, _, _, _, _, _, equipLoc, icon, vendor, classID, subclassID = ns.GetItemInfo(link)
                if name then
                    q = q or quality or 1
                    if IsCandidate(classID, subclassID, q, equipLoc) and q >= cfg.minQuality and q <= cfg.maxQuality then
                        local itemID = ns.ItemID(link)
                        if not (itemID and (protected[itemID] or NEVER[itemID])) and not Ignored(itemID)
                            and not TooltipSaysNo(bag, slot, link) then
                            local ilvl = 0
                            if C_Item and C_Item.GetDetailedItemLevelInfo then
                                local ok, v = pcall(C_Item.GetDetailedItemLevelInfo, link)
                                if ok and v then ilvl = v end
                            end
                            -- Wert: Auktionspreis eines Preis-Addons oder Händlerpreis (Option "Preisquelle")
                            local unit, auction = ns.ItemPrice(link, vendor or 0)
                            list[#list + 1] = { bag = bag, slot = slot, link = link, name = name, quality = q,
                                icon = icon, ilvl = ilvl, count = count or 1,
                                value = (unit or 0) * (count or 1), auction = auction,
                                vendorValue = (vendor or 0) * (count or 1) }
                        end
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.quality ~= b.quality then return a.quality < b.quality end
        if a.ilvl ~= b.ilvl then return a.ilvl < b.ilvl end
        return a.name < b.name
    end)
    return list
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------

local ScrollBy

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
    d.scroll:SetVerticalScroll(math.max(0, math.min(maxScroll, d.scroll:GetVerticalScroll() - delta * STEP)))
    UpdateScroll()
end

-- Eine Zeile samt gesichertem Knopf. Wird nur außerhalb des Kampfes angelegt.
local function MakeRow(i)
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

    local b = CreateFrame("Button", nil, r, "SecureActionButtonTemplate")
    b:SetSize(84, 22)
    b:SetPoint("RIGHT", -8, 0)
    -- Klick beim Loslassen: Neuere Clients lassen gesicherte Knöpfe sonst beim Drücken feuern (CVar
    -- ActionButtonUseKeyDown), und dann kommt der Klick nie an (gleiche Erfahrung wie bei SexyInterrupter)
    b:RegisterForClicks("AnyUp")
    b:SetAttribute("useOnKeyDown", false)
    b:SetAttribute("type", "macro")
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(ns.BTN[1], ns.BTN[2], ns.BTN[3], 1)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.25)
    b.text = b:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    b.text:SetAllPoints()
    ns.StyleButton(b)
    b.text:SetText(T["Entzaubern"])
    r.btn = b

    r.ilvl = ns.Pill(r)
    r.ilvl.tex:SetPoint("RIGHT", b, "LEFT", -8, 0)

    r.value = r:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    r.value:SetPoint("RIGHT", r.ilvl.tex, "LEFT", -8, 0)
    r.value:SetWidth(120)
    r.value:SetJustifyH("RIGHT")
    r.value:SetWordWrap(false)

    r.vendorLine = r:CreateFontString(nil, "OVERLAY", "SexyLootDim")
    r.vendorLine:SetPoint("RIGHT", r.ilvl.tex, "LEFT", -8, -7)
    r.vendorLine:SetWidth(120)
    r.vendorLine:SetJustifyH("RIGHT")
    r.vendorLine:SetWordWrap(false)
    r.vendorLine:Hide()

    r.name = r:CreateFontString(nil, "OVERLAY", "SexyLootText")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
    r.name:SetPoint("RIGHT", r.value, "LEFT", -6, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)

    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
        if not self.item then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(self.item.bag, self.item.slot)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(T["Rechtsklick: nicht mehr anzeigen"], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", GameTooltip_Hide)
    -- Rechtsklick: dieses Item nie mehr anbieten (z. B. wenn es sich doch nicht entzaubern lässt)
    r:SetScript("OnMouseUp", function(self, button)
        if button ~= "RightButton" or not self.item then return end
        local itemID = ns.ItemID(self.item.link)
        if not itemID then return end
        SexyLootDB.deIgnore = SexyLootDB.deIgnore or {}
        SexyLootDB.deIgnore[itemID] = true
        GameTooltip:Hide()
        DE:Refresh()
    end)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, delta) ScrollBy(delta) end)
    rows[i] = r
    return r
end

-- Gruppenzeile je Qualität (wie in SexyHarvester): dunkles Band, links das Etikett mit dem Namen der Qualität, rechts die Summe
local function GetHeader(i)
    local h = dialog.heads[i]
    if h then return h end
    h = CreateFrame("Frame", nil, dialog.content)
    h:SetHeight(HEAD_H)
    h.bg = h:CreateTexture(nil, "BACKGROUND")
    h.bg:SetAllPoints()
    h.bg:SetColorTexture(0.15, 0.12, 0.07, 0.96)
    h.pill = h:CreateTexture(nil, "ARTWORK")
    h.pill:SetPoint("LEFT", 8, 0)
    h.pill:SetHeight(16)
    h.label = h:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    h.label:SetPoint("CENTER", h.pill, "CENTER")
    h.sum = h:CreateFontString(nil, "OVERLAY", "SexyLootDim")
    h.sum:SetPoint("RIGHT", -8, 0)
    h:EnableMouse(true)
    h:EnableMouseWheel(true)
    h:SetScript("OnMouseWheel", function(_, delta) ScrollBy(delta) end)
    dialog.heads[i] = h
    return h
end

local function CreateDialog()
    local d = ns.FramedPanel(UIParent, T["Entzaubern"])
    d.heads = {}
    d:SetFrameStrata("DIALOG")
    d:SetWidth(DIALOG_W)
    d:SetClampedToScreen(true)
    d:SetMovable(true)
    d:EnableMouse(true)
    d:RegisterForDrag("LeftButton")
    d:SetScript("OnDragStart", d.StartMoving)
    d:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SexyLootDB.dePos = { x = self:GetLeft(), y = self:GetBottom() }
    end)
    ns.ApplyStyle(d, "disenchant")
    d:Hide()
    d.badgeInset = 32
    dialog = d

    local pos = SexyLootDB.dePos
    if pos and pos.x then
        d:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    else
        d:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    end

    local close = CreateFrame("Button", nil, d, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetFrameLevel(d:GetFrameLevel() + 10)
    close:SetScript("OnClick", function() d:Hide() end)
    _G.SexyLootDisenchant = d
    tinsert(UISpecialFrames, "SexyLootDisenchant")

    d.info = d:CreateFontString(nil, "OVERLAY", "SexyLootDim")
    d.info:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -(ns.HEAD + 8))
    d.info:SetPoint("RIGHT", d, "RIGHT", -12, 0)
    d.info:SetJustifyH("LEFT")

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
    d.empty:SetText(T["Nichts zum Entzaubern gefunden."])

    d.foot = d:CreateFontString(nil, "OVERLAY", "SexyLootDim")
    d.foot:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 12, 40)
    d.foot:SetJustifyH("LEFT")

    -- "Alle entzaubern": öffnet das Fenster "Als Nächstes". Jeder Zauber braucht einen eigenen Klick (Blizzard
    -- erlaubt nur einen Zauber je Klick); dort zielt ein gesicherter Knopf immer auf das nächste Item der Liste.
    local all = CreateFrame("Button", "SexyLootDisenchantAll", d)
    all:SetHeight(24)
    all:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 12, 10)
    all:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -12, 10)
    all:RegisterForClicks("LeftButtonUp")
    all:SetScript("OnClick", function() DE:ShowStrip() end)
    all.bg = all:CreateTexture(nil, "BACKGROUND")
    all.bg:SetAllPoints()
    all.bg:SetColorTexture(ns.BTN[1], ns.BTN[2], ns.BTN[3], 1)
    all.hl = all:CreateTexture(nil, "HIGHLIGHT")
    all.hl:SetAllPoints()
    all.hl:SetColorTexture(1, 1, 1, 0.25)
    all.text = all:CreateFontString(nil, "OVERLAY", "SexyLootText")
    all.text:SetAllPoints()
    ns.StyleButton(all)
    all:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(T["Alle entzaubern"])
        GameTooltip:AddLine(T["Öffnet das Fenster „Als Nächstes“: jeder Klick entzaubert das nächste Item der Liste (ein Zauber je Klick)."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    all:SetScript("OnLeave", GameTooltip_Hide)
    d.all = all
    -- Die Taste für "Alle entzaubern" gilt nur, solange das Fenster offen ist
    d:HookScript("OnShow", function() DE:ApplyBinding() end)
    d:HookScript("OnHide", function() DE:ApplyBinding() end)
    return d
end

-- Liste nach Qualität gruppiert: je Gruppe eine Zeile mit Etikett und Summe, darunter die Items
local function FillList(list, known, macroSpell)
    local cfg = ns.cfg.disenchant
    local n = #list
    local view = cfg.rows   -- feste Höhe: das Fenster bleibt gleich groß, egal wie viele Items es gibt
    local y, headers, lastQ = 0, 0, nil
    for i = 1, n do
        local item = list[i]
        if item.quality ~= lastQ then
            if lastQ then y = y + GROUP_GAP end
            lastQ = item.quality
            headers = headers + 1
            local h = GetHeader(headers)
            local sum = 0
            for j = i, n do
                if list[j].quality ~= item.quality then break end
                sum = sum + list[j].value
            end
            local hr, hg, hb = ns.QualityColor(item.quality)
            h.pill:SetColorTexture(hr * 0.2, hg * 0.2, hb * 0.2, 1)
            h.label:SetText(_G["ITEM_QUALITY" .. item.quality .. "_DESC"] or tostring(item.quality))
            h.label:SetTextColor(hr, hg, hb)
            h.pill:SetWidth(h.label:GetStringWidth() + 18)
            h.sum:SetText(sum > 0 and Coins(sum) or "")
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", dialog.content, "TOPLEFT", 0, -y)
            h:SetPoint("TOPRIGHT", dialog.content, "TOPRIGHT", 0, -y)
            h:Show()
            y = y + HEAD_H + ROW_GAP
        end
        local r = rows[i] or MakeRow(i)
        r.item = item
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", dialog.content, "TOPLEFT", 0, -y)
        r:SetPoint("TOPRIGHT", dialog.content, "TOPRIGHT", 0, -y)
        y = y + STEP
        r.bg:SetColorTexture(0.15, 0.12, 0.07, i % 2 == 1 and 0.55 or 0.25)
        local cr, cg, cb = ns.QualityColor(item.quality)
        r.border:SetColorTexture(cr, cg, cb, 1)
        r.icon:SetTexture(item.icon)
        r.name:SetText(item.name)
        r.name:SetTextColor(cr, cg, cb)
        if item.ilvl > 0 then r.ilvl:Set("grey", "iLvl " .. item.ilvl, nil, 16) else r.ilvl:Hide() end
        -- Auktionspreis oben, darunter klein der normale Händlerpreis (zwei Textzeilen: SetWordWrap(false)
        -- würde einen Zeilenumbruch im Text unterdrücken)
        local two = item.auction and item.vendorValue > 0
        r.value:ClearAllPoints()
        r.value:SetPoint("RIGHT", r.ilvl.tex, "LEFT", -8, two and 7 or 0)
        r.value:SetText(item.value > 0 and Coins(item.value) or "-")
        r.vendorLine:SetShown(two and true or false)
        if two then r.vendorLine:SetText(Coins(item.vendorValue)) end
        -- Auktionspreise in Informationsblau, Händlerpreise in Standardfarbe
        if item.auction then r.value:SetTextColor(0.53, 0.8, 1) else r.value:SetTextColor(0.95, 0.92, 0.86) end
        r.btn:SetAttribute("macrotext", "/cast " .. macroSpell .. "\n/use " .. item.bag .. " " .. item.slot)
        r.btn:SetEnabled(known)
        r.btn.bg:SetColorTexture(known and ns.BTN[1] or 0.2, known and ns.BTN[2] or 0.18, known and ns.BTN[3] or 0.15, 1)
        r:Show()
    end
    for i = n + 1, #rows do
        rows[i].item = nil
        rows[i]:Hide()
    end
    for i = headers + 1, #dialog.heads do dialog.heads[i]:Hide() end
    dialog.content:SetHeight(math.max(1, y - ROW_GAP))
    local viewH = view * STEP + HEAD_H + ROW_GAP   -- Platz für die Zeilen und eine Gruppenzeile
    dialog.scroll:SetHeight(viewH)
    dialog.empty:SetShown(n == 0)
    -- "Alle entzaubern" öffnet das Fenster "Als Nächstes"; die Zahl sagt, wie viele Items es sind
    local canAll = known and n > 0
    dialog.all:SetEnabled(canAll)
    dialog.all.bg:SetColorTexture(canAll and ns.BTN[1] or 0.2, canAll and ns.BTN[2] or 0.18, canAll and ns.BTN[3] or 0.15, 1)
    local key = Hotkey() and ns.LootWindow.PrettyKey(Hotkey())
    dialog.all.text:SetText(T("Alle entzaubern (%d)", n) .. (key and ("  |cffe8c26a[" .. key .. "]|r") or ""))
    dialog.info:SetText(known and T["Ein Klick wirkt Entzaubern auf das Item. Die Beute erscheint im Beutefenster."]
        or T["Du kennst Entzaubern nicht (Verzauberkunst nötig). Die Liste zeigt trotzdem, was sich eignen würde."])
    local total = 0
    for _, item in ipairs(list) do total = total + item.value end
    dialog.foot:SetText(T("%d Items", n) .. "   " .. T["Gesamtwert"] .. ": " .. (total > 0 and Coins(total) or "-")
        .. "   |cff88ccff" .. T["Blau: Auktionspreis, darunter Händlerpreis"] .. "|r")
    dialog:SetHeight(ns.HEAD + INFO_H + viewH + FOOT_H)
    UpdateScroll()
end

-- Fenster "Als Nächstes": das nächste Item groß, ein gesicherter Knopf entzaubert es, "Überspringen" nimmt es aus der Runde
local function FillStrip(list, known, macroSpell)
    local s = strip
    local n = #list
    local nextItem, restValue, skippedHere = nil, 0, 0
    for _, item in ipairs(list) do
        if skipped[ItemKey(item)] then
            skippedHere = skippedHere + 1
        else
            restValue = restValue + item.value
            nextItem = nextItem or item
        end
    end
    if not stripTotal or n > stripTotal then stripTotal = n end
    s.nextItem = nextItem
    s.skippedHere = skippedHere

    s:SetBadge(T("noch %d", n - skippedHere))
    s.iconBox:SetShown(nextItem ~= nil)
    s.label:SetShown(nextItem ~= nil)
    s.name:SetShown(nextItem ~= nil)
    s.ilvl.tex:SetShown(false)
    s.value:SetShown(nextItem ~= nil)
    s.vendor:SetShown(false)
    s.empty:SetShown(nextItem == nil)
    if nextItem then
        local cr, cg, cb = ns.QualityColor(nextItem.quality)
        s.border:SetColorTexture(cr, cg, cb, 1)
        s.icon:SetTexture(nextItem.icon)
        s.name:SetText(nextItem.name)
        s.name:SetTextColor(cr, cg, cb)
        if nextItem.ilvl > 0 then
            s.ilvl:Set("grey", "iLvl " .. nextItem.ilvl, nil, 16)
        else
            s.ilvl:Hide()
        end
        s.value:SetText(nextItem.value > 0 and Coins(nextItem.value) or "-")
        if nextItem.auction then s.value:SetTextColor(0.53, 0.8, 1) else s.value:SetTextColor(0.95, 0.92, 0.86) end
        if nextItem.auction and nextItem.vendorValue > 0 then
            s.vendor:SetText(Coins(nextItem.vendorValue))
            s.vendor:Show()
        end
    else
        s.ilvl:Hide()
        s.empty:SetText(skippedHere > 0 and T["Alle übrigen Items übersprungen."] or T["Nichts mehr zu entzaubern."])
    end

    s.next:SetAttribute("macrotext", nextItem
        and ("/cast " .. macroSpell .. "\n/use " .. nextItem.bag .. " " .. nextItem.slot) or "")
    local canNext = known and nextItem ~= nil
    s.next:SetEnabled(canNext)
    s.next.bg:SetColorTexture(canNext and ns.BTN[1] or 0.2, canNext and ns.BTN[2] or 0.18, canNext and ns.BTN[3] or 0.15, 1)
    -- Überspringen; sind alle übrigen übersprungen, bietet derselbe Knopf sie wieder an
    s.skip.text:SetText(nextItem and T["Überspringen"] or T["Übersprungene wieder anbieten"])
    s.skip:SetShown(nextItem ~= nil or skippedHere > 0)

    local done = stripTotal and stripTotal > 0 and (stripTotal - n) / stripTotal or 0
    s.barFill:SetWidth(math.max(0.001, s.barW * math.min(1, done)))
    local key = Hotkey() and ns.LootWindow.PrettyKey(Hotkey())
    s.hint:SetText(T["Jeder Klick entzaubert das nächste Item"] .. (key and ("  |cffe8c26a[" .. key .. "]|r") or ""))
    s.rest:SetText(restValue > 0 and (T["Rest"] .. " " .. Coins(restValue)) or "")
end

function DE:Refresh()
    if bindPending and not InCombatLockdown() then self:ApplyBinding() end
    local listShown = dialog and dialog:IsShown()
    local stripShown = strip and strip:IsShown()
    if not (listShown or stripShown) then return end
    -- Gesicherte Knöpfe lassen sich im Kampf nicht ändern: nach dem Kampf nachholen
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    local known = KnowsDisenchant()
    local macroSpell = SpellName()
    local list = Scan()
    if listShown then FillList(list, known, macroSpell) end
    if stripShown then
        FillStrip(list, known, macroSpell)
        -- Nichts mehr zu entzaubern: das Fenster geht zu (übersprungene Items zählen mit, sie sind noch da)
        if #list == 0 then
            strip:Hide()
            stripTotal, skipped = nil, {}
        end
    elseif strip then
        -- Nur die Liste offen: der versteckte Knopf zielt schon auf das erste Item, damit die Taste sofort entzaubert
        local first = list[1]
        strip.next:SetAttribute("macrotext", first and ("/cast " .. macroSpell .. "\n/use " .. first.bag .. " " .. first.slot) or "")
        strip.next:SetEnabled(known and first ~= nil)
    end
end

local BAR_W = DIALOG_W - 28

local function CreateStrip()
    local s = ns.FramedPanel(UIParent, T["Entzaubern"])
    s:SetFrameStrata("DIALOG")
    s:SetSize(DIALOG_W, ns.HEAD + 166)
    s:SetClampedToScreen(true)
    s:SetMovable(true)
    s:EnableMouse(true)
    s:RegisterForDrag("LeftButton")
    s:SetScript("OnDragStart", s.StartMoving)
    s:SetScript("OnDragStop", s.StopMovingOrSizing)
    ns.ApplyStyle(s, "disenchant")
    s:Hide()
    s.badgeInset = 32
    strip = s

    local close = CreateFrame("Button", nil, s, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetFrameLevel(s:GetFrameLevel() + 10)
    close:SetScript("OnClick", function() s:Hide() end)
    _G.SexyLootDisenchantStrip = s
    tinsert(UISpecialFrames, "SexyLootDisenchantStrip")

    local top = ns.HEAD + 14
    -- Symbol des nächsten Items (Rand in der Qualitätsfarbe)
    s.iconBox = CreateFrame("Frame", nil, s)
    s.iconBox:SetSize(56, 56)
    s.iconBox:SetPoint("TOPLEFT", s, "TOPLEFT", 14, -top)
    s.border = s.iconBox:CreateTexture(nil, "BACKGROUND")
    s.border:SetAllPoints()
    s.icon = s.iconBox:CreateTexture(nil, "ARTWORK")
    s.icon:SetPoint("TOPLEFT", 2, -2)
    s.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    s.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    s.label = s:CreateFontString(nil, "OVERLAY", "SexyLootDim")
    s.label:SetPoint("TOPLEFT", s.iconBox, "TOPRIGHT", 12, -2)
    s.label:SetText(T["Als Nächstes"])
    s.name = s:CreateFontString(nil, "OVERLAY", "SexyLootTitle")
    s.name:SetPoint("TOPLEFT", s.label, "BOTTOMLEFT", 0, -3)
    s.name:SetPoint("RIGHT", s, "RIGHT", -156, 0)
    s.name:SetJustifyH("LEFT")
    s.name:SetWordWrap(false)
    s.ilvl = ns.Pill(s)
    s.ilvl.tex:SetPoint("TOPLEFT", s.name, "BOTTOMLEFT", 0, -6)
    s.value = s:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    s.value:SetPoint("LEFT", s.ilvl.tex, "RIGHT", 8, 0)
    s.vendor = s:CreateFontString(nil, "OVERLAY", "SexyLootDim")
    s.vendor:SetPoint("LEFT", s.value, "RIGHT", 8, 0)
    s.empty = s:CreateFontString(nil, "OVERLAY", "SexyLootText")
    s.empty:SetPoint("LEFT", s, "LEFT", 14, 0)
    s.empty:SetPoint("RIGHT", s, "RIGHT", -156, 0)
    s.empty:SetPoint("TOP", s, "TOP", 0, -(top + 14))
    s.empty:SetJustifyH("LEFT")

    -- Tooltip des nächsten Items: über Symbol, Name und Etiketten
    s.hit = CreateFrame("Frame", nil, s)
    s.hit:SetPoint("TOPLEFT", s.iconBox, "TOPLEFT", 0, 0)
    s.hit:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", -156, -(top + 56))
    s.hit:EnableMouse(true)
    s.hit:SetScript("OnEnter", function(self)
        local item = s.nextItem
        if not item then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not pcall(GameTooltip.SetBagItem, GameTooltip, item.bag, item.slot) then
            GameTooltip:SetHyperlink(item.link)
        end
        GameTooltip:Show()
    end)
    s.hit:SetScript("OnLeave", GameTooltip_Hide)

    -- Knopf "Entzaubern": gesicherter Makroknopf, zielt immer auf das nächste Item (jeder Klick ein Zauber)
    local nb = CreateFrame("Button", "SexyLootDisenchantNext", s, "SecureActionButtonTemplate")
    nb:SetSize(130, 30)
    nb:SetPoint("TOPRIGHT", s, "TOPRIGHT", -14, -top)
    nb:RegisterForClicks("AnyUp")
    nb:SetAttribute("useOnKeyDown", false)
    nb:SetAttribute("type", "macro")
    nb.bg = nb:CreateTexture(nil, "BACKGROUND")
    nb.bg:SetAllPoints()
    nb.bg:SetColorTexture(ns.BTN[1], ns.BTN[2], ns.BTN[3], 1)
    nb.hl = nb:CreateTexture(nil, "HIGHLIGHT")
    nb.hl:SetAllPoints()
    nb.hl:SetColorTexture(1, 1, 1, 0.25)
    nb.text = nb:CreateFontString(nil, "OVERLAY", "SexyLootText")
    nb.text:SetAllPoints()
    ns.StyleButton(nb)
    nb.text:SetText(T["Entzaubern"])
    s.next = nb
    -- Taste in der Liste: der Zauber läuft über diesen gesicherten Knopf, danach öffnet sich das Fenster "Als Nächstes"
    nb:SetScript("PostClick", function()
        if dialog and dialog:IsShown() and not s:IsShown() and not InCombatLockdown() then DE:ShowStrip() end
    end)

    -- Überspringen: das Item bleibt in der Tasche und kommt in dieser Runde nicht mehr dran
    local sk = CreateFrame("Button", nil, s)
    sk:SetSize(130, 22)
    sk:SetPoint("TOP", nb, "BOTTOM", 0, -6)
    sk:RegisterForClicks("LeftButtonUp")
    sk.bg = sk:CreateTexture(nil, "BACKGROUND")
    sk.bg:SetAllPoints()
    sk.bg:SetColorTexture(0.15, 0.12, 0.07, 1)
    sk.hl = sk:CreateTexture(nil, "HIGHLIGHT")
    sk.hl:SetAllPoints()
    sk.hl:SetColorTexture(1, 1, 1, 0.18)
    sk.text = sk:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    sk.text:SetPoint("LEFT", 4, 0)
    sk.text:SetPoint("RIGHT", -4, 0)
    sk.text:SetWordWrap(false)
    sk:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        if s.nextItem then skipped[ItemKey(s.nextItem)] = true else skipped = {} end
        DE:Refresh()
    end)
    s.skip = sk

    -- Fortschritt: Balken über die Breite, darunter Hinweis, Restwert und der Weg zurück zur Liste
    s.barBg = s:CreateTexture(nil, "ARTWORK")
    s.barBg:SetHeight(6)
    s.barBg:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", 14, 44)
    s.barBg:SetWidth(BAR_W)
    s.barBg:SetColorTexture(0.15, 0.12, 0.07, 1)
    s.barFill = s:CreateTexture(nil, "OVERLAY")
    s.barFill:SetHeight(6)
    s.barFill:SetPoint("BOTTOMLEFT", s.barBg, "BOTTOMLEFT", 0, 0)
    s.barFill:SetColorTexture(0.91, 0.76, 0.42, 1)
    s.barW = BAR_W

    -- Zauberbalken: läuft, solange Entzaubern gewirkt wird (Zeit aus UnitCastingInfo), sonst leer
    local cb = CreateFrame("StatusBar", nil, s)
    cb:SetSize(BAR_W, 14)
    cb:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", 14, 60)
    cb:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    cb:SetStatusBarColor(0.91, 0.76, 0.42)
    cb:SetMinMaxValues(0, 1)
    cb:SetValue(0)
    cb.bg = cb:CreateTexture(nil, "BACKGROUND")
    cb.bg:SetAllPoints()
    cb.bg:SetColorTexture(0.15, 0.12, 0.07, 1)
    cb.text = cb:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    cb.text:SetPoint("CENTER")
    cb.text:SetText(T["Entzaubern"])
    cb.text:SetTextColor(0.62, 0.57, 0.5)
    s.castBar = cb

    local castFrom, castTo
    local function CastReset()
        castFrom, castTo = nil, nil
        cb:SetScript("OnUpdate", nil)
        cb:SetValue(0)
        cb.text:SetText(T["Entzaubern"])
        cb.text:SetTextColor(0.62, 0.57, 0.5)
    end
    local function CastStart()
        local ok, name, _, _, startMS, endMS = pcall(UnitCastingInfo, "player")
        if not (ok and type(startMS) == "number" and type(endMS) == "number" and endMS > startMS) then return end
        castFrom, castTo = startMS / 1000, endMS / 1000
        cb:SetMinMaxValues(0, castTo - castFrom)
        cb.text:SetTextColor(1, 1, 1)
        cb:SetScript("OnUpdate", function()
            local now = GetTime()
            if now >= castTo then CastReset() return end
            cb:SetValue(now - castFrom)
            cb.text:SetText(("%s  %.1f s"):format(SpellName(), castTo - now))
        end)
    end
    local ev = CreateFrame("Frame", nil, s)
    for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
        "UNIT_SPELLCAST_SUCCEEDED" }) do
        pcall(ev.RegisterUnitEvent, ev, e, "player")
    end
    ev:SetScript("OnEvent", function(_, event, _, _, spellID)
        if event == "UNIT_SPELLCAST_START" then
            if spellID == SPELL_ID then CastStart() end
        elseif castFrom then
            CastReset()
        end
    end)
    s:HookScript("OnHide", CastReset)
    s.hint = s:CreateFontString(nil, "OVERLAY", "SexyLootDim")
    s.hint:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", 14, 22)
    s.hint:SetJustifyH("LEFT")
    s.rest = s:CreateFontString(nil, "OVERLAY", "SexyLootDim")
    s.rest:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", 14, 8)
    s.rest:SetJustifyH("LEFT")

    local back = CreateFrame("Button", nil, s)
    back:SetSize(96, 22)
    back:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -14, 10)
    back:RegisterForClicks("LeftButtonUp")
    back.bg = back:CreateTexture(nil, "BACKGROUND")
    back.bg:SetAllPoints()
    back.bg:SetColorTexture(0.15, 0.12, 0.07, 1)
    back.hl = back:CreateTexture(nil, "HIGHLIGHT")
    back.hl:SetAllPoints()
    back.hl:SetColorTexture(1, 1, 1, 0.18)
    back.text = back:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    back.text:SetAllPoints()
    back.text:SetText(T["Zur Liste"])
    back:SetScript("OnClick", function() DE:ShowList() end)

    -- Die Taste gilt nur, solange eines der beiden Fenster offen ist
    s:HookScript("OnShow", function() DE:ApplyBinding() end)
    s:HookScript("OnHide", function() DE:ApplyBinding() end)
    return s
end

-- Von der Liste zum Fenster "Als Nächstes": beginnt eine neue Runde (nichts übersprungen)
function DE:ShowStrip()
    if InCombatLockdown() then
        print("|cffe8c26aSexyLoot|r: " .. T["Im Kampf nicht möglich."])
        return
    end
    if not dialog then CreateDialog() end
    if not strip then CreateStrip() end
    skipped, stripTotal = {}, nil
    strip:ClearAllPoints()
    local l, t = dialog:GetLeft(), dialog:GetTop()
    if l and t then strip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t) else strip:SetPoint("CENTER", UIParent, "CENTER", 0, 80) end
    dialog:Hide()
    strip:Show()
    self:Refresh()
end

-- Zurück zur Liste (am Platz des Fensters "Als Nächstes")
function DE:ShowList()
    if InCombatLockdown() then
        print("|cffe8c26aSexyLoot|r: " .. T["Im Kampf nicht möglich."])
        return
    end
    if not dialog then CreateDialog() end
    if strip and strip:IsShown() then
        local l, t = strip:GetLeft(), strip:GetTop()
        dialog:ClearAllPoints()
        if l and t then dialog:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t) end
        strip:Hide()
    end
    dialog:Show()
    self:Refresh()
end

-- Ausgeblendete Items wieder anbieten
function DE:ResetIgnored()
    SexyLootDB.deIgnore = nil
    self:UpdateButton()
    self:Refresh()
end

-- Taste für "Alle entzaubern" (SexyLootDB.deHotkey, z. B. "CTRL-F"): belegt den Knopf per Override-Bindung, solange
-- das Fenster offen ist. Jeder Tastendruck entzaubert das nächste Item; Blizzard erlaubt nur einen Zauber je Druck.
function DE:HotkeyText() return ns.LootWindow.PrettyKey(Hotkey()) end
function DE:IsCapturing() return ns.LootWindow:IsCapturing() end

function DE:ApplyBinding()
    if InCombatLockdown() then
        bindPending, pending = true, true
        return
    end
    bindPending = false
    if not dialog then return end
    ClearOverrideBindings(dialog)
    -- Fenster "Als Nächstes" offen: die Taste entzaubert das nächste Item; in der Liste öffnet sie dieses Fenster
    local stripOpen = strip and strip:IsShown()
    if Hotkey() and (stripOpen or dialog:IsShown()) then
        -- gibt es das Fenster "Als Nächstes" schon, entzaubert die Taste sofort (auch aus der Liste); sonst öffnet sie es
        SetOverrideBindingClick(dialog, true, Hotkey(), strip and "SexyLootDisenchantNext" or "SexyLootDisenchantAll", "LeftButton")
    end
end

local function SayKey(text) print("|cffe8c26aSexyLoot|r: " .. text) end

function DE:CaptureHotkey()
    ns.LootWindow:CaptureKey(function(combo)
        SexyLootDB.deHotkey = combo
        DE:ApplyBinding()
        DE:Refresh()
        SayKey(T("Taste für „Alle entzaubern“: %s", ns.LootWindow.PrettyKey(combo)))
    end)
end

function DE:ClearHotkey()
    SexyLootDB.deHotkey = false   -- bewusst keine Taste
    self:ApplyBinding()
    self:Refresh()
    local SEM = LibStub("SexyEditMode-1.0", true)
    if SEM and SEM.RefreshDialog then SEM:RefreshDialog() end
    SayKey(T["Hotkey entfernt."])
end

function DE:Open()
    if InCombatLockdown() then
        print("|cffe8c26aSexyLoot|r: " .. T["Im Kampf nicht möglich."])
        return
    end
    if not dialog then CreateDialog() end
    if not strip then CreateStrip() end
    if strip:IsShown() then strip:Hide() end
    dialog:Show()
    self:Refresh()
end

function DE:Toggle()
    if (dialog and dialog:IsShown()) or (strip and strip:IsShown()) then
        if dialog then dialog:Hide() end
        if strip then strip:Hide() end
    else
        self:Open()
    end
end

ns.Apply.disenchant = function()
    if dialog then ns.ApplyStyle(dialog, "disenchant") end
    if strip then ns.ApplyStyle(strip, "disenchant") end
    DE:Refresh()
end

---------------------------------------------------------------------------
-- Knopf, den man im Edit Mode platziert: öffnet das Entzauber-Fenster
---------------------------------------------------------------------------

local button, previewing

local function DisenchantIcon()
    local tex
    if C_Spell and C_Spell.GetSpellTexture then tex = C_Spell.GetSpellTexture(SPELL_ID)
    elseif GetSpellTexture then tex = GetSpellTexture(SPELL_ID) end
    return tex or "Interface/Icons/INV_Enchant_Disenchant"
end

local function CreateButton()
    local p = ns.FramedPanel(ns.frames.deButton)
    p:SetAllPoints(ns.frames.deButton)

    local b = CreateFrame("Button", nil, p)
    b:SetPoint("TOPLEFT", ns.INSET + 3, -(ns.INSET + 3))
    b:SetPoint("BOTTOMRIGHT", -(ns.INSET + 3), ns.INSET + 3)
    b:RegisterForClicks("LeftButtonUp")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(DisenchantIcon())
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.2)

    -- Anzahl der entzauberbaren Items als Zahlenabzeichen an der Ecke: dunkle Fläche, goldener Rand,
    -- liegt über dem Symbol und bleibt dadurch auf jedem Hintergrund lesbar
    local badge = CreateFrame("Frame", nil, p)
    badge:SetFrameLevel(b:GetFrameLevel() + 5)
    badge:SetHeight(16)
    badge:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 4, -4)
    badge.edge = badge:CreateTexture(nil, "BACKGROUND")
    badge.edge:SetAllPoints()
    badge.edge:SetColorTexture(0.91, 0.76, 0.42, 1)
    badge.bg = badge:CreateTexture(nil, "BORDER")
    badge.bg:SetPoint("TOPLEFT", 1, -1)
    badge.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    badge.bg:SetColorTexture(0.08, 0.065, 0.05, 1)
    badge.text = badge:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    badge.text:SetPoint("CENTER", 0, 0)
    badge.text:SetTextColor(1, 0.9, 0.5)
    badge:Hide()
    b.count = badge

    b:SetScript("OnClick", function() DE:Toggle() end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(T["Entzaubern"])
        GameTooltip:AddLine(T["Klick: Entzauber-Fenster öffnen"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    p.button = b
    button = p
end

function DE:UpdateButton()
    if not button then return end
    local cfg = ns.cfg.deButton
    local count = previewing and 3 or #Scan()
    if cfg.showCount and count > 0 then
        local badge = button.button.count
        badge.text:SetText(count)
        badge:SetWidth(math.max(18, badge.text:GetStringWidth() + 10))
        badge:Show()
    else
        button.button.count:Hide()
    end
    -- Ohne den Zauber (Verzauberkunst) gibt es keinen Knopf; im Edit Mode bleibt er zum Platzieren sichtbar
    button:SetShown(previewing or (not cfg.hidden and KnowsDisenchant() and (not cfg.onlyWithItems or count > 0)))
end

-- Edit Mode: Knopf mit Beispielzahl zeigen
function DE:Preview(active)
    previewing = active and true or false
    self:UpdateButton()
end

ns.Apply.deButton = function()
    local size = ns.cfg.deButton.size or 44
    ns.frames.deButton:SetSize(size, size)
    if button then
        ns.ApplyStyle(button, "deButton")
        DE:UpdateButton()
    end
end

function DE:Init()
    CreateButton()
    local queued = false
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("BAG_UPDATE_DELAYED")
    ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("SPELLS_CHANGED")
    ev:SetScript("OnEvent", function(_, event)
        if queued then return end
        queued = true
        C_Timer.After(0.3, function()
            queued = false
            DE:UpdateButton()
            DE:Refresh()
        end)
    end)
end
