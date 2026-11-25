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
local win   -- Fenster "Gruppenwurf" mit Goldrahmen und Band; die Zeilen sind Karten darin

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

-- Die drei Wahl-Buttons stehen nebeneinander unter der Leiste (Symbol + Text); alles darunter rückt um BTN_OFF
local BTN_H, BTN_GAP = 22, 4
-- Würfel und Münze sitzen in ihren Bildern etwas hoch: nach unten rücken, damit sie mit der Schrift in einer Linie stehen
local ICON_DY = { need = -2, greed = -2 }
local BTN_OFF = BTN_H + 12
local BTN_W = (WIDTH - 16 - 12 - 2 * BTN_GAP) / 3

local function MakeButton(row, kind, index)
    local b = CreateFrame("Button", nil, row)
    b:SetSize(BTN_W, BTN_H)
    b:SetPoint("TOPLEFT", row, "TOPLEFT", 6 + (index - 1) * (BTN_W + BTN_GAP), -62)
    b.kind = kind
    -- flache dunkle Fläche
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(0.075, 0.062, 0.04, 1)
    -- Rand wie bei den Fenstern (Tooltip-Rand); beim Darüberfahren heller, bei der gewählten Antwort voll golden
    b.rim = CreateFrame("Frame", nil, b, "BackdropTemplate")
    b.rim:SetAllPoints(b)
    b.rim:SetFrameLevel(b:GetFrameLevel() + 2)
    b.rim:SetBackdrop({ edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10 })
    b.rim:SetBackdropBorderColor(0.42, 0.34, 0.15, 1)
    -- Hover: Fläche hellt leicht auf, zarter goldener Rand; gewählt: voller goldener Rand
    b.hover = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.hover:SetAllPoints()
    b.hover:SetColorTexture(1, 0.9, 0.62, 0.12)
    b.hover:Hide()
    function b:UpdateEdges()
        if self.chosen then self.rim:SetBackdropBorderColor(0.91, 0.76, 0.42, 1)
        elseif self.hovering then self.rim:SetBackdropBorderColor(0.7, 0.58, 0.3, 1)
        else self.rim:SetBackdropBorderColor(0.42, 0.34, 0.15, 1) end
    end
    function b:ShowChosen(on)
        self.chosen = on and true or false
        self:UpdateEdges()
    end
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(BTN_H - 4, BTN_H - 4)
    b.icon:SetTexture(TEX[kind])
    b.text = b:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
    b.text:SetWordWrap(false)
    b.text:SetTextColor(0.95, 0.92, 0.86)   -- helle Schrift; gesperrte Buttons werden über die Deckkraft gedämpft
    -- Symbol und Text als Gruppe mittig im Button (dy: Versatz beim Drücken)
    function b:SetLabel(text, dy)
        self.text:SetText(text)
        local iw = BTN_H - 4
        local labels = ns.cfg.roll.btnLabels ~= false
        self.text:SetShown(labels)
        local x = math.floor((BTN_W - (iw + (labels and (4 + self.text:GetStringWidth()) or 0))) / 2 + 0.5)
        self.icon:ClearAllPoints()
        self.icon:SetPoint("LEFT", self, "LEFT", math.max(2, x), (dy or 0) + (ICON_DY[self.kind] or 0))
    end
    b:SetLabel(LABEL[kind])
    b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self:SetLabel(self.text:GetText(), -1) end end)
    b:SetScript("OnMouseUp", function(self) self:SetLabel(self.text:GetText()) end)
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
        if self:IsEnabled() then
            self.hovering = true
            self.hover:Show()
            self.text:SetTextColor(1, 0.97, 0.88)
            self:UpdateEdges()
        end
    end)
    b:SetScript("OnLeave", function(self)
        GameTooltip_Hide()
        self.hovering = false
        self.hover:Hide()
        self.text:SetTextColor(0.95, 0.92, 0.86)
        self:UpdateEdges()
    end)
    return b
end

local function NewRow()
    -- Karte in Zeilenfarbe des Questfensters, im Fenster "Gruppenwurf"
    local r = CreateFrame("Frame", nil, win)
    r.fill = r:CreateTexture(nil, "BACKGROUND")
    r.fill:SetAllPoints()
    r.fill:SetColorTexture(0.145, 0.125, 0.10, 1)
    r:SetWidth(WIDTH - 16)
    r:SetHeight(70 + BTN_OFF)

    r.qual = r:CreateTexture(nil, "BACKGROUND")
    r.qual:SetSize(40, 40)
    r.qual:SetPoint("TOPLEFT", 4, -4)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(36, 36)
    r.icon:SetPoint("TOPLEFT", 6, -6)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    r.hit = CreateFrame("Button", nil, r)
    r.hit:SetPoint("TOPLEFT", 6, -6)
    r.hit:SetPoint("BOTTOMRIGHT", r, "TOPRIGHT", -8, -42)
    r.hit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        -- Läuft der Wurf noch, kennt das Spiel das Item über die Roll-ID. Ist er entschieden,
        -- ist die ID ungültig (leerer Tooltip): dann gilt der Item-Link.
        if r.rollID and not r.fake and not r.done then GameTooltip:SetLootRollItem(r.rollID)
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

    r.name = r:CreateFontString(nil, "OVERLAY", "SexyLootText")
    r.name:SetPoint("TOPLEFT", 52, -8)
    r.name:SetPoint("RIGHT", r, "RIGHT", -8, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.nameFont = { r.name:GetFont() }
    r.sub = r:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
    r.sub:SetTextColor(0.6, 0.55, 0.45)
    -- Rüstungsklasse (Stoff, Leder, Kette, Platte) als Etikett unter dem Namen; "Bindet beim Aufheben" rückt daneben
    r.armor = ns.Pill(r)
    r.armor.tex:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
    r.armor:Hide()

    r.btn = {}
    r.btn.need  = MakeButton(r, "need", 1)
    r.btn.greed = MakeButton(r, "greed", 2)
    r.btn.pass  = MakeButton(r, "pass", 3)

    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetPoint("TOPLEFT", 6, -50)
    r.bar:SetPoint("TOPRIGHT", -6, -50)
    r.bar:SetHeight(6)
    r.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    r.bar.bg = r.bar:CreateTexture(nil, "BACKGROUND")
    r.bar.bg:SetAllPoints()
    r.bar.bg:SetColorTexture(0, 0, 0, 0.6)
    local SEM = LibStub("SexyEditMode-1.0", true)
    if SEM and SEM.ShineBar then SEM:ShineBar(r.bar, { radius = 3, surround = { 0.145, 0.125, 0.10 } }) end   -- gläserner Glanz, runde Ecken

    -- Spielerzeilen (siehe UpdateChips): Trennlinie, eine Zeile je Spieler, Ergebnisstreifen
    r.sep = r:CreateTexture(nil, "ARTWORK")
    r.sep:SetColorTexture(0.21, 0.19, 0.14, 1)
    r.sep:SetHeight(1)
    r.sep:SetPoint("TOPLEFT", 8, -(60 + BTN_OFF))
    r.sep:SetPoint("TOPRIGHT", -8, -(60 + BTN_OFF))
    r.lines = {}
    -- Eingeklappte Zeile: eine Kurzzeile, Tooltip zeigt alle Spieler
    r.summary = r:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    r.summary:SetPoint("TOPLEFT", 10, -(64 + BTN_OFF))
    r.summary:SetPoint("TOPRIGHT", -10, -(64 + BTN_OFF))
    r.summary:SetJustifyH("LEFT")
    r.summary:SetWordWrap(false)
    r.sumBtn = CreateFrame("Button", nil, r)
    r.sumBtn:SetPoint("TOPLEFT", 6, -(60 + BTN_OFF))
    r.sumBtn:SetPoint("TOPRIGHT", -6, -(60 + BTN_OFF))
    r.sumBtn:SetHeight(22)
    r.sumBtn:SetScript("OnEnter", function(self) RF:ShowPlayerTip(r, self) end)
    r.sumBtn:SetScript("OnLeave", GameTooltip_Hide)
    r.resultBg = r:CreateTexture(nil, "ARTWORK")
    r.resultBg:SetColorTexture(0.91, 0.76, 0.42, 0.14)
    r.result = r:CreateFontString(nil, "OVERLAY", "SexyLootTitle")
    r.result:SetJustifyH("CENTER")

    -- Rest-Anzeige der Leiste: vor der Entscheidung die Rollzeit, danach die Zeit,
    -- bis die Zeile verschwindet
    r.timerText = r:CreateFontString(nil, "OVERLAY", "SexyLootDim")
    r.timerText:SetPoint("TOPRIGHT", r, "TOPRIGHT", -8, -33)
    r.timerText:SetJustifyH("RIGHT")

    r:SetScript("OnUpdate", function(self)
        if not self.expires then return end
        local left = math.max(0, self.expires - GetTime())
        self.bar:SetValue(left)
        if self.done then
            self.bar:SetStatusBarColor(0.55, 0.6, 0.7)
            self.timerText:SetText(T("Schließt in %ds", math.ceil(left)))
        elseif left < self.duration * 0.25 then
            self.bar:SetStatusBarColor(0.85, 0.28, 0.17)
            -- Zeit wird knapp: die Leiste pulsiert
            if ns.Motion.On() then self.bar:SetAlpha(0.65 + 0.35 * math.sin(GetTime() * 6)) end
        else
            self.bar:SetStatusBarColor(0.9, 0.76, 0.42)
        end
    end)
    r.gen = 0
    -- Karte schneidet Inhalt ab, solange sie beim Auf- und Zuklappen wächst; Streifen für den Gewinn
    if r.SetClipsChildren then r:SetClipsChildren(true) end
    r.sweep = ns.Motion.NewSweep(r)
    return r
end

local function Acquire()
    local r = table.remove(pool) or NewRow()
    r.picks, r.rolls, r.roster = {}, {}, {}
    r.done, r.winner, r.chosen, r.fake, r.rollID = false, nil, nil, false, nil
    -- Zeilen kommen aus dem Pool: ALLES zurücksetzen. Ein altes preview = true ließ
    -- Klicks auf Bedarf/Gier bei echten Würfen ins Leere laufen (Vorschauzeilen
    -- aus dem Edit Mode landen im Pool).
    r.preview, r.transmog, r.compact, r.userCollapsed, r.pending = nil, false, false, nil, nil
    r.fullH, r.nLines, r.names, r.expires = nil, 0, nil, nil
    r.timerText:SetText("")
    r.bar:SetShown(ns.cfg.roll.showBar ~= false)
    -- Animationen der Karte und ihrer Zeilen zurücksetzen (Karte kommt aus dem Pool)
    ns.Motion.Cancel(r)
    ns.Motion.Cancel(r.sweep)
    r.placed, r.curH, r.toH, r.enterOff, r.yOff, r.lastStack, r.chipsDone = false, nil, nil, 0, 0, nil, false
    r.lineOf = {}
    r:SetAlpha(1)
    r.bar:SetAlpha(1)
    for _, l in ipairs(r.lines) do
        ns.Motion.Cancel(l)
        ns.Motion.Cancel(l.sweep)
        l.owner, l.used, l.y, l.curY, l.shownPick, l.shownRoll, l.swept, l.counting = nil, false, nil, nil, nil, nil, false, nil
        l.pickIcon:SetAlpha(1)
        l:Hide()
    end
    r:Show()
    ns.FadeIn(r)
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
    r.timerText:SetText("")
    ns.Motion.Cancel(r)
    if ns.Motion.On() and r:IsShown() and win and win:IsShown() then
        -- blendet an Ort und Stelle aus und kommt erst danach in den Pool
        ns.Motion.Tween(r, "out", 1, 0, 0.2, function(v) r:SetAlpha(v) end, function()
            r:Hide()
            r:SetAlpha(1)
            pool[#pool + 1] = r
        end)
    else
        r:Hide()
        pool[#pool + 1] = r
    end
    self:Layout()
end

-- Kopf (Item, Buttons, Leiste) plus Kurzzeile
local COMPACT_H = 86 + BTN_OFF
local FULL_H = 70 + BTN_OFF   -- Karte ohne Spielerzeilen

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

-- Zeigt die Spielertabelle (voll) oder nur die Kurzzeile (eingeklappt). Ein-/Ausklappen: Klick auf den Kopf (r.hit)
local function ShowDetail(r, full)
    for _, l in ipairs(r.lines) do l:SetShown(full and l.used and true or false) end
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
    if not win then return end
    -- Für die Karten bleibt die maximale Höhe abzüglich Band und Rand
    local limit = cfg.maxHeight - (win.headH + 16)
    local total = 0
    for _, r in ipairs(active) do
        r.compact = r.userCollapsed == true and (r.fullH or FULL_H) > COMPACT_H
        total = total + (r.compact and COMPACT_H or (r.fullH or FULL_H)) + cfg.gap
    end
    if total > limit then
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
            if total <= limit then break end
            local r = o.r
            if not r.compact and (r.fullH or FULL_H) > COMPACT_H then
                total = total - (r.fullH - COMPACT_H)
                r.compact = true
            end
        end
    end

    -- Höhen und Einblenden laufen als Übergang; Place setzt die Karten danach untereinander
    local M = ns.Motion
    for _, r in ipairs(active) do
        local target = r.compact and COMPACT_H or (r.fullH or FULL_H)
        ShowDetail(r, not r.compact)
        if not r.placed then
            r.placed, r.curH = true, target
            M.Tween(r, "enter", 12, 0, 0.22, function(v) r.enterOff = v; RF:Place(false) end)
        elseif r.curH ~= target and r.toH ~= target then
            r.toH = target
            M.Tween(r, "h", r.curH, target, 0.22, function(v) r.curH = v; RF:Place(false) end, function() r.toH = nil end)
        end
    end
    self:Place(true)
end

-- Karten untereinander setzen (mit der aktuellen, ggf. noch wachsenden Höhe) und das Fenster darum legen.
-- structural: Karten wurden eingefügt oder entfernt, verschobene Karten gleiten an ihren neuen Platz.
function RF:Place(structural)
    local cfg, anchor = ns.cfg.roll, ns.frames.roll
    if not win then return end
    local M = ns.Motion
    local y, starts = 0, nil
    for _, r in ipairs(active) do
        local h = r.curH or (r.compact and COMPACT_H or (r.fullH or FULL_H))
        if structural and r.lastStack and r.lastStack ~= y then
            starts = starts or {}
            starts[#starts + 1] = { r, (r.yOff or 0) + (r.lastStack - y) }
        end
        r.lastStack = y
        local pos, e = y + (r.yOff or 0), r.enterOff or 0
        r:SetHeight(h)
        r:ClearAllPoints()
        if cfg.growUp then
            r:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 8, 8 + pos - e)
        else
            r:SetPoint("TOPLEFT", win, "TOPLEFT", 8, -(win.headH + 8 + pos) + e)
        end
        y = y + h + cfg.gap
    end

    -- Das Fenster umschließt alle Karten und hängt oben (oder steht unten bei "nach oben").
    -- Ohne Karten blendet es aus, statt zu verschwinden.
    if #active > 0 then
        if win.fading then
            win.fading = false
            M.Cancel(win, "fade")
            win:SetAlpha(1)
        end
        win:ClearAllPoints()
        win:SetPoint(cfg.growUp and "BOTTOMLEFT" or "TOPLEFT", anchor, cfg.growUp and "BOTTOMLEFT" or "TOPLEFT")
        win:SetWidth(WIDTH)
        win:SetHeight(win.headH + 16 + math.max(0, y - cfg.gap))
        win:SetBadge(#active .. " " .. (#active == 1 and T["Gegenstand"] or T["Gegenstände"]))
        win:Show()
    elseif win:IsShown() and not win.fading then
        if M.On() then
            win.fading = true
            M.Tween(win, "fade", 1, 0, 0.2, function(v) win:SetAlpha(v) end, function()
                win.fading = false
                win:SetAlpha(1)
                if #active == 0 then win:Hide() end
            end)
        else
            win:Hide()
        end
    end

    if starts then
        for _, st in ipairs(starts) do
            local r = st[1]
            M.Tween(r, "yoff", st[2], 0, 0.25, function(v) r.yOff = v; RF:Place(false) end)
        end
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
-- Setzt eine Spielerzeile auf y; verschiebt sie sich, gleitet sie (animate)
local function PlaceLine(l, r, y, animate)
    local function put(v)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", r, "TOPLEFT", 6, -v)
        l:SetPoint("TOPRIGHT", r, "TOPRIGHT", -6, -v)
    end
    if animate and l.y and l.y ~= y then
        ns.Motion.Tween(l, "y", l.curY or l.y, y, 0.25, function(v) l.curY = v; put(v) end)
    else
        ns.Motion.Cancel(l, "y")
        l.curY = y
        put(y)
    end
    l.y = y
end

-- Eine Zeile gehört einem Spieler und bleibt bei ihm, auch wenn sich die Reihenfolge ändert
local function GetLine(r, name)
    local l = r.lineOf[name]
    if l then return l end
    for _, x in ipairs(r.lines) do
        if not x.owner then l = x break end
    end
    if l then
        l.owner, l.y, l.shownPick, l.shownRoll, l.swept = name, nil, nil, nil, false
        r.lineOf[name] = l
        return l
    end
    l = CreateFrame("Frame", nil, r)
    l:SetPoint("LEFT", r, "LEFT", 6, 0)
    l:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    l.bg = l:CreateTexture(nil, "BACKGROUND")
    l.bg:SetAllPoints()
    l.name = l:CreateFontString(nil, "OVERLAY")
    l.name:SetJustifyH("LEFT")
    l.name:SetWordWrap(false)
    l.check = l:CreateTexture(nil, "OVERLAY")
    l.check:SetTexture(CHECK)
    l.check:SetPoint("RIGHT", -4, 0)
    l.roll = l:CreateFontString(nil, "OVERLAY")
    l.roll:SetJustifyH("RIGHT")
    l.roll:SetWordWrap(false)
    l.roll:SetWidth(40)   -- "100" in der größeren Schrift braucht mehr als 28 px
    l.roll:SetPoint("RIGHT", l.check, "LEFT", -4, 0)
    -- Wahl als Symbol (Würfel, Münze, Passen) vor dem Namen; ohne Wahl bleibt der Platz leer
    l.pickIcon = l:CreateTexture(nil, "ARTWORK")
    l.pickIcon:SetPoint("LEFT", l, "LEFT", 6, 0)
    l.name:SetPoint("LEFT", l.pickIcon, "RIGHT", 6, 0)
    l.name:SetPoint("RIGHT", l.roll, "LEFT", -6, 0)
    l.sweep = ns.Motion.NewSweep(l)
    l.owner = name
    r.lineOf[name] = l
    r.lines[#r.lines + 1] = l
    return l
end

-- Darstellung einer Karte nach den Einstellungen: Deckkraft, Schrift, Etiketten, Leiste, Zeit, Button-Beschriftung
function RF:Look(r)
    local cfg = ns.cfg.roll
    r.fill:SetColorTexture(0.145, 0.125, 0.10, cfg.cardOpacity or 1)
    if (cfg.nameSize or 0) > 0 then
        r.name:SetFont(r.nameFont[1], cfg.nameSize, r.nameFont[3])
    elseif r.nameFont[1] then
        r.name:SetFont(unpack(r.nameFont))
    end
    r.sub:ClearAllPoints()
    if r.armorName and cfg.showArmor ~= false then
        r.armor:Set("grey", r.armorName, nil, 16)
        r.sub:SetPoint("LEFT", r.armor.tex, "RIGHT", 6, 0)
    else
        r.armor:Hide()
        r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
    end
    r.sub:SetShown(cfg.showBound ~= false)
    if cfg.showBar == false then r.bar:Hide() elseif r.expires then r.bar:Show() end
    r.timerText:SetShown(cfg.showTimer ~= false)
    for _, k in ipairs(KINDS) do r.btn[k]:SetLabel(r.btn[k].text:GetText()) end
end

function RF:UpdateChips(r)
    local size = ns.cfg.roll.size
    local lh = size + 8 + (ns.cfg.roll.lineGap or 0)                         -- Höhe einer Spielerzeile
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

    local y = 66 + BTN_OFF
    for i, name in ipairs(names) do
        local l = GetLine(r, name)
        l.used = true
        local pick, roll = r.picks[name], r.rolls[name]
        local winner = r.winner == name
        l:SetHeight(lh)
        PlaceLine(l, r, y, r.chipsDone)
        l.check:SetSize(size, size)
        l.pickIcon:SetSize(size + 4, size + 4)
        l.name:SetFont(ns.FONT_TEXT, size, "")
        l.roll:SetFont(ns.FONT_TEXT, size + 1, "OUTLINE")
        if pick then
            l.pickIcon:SetTexture(TEX[pick])
            l.pickIcon:Show()
            l.name:SetText(ns.ColorName(name))
            if not l.counting then l.roll:SetText(roll and tostring(roll) or "") end
            l.roll:SetTextColor(winner and 1 or 0.95, winner and 0.82 or 0.95, winner and 0.2 or 0.95)
            -- Passen tritt optisch zurück
            l:SetAlpha(pick == "pass" and 0.55 or 1)
        else
            l.pickIcon:Hide()
            l.name:SetText("|cff8a8a8a" .. ns.Short(name) .. "|r")
            l.roll:SetText("|cff8a8a8a…|r")
            l:SetAlpha(0.8)
        end
        -- Bewegung: neue Wahl blendet das Etikett ein, ein neuer Wurf zählt hoch, der Gewinner bekommt einen Lichtstreifen
        l.pickIcon:SetAlpha(1)
        if r.chipsDone then
            if pick and l.shownPick ~= pick then
                ns.Motion.Tween(l, "pop", 0, 1, 0.3, function(v) l.pickIcon:SetAlpha(v) end)
            end
            if roll and l.shownRoll ~= roll then ns.Motion.CountTo(l, l.roll, roll, 0.5) end
        end
        if not winner then l.swept = false end
        l.shownPick, l.shownRoll = pick, roll
        l.check:SetShown(winner and ns.cfg.roll.showCheck ~= false)
        -- Hintergrund: Gewinner golden, sonst feine Streifen
        if winner then
            l.bg:SetColorTexture(0.91, 0.76, 0.42, 0.20)
        else
            l.bg:SetColorTexture(1, 1, 1, (ns.cfg.roll.zebra ~= false and i % 2 == 0) and 0.05 or 0)
        end
        y = y + lh
    end
    r.names, r.nLines = names, #names
    -- Zeilen von Spielern, die nicht mehr in der Liste stehen, frei geben
    local listed = {}
    for _, name in ipairs(names) do listed[name] = true end
    for _, l in ipairs(r.lines) do
        if l.owner and not listed[l.owner] then
            r.lineOf[l.owner] = nil
            l.owner, l.used = nil, false
            ns.Motion.Cancel(l)
            l:Hide()
        end
    end

    -- Ergebnis, sobald der Wurf entschieden ist
    local bottom = (#names > 0) and (y + 4) or (62 + BTN_OFF)
    if r.done and not r.winner then
        r.result:SetFont(ns.FONT_TEXT, size + 1, "")
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
    r.chipsDone = true   -- ab jetzt dürfen Änderungen animiert werden (die erste Füllung springt)
    self:Layout()
end

-- Bei Transmog-Würfen ist "Gier" gesperrt und der Button würfelt stattdessen auf
-- Transmog (Typ 4, wie bei XLoot). transmog = true stellt ihn entsprechend um.
local TRANSMOG_TEX = "Interface/MINIMAP/TRACKING/Transmogrifier"

local function SetupButtons(r, canNeed, canGreed, reasonNeed, reasonGreed, transmog)
    r.transmog = transmog and true or false
    local g = r.btn.greed
    g.label = r.transmog and (TRANSMOGRIFY or "Transmog") or nil
    -- Symbol bleibt klein links vom Text (das Transmog-Bild füllte den ganzen Button); bei Transmog sagt es der Text
    g.icon:SetTexture(TEX.greed)
    g.icon:SetTexCoord(0, 1, 0, 1)
    g.icon:SetSize(BTN_H - 4, BTN_H - 4)
    g:SetLabel(g.label or LABEL.greed)
    -- Liefert der Client die Berechtigungen noch nicht (nil statt true/false, Item noch nicht geladen), bleiben alle
    -- Buttons offen und werden gleich nochmal geprüft; sonst konnte man manchmal nicht würfeln
    local unknown = canNeed == nil and canGreed == nil
    for _, k in ipairs(KINDS) do
        local b = r.btn[k]
        local ok = unknown or ((k ~= "need" or canNeed) and (k ~= "greed" or canGreed or r.transmog))
        b.reason = nil
        if k == "need" and not canNeed and reasonNeed then b.reason = _G["LOOT_ROLL_INELIGIBLE_REASON" .. reasonNeed] end
        if k == "greed" and not canGreed and reasonGreed then b.reason = _G["LOOT_ROLL_INELIGIBLE_REASON" .. reasonGreed] end
        b:SetEnabled(ok)
        b:ShowChosen(false)   -- Aussehen immer normal; nur die eigene Wahl bekommt einen goldenen Rahmen
    end
end

function RF:SetChoice(r, kind)
    r.chosen = kind
    for _, k in ipairs(KINDS) do
        r.btn[k]:Disable()
        r.btn[k]:ShowChosen(k == kind)
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
    -- Rüstungsklasse nur bei echter Rüstung (Klasse 4, Unterklasse 1-4); Schilde, Schmuck usw. bekommen keins
    local armorName
    local _, itemType, subType, equipLoc, _, classID, subClassID = ns.GetItemInfoInstant(link)
    -- fehlen die Klassen-IDs im Instant-Aufruf, kommen sie aus dem vollen Item (Rückgabe 12 und 13)
    if not classID then
        local _, _, _, _, _, t, s, _, _, _, _, c, sc = ns.GetItemInfo(link)
        itemType, subType, classID, subClassID = t or itemType, s or subType, c, sc
    end
    ns.Dbg("Rüstung", link, itemType, subType, equipLoc, classID, subClassID)
    local armorClass = Enum and Enum.ItemClass and Enum.ItemClass.Armor or 4
    if classID == armorClass and subClassID and subClassID >= 1 and subClassID <= 4 and subType and subType ~= "" then
        armorName = subType
    end
    r.sub:ClearAllPoints()
    r.armorName = armorName
    RF:Look(r)
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
    -- Berechtigungen nach kurzer Zeit erneut lesen: gleich beim Start sind sie manchmal noch leer oder veraltet
    local gen = r.gen
    for _, delay in ipairs({ 0.4, 1.5 }) do
        C_Timer.After(delay, function()
            if r.gen ~= gen or r.rollID ~= rollID or r.done or r.chosen or r.fake then return end
            local _, _, _, _, _, cN, cG, _, rN, rG, _, _, cT = GetLootRollItemInfo(rollID)
            if cN ~= nil or cG ~= nil then SetupButtons(r, cN, cG, rN, rG, cT) end
        end)
    end
end

function RF:Choose(r, kind)
    if r.preview then return end
    if r.fake then return self:FakeChoose(r, kind) end
    -- Die Buttons werden erst gesperrt, wenn die eigene Wahl im Chat bestätigt
    -- ist (OnChat). Bei Bind-on-Pickup-Items fragt Blizzard erst nach; bricht
    -- man dort ab, muss man noch einmal wählen können.
    local rolltype = (kind == "greed" and r.transmog) and 4 or ROLLTYPE[kind]
    r.pending = kind   -- kommt CANCEL_LOOT_ROLL, hat das Spiel die Wahl genommen (siehe OnCancel)
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
    -- Die Leiste läuft jetzt über die Standzeit leer (siehe OnUpdate)
    local hold = ns.cfg.roll.hold
    r.duration, r.expires = hold, GetTime() + hold
    r.bar:SetMinMaxValues(0, hold)
    r.bar:SetValue(hold)
    r.bar:SetShown(ns.cfg.roll.showBar ~= false)
    for _, k in ipairs(KINDS) do r.btn[k]:Disable() end
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
    -- Im Kampf kann die Chatzeile ein geheimer Wert sein: er lässt sich weder durchsuchen noch vergleichen
    if type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then return end
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

-- Loot-Historie des Clients (wie DaylightUI): jede Änderung eines Wurfs kommt als LOOT_HISTORY_UPDATE_DROP, mit den
-- Wahlen, Würfen und dem Gewinner aller Spieler. Das ist schneller und verlässlicher als die Chatzeilen.
-- Enum.EncounterLootDropRollState: 0/1 Bedarf, 2/3 Transmog bzw. Gier, 4 noch keine Wahl, 5 Passen.
local HISTORY_PICK = { [0] = "need", [1] = "need", [2] = "greed", [3] = "greed", [5] = "pass" }

function RF:OnHistory(encounterID, key)
    local H = C_LootHistory
    if not (H and H.GetSortedInfoForDrop) then return end
    local ok, info = pcall(H.GetSortedInfoForDrop, encounterID, key)
    if not ok or type(info) ~= "table" then return end
    local link = info.itemHyperlink
    if type(link) ~= "string" or (issecretvalue and issecretvalue(link)) then return end
    local r = FindRow(ns.ItemID(link), nil)
    if not r or r.done or r.fake then return end

    local changed, winner = false, nil
    for _, ri in ipairs(type(info.rollInfos) == "table" and info.rollInfos or {}) do
        local name = ri.playerName
        if type(name) == "string" and not (issecretvalue and issecretvalue(name)) then
            name = AddPlayer(r, name)
            local pick = type(ri.state) == "number" and HISTORY_PICK[ri.state]
            if pick and r.picks[name] ~= pick then
                r.picks[name] = pick
                changed = true
                if (ri.isSelf == true or ns.SameName(name, Me())) and not r.chosen then self:SetChoice(r, pick) end
            end
            if type(ri.roll) == "number" and r.rolls[name] ~= ri.roll then
                r.rolls[name] = ri.roll
                changed = true
            end
            if ri.isWinner == true then winner = name end
        end
    end
    if changed then self:UpdateChips(r) end
    if winner then
        self:Finish(r, winner)
    elseif info.allPassed == true then
        self:Finish(r, nil)
    end
end

function RF:OnCancel(rollID)
    -- UIParent schließt den Bestätigungsdialog sonst selbst, aber wir haben
    -- CANCEL_LOOT_ROLL dort abgemeldet.
    StaticPopup_Hide("CONFIRM_LOOT_ROLL", rollID)
    local r = FindRow(nil, rollID)
    if not r or r.done then return end
    -- Das Spiel hat das Fenster geschlossen: hast du gerade gedrückt, wurde deine Wahl genommen. So zeigt die Zeile sie
    -- sofort, ohne auf die Chatzeile oder die Historie zu warten.
    if r.pending and not r.chosen then
        local pick = r.pending
        self:SetChoice(r, pick)
        r.picks[AddPlayer(r, Me())] = pick
        self:UpdateChips(r)
    end
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
    for _, k in ipairs(KINDS) do r.btn[k]:Disable() end
    FillRoster(r)
    local n = r.roster
    r.picks[n[1]] = done and "pass" or nil
    r.picks[n[2]], r.picks[n[3]], r.picks[n[4]], r.picks[n[5]] = "need", "greed", "pass", "need"
    if done then
        r.rolls[n[2]], r.rolls[n[3]], r.rolls[n[5]] = 92, 34, 61
        r.done, r.winner = true, n[2]
        r.bar:Hide()
        for _, k in ipairs(KINDS) do r.btn[k]:Disable() end
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
    win:SetHeaderShown(not ns.cfg.roll.hideHeader)
    ns.ApplyStyle(win, "roll")
    for _, r in ipairs(active) do RF:Look(r); RF:UpdateChips(r) end
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
    win = ns.FramedPanel(ns.frames.roll, T["Gruppenwurf"])
    win:Hide()

    -- Blizzards Gruppenwurf-Fenster abschalten
    UIParent:UnregisterEvent("START_LOOT_ROLL")
    UIParent:UnregisterEvent("CANCEL_LOOT_ROLL")
    -- Der Container wird von Blizzard beim ersten Gruppenwurf eingeblendet und fängt in der
    -- Bildschirmmitte Mausklicks ab, auch wenn seine Wurf-Fenster leer sind: dauerhaft verstecken
    local container = _G.GroupLootContainer
    if container then
        container:UnregisterAllEvents()
        container:EnableMouse(false)
        container:HookScript("OnShow", function(self) self:Hide() end)
        container:Hide()
    end
    if _G.hooksecurefunc and _G.GroupLootContainer_Update then
        hooksecurefunc("GroupLootContainer_Update", function()
            if container and container:IsShown() then container:Hide() end
        end)
    end
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
    -- Loot-Historie und "alle Würfe abgebrochen" (Ereignisse, die es nicht in jedem Client gibt)
    pcall(ev.RegisterEvent, ev, "LOOT_HISTORY_UPDATE_DROP")
    pcall(ev.RegisterEvent, ev, "CANCEL_ALL_LOOT_ROLLS")
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
        elseif event == "LOOT_HISTORY_UPDATE_DROP" then RF:OnHistory(a, b)
        elseif event == "CANCEL_ALL_LOOT_ROLLS" then
            for i = #active, 1, -1 do
                if active[i].rollID and not active[i].fake and not active[i].done then RF:Remove(active[i]) end
            end
        else RF:OnChat(a) end
    end)
end
