local ADDON, ns = ...
local T = ns.T

-- Gewinner-Anzeige: Wenn ein Wurf entschieden ist, steht der Gewinner mit Item
-- gut sichtbar auf dem Bildschirm (Position im Edit Mode einstellbar). Die Karte
-- ist abgerundet und hat einen weichen, runden Schein in Qualitätsfarbe, das
-- Symbol ist abgerundet und glüht. Kurze Ein- und Ausblend-Animationen machen
-- sie präsent. Gewinnen mehrere kurz hintereinander, stehen die Karten
-- untereinander (neueste oben), jede mit eigenem Timer.
--
-- Die Rundungen kommen aus kleinen Texturen in media/ (erzeugt von
-- tools/make_textures.py), die hier als 9-Slice zusammengesetzt werden.

local W = {}
ns.Winner = W
table.insert(ns.modules, W)

local LABEL = { need = NEED or "Need", greed = GREED or "Greed", pass = PASS or "Pass" }   -- Blizzard-Texte, in jeder Clientsprache
local SAMPLE = "|cffa335ee|Hitem:17063::::::::60:::::|h[" .. T["Ring des Glutkerns"] .. "]|h|r"
local SAMPLE2 = "|cff0070dd|Hitem:14551::::::::60:::::|h[" .. T["Kettenkappe der Wachsamkeit"] .. "]|h|r"
local FALLBACK_ICON = "Interface/Icons/INV_Misc_QuestionMark"
local MEDIA = "Interface/AddOns/SexyLoot/media/"
local CARD_H = 110  -- Höhe einer Karte
local GAP = 28      -- Abstand zwischen den Karten (Platz für den Schein)

local cards, pool = {}, {}   -- sichtbare Karten (neueste zuerst) und freie Karten

-- Farbverlauf mit Alpha, neue und alte API
local function Gradient(tex, orient, r, g, b, a1, a2)
    tex:SetColorTexture(1, 1, 1, 1)
    if CreateColor and tex.SetGradient then
        tex:SetGradient(orient, CreateColor(r, g, b, a1), CreateColor(r, g, b, a2))
    elseif tex.SetGradientAlpha then
        tex:SetGradientAlpha(orient, r, g, b, a1, r, g, b, a2)
    end
end

-- Neun Texturteile um ein Ziel: vier Ecken fest, vier Kanten und die Mitte gedehnt.
--   texSize/tc: Kantenlänge der Textur und Eckgröße darin (Pixel)
--   disp:       Eckgröße auf dem Bildschirm
--   out:        wie weit das Ganze über das Ziel hinausragt
-- Liefert ein Objekt mit :SetColor(r, g, b, a).
local function NineSlice(parent, target, path, texSize, tc, disp, out, layer, sub)
    local f = tc / texSize
    local pieces = {}
    local function tex(l, r, t, b)
        local x = parent:CreateTexture(nil, layer, nil, sub or 0)
        x:SetTexture(path)
        x:SetTexCoord(l, r, t, b)
        pieces[#pieces + 1] = x
        return x
    end
    local tl = tex(0, f, 0, f);          tl:SetSize(disp, disp); tl:SetPoint("TOPLEFT", target, "TOPLEFT", -out, out)
    local tr = tex(1 - f, 1, 0, f);      tr:SetSize(disp, disp); tr:SetPoint("TOPRIGHT", target, "TOPRIGHT", out, out)
    local bl = tex(0, f, 1 - f, 1);      bl:SetSize(disp, disp); bl:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", -out, -out)
    local br = tex(1 - f, 1, 1 - f, 1);  br:SetSize(disp, disp); br:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", out, -out)
    local top = tex(f, 1 - f, 0, f);     top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    local bot = tex(f, 1 - f, 1 - f, 1); bot:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bot:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    local lef = tex(0, f, f, 1 - f);     lef:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); lef:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    local rig = tex(1 - f, 1, f, 1 - f); rig:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); rig:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    local mid = tex(f, 1 - f, f, 1 - f); mid:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT"); mid:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")
    local obj = {}
    function obj:SetColor(r, g, b, a)
        for _, x in ipairs(pieces) do x:SetVertexColor(r, g, b, a or 1) end
    end
    return obj
end

-- Farbe des Scheins: Karte, Symbolglühen, Symbolring und Zierlinie
local function SetGlow(c, r, g, b)
    c.glowCard:SetColor(r, g, b, 1)
    c.glowIcon:SetColor(r, g, b, 1)
    c.iring:SetColor(r, g, b, 1)
    Gradient(c.line, "HORIZONTAL", r, g, b, 0.9, 0)
end

local function Style(c)
    local cfg = ns.cfg.winner
    local bg, bd = cfg.bg, cfg.border
    c.fill:SetColor(bg[1], bg[2], bg[3], bg[4])
    c.ring:SetColor(bd[1], bd[2], bd[3], bd[4])
    c:SetSize(ns.frames.winner:GetWidth(), CARD_H)
    local s = cfg.size
    local icon = math.min(64, s * 2 + 8)
    c.icon:SetSize(icon, icon)
    c.qual:SetSize(icon + 4, icon + 4)
    c.title:SetFont(STANDARD_TEXT_FONT, s, "OUTLINE")
    c.item:SetFont(STANDARD_TEXT_FONT, math.max(12, s - 6), "OUTLINE")
    c.detail:SetFont(STANDARD_TEXT_FONT, math.max(11, s - 12), "")
end

-- Dauer-Animationen: laufen nur, solange die Karte sichtbar ist
local function Pulse(c, target, from, to, seconds)
    local ag = target:CreateAnimationGroup()
    local a = ag:CreateAnimation("Alpha")
    if a.SetFromAlpha then
        a:SetFromAlpha(from)
        a:SetToAlpha(to)
    else
        a:SetChange(to - from)
    end
    a:SetDuration(seconds)
    a:SetSmoothing("IN_OUT")
    ag:SetLooping("BOUNCE")
    c.pulses[#c.pulses + 1] = ag
end

local function Layout()
    local anchor = ns.frames.winner
    for i, c in ipairs(cards) do
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -(i - 1) * (CARD_H + GAP))
    end
end

local function Release(c)
    for i, x in ipairs(cards) do
        if x == c then table.remove(cards, i) break end
    end
    c.gen = c.gen + 1
    c.fadeIn:Stop()
    c.fadeOut:Stop()
    for _, ag in ipairs(c.pulses) do ag:Stop() end
    c:Hide()
    pool[#pool + 1] = c
    Layout()
end

local function NewCard()
    local c = CreateFrame("Frame", nil, ns.frames.winner)
    c:SetSize(ns.frames.winner:GetWidth(), CARD_H)
    c:EnableMouse(false)
    c:Hide()
    c.gen = 0
    c.pulses = {}

    -- Abgerundeter Körper: Füllung und Rand
    c.fill = NineSlice(c, c, MEDIA .. "fill64.tga", 64, 20, 20, 0, "BACKGROUND", -2)
    c.ring = NineSlice(c, c, MEDIA .. "ring64.tga", 64, 20, 20, 0, "BORDER", 0)

    -- Weicher, runder Schein um die Karte (liegt über der Karte, ist innen durchsichtig)
    c.glow = CreateFrame("Frame", nil, c)
    c.glow:SetAllPoints(c)
    c.glowCard = NineSlice(c.glow, c, MEDIA .. "glow128.tga", 128, 48, 48, 32, "BACKGROUND", 0)

    c.qual = c:CreateTexture(nil, "BACKGROUND")   -- nur Anker für Symbol und Text
    c.qual:SetPoint("LEFT", 18, 0)
    c.qual:SetColorTexture(0, 0, 0, 0)

    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetPoint("CENTER", c.qual, "CENTER")
    c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    -- Symbol abrunden (MaskTexture, falls der Client sie kennt)
    if c.CreateMaskTexture then
        c.iconMask = c:CreateMaskTexture()
        c.iconMask:SetTexture(MEDIA .. "mask64.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        c.iconMask:SetAllPoints(c.icon)
        c.icon:AddMaskTexture(c.iconMask)
    end
    -- Ring in Qualitätsfarbe um das Symbol und weicher Schein darum
    c.iring = NineSlice(c, c.icon, MEDIA .. "ring64.tga", 64, 20, 20, 2, "ARTWORK", 2)
    c.iglow = CreateFrame("Frame", nil, c)
    c.iglow:SetAllPoints(c)
    c.glowIcon = NineSlice(c.iglow, c.icon, MEDIA .. "glowicon64.tga", 64, 32, 32, 16, "BACKGROUND", 0)

    -- Funkelnder Stern an der Ecke des Symbols (eigener Frame, liegt über den Scheinen)
    c.topf = CreateFrame("Frame", nil, c)
    c.topf:SetAllPoints(c)
    c.star = c.topf:CreateTexture(nil, "OVERLAY")
    c.star:SetTexture("Interface/Cooldown/star4")
    c.star:SetBlendMode("ADD")
    c.star:SetVertexColor(1, 0.9, 0.5, 0.9)
    c.star:SetSize(30, 30)
    c.star:SetPoint("CENTER", c.icon, "TOPRIGHT", -3, -3)
    do
        local ag = c.star:CreateAnimationGroup()
        local rot = ag:CreateAnimation("Rotation")
        rot:SetDegrees(-360)
        rot:SetDuration(9)
        ag:SetLooping("REPEAT")
        c.pulses[#c.pulses + 1] = ag
        Pulse(c, c.star, 0.35, 1, 0.8)
    end

    c.title = c:CreateFontString(nil, "OVERLAY")
    c.title:SetPoint("TOPLEFT", c.qual, "TOPRIGHT", 18, 0)
    c.title:SetPoint("RIGHT", c, "RIGHT", -18, 0)
    c.title:SetJustifyH("LEFT")
    c.title:SetWordWrap(false)
    c.title:SetShadowColor(0, 0, 0, 1)
    c.title:SetShadowOffset(1, -1)

    -- Zierlinie unter dem Titel, läuft nach rechts aus
    c.line = c:CreateTexture(nil, "ARTWORK")
    c.line:SetHeight(1)
    c.line:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -3)
    c.line:SetPoint("RIGHT", c, "RIGHT", -20, 0)

    c.item = c:CreateFontString(nil, "OVERLAY")
    c.item:SetPoint("TOPLEFT", c.line, "BOTTOMLEFT", 0, -5)
    c.item:SetPoint("RIGHT", c, "RIGHT", -18, 0)
    c.item:SetJustifyH("LEFT")
    c.item:SetWordWrap(false)

    c.detail = c:CreateFontString(nil, "OVERLAY")
    c.detail:SetPoint("TOPLEFT", c.item, "BOTTOMLEFT", 0, -2)
    c.detail:SetJustifyH("LEFT")

    -- Sanftes Pulsieren von Kartenschein und Symbolglühen
    Pulse(c, c.glow, 1, 0.45, 0.9)
    Pulse(c, c.iglow, 1, 0.5, 0.9)

    -- Einblenden: kurz aufpoppen und einblenden
    c.fadeIn = c:CreateAnimationGroup()
    do
        local a = c.fadeIn:CreateAnimation("Alpha")
        if a.SetFromAlpha then a:SetFromAlpha(0); a:SetToAlpha(1) else a:SetChange(0) end
        a:SetDuration(0.25)
        local sc = c.fadeIn:CreateAnimation("Scale")
        if sc.SetScaleFrom then
            sc:SetScaleFrom(0.88, 0.88)
            sc:SetScaleTo(1, 1)
            sc:SetOrigin("CENTER", 0, 0)
            sc:SetDuration(0.25)
            sc:SetSmoothing("OUT")
        end
    end

    -- Ausblenden: weich verschwinden, danach freigeben und Stapel neu ordnen
    c.fadeOut = c:CreateAnimationGroup()
    do
        local a = c.fadeOut:CreateAnimation("Alpha")
        if a.SetFromAlpha then a:SetFromAlpha(1); a:SetToAlpha(0) else a:SetChange(-1) end
        a:SetDuration(0.5)
        c.fadeOut:SetScript("OnFinished", function() Release(c) end)
    end
    return c
end

-- sticky: bleibt stehen (Edit-Mode-Vorschau), sonst nach cfg.hold Sekunden weg
function W:Display(player, link, pick, roll, sticky)
    if not link then return end
    local cfg = ns.cfg.winner
    -- Mehr als erlaubt: die älteste Karte weicht sofort
    while #cards >= cfg.max do Release(cards[#cards]) end

    local c = table.remove(pool) or NewCard()
    table.insert(cards, 1, c)
    c.gen = c.gen + 1
    Style(c)

    local me = ns.SameName(ns.Short(player), ns.Short(UnitName("player")))
    c.title:SetText(me and ("|cff33ff66" .. T["Du gewinnst!"] .. "|r") or T("%s gewinnt!", ns.ColorName(player)))
    c.item:SetText(link)
    c.detail:SetText(pick and ("|cffbbbbbb" .. LABEL[pick] .. (roll and (" " .. roll) or "") .. "|r") or "")

    local tex = select(5, ns.GetItemInfoInstant(link))
    c.icon:SetTexture(tex or FALLBACK_ICON)
    local q = ns.LinkQuality(link)
    local r, g, b = ns.QualityColor(q)
    -- Schein: bei dir selbst grün, sonst Qualitätsfarbe (weiß und grau golden)
    if me then SetGlow(c, 0.2, 1, 0.45)
    elseif q <= 1 then SetGlow(c, 1, 0.82, 0.2)
    else SetGlow(c, r, g, b) end

    Layout()
    c.fadeOut:Stop()
    c:Show()
    c.fadeIn:Stop()
    c.fadeIn:Play()
    for _, ag in ipairs(c.pulses) do
        if not ag:IsPlaying() then ag:Play() end
    end

    if sticky then return end
    local mine = c.gen
    C_Timer.After(cfg.hold, function()
        if c.gen == mine then c.fadeOut:Play() end
    end)
end

-- Zwei Gewinner kurz nacheinander, damit man den Stapel sieht
function W:Test()
    self:Display("Aldrin", SAMPLE, "need", 92)
    C_Timer.After(0.7, function() self:Display("Mirelle", SAMPLE2, "greed", 77) end)
end

local function ClearAll()
    for i = #cards, 1, -1 do Release(cards[i]) end
end

-- Im Edit Mode stehen zwei Beispielgewinner, beim Verlassen verschwinden sie
function W:Preview(active)
    ClearAll()
    if active then
        self:Display("Aldrin", SAMPLE, "need", 92, true)
        self:Display("Mirelle", SAMPLE2, "greed", 77, true)
    end
end

ns.Apply.winner = function()
    -- Der Edit-Mode-Rahmen umfasst den ganzen Stapel
    local n = ns.cfg.winner.max
    ns.frames.winner:SetHeight(n * CARD_H + (n - 1) * GAP)
    for _, c in ipairs(cards) do Style(c) end
    Layout()
end

function W:Init() end
