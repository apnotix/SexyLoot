local ADDON, ns = ...
local T = ns.T

-- Beutefenster: ersetzt das Blizzard-LootFrame. Qualitätsfarben, Tooltips,
-- Shift-Klick verlinkt im Chat, "Alles nehmen", optional graue Items automatisch.
-- Hinweis: Plündermeister-Verteilung (Master Loot) wird nicht unterstützt.

local LW = {}
ns.LootWindow = LW
table.insert(ns.modules, LW)

local WIDTH = 250
local HEAD, FOOT = 28, 30
local panel, title, closeBtn, allBtn
local rows, slots = {}, {}

--------------------------------------------------------------------------
-- Zeilen
--------------------------------------------------------------------------

local function MakeRow(i)
    local b = CreateFrame("Button", nil, panel)
    b:RegisterForClicks("LeftButtonUp")
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    b.qual = b:CreateTexture(nil, "BACKGROUND")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetJustifyH("RIGHT")

    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.sub:SetJustifyH("LEFT")

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.data.fake then
            if self.data.link then GameTooltip:SetHyperlink(self.data.link) else GameTooltip:SetText(self.data.name) end
        elseif self.data.item then
            GameTooltip:SetLootItem(self.data.slot)
        else
            GameTooltip:SetText(self.data.name)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", function(self)
        local d = self.data
        if d.link and IsModifiedClick("CHATLINK") then
            HandleModifiedItemClick(d.link)
        elseif d.fake then
            for k, s in ipairs(slots) do if s == d then table.remove(slots, k) break end end
            LW:Draw()
        else
            LootSlot(d.slot)
        end
    end)
    rows[i] = b
    return b
end

function LW:Draw()
    local cfg = ns.cfg.loot
    local h = cfg.icon
    local thr = cfg.thr   -- Qualität 2 grün, 3 blau, 4 episch
    for i = 1, math.max(#rows, #slots) do
        local row = rows[i] or MakeRow(i)
        local d = slots[i]
        if d then
            row.data = d
            row:SetSize(WIDTH - 16, h + 4)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -(HEAD + (i - 1) * (h + 4)))

            row.qual:SetSize(h + 2, h + 2)
            row.qual:ClearAllPoints()
            row.qual:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.icon:SetSize(h, h)
            row.icon:ClearAllPoints()
            row.icon:SetPoint("CENTER", row.qual, "CENTER")
            row.icon:SetTexture(d.icon)
            local r, g, b = 0.3, 0.26, 0.2
            if d.item then r, g, b = ns.QualityColor(d.quality) end
            if d.locked then r, g, b = 0.8, 0.2, 0.2 end
            row.qual:SetColorTexture(r, g, b, 1)

            row.count:ClearAllPoints()
            row.count:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", -1, 1)
            row.count:SetText((d.qty or 1) > 1 and d.qty or "")

            row.name:ClearAllPoints()
            row.name:SetPoint("TOPLEFT", row.qual, "TOPRIGHT", 6, -1)
            row.name:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            row.name:SetText(d.name)
            if d.item then row.name:SetTextColor(r, g, b) else row.name:SetTextColor(1, 0.85, 0.3) end

            row.sub:ClearAllPoints()
            row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -1)
            if d.item then
                row.sub:SetText(d.quality >= thr and T["Gruppenloot"] or T["Freie Beute"])
            else
                row.sub:SetText("")
            end
            row:Show()
        else
            row.data = nil
            row:Hide()
        end
    end
    local height = HEAD + #slots * (h + 4) + FOOT
    panel:SetHeight(height)
    ns.frames.loot:SetHeight(height)
    if #slots == 0 then panel:Hide() else panel:Show() end
end

--------------------------------------------------------------------------
-- Echte Beute
--------------------------------------------------------------------------

function LW:OnOpened(autoLoot)
    local cfg = ns.cfg.loot
    wipe(slots)
    self.preview = false
    for i = 1, GetNumLootItems() do
        -- LootSlotHasItem ist seit MoP generisch (Item, Geld UND Währung), der
        -- Slot-Typ steckt in GetLootSlotType (1 Item, 2 Geld, 3 Währung)
        local slotType = GetLootSlotType and GetLootSlotType(i)
        local isItem, isMoney
        if slotType then
            isItem = slotType == (LOOT_SLOT_ITEM or 1)
            isMoney = slotType == (LOOT_SLOT_MONEY or 2) or slotType == (LOOT_SLOT_CURRENCY or 3)
        else
            isItem = LootSlotHasItem(i)
            isMoney = not isItem
        end
        local icon, name, qty, a, b, c = GetLootSlotInfo(i)
        ns.Dbg("Slot", i, "Typ", slotType, "Item", isItem, "Geld", isMoney, name)
        if icon then
            -- Klassische Clients liefern (icon, name, qty, quality, locked, ...),
            -- neuere (icon, name, qty, currencyID, quality, locked, ...)
            local quality, locked
            if type(b) == "number" then quality, locked = b, c else quality, locked = a, b end
            quality = quality or 1
            -- Graue Items (Option) und Geld/Währung werden gleich eingesammelt
            if (cfg.auto and isItem and quality == 0) or (isMoney and not cfg.noAutoMoney) then
                LootSlot(i)
            else
                slots[#slots + 1] = {
                    slot = i, icon = icon, qty = qty, quality = quality, locked = locked,
                    item = isItem, link = isItem and GetLootSlotLink(i) or nil,
                    name = (name or "?"):gsub("\n", " "),
                }
            end
        end
    end
    title:SetText(UnitExists("target") and UnitName("target") or (LOOT or "Loot"))
    self:Draw()

    -- Blizzards LootFrame hat bei Auto-Loot alles selbst genommen. Das machen
    -- wir hier nach. Übrig bleibt, was nicht ging (z. B. volle Taschen).
    if autoLoot then
        for _, s in ipairs({ unpack(slots) }) do LootSlot(s.slot) end
    end
end

function LW:OnCleared(slot)
    for k, s in ipairs(slots) do
        if s.slot == slot and not s.fake then table.remove(slots, k) break end
    end
    self:Draw()
end

function LW:Close()
    wipe(slots)
    self:Draw()
end

function LW:BindConfirm(slot)
    local _, name, _, a, b = GetLootSlotInfo(slot)
    local quality = type(b) == "number" and b or a or 1
    StaticPopup_Hide("LOOT_BIND")
    local hex = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] and ITEM_QUALITY_COLORS[quality].hex or ""
    local dialog = StaticPopup_Show("LOOT_BIND", hex .. (name or "") .. "|r")
    if dialog then dialog.data = slot end
end

--------------------------------------------------------------------------
-- Test
--------------------------------------------------------------------------

-- Im Edit Mode steht eine Beispielbeute im Fenster. Echte Beute (LOOT_OPENED)
-- ersetzt sie, beim Verlassen des Edit Modes verschwindet sie wieder.
function LW:Preview(active)
    if active then
        if #slots == 0 then
            self:Test()
            self.preview = true
        end
    elseif self.preview then
        self.preview = false
        self:Close()
    end
end

function LW:Test()
    wipe(slots)
    self.preview = false
    local function L(id, name, color)
        return select(2, ns.GetItemInfo(id)) or ("|cff" .. color .. "|Hitem:" .. id .. "::::::::60:::::|h[" .. name .. "]|h|r")
    end
    slots[1] = { fake = true, item = true, quality = 4, name = T["Ring des Glutkerns"], icon = "Interface\\Icons\\INV_Jewelry_Ring_36", link = L(17063, T["Ring des Glutkerns"], "a335ee") }
    slots[2] = { fake = true, item = true, quality = 3, name = T["Kettenkappe der Wachsamkeit"], icon = "Interface\\Icons\\INV_Helmet_08", link = L(14551, T["Kettenkappe der Wachsamkeit"], "0070dd") }
    slots[3] = { fake = true, item = true, quality = 1, qty = 3, name = T["Leinenstoff"], icon = "Interface\\Icons\\INV_Fabric_Linen_01", link = L(2589, T["Leinenstoff"], "ffffff") }
    slots[4] = { fake = true, item = true, quality = 0, name = T["Zerrissene Wolfshaut"], icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", link = L(769, T["Zerrissene Wolfshaut"], "9d9d9d") }
    slots[5] = { fake = true, item = false, name = T["1 Silber 24 Kupfer"], icon = "Interface\\Icons\\INV_Misc_Coin_01" }
    title:SetText(T["Testbeute"])
    self:Draw()
end

--------------------------------------------------------------------------

--------------------------------------------------------------------------
-- Hotkey für "Alles nehmen"
--------------------------------------------------------------------------
-- XML-Keybindings sind im Forever-Client nicht möglich. Darum hört ein eigener
-- Frame auf Tasten, solange das Beutefenster sichtbar ist (so macht es auch
-- Dialogue UI): er liegt in der Strata TOOLTIP, und in OnKeyDown wird per
-- SetPropagateKeyboardInput(nicht behandelt) entschieden, ob die Taste an das
-- Spiel weitergeht. Nur die Hotkey-Taste wird verschluckt, alles andere läuft
-- normal durch. Im Kampf lässt sich die Weitergabe nicht ändern: dort ist die
-- Abfrage im Kampf nur "mithören": der Hotkey löst "Alles nehmen" aus, die Taste
-- geht aber zusätzlich ans Spiel (Leertaste springt dann auch).
-- Der Hotkey liegt in SexyLootDB.hotkey (z. B. "SPACE", "CTRL-F").

local MODS = { LSHIFT = 1, RSHIFT = 1, LCTRL = 1, RCTRL = 1, LALT = 1, RALT = 1, LMETA = 1, RMETA = 1 }

local function KeyCombo(key)
    if MODS[key] then return end   -- reine Modifikatortaste
    return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
        .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
end

local function Say(text) print("|cffe8c26aSexyLoot|r: " .. text) end

local listener
local lootOpen = false   -- LOOT_OPENED bis LOOT_CLOSED, unabhängig vom Anzeige-Zustand

-- Der Listener hört IMMER mit, sobald ein Hotkey gesetzt ist. Ob das Beutefenster
-- offen ist, wird erst beim Tastendruck geprüft. So gibt es keinen Zustand mehr,
-- der mit dem Fenster auseinanderlaufen kann (verpasstes Ereignis, Kampf, ...).
-- Alle anderen Tasten gehen unverändert durch (Weitergabe "ja", nach jedem
-- Loslassen neu gesetzt). Im Kampf nur, wenn die Weitergabe vorher auf "ja" gestellt
-- werden konnte, sonst würde der Frame im Kampf ALLE Tasten verschlucken.
function LW:UpdateListener()
    if not listener then return end
    local want = SexyLootDB.hotkey and (not InCombatLockdown() or listener.passThrough)
    listener:EnableKeyboard(want and true or false)
    ns.Dbg("Hotkey-Abfrage", want and "an" or "aus", "Hotkey", SexyLootDB.hotkey,
        "Beute offen", lootOpen, "Fenster", panel and panel:IsShown(), "Kampf", InCombatLockdown())
end

function LW:UpdateHotkey()
    if not allBtn then return end
    local hk = SexyLootDB.hotkey
    allBtn:SetText(T["Alles nehmen"] .. (hk and (" |cffe8c26a" .. hk .. "|r") or ""))
    allBtn:SetWidth(hk and math.max(100, allBtn:GetTextWidth() + 24) or 100)
    self:UpdateListener()
end

local capture
function LW:CaptureHotkey()
    if not capture then
        capture = CreateFrame("Frame", nil, UIParent)
        capture:SetFrameStrata("TOOLTIP")
        capture:SetScript("OnKeyDown", function(self, key)
            self:SetPropagateKeyboardInput(false)
            local combo = KeyCombo(key)
            if not combo then return end
            self:EnableKeyboard(false)
            self:Hide()
            if key == "ESCAPE" then return end
            SexyLootDB.hotkey = combo
            LW:UpdateHotkey()
            Say(T("Hotkey für „Alles nehmen“: %s", combo))
        end)
    end
    capture:Show()
    capture:EnableKeyboard(true)
    -- nach 10 Sekunden aufgeben, damit die Tastaturabfrage nie hängen bleibt
    C_Timer.After(10, function()
        if capture:IsShown() then capture:EnableKeyboard(false); capture:Hide() end
    end)
    Say(T["Drücke die gewünschte Taste (Esc bricht ab) …"])
end

function LW:ClearHotkey()
    SexyLootDB.hotkey = nil
    self:UpdateHotkey()
    Say(T["Hotkey entfernt."])
end

ns.Apply.loot = function()
    ns.ApplyStyle(panel, "loot")
    LW:UpdateHotkey()
    LW:Draw()
end

function LW:Init()
    -- Blizzards Beutefenster abschalten
    if LootFrame then LootFrame:UnregisterAllEvents() end

    panel = ns.Panel(ns.frames.loot)
    panel:SetPoint("TOPLEFT", ns.frames.loot, "TOPLEFT")
    panel:SetPoint("TOPRIGHT", ns.frames.loot, "TOPRIGHT")
    panel:Hide()

    title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -9)
    title:SetPoint("RIGHT", panel, "RIGHT", -30, 0)
    title:SetJustifyH("LEFT")

    closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", 2, 2)
    closeBtn:SetScale(0.8)
    closeBtn:SetScript("OnClick", function()
        local fake = slots[1] and slots[1].fake
        if fake then LW:Close() else CloseLoot() end
    end)

    allBtn = CreateFrame("Button", "SexyLootAllButton", panel, "UIPanelButtonTemplate")
    allBtn:SetSize(100, 22)
    allBtn:SetPoint("BOTTOMRIGHT", -8, 6)
    allBtn:SetText(T["Alles nehmen"])
    allBtn:SetScript("OnClick", function()
        if slots[1] and slots[1].fake then LW:Close() return end
        for i = GetNumLootItems(), 1, -1 do LootSlot(i) end
    end)

    -- Hotkey-Abfrage: eigener Frame, nicht das Beutefenster selbst
    listener = CreateFrame("Frame", nil, UIParent)
    listener:SetFrameStrata("TOOLTIP")
    listener:SetFrameLevel(10000)   -- ganz oben, damit uns kein anderer Frame die Taste vorwegnimmt
    listener:SetScript("OnKeyDown", function(self, key)
        local hk = SexyLootDB.hotkey
        local combo = KeyCombo(key)
        local combat = InCombatLockdown()
        ns.Dbg("Taste", key, "als", combo, "Hotkey", hk, "Fenster", panel:IsShown(), "Kampf", combat)
        local hit = hk and panel:IsShown() and combo == hk
        if hit then allBtn:Click() end
        -- Das Fenster schließt sich nach dem ersten Druck. Hält man die Taste länger,
        -- käme die Wiederholung bei geschlossenem Fenster beim Spiel an (Sprung).
        -- Darum Wiederholungen derselben Taste verbrauchen, bis sie losgelassen wird.
        if hit then self.heldKey = key
        elseif self.heldKey and self.heldKey == key then hit = true end
        -- Die Weitergabe lässt sich im Kampf nicht ändern: dort bleibt sie "ja"
        if not combat then
            self:SetPropagateKeyboardInput(not hit)
            if hit then
                -- gleich danach wieder auf "weitergeben", falls ein Kampf beginnt
                C_Timer.After(0, function()
                    if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
                end)
            end
        end
    end)
    -- Nach einem verbrauchten Tastendruck bleibt die Weitergabe auf "nein". Ohne
    -- OnKeyUp würde dann das Loslassen einer anderen Taste (z. B. der Lauftaste)
    -- verschluckt, und der Charakter liefe weiter. Darum bei jedem Loslassen
    -- wieder auf "weitergeben" stellen.
    listener:SetScript("OnKeyUp", function(self, key)
        if self.heldKey == key then self.heldKey = nil end
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
    end)
    -- Weitergabe von Anfang an auf "ja", solange wir nicht im Kampf sind; nur dann
    -- darf die Abfrage im Kampf an bleiben (siehe UpdateListener)
    local function PassThrough()
        if not InCombatLockdown() then
            listener:SetPropagateKeyboardInput(true)
            listener.passThrough = true
        end
    end
    PassThrough()
    panel:HookScript("OnShow", function() LW:UpdateListener() end)
    panel:HookScript("OnHide", function() LW:UpdateListener() end)
    local regen = CreateFrame("Frame")
    regen:RegisterEvent("PLAYER_REGEN_DISABLED")
    regen:RegisterEvent("PLAYER_REGEN_ENABLED")
    regen:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then PassThrough() end
        LW:UpdateListener()
    end)

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("LOOT_OPENED")
    ev:RegisterEvent("LOOT_CLOSED")
    ev:RegisterEvent("LOOT_SLOT_CLEARED")
    ev:RegisterEvent("LOOT_SLOT_CHANGED")
    ev:RegisterEvent("LOOT_BIND_CONFIRM")
    ev:SetScript("OnEvent", function(_, event, a)
        if event == "LOOT_OPENED" then
            lootOpen = true
            LW:OnOpened(a)
            LW:UpdateListener()
        elseif event == "LOOT_CLOSED" then
            lootOpen = false
            LW:Close()
            LW:UpdateListener()
        elseif event == "LOOT_SLOT_CLEARED" then LW:OnCleared(a)
        elseif event == "LOOT_SLOT_CHANGED" then LW:OnOpened()
        elseif event == "LOOT_BIND_CONFIRM" then LW:BindConfirm(a) end
    end)
end
