local ADDON, ns = ...
local T = ns.T

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
local LABEL = { need = NEED or "Need", greed = GREED or "Greed", pass = PASS or "Pass" }   -- Blizzard-Texte, in jeder Clientsprache
local CHECK = "Interface/RaidFrame/ReadyCheck-Ready"
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
-- Reihenfolge wichtig: Die Muster mit "%s" für den Spieler passen auch auf die
-- Ich-Formen ("You won: ..." würde als Spieler "You" erkannt), daher zuerst SELF.
Def("LOOT_ROLL_NEED_SELF", "pick", I, "need")
Def("LOOT_ROLL_GREED_SELF", "pick", I, "greed")
Def("LOOT_ROLL_DISENCHANT_SELF", "pick", I, "greed")
Def("LOOT_ROLL_PASSED_SELF", "pick", I, "pass")
Def("LOOT_ROLL_PASSED_SELF_AUTO", "pick", I, "pass")
Def("LOOT_ROLL_YOU_WON", "won", I)
Def("LOOT_ROLL_NEED", "pick", PI, "need")
Def("LOOT_ROLL_GREED", "pick", PI, "greed")
Def("LOOT_ROLL_DISENCHANT", "pick", PI, "greed")
Def("LOOT_ROLL_PASSED", "pick", PI, "pass")
Def("LOOT_ROLL_PASSED_AUTO", "pick", PI, "pass")
Def("LOOT_ROLL_PASSED_AUTO_FEMALE", "pick", PI, "pass")
Def("LOOT_ROLL_ROLLED_NEED", "roll", { "roll", "item", "player" }, "need")
Def("LOOT_ROLL_ROLLED_GREED", "roll", { "roll", "item", "player" }, "greed")
Def("LOOT_ROLL_ROLLED_DE", "roll", { "roll", "item", "player" }, "greed")
Def("LOOT_ROLL_WON", "won", PI)
Def("LOOT_ROLL_ALL_PASSED", "allpassed", I)

local function Match(msg, d)
    local caps = { msg:match(d.pat) }
    if #caps == 0 then return end
    local out = {}
    -- Der Forever-Client stellt den Meldungen einen Link voran
    -- (|Hlootroll:<ID>|h[Loot]|h), dessen %d-Token in den Feldnamen nicht
    -- vorkommt. Solche führenden Tokens werden übersprungen.
    local skip = math.max(0, #d.tokens - #d.fields)
    for i, tk in ipairs(d.tokens) do
        local field = d.fields[tk.pos - skip]
        if field then out[field] = caps[i] end
    end
    return out
end

--------------------------------------------------------------------------
-- Zeilen
--------------------------------------------------------------------------

local function Me() return ns.Short(UnitName("player")) end

local function MakeButton(row, kind, x)
    local b = CreateFrame("Button", nil, row)
    b:SetSize(30, 30)
    b:SetPoint("TOPRIGHT", row, "TOPRIGHT", x, -6)
    b:SetNormalTexture(TEX[kind])
    b:SetPushedTexture((TEX[kind]:gsub("Up$", "Down")))
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b.kind = kind
    -- Auch gesperrte Buttons zeigen den Tooltip mit dem Grund (wie XLoot)
    b:SetMotionScriptsWhileDisabled(true)
    b:SetScript("OnClick", function(self)
        ns.Dbg("Klick", self.kind, "enabled", self:IsEnabled(), "rollID", row.rollID)
        RF:Choose(row, self.kind)
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.label or LABEL[self.kind])
        if self.reason then GameTooltip:AddLine(self.reason, 1, 0.3, 0.3, true) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

local function NewRow()
    local r = ns.Panel(ns.frames.roll)
    ns.ApplyStyle(r, "roll")
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
        if (r.nLines or 0) > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(T["Klick: Zeile ein- oder ausklappen"], 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    r.hit:SetScript("OnLeave", GameTooltip_Hide)
    r.hit:SetScript("OnClick", function()
        if IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP") then
            if r.link then HandleModifiedItemClick(r.link) end
        elseif (r.nLines or 0) > 0 then
            -- aktuellen Zustand umkehren; ab jetzt gilt die Wahl des Spielers
            r.userCollapsed = not r.compact
            RF:Layout()
        end
    end)

    r.arrow = r:CreateTexture(nil, "OVERLAY")
    r.arrow:SetSize(14, 14)
    r.arrow:SetPoint("TOPLEFT", 50, -10)

    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.name:SetPoint("TOPLEFT", 68, -8)
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

    -- Spielerzeilen (siehe UpdateChips): Trennlinie, eine Zeile je Spieler, Ergebnisstreifen
    r.sep = r:CreateTexture(nil, "ARTWORK")
    r.sep:SetColorTexture(1, 1, 1, 0.08)
    r.sep:SetHeight(1)
    r.sep:SetPoint("TOPLEFT", 8, -60)
    r.sep:SetPoint("TOPRIGHT", -8, -60)
    r.lines = {}
    -- Eingeklappte Zeile: eine Kurzzeile, Tooltip zeigt alle Spieler
    r.summary = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.summary:SetPoint("TOPLEFT", 10, -64)
    r.summary:SetPoint("TOPRIGHT", -10, -64)
    r.summary:SetJustifyH("LEFT")
    r.summary:SetWordWrap(false)
    r.sumBtn = CreateFrame("Button", nil, r)
    r.sumBtn:SetPoint("TOPLEFT", 6, -60)
    r.sumBtn:SetPoint("TOPRIGHT", -6, -60)
    r.sumBtn:SetHeight(22)
    r.sumBtn:SetScript("OnEnter", function(self) RF:ShowPlayerTip(r, self) end)
    r.sumBtn:SetScript("OnLeave", GameTooltip_Hide)
    r.resultBg = r:CreateTexture(nil, "ARTWORK")
    r.resultBg:SetColorTexture(0.91, 0.76, 0.42, 0.14)
    r.result = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.result:SetJustifyH("CENTER")

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
    -- Zeilen kommen aus dem Pool: ALLES zurücksetzen. Ein altes preview = true ließ
    -- Klicks auf Bedarf/Gier bei echten Würfen ins Leere laufen (Vorschauzeilen
    -- aus dem Edit Mode landen im Pool).
    r.preview, r.transmog, r.compact, r.userCollapsed = nil, false, false, nil
    r.fullH, r.nLines, r.names, r.expires = nil, 0, nil, nil
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

-- Kopf (Item, Buttons, Leiste) plus Kurzzeile
local COMPACT_H = 86

-- Spielerliste als Tooltip für eingeklappte Zeilen
function RF:ShowPlayerTip(r, owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(T["Würfe"], 1, 0.82, 0)
    for _, name in ipairs(r.names or {}) do
        local pick = r.picks[name]
        local right = pick and (LABEL[pick] .. (r.rolls[name] and ("  " .. r.rolls[name]) or "")) or "..."
        GameTooltip:AddDoubleLine(ns.ColorName(name) .. (r.winner == name and "  |T" .. CHECK .. ":14|t" or ""),
            right, 1, 1, 1, 0.9, 0.9, 0.9)
    end
    GameTooltip:Show()
end

-- Zeigt die Spielertabelle (voll) oder nur die Kurzzeile (eingeklappt)
local PLUS, MINUS = "Interface/Buttons/UI-PlusButton-Up", "Interface/Buttons/UI-MinusButton-Up"

local function ShowDetail(r, full)
    r.arrow:SetTexture(full and MINUS or PLUS)
    r.arrow:SetShown((r.nLines or 0) > 0)
    for i, l in ipairs(r.lines) do l:SetShown(full and i <= (r.nLines or 0)) end
    r.sep:SetShown(full and (r.nLines or 0) > 0)
    -- Ergebnisstreifen nur, wenn alle gepasst haben; sonst zeigt der Haken den Gewinner
    local showResult = full and r.done and not r.winner
    r.result:SetShown(showResult)
    r.resultBg:SetShown(showResult)
    r.summary:SetShown(not full)
    r.sumBtn:SetShown(not full)
end

function RF:Layout()
    local cfg, anchor = ns.cfg.roll, ns.frames.roll
    -- Wird die Liste zu hoch (viele Items gleichzeitig), klappen Zeilen auf den Kopf
    -- zusammen: erst entschiedene, dann solche, bei denen du schon gewählt hast, dann
    -- die ältesten. Wartet noch eine Wahl von dir, bleibt die Zeile möglichst offen.
    -- Vom Spieler eingeklappte Zeilen (Klick auf den Kopf) sind von Anfang an klein,
    -- vom Spieler ausgeklappte werden zuletzt automatisch eingeklappt.
    local total = 0
    for _, r in ipairs(active) do
        r.compact = r.userCollapsed == true and (r.fullH or 70) > COMPACT_H
        total = total + (r.compact and COMPACT_H or (r.fullH or 70)) + cfg.gap
    end
    if total > cfg.maxHeight then
        local order = {}
        for i, r in ipairs(active) do order[#order + 1] = { r = r, i = i } end
        local function rank(r)
            if r.userCollapsed == false then return 4 end
            return r.done and 1 or (r.chosen and 2 or 3)
        end
        table.sort(order, function(x, y)
            local rx, ry = rank(x.r), rank(y.r)
            if rx ~= ry then return rx < ry end
            return x.i < y.i
        end)
        for _, o in ipairs(order) do
            if total <= cfg.maxHeight then break end
            local r = o.r
            if not r.compact and (r.fullH or 70) > COMPACT_H then
                total = total - (r.fullH - COMPACT_H)
                r.compact = true
            end
        end
    end

    local y = 0
    for _, r in ipairs(active) do
        r:SetHeight(r.compact and COMPACT_H or (r.fullH or 70))
        ShowDetail(r, not r.compact)
        r:ClearAllPoints()
        if cfg.growUp then
            r:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, y)
        else
            r:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -y)
        end
        y = y + r:GetHeight() + cfg.gap
    end
end

-- Gibt den Namen zurück, unter dem der Spieler in dieser Zeile geführt wird.
-- Kurzer und langer Name ("Arak" / "Arak Ragerunner") sind derselbe Spieler: der
-- Eintrag wird auf den längeren Namen gestellt, vorhandene Daten ziehen mit um.
local function AddPlayer(r, name)
    name = ns.Short(name)   -- ohne Realm, sonst steht ein Spieler doppelt in der Liste
    for i, n in ipairs(r.roster) do
        if n == name then return n end
        if ns.SameName(n, name) then
            if #name <= #n then return n end
            r.roster[i] = name
            for _, t in ipairs({ r.picks, r.rolls }) do
                if t[n] ~= nil then t[name] = t[n]; t[n] = nil end
            end
            if r.winner == n then r.winner = name end
            ns.classByName[name] = ns.classByName[name] or ns.classByName[n]
            return name
        end
    end
    r.roster[#r.roster + 1] = name
    return name
end

-- Eine Spielerzeile: Wahl-Symbol, Name, rechts der Wurf, beim Gewinner ein Haken
local function GetLine(r, i)
    local l = r.lines[i]
    if l then return l end
    l = CreateFrame("Frame", nil, r)
    l:SetPoint("LEFT", r, "LEFT", 6, 0)
    l:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    l.bg = l:CreateTexture(nil, "BACKGROUND")
    l.bg:SetAllPoints()
    l.icon = l:CreateTexture(nil, "ARTWORK")
    l.icon:SetPoint("LEFT", 4, 0)
    l.name = l:CreateFontString(nil, "OVERLAY")
    l.name:SetJustifyH("LEFT")
    l.name:SetWordWrap(false)
    l.check = l:CreateTexture(nil, "OVERLAY")
    l.check:SetTexture(CHECK)
    l.check:SetPoint("RIGHT", -4, 0)
    l.roll = l:CreateFontString(nil, "OVERLAY")
    l.roll:SetJustifyH("RIGHT")
    l.roll:SetPoint("RIGHT", l.check, "LEFT", -4, 0)
    l.name:SetPoint("LEFT", l.icon, "RIGHT", 6, 0)
    l.name:SetPoint("RIGHT", l.roll, "LEFT", -6, 0)
    r.lines[i] = l
    return l
end

function RF:UpdateChips(r)
    local size = ns.cfg.roll.size
    local lh = size + 8                          -- Höhe einer Spielerzeile
    local names = {}
    if not ns.cfg.roll.hideRolls then
        names = { unpack(r.roster) }
        -- Beste Ergebnisse zuerst: Bedarf vor Gier vor Passen vor "noch keine Wahl",
        -- innerhalb davon der höchste Wurf oben
        local RANK = { need = 3, greed = 2, pass = 1 }
        table.sort(names, function(a, b)
            local ra, rb = RANK[r.picks[a]] or 0, RANK[r.picks[b]] or 0
            if ra ~= rb then return ra > rb end
            local xa, xb = r.rolls[a] or 0, r.rolls[b] or 0
            if xa ~= xb then return xa > xb end
            return a < b
        end)
    end

    local y = 66
    for i, name in ipairs(names) do
        local l = GetLine(r, i)
        local pick, roll = r.picks[name], r.rolls[name]
        local winner = r.winner == name
        l:SetHeight(lh)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", r, "TOPLEFT", 6, -y)
        l:SetPoint("TOPRIGHT", r, "TOPRIGHT", -6, -y)
        l.icon:SetSize(size + 2, size + 2)
        l.check:SetSize(size, size)
        l.name:SetFont(STANDARD_TEXT_FONT, size, "")
        l.roll:SetFont(STANDARD_TEXT_FONT, size + 1, "OUTLINE")
        if pick then
            l.icon:SetTexture(TEX[pick])
            l.icon:Show()
            l.name:SetText(ns.ColorName(name))
            l.roll:SetText(roll and tostring(roll) or "")
            l.roll:SetTextColor(winner and 1 or 0.95, winner and 0.82 or 0.95, winner and 0.2 or 0.95)
            -- Passen tritt optisch zurück
            l:SetAlpha(pick == "pass" and 0.55 or 1)
        else
            l.icon:Hide()
            l.name:SetText("|cff8a8a8a" .. ns.Short(name) .. "|r")
            l.roll:SetText("|cff8a8a8a…|r")
            l:SetAlpha(0.8)
        end
        l.check:SetShown(winner)
        -- Hintergrund: Gewinner golden, sonst feine Streifen
        if winner then
            l.bg:SetColorTexture(0.91, 0.76, 0.42, 0.20)
        else
            l.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.05 or 0)
        end
        y = y + lh
    end
    r.names, r.nLines = names, #names

    -- Ergebnis, sobald der Wurf entschieden ist
    local bottom = (#names > 0) and (y + 4) or 62
    if r.done and not r.winner then
        r.result:SetFont(STANDARD_TEXT_FONT, size + 1, "")
        r.result:SetText("|cffe8c26a" .. T["Alle haben gepasst"] .. "|r")
        r.result:ClearAllPoints()
        r.result:SetPoint("TOP", r, "TOP", 0, -(bottom + 5))
        r.resultBg:ClearAllPoints()
        r.resultBg:SetPoint("TOPLEFT", r, "TOPLEFT", 6, -bottom)
        r.resultBg:SetPoint("TOPRIGHT", r, "TOPRIGHT", -6, -bottom)
        r.resultBg:SetHeight(size + 12)
        bottom = bottom + size + 12
    end

    -- Kurzzeile für den eingeklappten Zustand
    local chosen = 0
    for _, name in ipairs(r.roster) do if r.picks[name] then chosen = chosen + 1 end end
    if r.done then
        r.summary:SetText(r.winner and T("%s gewinnt (%s)", ns.ColorName(r.winner), LABEL[r.picks[r.winner] or "greed"]
            .. (r.rolls[r.winner] and (" " .. r.rolls[r.winner]) or "")) or T["Alle haben gepasst"])
    else
        r.summary:SetText("|cffaaaaaa" .. T("%d von %d haben gewählt", chosen, #r.roster) .. "|r")
    end
    r.fullH = bottom + 8
    self:Layout()
end

-- Bei Transmog-Würfen ist "Gier" gesperrt und der Button würfelt stattdessen auf
-- Transmog (Typ 4, wie bei XLoot). transmog = true stellt ihn entsprechend um.
local TRANSMOG_TEX = "Interface/MINIMAP/TRACKING/Transmogrifier"

local function SetupButtons(r, canNeed, canGreed, reasonNeed, reasonGreed, transmog)
    r.transmog = transmog and true or false
    local g = r.btn.greed
    g.label = r.transmog and (TRANSMOGRIFY or "Transmog") or nil
    g:SetNormalTexture(r.transmog and TRANSMOG_TEX or TEX.greed)
    g:SetPushedTexture(r.transmog and TRANSMOG_TEX or (TEX.greed:gsub("Up$", "Down")))
    for _, k in ipairs(KINDS) do
        local b = r.btn[k]
        local ok = (k ~= "need" or canNeed) and (k ~= "greed" or canGreed or r.transmog)
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
    r.sub:SetText(bop and (ITEM_BIND_ON_PICKUP or "Binds when picked up") or "")
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
    local tex, name, count, quality, bop, canNeed, canGreed, canDE, reasonNeed, reasonGreed, _, _, canTransmog = GetLootRollItemInfo(rollID)
    ns.Dbg("Start", rollID, name, "need", canNeed, "greed", canGreed, "de", canDE,
        "reasons", reasonNeed, reasonGreed, "transmog", canTransmog)
    if not name then return end
    local r = Acquire()
    r.rollID = rollID
    Fill(r, GetLootRollItemLink(rollID), tex, name, count, quality, bop, (rollTime or 60000) / 1000)
    SetupButtons(r, canNeed, canGreed, reasonNeed, reasonGreed, canTransmog)
    self:UpdateChips(r)
end

function RF:Choose(r, kind)
    if r.preview then return end
    if r.fake then return self:FakeChoose(r, kind) end
    -- Die Buttons werden erst gesperrt, wenn die eigene Wahl im Chat bestätigt
    -- ist (OnChat). Bei Bind-on-Pickup-Items fragt Blizzard erst nach; bricht
    -- man dort ab, muss man noch einmal wählen können.
    local rolltype = (kind == "greed" and r.transmog) and 4 or ROLLTYPE[kind]
    ns.Dbg("RollOnLoot", r.rollID, "Typ", rolltype, "preview", r.preview, "fake", r.fake, "chosen", r.chosen, "done", r.done)
    RollOnLoot(r.rollID, rolltype)
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
    if winner and not r.preview then
        ns.Winner:Display(winner, r.link, r.picks[winner] or "greed", r.rolls[winner])
    end
    -- Das Fenster bleibt nach dem Wurf noch einige Sekunden stehen
    local gen = r.gen
    C_Timer.After(ns.cfg.roll.hold, function() if r.gen == gen then RF:Remove(r) end end)
end

function RF:OnChat(msg)
    for _, d in ipairs(DEFS) do
        local t = Match(msg, d)
        if t then
            local id = ns.ItemID(t.item)
            local player = ns.Short(t.player or Me())
            local r = FindRow(id)
            if d.kind == "pick" and r then
                player = AddPlayer(r, player)
                r.picks[player] = d.choice
                if ns.SameName(player, Me()) and not r.chosen then self:SetChoice(r, d.choice) end
                self:UpdateChips(r)
            elseif d.kind == "roll" and r then
                player = AddPlayer(r, player)
                r.picks[player] = r.picks[player] or d.choice
                r.rolls[player] = tonumber(t.roll)
                self:UpdateChips(r)
            elseif d.kind == "won" then
                ns.Feed:NoteWin(player, id)
                if r then
                    player = AddPlayer(r, player)
                    r.picks[player] = r.picks[player] or "greed"
                    self:Finish(r, player)
                else
                    ns.Feed:AddWin(player, t.item)
                    ns.Winner:Display(player, t.item)
                end
            elseif d.kind == "allpassed" then
                if r then self:Finish(r, nil) end
            end
            return
        end
    end
end

-- Läuft der Wurf noch? Restzeit des Clients oder, falls vorhanden, die Loot-Historie
local function RollStillOpen(rollID)
    if GetLootRollTimeLeft and (GetLootRollTimeLeft(rollID) or 0) > 0 then return true end
    local H = C_LootHistory
    if H and H.GetItem and H.GetNumItems then
        for hid = 1, H.GetNumItems() do
            local id, _, _, done = H.GetItem(hid)
            if id == rollID then return not done end
        end
    end
    return false
end

function RF:OnCancel(rollID)
    -- UIParent schließt den Bestätigungsdialog sonst selbst, aber wir haben
    -- CANCEL_LOOT_ROLL dort abgemeldet.
    StaticPopup_Hide("CONFIRM_LOOT_ROLL", rollID)
    local r = FindRow(nil, rollID)
    if not r or r.done then return end
    -- Die Gewinnernachricht kommt oft kurz nach CANCEL_LOOT_ROLL. Der Client
    -- schickt das Ereignis aber auch, wenn nur DU fertig gewählt hast, während
    -- andere noch würfeln. Darum erst entfernen, wenn der Wurf wirklich vorbei
    -- ist (keine Restzeit mehr), sonst erneut nachsehen.
    local gen = r.gen
    local function check()
        if r.gen ~= gen or r.done then return end
        if RollStillOpen(rollID) and r.expires and GetTime() < r.expires + 5 then
            C_Timer.After(5, check)
        else
            RF:Remove(r)
        end
    end
    C_Timer.After(8, check)
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
    -- Der Edit-Mode-Rahmen zeigt die maximale Höhe der Liste
    ns.frames.roll:SetHeight(ns.cfg.roll.maxHeight)
    for _, r in ipairs(pool) do ns.ApplyStyle(r, "roll") end
    for _, r in ipairs(active) do
        ns.ApplyStyle(r, "roll")
        RF:UpdateChips(r)
    end
    RF:Layout()
end

-- Nach /reload kennt das Addon laufende Würfe nicht mehr (START_LOOT_ROLL kam
-- schon vorher). Sie werden aus der Liste der aktiven Würfe neu aufgebaut, mit
-- der Restzeit des Clients. Wahlen anderer Spieler stehen nur im Chat und sind
-- nach einem Reload nicht mehr bekannt, neue kommen wieder normal dazu.
-- Die Loot-Historie des Clients kennt alle bisherigen Wahlen und Würfe eines
-- laufenden Wurfs und übersteht einen Reload (auf manchen Clients fehlt sie).
-- rollType: 0 Passen, 1 Bedarf, 2 Gier, 3 Entzaubern (zählt als Gier)
local PICK_BY_TYPE = { [0] = "pass", [1] = "need", [2] = "greed", [3] = "greed", [4] = "greed" }

function RF:ImportHistory(r)
    local H = C_LootHistory
    if not (H and H.GetItem and H.GetPlayerInfo and H.GetNumItems and r.rollID) then return end
    for hid = 1, H.GetNumItems() do
        local rollID, _, players = H.GetItem(hid)
        if rollID == r.rollID then
            for j = 1, players or 0 do
                local name, class, rtype, roll = H.GetPlayerInfo(hid, j)
                if name then
                    name = AddPlayer(r, name)
                    if class then ns.classByName[name] = ns.classByName[name] or class end
                    local pick = rtype and PICK_BY_TYPE[rtype]
                    if pick then
                        r.picks[name] = pick
                        -- die eigene Wahl vor dem Reload: Buttons wieder sperren
                        if ns.SameName(name, Me()) and not r.chosen then self:SetChoice(r, pick) end
                    end
                    if roll then r.rolls[name] = roll end
                end
            end
            self:UpdateChips(r)
            return
        end
    end
end

function RF:Restore()
    if not GetLootRollTimeLeft or not IsInGroup() then return end
    -- Wie XLoot: die Roll-IDs durchprobieren, aktive haben eine Restzeit > 0
    for rollID = 1, 300 do
        local left = GetLootRollTimeLeft(rollID) or 0
        if left > 0 and left < 300000 and not FindRow(nil, rollID) then
            self:Start(rollID, left)
        end
    end
    -- Wahlen und Würfe, die vor dem Reload schon gefallen sind
    for _, r in ipairs(active) do
        if r.rollID and not r.fake and not r.done then self:ImportHistory(r) end
    end
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
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- Blockierte Aktionen sichtbar machen (nur im Debug-Modus)
    pcall(ev.RegisterEvent, ev, "ADDON_ACTION_FORBIDDEN")
    pcall(ev.RegisterEvent, ev, "ADDON_ACTION_BLOCKED")
    ev:SetScript("OnEvent", function(_, event, a, b)
        if event == "ADDON_ACTION_FORBIDDEN" or event == "ADDON_ACTION_BLOCKED" then
            if a == ADDON then ns.Dbg("BLOCKIERT:", b) end
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Iteminfos sind direkt beim Laden oft noch nicht da
            -- zweiter Versuch, falls das Item beim ersten noch nicht geladen war
            C_Timer.After(1, function() RF:Restore() end)
            C_Timer.After(4, function() RF:Restore() end)
        elseif event == "START_LOOT_ROLL" then RF:Start(a, b)
        elseif event == "CANCEL_LOOT_ROLL" then RF:OnCancel(a)
        else RF:OnChat(a) end
    end)
end
