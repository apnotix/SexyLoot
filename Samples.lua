local ADDON, ns = ...
local T = ns.T

-- Beispiele für die Vorschau im Einstellungsfenster (SexyEditMode-Hub): jedes Fenster zeichnet sich verkleinert mit
-- Beispieldaten und meldet seine Teile als Klickbereiche (jump = Einstellung, zu der ein Klick springt).
-- Aufruf: ns.Samples[key](host, cache) -> { w, h, parts = { { name, x, y, w, h, jump }, ... } }; cache wird wiederverwendet.

ns.Samples = {}

local CARD = { 0.145, 0.125, 0.10, 1 }
local WIDTH = 300
local BTN_H, BTN_GAP = 22, 4
local BTN_W = (WIDTH - 16 - 12 - 2 * BTN_GAP) / 3
local BTN_OFF = BTN_H + 12   -- wie in RollFrames: Platz der Button-Zeile unter der Leiste
local TEX = {
    need = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
    greed = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
    pass = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
}
local PLAYERS = {
    { "Aldrin", { 0.78, 0.61, 0.43 }, "need", 87 },
    { "Mirelle", { 1, 1, 1 }, "greed", 54 },
    { "Thokk", { 0, 0.44, 0.87 }, "pass", nil },
}

-- Rollfenster: Fenster mit Titelband, eine volle Karte (Item, Leiste, Buttons, Spielerliste) und der Anfang einer zweiten
function ns.Samples.roll(host, c)
    local cfg = ns.cfg.roll
    local size = cfg.size or 14
    local lh = size + 8 + (cfg.lineGap or 0)
    local zebra = cfg.zebra ~= false

    if not c.win then
        c.win = ns.FramedPanel(host, T["Gruppenwurf"])
        c.win:SetPoint("TOPLEFT", host, "TOPLEFT")

        local card = CreateFrame("Frame", nil, c.win)
        card.fill = card:CreateTexture(nil, "BACKGROUND")
        card.fill:SetAllPoints()
        card.fill:SetColorTexture(CARD[1], CARD[2], CARD[3], 1)
        c.card = card

        card.qual = card:CreateTexture(nil, "BACKGROUND")
        card.qual:SetSize(40, 40)
        card.qual:SetPoint("TOPLEFT", 4, -4)
        card.qual:SetColorTexture(0.64, 0.21, 0.93, 1)
        card.icon = card:CreateTexture(nil, "ARTWORK")
        card.icon:SetSize(36, 36)
        card.icon:SetPoint("TOPLEFT", 6, -6)
        card.icon:SetTexture("Interface\\Icons\\INV_Helmet_08")
        card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        card.name = card:CreateFontString(nil, "OVERLAY", "SexyLootText")
        card.name:SetPoint("TOPLEFT", 52, -8)
        card.name:SetTextColor(0.64, 0.21, 0.93)
        card.name:SetText(T["Beispiel-Gegenstand"])
        c.nameFont = { card.name:GetFont() }
        card.pill = ns.Pill(card)
        card.pill.tex:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -3)
        card.pill:Set("grey", T["Platte"], nil, 16)
        card.bound = card:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
        card.bound:SetPoint("LEFT", card.pill.tex, "RIGHT", 6, 0)
        card.bound:SetTextColor(0.6, 0.55, 0.45)
        card.bound:SetText(ITEM_BIND_ON_PICKUP or "Binds when picked up")
        card.time = card:CreateFontString(nil, "OVERLAY", "SexyLootDim")
        card.time:SetPoint("TOPRIGHT", -8, -33)
        card.time:SetText("18s")

        card.bar = CreateFrame("StatusBar", nil, card)
        card.bar:SetPoint("TOPLEFT", 6, -50)
        card.bar:SetPoint("TOPRIGHT", -6, -50)
        card.bar:SetHeight(6)
        card.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        card.bar:SetStatusBarColor(0.9, 0.76, 0.42)
        card.bar:SetMinMaxValues(0, 1)
        card.bar:SetValue(0.62)
        card.bar.bg = card.bar:CreateTexture(nil, "BACKGROUND")
        card.bar.bg:SetAllPoints()
        card.bar.bg:SetColorTexture(0, 0, 0, 0.6)
        local SEM = LibStub("SexyEditMode-1.0", true)
        if SEM and SEM.ShineBar then SEM:ShineBar(card.bar, { radius = 3, surround = CARD }) end

        card.btn = {}
        for i, kind in ipairs({ "need", "greed", "pass" }) do
            local b = CreateFrame("Frame", nil, card)
            b:SetSize(BTN_W, BTN_H)
            b:SetPoint("TOPLEFT", 6 + (i - 1) * (BTN_W + BTN_GAP), -62)
            b.bg = b:CreateTexture(nil, "BACKGROUND")
            b.bg:SetAllPoints()
            b.bg:SetColorTexture(0.075, 0.062, 0.04, 1)
            b.rim = CreateFrame("Frame", nil, b, "BackdropTemplate")
            b.rim:SetAllPoints(b)
            b.rim:SetBackdrop({ edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10 })
            b.rim:SetBackdropBorderColor(0.42, 0.34, 0.15, 1)
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetSize(BTN_H - 4, BTN_H - 4)
            b.icon:SetTexture(TEX[kind])
            b.text = b:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
            b.text:SetTextColor(0.95, 0.92, 0.86)
            b.text:SetText(kind == "need" and (NEED or "Need") or kind == "greed" and (GREED or "Greed") or (PASS or "Pass"))
            local x = math.floor((BTN_W - ((BTN_H - 4) + 4 + b.text:GetStringWidth())) / 2 + 0.5)
            b.icon:SetPoint("LEFT", b, "LEFT", math.max(2, x), (kind == "pass") and 0 or -2)
            b.text:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
            card.btn[i] = b
        end

        card.sep = card:CreateTexture(nil, "ARTWORK")
        card.sep:SetColorTexture(0.21, 0.19, 0.14, 1)
        card.sep:SetHeight(1)
        card.sep:SetPoint("TOPLEFT", 8, -(60 + BTN_OFF))
        card.sep:SetPoint("TOPRIGHT", -8, -(60 + BTN_OFF))

        card.lines = {}
        for i, p in ipairs(PLAYERS) do
            local l = CreateFrame("Frame", nil, card)
            l.bg = l:CreateTexture(nil, "BACKGROUND")
            l.bg:SetAllPoints()
            l.pick = l:CreateTexture(nil, "ARTWORK")
            l.pick:SetPoint("LEFT", 6, 0)
            l.pick:SetTexture(p[3] and TEX[p[3]])
            l.name = l:CreateFontString(nil, "OVERLAY")
            l.name:SetPoint("LEFT", l.pick, "RIGHT", 6, 0)
            l.check = l:CreateTexture(nil, "OVERLAY")
            l.check:SetTexture("Interface/RaidFrame/ReadyCheck-Ready")
            l.check:SetPoint("RIGHT", -4, 0)
            l.roll = l:CreateFontString(nil, "OVERLAY")
            l.roll:SetWidth(40)
            l.roll:SetPoint("RIGHT", l.check, "LEFT", -4, 0)
            l.roll:SetJustifyH("RIGHT")
            l.sweep = ns.Motion.NewSweep(l)
            card.lines[i] = l
        end

        -- der Anfang einer zweiten Karte: zeigt den Abstand zwischen den Karten
        c.stub = CreateFrame("Frame", nil, c.win)
        c.stub.fill = c.stub:CreateTexture(nil, "BACKGROUND")
        c.stub.fill:SetAllPoints()
        c.stub.fill:SetColorTexture(CARD[1], CARD[2], CARD[3], 0.75)
    end

    local win, card, stub = c.win, c.card, c.stub
    ns.Samples.rollCache = c
    if not c.sweep then c.sweep = ns.Motion.NewSweep(card) end
    win:SetHeaderShown(not cfg.hideHeader)
    win:SetBadge("1 " .. T["Gegenstand"])
    ns.ApplyStyle(win, "roll")
    local head = win.headH

    -- Karte: Deckkraft, Schrift, Etiketten, Leiste, Zeit und Beschriftung der Buttons
    card.fill:SetColorTexture(CARD[1], CARD[2], CARD[3], cfg.cardOpacity or 1)
    if (cfg.nameSize or 0) > 0 then
        card.name:SetFont(c.nameFont[1], cfg.nameSize, c.nameFont[3])
    else
        card.name:SetFont(unpack(c.nameFont))
    end
    local armor = cfg.showArmor ~= false
    if armor then card.pill:Set("grey", T["Platte"], nil, 16) else card.pill:Hide() end
    card.bound:ClearAllPoints()
    if armor then
        card.bound:SetPoint("LEFT", card.pill.tex, "RIGHT", 6, 0)
    else
        card.bound:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -3)
    end
    card.bound:SetShown(cfg.showBound ~= false)
    card.bar:SetShown(cfg.showBar ~= false)
    card.time:SetShown(cfg.showTimer ~= false)
    local labels = cfg.btnLabels ~= false
    for bi, b in ipairs(card.btn) do
        b.text:SetShown(labels)
        local x = math.floor((BTN_W - ((BTN_H - 4) + (labels and (4 + b.text:GetStringWidth()) or 0))) / 2 + 0.5)
        b.icon:ClearAllPoints()
        b.icon:SetPoint("LEFT", b, "LEFT", math.max(2, x), bi < 3 and -2 or 0)
    end

    -- Karte: Spielerliste je nach Einstellung
    local rows = cfg.hideRolls and 0 or #PLAYERS
    local bottom = rows > 0 and (60 + BTN_OFF + 6 + rows * lh + 4) or (62 + BTN_OFF)
    local cardH = bottom + 8
    local cardTop = head + 8

    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", win, "TOPLEFT", 8 + (c.demoOff or 0), -cardTop)
    card:SetAlpha(c.demoAlpha or 1)
    card:SetSize(WIDTH - 16, cardH)
    card.sep:SetShown(rows > 0)
    for i, l in ipairs(card.lines) do
        local p = PLAYERS[i]
        l:SetShown(i <= rows)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -(66 + BTN_OFF + (i - 1) * lh))
        l:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -(66 + BTN_OFF + (i - 1) * lh))
        l:SetHeight(lh)
        l.bg:SetColorTexture(1, 1, 1, (zebra and i % 2 == 0) and 0.05 or 0)
        l.pick:SetSize(size + 4, size + 4)
        l.check:SetSize(size, size)
        l.name:SetFont(ns.FONT_TEXT, size, "")
        l.name:SetText(p[1])
        l.roll:SetFont(ns.FONT_TEXT, size + 1, "OUTLINE")
        local d = c.demo and c.demo[i]
        if d then
            -- Demo läuft: erst "wartet" (grau, kein Symbol), dann erscheinen Wahl und Wurf nacheinander
            local picked = d.pick > 0.01
            l.pick:SetShown(picked and p[3] ~= nil)
            l.pick:SetAlpha(d.pick)
            l.name:SetTextColor(picked and p[2][1] or 0.55, picked and p[2][2] or 0.55, picked and p[2][3] or 0.55)
            l.roll:SetText(d.roll or (picked and "" or "…"))
            l.roll:SetTextColor(d.win and 1 or 0.95, d.win and 0.82 or 0.95, d.win and 0.2 or 0.95)
            l.check:SetShown(d.win and cfg.showCheck ~= false)
            l.bg:SetColorTexture(d.win and 0.91 or 1, d.win and 0.76 or 1, d.win and 0.42 or 1, d.win and 0.2 or ((zebra and i % 2 == 0) and 0.05 or 0))
        else
            l.pick:SetShown(p[3] ~= nil)
            l.pick:SetAlpha(1)
            l.name:SetTextColor(p[2][1], p[2][2], p[2][3])
            l.roll:SetText(p[4] and tostring(p[4]) or "")
            l.roll:SetTextColor(0.95, 0.95, 0.95)
            l.check:Hide()
        end
    end

    local gap = cfg.gap or 10
    local stubTop = cardTop + cardH + gap
    local stubH = 30
    stub:ClearAllPoints()
    stub:SetPoint("TOPLEFT", win, "TOPLEFT", 8, -stubTop)
    stub:SetSize(WIDTH - 16, stubH)

    local total = stubTop + stubH + 8
    win:SetSize(WIDTH, total)

    return {
        w = WIDTH, h = total,
        parts = {
            { name = T["Fenster"], x = 0, y = 0, w = WIDTH, h = total, jump = "_pos" },
            { name = T["Kopfzeile"], x = 0, y = 0, w = WIDTH, h = head, jump = "roll.hideHeader" },
            { name = T["Gegenstand"], x = 8, y = cardTop, w = WIDTH - 16, h = 48, jump = "roll.cardOpacity" },
            { name = T["Name"], x = 60, y = cardTop + 8, w = math.min(card.name:GetStringWidth() + 4, WIDTH - 90), h = math.max(14, cfg.nameSize or 0), jump = "roll.nameSize" },
            armor and { name = T["Etikett"], x = 60, y = cardTop + 26, w = 50, h = 16, jump = "roll.showArmor" }
                or { name = T["Etikett"], x = 60, y = cardTop + 24, w = 70, h = 6, jump = "roll.showArmor" },
            cfg.showBound ~= false and { name = T["Bindet beim Aufheben"], x = armor and 116 or 60, y = cardTop + 26, w = 120, h = 16, jump = "roll.showBound" }
                or { name = T["Bindet beim Aufheben"], x = 140, y = cardTop + 24, w = 60, h = 6, jump = "roll.showBound" },
            { name = T["Restzeit"], x = WIDTH - 60, y = cardTop + 33, w = 44, h = 12, jump = "roll.showTimer" },
            { name = T["Restzeit-Leiste"], x = 14, y = cardTop + 50, w = WIDTH - 28, h = 6, jump = "roll.showBar" },
            { name = T["Buttons"], x = 14, y = cardTop + 62, w = WIDTH - 28, h = BTN_H, jump = labels and "roll.animate" or "roll.btnLabels" },
            rows > 0 and { name = T["Spielerliste"], x = 14, y = cardTop + 66 + BTN_OFF, w = WIDTH - 28, h = rows * lh, jump = "roll.size" }
                or { name = T["Spielerliste"], x = 14, y = cardTop + 62 + BTN_OFF - 4, w = WIDTH - 28, h = 10, jump = "roll.hideRolls" },
            { name = T["Abstand zwischen Fenstern"], x = 8, y = cardTop + cardH, w = WIDTH - 16, h = math.max(gap, 8), jump = "roll.gap" },
        },
    }
end

-- Abstände zwischen den Spielerzeilen als eigene Klickbereiche
local baseRoll = ns.Samples.roll
function ns.Samples.roll(host, c)
    local res = baseRoll(host, c)
    local cfg = ns.cfg.roll
    local gap = cfg.lineGap or 0
    if gap > 0 and not cfg.hideRolls then
        local lh = (cfg.size or 14) + 8 + gap
        local top = c.win.headH + 8 + 66 + (BTN_H + 12)
        for i = 1, #PLAYERS - 1 do
            res.parts[#res.parts + 1] = { name = T["Zeilenabstand"], x = 14, y = top + i * lh - gap, w = WIDTH - 28, h = gap, jump = "roll.lineGap" }
        end
    end
    return res
end

-- Spielt den Ablauf eines Wurfs in der Vorschau einmal ab (wie im echten Fenster): die Karte fliegt ein, die Spieler
-- wählen nacheinander (Symbol blendet ein, die Würfe zählen hoch), der Gewinner leuchtet auf. Ohne Animationen
-- (Einstellung aus) bleibt die Vorschau still.
function ns.Samples.PlayRoll()
    local c = ns.Samples.rollCache
    local SEM = LibStub("SexyEditMode-1.0", true)
    local M = ns.Motion
    if not (c and c.card and SEM and SEM.RedrawSample) then return end
    c.demoGen = (c.demoGen or 0) + 1
    local gen = c.demoGen
    local function Redraw() SEM:RedrawSample() end
    local function After(t, fn)
        C_Timer.After(t, function() if c.demoGen == gen then fn() end end)
    end
    local function Pop(i)
        M.Tween(c, "pick" .. i, 0, 1, 0.25, function(v) if c.demo then c.demo[i].pick = v; Redraw() end end)
    end
    local function Count(i, to)
        M.Tween(c, "roll" .. i, 0, to, 0.5, function(v) if c.demo then c.demo[i].roll = tostring(math.floor(v + 0.5)); Redraw() end end)
    end

    if not M.On() then
        c.demo, c.demoOff, c.demoAlpha = nil, 0, 1
        Redraw()
        return
    end

    c.demo = { { pick = 0 }, { pick = 0 }, { pick = 0 } }
    -- Karte fliegt ein
    M.Tween(c, "demoIn", 28, 0, 0.35, function(v)
        c.demoOff, c.demoAlpha = v, 1 - v / 28
        Redraw()
    end)
    After(0.7, function() Pop(1) end)
    After(1.0, function() Count(1, 87) end)
    After(1.6, function() Pop(2) end)
    After(1.9, function() Count(2, 54) end)
    After(2.5, function() Pop(3) end)
    After(3.2, function()
        if c.demo then c.demo[1].win = true end
        Redraw()
    end)
    After(5.2, function()
        c.demo, c.demoOff, c.demoAlpha = nil, 0, 1
        Redraw()
    end)
end
