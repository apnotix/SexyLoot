local ADDON, ns = ...
local T = ns.T

-- Gewinner-Anzeige: Wenn ein Wurf entschieden ist, steht der Gewinner mit Item
-- gut sichtbar auf dem Bildschirm (Position im Edit Mode einstellbar). Die Karte
-- hat den Look der anderen Fenster (Goldrand, Titelband "Gewinner") und einen
-- weichen Schein in Qualitätsfarbe, das Symbol trägt einen Rahmen in Qualitätsfarbe.
-- Wurfart und Ergebnis stehen als Etiketten neben dem Gewinner. Kurze Ein- und
-- Ausblend-Animationen machen sie präsent. Gewinnen mehrere kurz hintereinander,
-- stehen die Karten untereinander (neueste oben), jede mit eigenem Timer.
--
-- Der Schein kommt aus einer kleinen Textur in media/ (erzeugt von
-- tools/make_textures.py), die hier als 9-Slice zusammengesetzt wird.

local W = {}
ns.Winner = W
table.insert(ns.modules, W)

local LABEL = { need = NEED or "Need", greed = GREED or "Greed", pass = PASS or "Pass" }   -- Blizzard-Texte, in jeder Clientsprache
local TONE = { need = "ok", greed = "warn", pass = "grey" }                                -- Etikettenfarbe je Wurfart
local SAMPLE = "|cffa335ee|Hitem:17063::::::::60:::::|h[" .. T["Ring des Glutkerns"] .. "]|h|r"
local SAMPLE2 = "|cff0070dd|Hitem:14551::::::::60:::::|h[" .. T["Kettenkappe der Wachsamkeit"] .. "]|h|r"
local FALLBACK_ICON = "Interface/Icons/INV_Misc_QuestionMark"
local MEDIA = "Interface/AddOns/SexyLoot/media/"
local CARD_H = 112  -- Höhe einer Karte (Titelband plus Inhalt)
local GAP = 28      -- Abstand zwischen den Karten (Platz für den Schein)
local SLIM_H = 46       -- Höhe der schmalen Karte, wenn jemand anderes gewinnt
local SLIM_GAP = 8      -- Abstand zwischen schmalen Karten
local SLIM_W = 0.75     -- Breite der schmalen Karte relativ zum Anker

local cards, pool, slimPool = {}, {}, {}   -- sichtbare Karten (neueste zuerst) und freie Karten (groß: du gewinnst, schmal: andere)

local NineSlice = ns.NineSlice

-- Farbe des Scheins und des Symbolrahmens
local function SetGlow(c, r, g, b)
    c.glowCard:SetColor(r, g, b, 1)
    c.iborder:SetColorTexture(r, g, b, 1)
end

local function Style(c)
    local cfg = ns.cfg.winner
    ns.ApplyStyle(c, "winner")
    c:SetSize(ns.frames.winner:GetWidth(), CARD_H)
    local s = cfg.size
    local icon = math.min(64, s * 2 + 8)
    c.icon:SetSize(icon, icon)
    c.item:SetFont(ns.FONT_TITLE, math.max(14, s - 4), "OUTLINE")
    c.who:SetFont(ns.FONT_TEXT, math.max(12, s - 12), "")
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
    local y = 0
    for i, c in ipairs(cards) do
        c:ClearAllPoints()
        -- schmale Karten sitzen mittig im Anker
        local x = c.slim and anchor:GetWidth() * (1 - SLIM_W) / 2 or 0
        c:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, -y)
        local nextCard = cards[i + 1]
        -- der Schein großer Karten braucht Platz; zwischen zwei schmalen Karten reicht wenig
        y = y + (c.slim and SLIM_H or CARD_H) + ((c.slim and nextCard and nextCard.slim) and SLIM_GAP or GAP)
        -- Mehrere Karten tragen ihre Stapelposition als Badge
        c:SetBadge(#cards > 1 and (i .. "/" .. #cards) or "")
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
    local p = c.slim and slimPool or pool
    p[#p + 1] = c
    Layout()
end

-- Ein- und Ausblenden einer Karte
local function SetupAnim(c)
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
end

local function NewCard()
    local c = ns.FramedPanel(ns.frames.winner, T["Gewinner"])
    c:SetSize(ns.frames.winner:GetWidth(), CARD_H)
    c:EnableMouse(false)
    c:Hide()
    c.gen = 0
    c.pulses = {}

    -- Weicher Schein um die Karte (liegt über der Karte, ist innen durchsichtig)
    c.glow = CreateFrame("Frame", nil, c)
    c.glow:SetAllPoints(c)
    c.glowCard = NineSlice(c.glow, c, MEDIA .. "glow128.tga", 128, 48, 48, 32, "BACKGROUND", 0)

    -- Symbol mit Rahmen in Qualitätsfarbe, vertikal in der Mitte des Inhalts
    c.icon = c:CreateTexture(nil, "ARTWORK", nil, 1)
    c.icon:SetPoint("LEFT", c, "LEFT", 20, -ns.HEAD / 2)
    c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    c.iborder = c:CreateTexture(nil, "ARTWORK")
    c.iborder:SetPoint("TOPLEFT", c.icon, "TOPLEFT", -2, 2)
    c.iborder:SetPoint("BOTTOMRIGHT", c.icon, "BOTTOMRIGHT", 2, -2)

    c.item = c:CreateFontString(nil, "OVERLAY")
    c.item:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 14, -2)
    c.item:SetPoint("RIGHT", c, "RIGHT", -18, 0)
    c.item:SetJustifyH("LEFT")
    c.item:SetWordWrap(false)
    c.item:SetShadowColor(0, 0, 0, 1)
    c.item:SetShadowOffset(1, -1)

    -- Gewinner in Klassenfarbe, daneben Etiketten für Wurfart und Ergebnis
    c.who = c:CreateFontString(nil, "OVERLAY")
    c.who:SetPoint("TOPLEFT", c.item, "BOTTOMLEFT", 0, -10)
    c.who:SetJustifyH("LEFT")
    c.pick = ns.Pill(c)
    c.rollPill = ns.Pill(c)

    -- Sanftes Pulsieren des Kartenscheins
    Pulse(c, c.glow, 1, 0.45, 0.9)

    SetupAnim(c)
    return c
end

-- Schmale Karte (jemand anderes gewinnt): Symbol, darüber der Gegenstand, darunter Gewinner und Etiketten
local function NewSlimCard()
    local c = ns.FramedPanel(ns.frames.winner)
    c:EnableMouse(false)
    c:Hide()
    c.gen = 0
    c.slim = true
    c.pulses = {}

    c.icon = c:CreateTexture(nil, "ARTWORK", nil, 1)
    c.icon:SetSize(30, 30)
    c.icon:SetPoint("LEFT", c, "LEFT", 10, 0)
    c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    c.iborder = c:CreateTexture(nil, "ARTWORK")
    c.iborder:SetPoint("TOPLEFT", c.icon, "TOPLEFT", -1, 1)
    c.iborder:SetPoint("BOTTOMRIGHT", c.icon, "BOTTOMRIGHT", 1, -1)

    c.item = c:CreateFontString(nil, "OVERLAY")
    c.item:SetFont(ns.FONT_TEXT, 13, "")
    c.item:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 8, 1)
    c.item:SetPoint("RIGHT", c, "RIGHT", -10, 0)
    c.item:SetJustifyH("LEFT")
    c.item:SetWordWrap(false)

    c.who = c:CreateFontString(nil, "OVERLAY")
    c.who:SetFont(ns.FONT_TEXT, 11, "")
    c.who:SetPoint("BOTTOMLEFT", c.icon, "BOTTOMRIGHT", 8, -1)
    c.who:SetJustifyH("LEFT")
    c.pick = ns.Pill(c)
    c.rollPill = ns.Pill(c)

    -- Statt eines Scheins färbt sich der Rahmen in der Qualitätsfarbe
    c.glowCard = { SetColor = function(_, r, g, b) c.accent:SetColorTexture(r, g, b, 1) end }

    SetupAnim(c)
    return c
end

-- sticky: bleibt stehen (Edit-Mode-Vorschau), sonst nach cfg.hold Sekunden weg
function W:Display(player, link, pick, roll, sticky)
    if not link then return end
    local cfg = ns.cfg.winner
    -- Mehr als erlaubt: die älteste Karte weicht sofort
    while #cards >= cfg.max do Release(cards[#cards]) end

    local me = ns.SameName(ns.Short(player), ns.Short(UnitName("player")))
    -- Ton, wenn du selbst gewinnst (nicht in der Edit-Mode-Vorschau)
    if me and cfg.sound and not sticky then pcall(ns.Sounds.Play, cfg.soundKey, cfg.soundChannel) end
    local c
    if me then
        c = table.remove(pool) or NewCard()
    else
        c = table.remove(slimPool) or NewSlimCard()
    end
    table.insert(cards, 1, c)
    c.gen = c.gen + 1
    if c.slim then
        ns.ApplyStyle(c, "winner")
        c:SetSize(ns.frames.winner:GetWidth() * SLIM_W, SLIM_H)
    else
        Style(c)
    end
    c.who:SetText(me and ("|cff33ff66" .. T["Du gewinnst!"] .. "|r") or ns.ColorName(player))
    c.item:SetText(link)

    -- Etiketten: Wurfart (grün Bedarf, bernstein Gier, grau Passen), danach das Ergebnis
    c.pick.tex:ClearAllPoints()
    c.pick.tex:SetPoint("LEFT", c.who, "RIGHT", c.slim and 8 or 10, 0)
    if pick and LABEL[pick] then c.pick:Set(TONE[pick], LABEL[pick], nil, c.slim and 14 or 18) else c.pick:Hide() end
    c.rollPill.tex:ClearAllPoints()
    if roll then
        c.rollPill.tex:SetPoint("LEFT", (pick and LABEL[pick]) and c.pick.tex or c.who, "RIGHT", 6, 0)
        c.rollPill:Set("grey", tostring(roll), nil, c.slim and 14 or 18)
    else
        c.rollPill:Hide()
    end

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
        self:Display(UnitName("player"), SAMPLE, "need", 88, true)
    end
end

ns.Apply.winner = function()
    -- Der Edit-Mode-Rahmen umfasst den ganzen Stapel
    local n = ns.cfg.winner.max
    ns.frames.winner:SetHeight(n * CARD_H + (n - 1) * GAP)
    for _, c in ipairs(cards) do
        if c.slim then c:SetSize(ns.frames.winner:GetWidth() * SLIM_W, SLIM_H) else Style(c) end
    end
    Layout()
end

function W:Init() end
