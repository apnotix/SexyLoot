local ADDON, ns = ...

-- Rollfenster: Bedarf / Gier / Passen mit den Würfen aller Spieler direkt am Item.
-- Die Wahl und die Würfe der anderen Spieler kommen aus den Loot-Chatnachrichten
-- (CHAT_MSG_LOOT). Die Muster werden aus den Blizzard-Globalstrings gebaut und
-- funktionieren deshalb in jeder Client-Sprache.

local RF = {}
ns.RollFrames = RF
table.insert(ns.modules, RF)

local WIDTH = 300
local TEX = {
    need  = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
    greed = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
    pass  = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
}
local LABEL = { need = "Bedarf", greed = "Gier", pass = "Passen" }
local ROLLTYPE = { pass = 0, need = 1, greed = 2 }
local KINDS = { "need", "greed", "pass" }

local pool, active = {}, {}

--------------------------------------------------------------------------
-- Chatmuster
--------------------------------------------------------------------------

local function Compile(fmt)
    local tokens = {}
    local s = fmt:gsub("%%(%d*)%$?([sd])", function(n, t)
        tokens[#tokens + 1] = { pos = tonumber(n) or (#tokens + 1), t = t }
        return "\1"
    end)
    s = s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    local i = 0
    s = s:gsub("\1", function()
        i = i + 1
        return tokens[i].t == "d" and "(%d+)" or "(.+)"
    end)
    return "^" .. s .. "$", tokens
end

ns.Compile = Compile

local DEFS = {}
local function Def(global, kind, fields, choice)
    local fmt = _G[global]
    if type(fmt) ~= "string" then return end
    local pat, tokens = Compile(fmt)
    DEFS[#DEFS + 1] = { pat = pat, tokens = tokens, kind = kind, fields = fields, choice = choice }
end

local PI = { "player", "item" }
local I = { "item" }
Def("LOOT_ROLL_NEED", "pick", PI, "need")
Def("LOOT_ROLL_GREED", "pick", PI, "greed")
Def("LOOT_ROLL_DISENCHANT", "pick", PI, "greed")
Def("LOOT_ROLL_PASSED", "pick", PI, "pass")
Def("LOOT_ROLL_PASSED_AUTO", "pick", PI, "pass")
Def("LOOT_ROLL_PASSED_AUTO_FEMALE", "pick", PI, "pass")
Def("LOOT_ROLL_NEED_SELF", "pick", I, "need")
Def("LOOT_ROLL_GREED_SELF", "pick", I, "greed")
Def("LOOT_ROLL_DISENCHANT_SELF", "pick", I, "greed")
Def("LOOT_ROLL_PASSED_SELF", "pick", I, "pass")
Def("LOOT_ROLL_PASSED_SELF_AUTO", "pick", I, "pass")
Def("LOOT_ROLL_ROLLED_NEED", "roll", { "roll", "item", "player" }, "need")
Def("LOOT_ROLL_ROLLED_GREED", "roll", { "roll", "item", "player" }, "greed")
Def("LOOT_ROLL_ROLLED_DE", "roll", { "roll", "item", "player" }, "greed")
Def("LOOT_ROLL_WON", "won", PI)
Def("LOOT_ROLL_YOU_WON", "won", I)
Def("LOOT_ROLL_ALL_PASSED", "allpassed", I)

local function Match(msg, d)
    local caps = { msg:match(d.pat) }
    if #caps == 0 then return end
    local out = {}
    for i, tk in ipairs(d.tokens) do out[d.fields[tk.pos]] = caps[i] end
    return out
end

--------------------------------------------------------------------------
-- Zeilen
--------------------------------------------------------------------------

local function Me() return UnitName("player") end

local function MakeButton(row, kind, x)
    local b = CreateFrame("Button", nil, row)
    b:SetSize(30, 30)
    b:SetPoint("TOPRIGHT", row, "TOPRIGHT", x, -6)
    b:SetNormalTexture(TEX[kind])
    b:SetPushedTexture((TEX[kind]:gsub("Up$", "Down")))
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b.kind = kind
    b:SetScript("OnClick", function(self) RF:Choose(row, self.kind) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(LABEL[self.kind])
        if self.reason then GameTooltip:AddLine(self.reason, 1, 0.3, 0.3, true) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

local function NewRow()
    local r = ns.Panel(ns.frames.roll)
    r:SetWidth(WIDTH)
    r:SetHeight(70)

    r.qual = r:CreateTexture(nil, "BACKGROUND")
    r.qual:SetSize(40, 40)
    r.qual:SetPoint("TOPLEFT", 4, -4)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(36, 36)
    r.icon:SetPoint("TOPLEFT", 6, -6)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    r.hit = CreateFrame("Button", nil, r)
    r.hit:SetPoint("TOPLEFT", 6, -6)
    r.hit:SetPoint("BOTTOMRIGHT", r, "TOPRIGHT", -108, -42)
    r.hit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if r.rollID and not r.fake then GameTooltip:SetLootRollItem(r.rollID)
        elseif r.link then GameTooltip:SetHyperlink(r.link) end
        GameTooltip:Show()
    end)
    r.hit:SetScript("OnLeave", GameTooltip_Hide)
    r.hit:SetScript("OnClick", function() if r.link then HandleModifiedItemClick(r.link) end end)

    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.name:SetPoint("TOPLEFT", 50, -8)
    r.name:SetPoint("RIGHT", r, "RIGHT", -108, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
    r.sub:SetTextColor(0.6, 0.55, 0.45)

    r.btn = {}
    r.btn.need  = MakeButton(r, "need", -74)
    r.btn.greed = MakeButton(r, "greed", -40)
    r.btn.pass  = MakeButton(r, "pass", -6)

    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetPoint("TOPLEFT", 6, -48)
    r.bar:SetPoint("TOPRIGHT", -6, -48)
    r.bar:SetHeight(6)
    r.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    r.bar.bg = r.bar:CreateTexture(nil, "BACKGROUND")
    r.bar.bg:SetAllPoints()
    r.bar.bg:SetColorTexture(0, 0, 0, 0.6)

    r.chips = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.chips:SetPoint("TOPLEFT", 8, -58)
    r.chips:SetWidth(WIDTH - 16)
    r.chips:SetJustifyH("LEFT")
    r.chips:SetSpacing(3)

    r:SetScript("OnUpdate", function(self)
        if not self.expires then return end
        local left = math.max(0, self.expires - GetTime())
        self.bar:SetValue(left)
        if left < self.duration * 0.25 then
            self.bar:SetStatusBarColor(0.85, 0.28, 0.17)
        else
            self.bar:SetStatusBarColor(0.9, 0.76, 0.42)
        end
    end)
    r.gen = 0
    return r
end

local function Acquire()
    local r = table.remove(pool) or NewRow()
    r.picks, r.rolls, r.roster = {}, {}, {}
    r.done, r.winner, r.chosen, r.fake, r.rollID = false, nil, nil, false, nil
    r.bar:Show()
    r:Show()
    active[#active + 1] = r
    return r
end

function RF:Remove(r)
    -- Nur Zeilen entfernen, die noch aktiv sind. Sonst landet dieselbe Zeile
    -- doppelt im Pool (z. B. Timer und Edit-Mode-Ende entfernen sie beide).
    local found
    for i, a in ipairs(active) do
        if a == r then table.remove(active, i) found = true break end
    end
    if not found then return end
    r.gen = r.gen + 1
    r.expires = nil
    r:Hide()
    pool[#pool + 1] = r
    self:Layout()
end

function RF:Layout()
    local cfg, anchor = ns.cfg.roll, ns.frames.roll
    local y = 0
    for _, r in ipairs(active) do
        r:ClearAllPoints()
        if cfg.growUp then
            r:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, y)
        else
            r:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -y)
        end
        y = y + r:GetHeight() + cfg.gap
    end
end

local function AddPlayer(r, name)
    for _, n in ipairs(r.roster) do if n == name then return end end
    r.roster[#r.roster + 1] = name
end

function RF:UpdateChips(r)
    local parts = {}
    if not ns.cfg.roll.hideRolls then
        for _, name in ipairs(r.roster) do
            local pick = r.picks[name]
            if pick then
                local s = ns.ColorName(name) .. " |T" .. TEX[pick] .. ":14|t"
                if r.rolls[name] then s = s .. " " .. r.rolls[name] end
                if r.winner == name then s = s .. " |TInterface\\RaidFrame\\ReadyCheck-Ready:14|t" end
                parts[#parts + 1] = s
            else
                parts[#parts + 1] = "|cff888888" .. ns.Short(name) .. " …|r"
            end
        end
    end
    local text = table.concat(parts, "   ")
    if r.done then
        local res
        if r.winner then
            res = ns.ColorName(r.winner) .. " gewinnt (" .. LABEL[r.picks[r.winner] or "greed"]
                .. (r.rolls[r.winner] and (" " .. r.rolls[r.winner]) or "") .. ")"
        else
            res = "Alle haben gepasst"
        end
        text = text .. (text ~= "" and "\n" or "") .. "|cffe8c26a" .. res .. "|r"
    end
    r.chips:SetText(text)
    r:SetHeight(58 + (text ~= "" and (r.chips:GetStringHeight() + 8) or 4))
    self:Layout()
end

local function SetupButtons(r, canNeed, canGreed, reasonNeed, reasonGreed)
    for _, k in ipairs(KINDS) do
        local b = r.btn[k]
        local ok = (k ~= "need" or canNeed) and (k ~= "greed" or canGreed)
        b.reason = nil
        if k == "need" and not canNeed and reasonNeed then b.reason = _G["LOOT_ROLL_INELIGIBLE_REASON" .. reasonNeed] end
        if k == "greed" and not canGreed and reasonGreed then b.reason = _G["LOOT_ROLL_INELIGIBLE_REASON" .. reasonGreed] end
        b:SetEnabled(ok)
        b:GetNormalTexture():SetDesaturated(not ok)
        b:SetAlpha(ok and 1 or 0.5)
    end
end

function RF:SetChoice(r, kind)
    r.chosen = kind
    for _, k in ipairs(KINDS) do
        r.btn[k]:Disable()
        r.btn[k]:SetAlpha(k == kind and 1 or 0.3)
    end
end

local function Fill(r, link, tex, name, count, quality, bop, duration)
    r.link = link
    r.icon:SetTexture(tex)
    local cr, cg, cb = ns.QualityColor(quality)
    r.qual:SetColorTexture(cr, cg, cb, 1)
    r.name:SetText(((count or 1) > 1 and (count .. "x ") or "") .. (name or "?"))
    r.name:SetTextColor(cr, cg, cb)
    r.sub:SetText(bop and "Beim Aufheben gebunden" or "")
    r.duration = duration
    r.expires = GetTime() + duration
    r.bar:SetMinMaxValues(0, duration)
    r.bar:SetValue(duration)
    r.itemID = ns.ItemID(link)
    for _, n in ipairs(ns.Roster()) do AddPlayer(r, n) end
end

--------------------------------------------------------------------------
-- Echte Würfe
--------------------------------------------------------------------------

function RF:Start(rollID, rollTime)
    local tex, name, count, quality, bop, canNeed, canGreed, _, reasonNeed, reasonGreed = GetLootRollItemInfo(rollID)
    if not name then return end
    local r = Acquire()
    r.rollID = rollID
    Fill(r, GetLootRollItemLink(rollID), tex, name, count, quality, bop, (rollTime or 60000) / 1000)
    SetupButtons(r, canNeed, canGreed, reasonNeed, reasonGreed)
    self:UpdateChips(r)
end

function RF:Choose(r, kind)
    if r.preview then return end
    if r.fake then return self:FakeChoose(r, kind) end
    -- Die Buttons werden erst gesperrt, wenn die eigene Wahl im Chat bestätigt
    -- ist (OnChat). Bei Bind-on-Pickup-Items fragt Blizzard erst nach; bricht
    -- man dort ab, muss man noch einmal wählen können.
    RollOnLoot(r.rollID, ROLLTYPE[kind])
end

local function FindRow(itemID, rollID)
    for _, r in ipairs(active) do
        if rollID and r.rollID == rollID then return r end
    end
    if not itemID then return end
    for _, r in ipairs(active) do
        if not r.done and r.itemID == itemID then return r end
    end
end

function RF:Finish(r, winner)
    if r.done then return end
    r.done, r.winner = true, winner
    r.expires = nil
    r.bar:Hide()
    for _, k in ipairs(KINDS) do r.btn[k]:Disable(); r.btn[k]:SetAlpha(0.3) end
    self:UpdateChips(r)
    ns.Feed:AddRoll(r)
    local gen = r.gen
    C_Timer.After(6, function() if r.gen == gen then RF:Remove(r) end end)
end

function RF:OnChat(msg)
    for _, d in ipairs(DEFS) do
        local t = Match(msg, d)
        if t then
            local id = ns.ItemID(t.item)
            local player = ns.Short(t.player or Me())
            local r = FindRow(id)
            if d.kind == "pick" and r then
                AddPlayer(r, player)
                r.picks[player] = d.choice
                if player == Me() and not r.chosen then self:SetChoice(r, d.choice) end
                self:UpdateChips(r)
            elseif d.kind == "roll" and r then
                AddPlayer(r, player)
                r.picks[player] = r.picks[player] or d.choice
                r.rolls[player] = tonumber(t.roll)
                self:UpdateChips(r)
            elseif d.kind == "won" then
                ns.Feed:NoteWin(player, id)
                if r then
                    AddPlayer(r, player)
                    r.picks[player] = r.picks[player] or "greed"
                    self:Finish(r, player)
                else
                    ns.Feed:AddWin(player, t.item)
                end
            elseif d.kind == "allpassed" then
                if r then self:Finish(r, nil) end
            end
            return
        end
    end
end

function RF:OnCancel(rollID)
    -- UIParent schließt den Bestätigungsdialog sonst selbst, aber wir haben
    -- CANCEL_LOOT_ROLL dort abgemeldet.
    StaticPopup_Hide("CONFIRM_LOOT_ROLL", rollID)
    local r = FindRow(nil, rollID)
    if not r or r.done then return end
    -- Die Gewinnernachricht kommt oft kurz nach CANCEL_LOOT_ROLL
    local gen = r.gen
    C_Timer.After(8, function() if r.gen == gen and not r.done then RF:Remove(r) end end)
end

--------------------------------------------------------------------------
-- Testwurf
--------------------------------------------------------------------------

local FAKES = {
    { "Aldrin", "WARRIOR" }, { "Mirelle", "PRIEST" }, { "Thokk", "SHAMAN" }, { "Vexa", "ROGUE" },
}

-- Gruppenmitglieder plus erfundene Spieler bis mindestens 5 Namen
local function FillRoster(r)
    r.roster = {}
    AddPlayer(r, Me())
    for _, n in ipairs(ns.Roster()) do AddPlayer(r, n) end
    for _, f in ipairs(FAKES) do
        if #r.roster < 5 then
            ns.classByName[f[1]] = f[2]
            AddPlayer(r, f[1])
        end
    end
end

function RF:Test()
    local id = 19019
    local link = select(2, ns.GetItemInfo(id))
        or "|cffff8000|Hitem:19019::::::::60:::::|h[Donnerzorn, Klinge des gepeitschten Windes]|h|r"
    local name = link:match("%[(.-)%]")
    local icon = select(5, ns.GetItemInfoInstant(id)) or "Interface\\Icons\\INV_Sword_39"

    local r = Acquire()
    r.fake = true
    Fill(r, link, icon, name, 1, 5, true, 20)
    SetupButtons(r, true, true)
    FillRoster(r)
    self:UpdateChips(r)

    local gen = r.gen
    for _, n in ipairs(r.roster) do
        if n ~= Me() then
            C_Timer.After(math.random(10, 60) / 10, function()
                if r.gen ~= gen or r.done then return end
                local x = math.random()
                r.picks[n] = x < 0.45 and "need" or x < 0.75 and "greed" or "pass"
                RF:UpdateChips(r)
                RF:FakeCheck(r)
            end)
        end
    end
    C_Timer.After(20, function()
        if r.gen == gen and not r.done and not r.picks[Me()] then RF:FakeChoose(r, "pass") end
    end)
end

function RF:FakeChoose(r, kind)
    if r.picks[Me()] then return end
    self:SetChoice(r, kind)
    r.picks[Me()] = kind
    self:UpdateChips(r)
    self:FakeCheck(r)
end

function RF:FakeCheck(r)
    if r.done then return end
    for _, n in ipairs(r.roster) do if not r.picks[n] then return end end
    local gen = r.gen
    C_Timer.After(0.6, function()
        if r.gen ~= gen or r.done then return end
        local best, tier = nil, nil
        for _, n in ipairs(r.roster) do
            local p = r.picks[n]
            if p ~= "pass" then
                r.rolls[n] = math.random(100)
                local rank = (p == "need") and 2 or 1
                if not best or rank > tier or (rank == tier and r.rolls[n] > r.rolls[best]) then
                    best, tier = n, rank
                end
            end
        end
        RF:Finish(r, best)
    end)
end

--------------------------------------------------------------------------
-- Demodaten im Edit Mode: zwei stehende Zeilen ohne Timer
--------------------------------------------------------------------------

local previewRows = {}

local function PreviewRow(link, name, icon, quality, done)
    local r = Acquire()
    r.fake, r.preview = true, true
    Fill(r, link, icon, name, 1, quality, done == nil, 60)
    r.itemID, r.expires = nil, nil          -- nie mit echten Würfen verwechseln
    r.bar:SetValue(r.duration * 0.6)
    r.bar:SetStatusBarColor(0.9, 0.76, 0.42)
    SetupButtons(r, true, true)
    -- Nur zum Ansehen: Buttons gesperrt, sonst würde ein Klick einen Fake-Wurf starten
    for _, k in ipairs(KINDS) do r.btn[k]:Disable(); r.btn[k]:SetAlpha(0.6) end
    FillRoster(r)
    local n = r.roster
    r.picks[n[1]] = done and "pass" or nil
    r.picks[n[2]], r.picks[n[3]], r.picks[n[4]], r.picks[n[5]] = "need", "greed", "pass", "need"
    if done then
        r.rolls[n[2]], r.rolls[n[3]], r.rolls[n[5]] = 92, 34, 61
        r.done, r.winner = true, n[2]
        r.bar:Hide()
        for _, k in ipairs(KINDS) do r.btn[k]:Disable(); r.btn[k]:SetAlpha(0.3) end
    end
    previewRows[#previewRows + 1] = r
    RF:UpdateChips(r)
end

function RF:Preview(active)
    for _, r in ipairs(previewRows) do self:Remove(r) end
    wipe(previewRows)
    if not active then return end
    PreviewRow("|cffa335ee|Hitem:17063::::::::60:::::|h[Ring des Glutkerns]|h|r",
        "Ring des Glutkerns", "Interface\\Icons\\INV_Jewelry_Ring_36", 4)
    PreviewRow("|cff0070dd|Hitem:14551::::::::60:::::|h[Kettenkappe der Wachsamkeit]|h|r",
        "Kettenkappe der Wachsamkeit", "Interface\\Icons\\INV_Helmet_08", 3, true)
end

--------------------------------------------------------------------------

ns.Apply.roll = function()
    for _, r in ipairs(active) do RF:UpdateChips(r) end
    RF:Layout()
end

function RF:Init()
    -- Blizzards Gruppenwurf-Fenster abschalten
    UIParent:UnregisterEvent("START_LOOT_ROLL")
    UIParent:UnregisterEvent("CANCEL_LOOT_ROLL")
    if GroupLootContainer then GroupLootContainer:UnregisterAllEvents() end
    for i = 1, 4 do
        local f = _G["GroupLootFrame" .. i]
        if f then
            f:UnregisterAllEvents()
            f:HookScript("OnShow", function(self) self:Hide() end)
            f:Hide()
        end
    end

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("START_LOOT_ROLL")
    ev:RegisterEvent("CANCEL_LOOT_ROLL")
    ev:RegisterEvent("CHAT_MSG_LOOT")
    ev:SetScript("OnEvent", function(_, event, a, b)
        if event == "START_LOOT_ROLL" then RF:Start(a, b)
        elseif event == "CANCEL_LOOT_ROLL" then RF:OnCancel(a)
        else RF:OnChat(a) end
    end)
end
