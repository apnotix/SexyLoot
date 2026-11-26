local ADDON, ns = ...

-- Standardwerte. Sie stehen hier, weil Schieberegler ihr onChanged
-- beim Laden nur mit gespeicherten Werten aufrufen.
-- Checkboxen sind im Standard immer false.
-- Die Farben (bg, border; r, g, b, Deckkraft) sind fest und nicht einstellbar.
-- Fenster im Look von SexyQuestHelper: dunkelbraune Fläche, Goldrand
local PANEL_BG = { 0.08, 0.065, 0.05, 0.96 }
local GOLD = { 0.42, 0.34, 0.15, 1 }
ns.defaults = {
    roll = { cardOpacity = 1, nameSize = 0, showArmor = true, showBound = true, showBar = true, showTimer = true, btnLabels = true, showCheck = true, zebra = true, lineGap = 0, animate = true, hideRolls = false, growUp = false, gap = 10, size = 14, hold = 12, maxHeight = 440,
        bg = PANEL_BG, border = GOLD },
    freeroll = { single = false, size = 14, hold = 30, rows = 10, chanNum = 1, showRank = true, showButton = true, showBar = true, width = 260, lineGap = 0, showCheck = true, zebra = true,
        bg = PANEL_BG, border = GOLD },
    winner = { size = 28, hold = 6, max = 3, glow = true, showPills = true, iconSize = 0, itemSize = 0, whoSize = 0, width = 480, cardGap = 28, slimWidth = 75, sound = false, soundKey = "UI_EPICLOOT_TOAST", soundChannel = "Master",
        bg = PANEL_BG, border = GOLD },
    loot = { auto = false, noAutoMoney = false, thr = 2, icon = 34, showPills = true, showAll = true, width = 250, nameSize = 0, rowGap = 0,
        bg = PANEL_BG, border = GOLD },
    feed = { hideStamp = false, sortPlayers = false, noFade = false, fade = 20, width = 340, height = 160, size = 15, lineGap = 0, outline = false, stampColor = { 0.53, 0.53, 0.53 },
        bg = { 0.08, 0.065, 0.05, 0.88 }, border = GOLD },
    mine = { growDown = false, hideTime = false, hideValue = false, hideItemValue = false, noStack = false, rows = 7, showIcons = true, rowH = 20, width = 280, nameSize = 0, showCount = true,
        bg = PANEL_BG, border = GOLD },
    toast = { hideValue = false, hold = 6, rows = 6, splitMoney = false, rowH = 40, width = 300, showStripe = true, iconSize = 0, nameSize = 0, gap = 2, showCount = true },
    wallet = { showSell = true, width = 200, fontSize = 0, showLabels = true, bg = PANEL_BG, border = GOLD },
    deButton = { hidden = false, showCount = true, onlyWithItems = false, size = 44, bg = PANEL_BG, border = GOLD },
    disenchant = { rows = 10, minQuality = 2, maxQuality = 3, protectSets = true,
        bg = PANEL_BG, border = GOLD },
    bags = { width = 300, iconSize = 28, showIcon = true, showButton = true, disabled = false, threshold = 4, rows = 10, maxQuality = 2, showNoValue = false, onlyJunk = false, ignoreProf = true, noAutoOpen = false,
        bg = PANEL_BG, border = GOLD },
}

ns.frames  = {}   -- Anker-Fenster, die im Edit Mode bewegt werden
ns.Apply   = {}   -- ns.Apply[key](cfg) wendet die Einstellungen an
ns.modules = {}   -- Module mit :Init()

-- roll: Platz für etwa vier Rollzeilen, damit der Edit-Mode-Rahmen alle Zeilen umfasst
local SIZES = { roll = { 300, 460 }, winner = { 480, 110 }, freeroll = { 260, 200 }, loot = { 250, 220 }, feed = { 340, 160 }, mine = { 280, 150 }, wallet = { 200, 44 }, toast = { 300, 252 }, bags = { 300, 46 }, deButton = { 44, 44 } }
local START = {
    roll = { 240, 520 },
    freeroll = { 1000, 400 },
    winner = { 720, 640 },      -- ungefähr Bildschirmmitte, oberhalb des Zentrums
    loot = { 900, 420 },
    feed = { 30, 190 },
    mine = { 900, 190 },
    wallet = { 900, 130 },
    toast = { 520, 560 },
    bags = { 520, 780 },
    deButton = { 1200, 300 },
}

-- Die frühere Bibliothek (EditModeExpanded) legte Schalter und Regler je Edit-Mode-Layout ab:
-- SexyLootDB.frames[key].profiles[Layout].settings[12 Schalter | 18 Regler][Option].
-- Einmalig in SexyLootDB.cfg übernehmen, bevor SexyEditMode die alten Daten wegräumt.
function ns.MigrateOldOptions()
    if SexyLootDB.optionsMigrated then return end
    local active
    local m = _G.EditModeManagerFrame
    if m and m.GetActiveLayoutInfo then
        local ok, info = pcall(m.GetActiveLayoutInfo, m)
        if ok and type(info) == "table" and info.layoutType and info.layoutName then
            active = info.layoutType .. "-" .. info.layoutName
        end
    end
    for key, def in pairs(ns.defaults) do
        local frameDB = SexyLootDB.frames and SexyLootDB.frames[key]
        local profiles = frameDB and frameDB.profiles
        if type(profiles) == "table" then
            local p = profiles[active or ""]
            if type(p) ~= "table" then
                -- aktives Layout unbekannt: das Layout nehmen, in dem verschoben wurde (zuletzt sortiert)
                local keys = {}
                for k, v in pairs(profiles) do
                    if type(v) == "table" and (v.x ~= v.defaultX or v.y ~= v.defaultY) then keys[#keys + 1] = k end
                end
                if #keys == 0 then
                    for k, v in pairs(profiles) do
                        if type(v) == "table" then keys[#keys + 1] = k end
                    end
                end
                table.sort(keys, function(x, y) return x > y end)
                p = keys[1] and profiles[keys[1]]
            end
            local settings = type(p) == "table" and p.settings
            if type(settings) == "table" then
                SexyLootDB.cfg[key] = SexyLootDB.cfg[key] or {}
                for _, kind in ipairs({ 12, 18 }) do
                    for opt, value in pairs(settings[kind] or {}) do
                        if def[opt] ~= nil and type(value) == "number" then
                            SexyLootDB.cfg[key][opt] = (kind == 12) and (value == 1) or value
                        end
                    end
                end
            end
        end
    end
    SexyLootDB.optionsMigrated = true
end

function ns.CreateFrames()
    for key, size in pairs(SIZES) do
        local f = CreateFrame("Frame", "SexyLoot" .. key .. "Anchor", UIParent)
        f:SetSize(size[1], size[2])
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", START[key][1], START[key][2])
        f:SetClampedToScreen(true)
        -- SexyEditMode speichert BOTTOMLEFT-Koordinaten in db.x / db.y; ohne gespeicherte
        -- Position gilt die Startposition
        local db = SexyLootDB.frames[key]
        if not (db.x and db.y) then
            db.x, db.y = START[key][1], START[key][2]
        end
        ns.frames[key] = f
    end
end

-- Wendet ns.cfg[key] auf das Fenster an (Zoom, Zeilen, Symbolgröße ...)
function ns.Refresh(key)
    if ns.Apply[key] and ns.cfg then ns.Apply[key](ns.cfg[key]) end
end

ns.Actions = {
    testRoll  = function() ns.RollFrames:Test() end,
    openLoot  = function() ns.LootWindow:Test() end,
    testWinner = function() ns.Winner:Test() end,
    testFree = function() ns.FreeRolls:Test() end,
    clearFeed = function() ns.Feed:Clear() end,
    clearMine = function() ns.MyLoot:Clear() end,
}

--------------------------------------------------------------------------
-- Hilfsfunktionen
--------------------------------------------------------------------------

ns.MEDIA = "Interface/AddOns/SexyLoot/media/"

-- Neun Texturteile um ein Ziel: vier Ecken fest, vier Kanten und die Mitte gedehnt.
--   texSize/tc: Kantenlänge der Textur und Eckgröße darin (Pixel)
--   disp:       Eckgröße auf dem Bildschirm
--   out:        wie weit das Ganze über das Ziel hinausragt
-- Liefert ein Objekt mit :SetColor(r, g, b, a).
function ns.NineSlice(parent, target, path, texSize, tc, disp, out, layer, sub)
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

-- Weiches Einblenden beim Erscheinen (Alpha-Animation, läuft einmal pro Aufruf)
function ns.FadeIn(frame, seconds)
    if not frame.fadeInAnim then
        local ag = frame:CreateAnimationGroup()
        local a = ag:CreateAnimation("Alpha")
        if a.SetFromAlpha then
            a:SetFromAlpha(0)
            a:SetToAlpha(1)
        else
            a:SetChange(1)
        end
        a:SetSmoothing("OUT")
        frame.fadeInAnim, frame.fadeInAlpha = ag, a
    end
    frame.fadeInAlpha:SetDuration(seconds or 0.18)
    frame.fadeInAnim:Stop()
    frame.fadeInAnim:Play()
end

--------------------------------------------------------------------------
-- Look von SexyQuestHelper: Goldrahmen, Titelband mit Badge, Etiketten
--------------------------------------------------------------------------

ns.HEAD = 30                               -- Höhe von Rahmen oben plus Titelband
ns.INSET = 3                               -- Abstand des Inhalts zum Fensterrand (Rahmenstärke)
ns.BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
ns.BTN = { 0.15, 0.12, 0.07 }              -- Aktionsknopf in der Farbe des Titelbands (wie im Einstellungsfenster)
ns.TONES = {
    ok = { bg = { 0.082, 0.188, 0.11 }, fg = { 0.48, 0.88, 0.56 } },
    warn = { bg = { 0.227, 0.173, 0.063 }, fg = { 0.94, 0.75, 0.29 } },
    grey = { bg = { 0.16, 0.145, 0.12 }, fg = { 0.66, 0.61, 0.54 } },
    lack = { bg = { 0.231, 0.102, 0.09 }, fg = { 1, 0.6, 0.56 } },
    they = { bg = { 0.078, 0.157, 0.227 }, fg = { 0.53, 0.8, 1 } },
}

-- Schriften: Marcellus für Titel, Inter für Text (beide SIL OFL, Lizenzen in media/fonts).
-- Fehlt eine Datei oder braucht die Clientsprache andere Zeichen (Kyrillisch, Asiatisch),
-- gilt die Spielschrift. SetFont meldet false, wenn die Datei nicht geladen werden kann.
local probe = CreateFont("SexyLootFontProbe")
local function LoadFont(file)
    local loc = GetLocale()
    if loc == "ruRU" or loc == "koKR" or loc == "zhCN" or loc == "zhTW" then return STANDARD_TEXT_FONT end
    local path = ns.MEDIA .. "fonts/" .. file
    if probe:SetFont(path, 12, "") == false then return STANDARD_TEXT_FONT end
    return path
end
ns.FONT_TITLE = LoadFont("Marcellus-Regular.ttf")
ns.FONT_TEXT = LoadFont("Inter.ttf")

-- Schriftobjekte für FontStrings: SexyLootTitle (Band), SexyLootText (Namen), SexyLootSmall
-- (Etiketten, Zahlen), SexyLootDim (Nebentext)
local function MakeFont(name, file, size, r, g, b)
    local f = CreateFont(name)
    f:SetFont(file, size, "")
    f:SetTextColor(r, g, b)
    f:SetShadowColor(0, 0, 0, 1)
    f:SetShadowOffset(1, -1)
end
MakeFont("SexyLootTitle", ns.FONT_TITLE, 14, 0.91, 0.76, 0.42)
MakeFont("SexyLootText", ns.FONT_TEXT, 13, 0.95, 0.92, 0.86)
MakeFont("SexyLootSmall", ns.FONT_TEXT, 11, 0.95, 0.92, 0.86)
MakeFont("SexyLootDim", ns.FONT_TEXT, 11, 0.61, 0.57, 0.5)
MakeFont("SexyLootButton", ns.FONT_TEXT, 12, 0.91, 0.76, 0.42)

-- Vier Randlinien um einen Rahmen. Liefert ein Objekt mit :SetColorTexture(r, g, b, a).
function ns.Edges(parent, thick, layer)
    local e = {}
    local function tex()
        local t = parent:CreateTexture(nil, layer or "BORDER")
        e[#e + 1] = t
        return t
    end
    local t = tex(); t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT"); t:SetHeight(thick)
    t = tex(); t:SetPoint("BOTTOMLEFT"); t:SetPoint("BOTTOMRIGHT"); t:SetHeight(thick)
    t = tex(); t:SetPoint("TOPLEFT", 0, -thick); t:SetPoint("BOTTOMLEFT", 0, thick); t:SetWidth(thick)
    t = tex(); t:SetPoint("TOPRIGHT", 0, -thick); t:SetPoint("BOTTOMRIGHT", 0, thick); t:SetWidth(thick)
    function e:SetColorTexture(r, g, b, a)
        for _, x in ipairs(self) do x:SetColorTexture(r, g, b, a) end
    end
    return e
end

-- Etikett (Pille) mit Zustandsfarbe. Verankert wird p.tex, der Text folgt.
function ns.Pill(parent)
    local p = {}
    p.tex = parent:CreateTexture(nil, "ARTWORK")
    p.text = parent:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    p.text:SetPoint("CENTER", p.tex, "CENTER")
    function p:Set(tone, text, width, height)
        local t = ns.TONES[tone]
        self.tex:SetColorTexture(t.bg[1], t.bg[2], t.bg[3], 1)
        self.text:SetTextColor(t.fg[1], t.fg[2], t.fg[3])
        self.text:SetText(text)
        self.tex:SetSize(width or (self.text:GetStringWidth() + 18), height or 16)
        self.tex:Show()
        self.text:Show()
    end
    function p:Hide()
        self.tex:Hide()
        self.text:Hide()
    end
    return p
end

-- Fenster im Look des Questfensters: Tooltip-Fläche und Tooltip-Rand (ns.BACKDROP, Inhalt ab ns.INSET) und (mit Titel)
-- ein Titelband mit Badge rechts. f.fill = Fläche, f.accent = Rand, f.band = Band,
-- f.title = Titeltext, f:SetBadge(text) = Badge ("" blendet es aus). Rechts vom
-- Badge bleibt f.badgeInset Pixel frei (Standard 6, z. B. für einen Schließen-Knopf).
-- Kopfzeile je Fenster ein-/ausblendbar ("Kopfzeile ausblenden" im Edit Mode): ns.HEAD ist die Höhe von Rahmen und Band
for _, key in ipairs({ "roll", "freeroll", "loot", "feed", "mine" }) do ns.defaults[key].hideHeader = false end

-- Anker eines Fensters auf die Größe des tatsächlichen Inhalts bringen (statt auf die größtmögliche): so bleibt beim Andocken kein
-- Freiraum. growDown: das Fenster hängt oben am Anker und wächst nach unten, dann bleibt die Oberkante an ihrem Platz (die gespeicherte
-- Position gilt für die untere Kante und wird um die Höhenänderung verschoben; angedockt oder beim Ziehen nicht). Wächst es nach oben,
-- bleibt die Unterkante stehen, nichts ist zu tun.
function ns.ResizeAnchor(key, width, height, growDown)
    local anchor = ns.frames[key]
    if not anchor then return end
    height = math.max(1, math.floor(height + 0.5))
    local db = SexyLootDB and SexyLootDB.frames and SexyLootDB.frames[key]
    local before = db and db.anchoredHeight or anchor:GetHeight()
    anchor:SetSize(width, height)
    if db and growDown and db.x and db.y and before ~= height and not (SexyLootDB.dock and SexyLootDB.dock[key]) then
        local SEM = LibStub("SexyEditMode-1.0", true)
        if SEM and not SEM:IsMoving(anchor) then SEM:SetPosition(anchor, db.x, db.y - (height - before)) end
    end
    if db then db.anchoredHeight = height end
end

function ns.FramedPanel(parent, title)
    -- Rahmen wie im Fenster von SexyQuestHelper: Tooltip-Fläche und Tooltip-Rand,
    -- Fläche und Rand werden über SetBackdropColor/SetBackdropBorderColor gefärbt.
    local f = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetBackdrop(ns.BACKDROP)
    f:SetBackdropColor(0.08, 0.065, 0.05, 0.96)
    f:SetBackdropBorderColor(0.42, 0.34, 0.15, 1)
    -- Dieselben Namen wie bisher (ns.ApplyStyle): f.fill = Fläche, f.accent = Rand
    f.fill = { SetColorTexture = function(_, r, g, b, a) f:SetBackdropColor(r, g, b, a) end }
    f.accent = { SetColorTexture = function(_, r, g, b, a) f:SetBackdropBorderColor(r, g, b, a) end }
    if title then
        f.band = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        f.band:SetPoint("TOPLEFT", ns.INSET, -ns.INSET)
        f.band:SetPoint("TOPRIGHT", -ns.INSET, -ns.INSET)
        f.band:SetHeight(ns.HEAD - ns.INSET)
        f.band:SetColorTexture(0.15, 0.12, 0.07, 0.96)
        f.title = f:CreateFontString(nil, "OVERLAY", "SexyLootTitle")
        f.title:SetPoint("LEFT", f.band, "LEFT", 8, 0)
        f.title:SetText(title)
    end
    -- f.headH: Abstand der Fensterinhalte zur Oberkante (mit Titelband ns.HEAD, ohne nur der Rand)
    f.headH = ns.HEAD
    function f:SetHeaderShown(show)
        if not self.band then return end
        self.headerHidden = not show
        self.headH = show and ns.HEAD or (ns.INSET + 3)
        self.band:SetShown(show)
        self.title:SetShown(show)
        self:SetBadge(self.badgeValue)
    end
    function f:SetBadge(text)
        self.badgeValue = text
        if not self.band then return end
        if not self.badgeBg then
            self.badgeBg = self:CreateTexture(nil, "ARTWORK")
            self.badgeBg:SetPoint("RIGHT", self.band, "RIGHT", -(self.badgeInset or 6), 0)
            self.badgeBg:SetHeight(18)
            self.badgeBg:SetColorTexture(0.165, 0.14, 0.10, 1)
            self.badgeText = self:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
            self.badgeText:SetPoint("CENTER", self.badgeBg, "CENTER")
            self.badgeText:SetTextColor(0.78, 0.73, 0.64)
        end
        local show = text and text ~= "" and not self.headerHidden
        self.badgeBg:SetShown(show and true or false)
        self.badgeText:SetShown(show and true or false)
        if show then
            self.badgeText:SetText(text)
            self.badgeBg:SetWidth(self.badgeText:GetStringWidth() + 18)
        end
    end
    return f
end

-- Flacher grüner Knopf wie "Teilen" im Questfenster. b.text ist der Beschriftungstext.
-- Look der Knöpfe wie im Einstellungsfenster (SexyEditMode): Bandfarbe, goldene Schrift, Tooltip-Rand in der Randfarbe.
-- Erwartet b.bg, b.hl und b.text; auch für gesicherte Knöpfe.
function ns.StyleButton(b)
    b.bg:SetColorTexture(ns.BTN[1], ns.BTN[2], ns.BTN[3], 1)
    b.hl:SetColorTexture(1, 1, 1, 0.12)
    b.text:SetTextColor(0.91, 0.76, 0.42)
    b.text:SetFont(ns.FONT_TEXT, 12, "")
    if BackdropTemplateMixin and not b.rim then
        local rim = CreateFrame("Frame", nil, b, "BackdropTemplate")
        rim:SetAllPoints(b)
        rim:SetFrameLevel(b:GetFrameLevel() + 2)
        rim:SetBackdrop({ edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10 })
        rim:SetBackdropBorderColor(0.42, 0.34, 0.15, 1)
        b.rim = rim
    end
end

function ns.Button(parent)
    local SEM = LibStub("SexyEditMode-1.0", true)
    if SEM and SEM.ui and SEM.ui.HeaderButton then
        local hb = SEM.ui.HeaderButton(parent, "", 100, 22)
        -- Schriftobjekt wie bei den übrigen Texten (die funktionieren), kein SetFont mit Dateipfad
        hb.text:SetFontObject(SexyLootButton)
        -- Schrift ausdrücklich gold und ganz oben (über Rand und Fläche)
        hb.text:SetDrawLayer("OVERLAY", 7)
        hb.text:SetTextColor(0.91, 0.76, 0.42, 1)
        hb.text:SetAlpha(1)
        -- Nach frischem Login blieb der Text oft unsichtbar (nach /reload nicht): beim Einblenden und
        -- einmal verzögert Schrift, Farbe und Text neu setzen, damit das Layout der Schrift neu entsteht
        local function Refresh(self)
            local t = self.text
            local s = t:GetText() or ""
            t:SetFontObject(SexyLootButton)
            t:SetDrawLayer("OVERLAY", 7)
            t:SetTextColor(0.91, 0.76, 0.42, 1)
            t:SetAlpha(1)
            t:SetText("")
            t:SetText(s)
        end
        hb:HookScript("OnShow", Refresh)
        if C_Timer and C_Timer.After then C_Timer.After(0, function() Refresh(hb) end) end
        return hb
    end
    local b = CreateFrame("Button", nil, parent)
    b:RegisterForClicks("LeftButtonUp")
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.text = b:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    b.text:SetAllPoints()
    ns.StyleButton(b)
    return b
end

-- Auf dem Forever-Client fehlen manche Item-Globals, daher C_Item bevorzugen.
function ns.GetItemInfo(...)
    local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if f then return f(...) end
end

-- Preis eines Stücks: Händlerpreis oder Auktionspreis eines installierten Preis-Addons
-- (Auctionator, TSM, Oribos Exchange, Auctioneer). Einstellung SexyLootDB.priceSource:
-- "auction" (Standard: Auktionspreis, ohne Treffer der Händlerpreis) oder "vendor".
-- Jede Quelle bekommt den Item-Link und die Item-ID. Ausrüstung hat im Link Bonus-IDs und Stufen, zu
-- denen ein Preis-Addon oft nichts kennt; darum probieren die Quellen zusätzlich den Preis der Basis-ID.
local AUCTION_SOURCES = {
    { "Auctionator", function(link, id)
        local A = _G.Auctionator
        local api = A and A.API and A.API.v1
        if not api then return end
        local price = api.GetAuctionPriceByItemLink and api.GetAuctionPriceByItemLink("SexyLoot", link)
        if (not price or price <= 0) and id and api.GetAuctionPriceByItemID then
            price = api.GetAuctionPriceByItemID("SexyLoot", id)
        end
        -- Der Tooltip liest direkt aus der Datenbank: dasselbe versuchen, falls die Schnittstelle nichts liefert
        if (not price or price <= 0) and A.Database and A.Database.GetPrice then
            local U = A.Utilities
            local keys = {}
            if U and U.BasicDBKeyFromLink then keys[#keys + 1] = U.BasicDBKeyFromLink(link) end
            if id then keys[#keys + 1] = tostring(id) end
            for _, key in ipairs(keys) do
                local ok, value = pcall(A.Database.GetPrice, A.Database, key)
                if ok and type(value) == "number" and value > 0 then price = value break end
            end
        end
        return price
    end },
    -- Mastercraft hat keine öffentliche Schnittstelle: die gespeicherten Scan-Preise (MastercraftDB) direkt lesen,
    -- je Server+Fraktion ein Buch; das jüngste Buch dieser Fraktion mit dem Item gewinnt
    { "Mastercraft", function(link, id)
        local db = _G.MastercraftDB
        if not (id and db and type(db.prices) == "table") then return end
        local faction = UnitFactionGroup and UnitFactionGroup("player") or ""
        local best, bestT
        for key, book in pairs(db.prices) do
            local e = type(book) == "table" and type(book.items) == "table" and book.items[id]
            if type(e) == "table" and not e.gone and type(e.p) == "number" and e.p > 0
                and tostring(key):sub(-#faction - 1) == "-" .. faction and (not bestT or (e.t or 0) > bestT) then
                best, bestT = e.p, e.t or 0
            end
        end
        return best
    end },
    { "TSM", function(link, id)
        local tsm = _G.TSM_API
        if not (tsm and tsm.GetCustomPriceValue) then return end
        local price
        if tsm.ToItemString then
            local item = tsm.ToItemString(link)
            price = item and tsm.GetCustomPriceValue("DBMarket", item)
        end
        if (not price or price <= 0) and id then price = tsm.GetCustomPriceValue("DBMarket", "i:" .. id) end
        return price
    end },
    { "Oribos Exchange", function(link)
        if _G.OEMarketInfo then
            local t = {}
            _G.OEMarketInfo(link, t)
            return t.market
        end
    end },
    { "Auctioneer", function(link)
        local A = _G.AucAdvanced
        if A and A.API and A.API.GetMarketValue then return A.API.GetMarketValue(link) end
    end },
}

local priceCache = {}   -- [Link] = { Preis, bis }

local function AuctionPrice(link)
    local c = priceCache[link]
    local now = GetTime()
    if c and c[2] > now then return c[1] end
    local price
    local id = ns.ItemID(link)
    for _, source in ipairs(AUCTION_SOURCES) do
        local ok, value = pcall(source[2], link, id)
        if ok and type(value) == "number" and value > 0 then price = value break end
    end
    priceCache[link] = { price, now + (price and 30 or 5) }  -- "kein Preis" nur kurz merken, die Datenbank lädt evtl. noch
    return price
end

-- /sl price [Item]: zeigt, welche Preis-Addons geladen sind und was jedes für das Item liefert
function ns.PriceDebug(link)
    local say = function(text) print("|cffe8c26aSexyLoot|r: " .. text) end
    local id = link and ns.ItemID(link)
    say("Preisquelle: " .. tostring((SexyLootDB and SexyLootDB.priceSource) or "auction") .. ", Item: " .. tostring(link))
    for _, source in ipairs(AUCTION_SOURCES) do
        local loaded = (source[1] == "Auctionator" and _G.Auctionator) or (source[1] == "TSM" and _G.TSM_API) or (source[1] == "Mastercraft" and _G.MastercraftDB)
            or (source[1] == "Oribos Exchange" and _G.OEMarketInfo) or (source[1] == "Auctioneer" and _G.AucAdvanced)
        if not loaded then
            say("  " .. source[1] .. ": nicht geladen")
        elseif link then
            local ok, value = pcall(source[2], link, id)
            say("  " .. source[1] .. ": " .. (ok and tostring(value) or ("Fehler: " .. tostring(value))))
        else
            say("  " .. source[1] .. ": geladen (Item angeben: /sl price [Item])")
        end
    end
end

-- Liefert den Preis und ob er ein Auktionspreis ist
function ns.ItemPrice(link, vendor)
    vendor = vendor or 0
    if not link or (SexyLootDB and SexyLootDB.priceSource == "vendor") then return vendor, false end
    local auction = AuctionPrice(link)
    if auction then return auction, true end
    return vendor, false
end

function ns.GetItemInfoInstant(...)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if f then return f(...) end
end

ns.qualityFallback = {
    [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 },
    [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 },
    [6] = { 0.9, 0.8, 0.5 }, [7] = { 0, 0.8, 1 },
}

-- Hintergrund- und Randfarbe des Fensters aus ns.cfg[key] auf ein Panel anwenden
function ns.ApplyStyle(panel, key)
    local cfg = ns.cfg and ns.cfg[key]
    if not (panel and cfg) then return end
    local bg, bd = cfg.bg, cfg.border
    local alpha = cfg.opacity or bg[4]   -- Deckkraft des Fensters (Einstellung), sonst der Wert der Vorgabe
    panel.fill:SetColorTexture(bg[1], bg[2], bg[3], alpha)
    panel.accent:SetColorTexture(bd[1], bd[2], bd[3], bd[4])
    if panel.band then panel.band:SetColorTexture(0.15, 0.12, 0.07, alpha) end
end

function ns.QualityColor(q)
    q = q or 1
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    if C_Item and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(q)
        if r then return r, g, b end
    end
    if GetItemQualityColor then
        local r, g, b = GetItemQualityColor(q)
        if r then return r, g, b end
    end
    local fallback = ns.qualityFallback[q]
    if fallback then return fallback[1], fallback[2], fallback[3] end
    return 1, 1, 1
end

-- Diagnose: /sexyloot debug schaltet Ausgaben zu Würfen und Klicks ein
function ns.Dbg(...)
    if ns.debug then print("|cff66ccffSexyLoot debug|r", ...) end
end

function ns.Short(name)
    if not name then return "?" end
    return Ambiguate and Ambiguate(name, "short") or name
end

ns.classByName = {}

-- Auf diesem Client kennt die Gruppenliste nur den Vornamen ("Arak"), der Chat
-- den ganzen Namen ("Arak Ragerunner"). Beide Formen gelten als derselbe Spieler,
-- wenn der kürzere ein Wortanfang des längeren ist.
function ns.SameName(a, b)
    if not (a and b) then return false end
    if a == b then return true end
    return a:sub(1, #b + 1) == b .. " " or b:sub(1, #a + 1) == a .. " "
end

local function AddUnit(list, unit)
    if not UnitExists(unit) then return end
    -- Immer ohne Realm, damit Gruppenliste und Chatnamen übereinstimmen
    local name = UnitName(unit)
    name = name and ns.Short(name)
    if not name then return end
    local _, class = UnitClass(unit)
    ns.classByName[name] = class
    list[#list + 1] = name
end

-- Alle Gruppenmitglieder, du selbst zuerst
function ns.Roster()
    local list = {}
    AddUnit(list, "player")
    if IsInRaid and IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if not UnitIsUnit("raid" .. i, "player") then AddUnit(list, "raid" .. i) end
        end
    elseif IsInGroup and IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do AddUnit(list, "party" .. i) end
    end
    return list
end

function ns.ColorName(name)
    name = ns.Short(name)
    local class = ns.classByName[name]
    if not class then
        for known, c in pairs(ns.classByName) do
            if ns.SameName(known, name) then class = c break end
        end
    end
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, name) end
    return name
end

function ns.ItemID(link)
    return link and tonumber(link:match("item:(%d+)"))
end

--------------------------------------------------------------------------
-- Demodaten im Edit Mode
--------------------------------------------------------------------------

-- Solange der Edit Mode offen ist, zeigt jedes Modul Beispielinhalte
-- (m:Preview(true)). Beim Verlassen räumt es sie wieder weg (m:Preview(false)).
function ns.SetEditMode(active)
    ns.editing = active and true or false
    for _, m in ipairs(ns.modules) do
        -- Ein Fehler in einem Modul darf die Vorschau der anderen nicht verhindern
        if m.Preview then
            local ok, err = pcall(m.Preview, m, ns.editing)
            if not ok then print("|cffe8c26aSexyLoot|r: Vorschau-Fehler: " .. tostring(err)) end
        end
    end
end

--------------------------------------------------------------------------
-- Start
--------------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
    if name ~= ADDON then return end
    f:UnregisterEvent("ADDON_LOADED")

    SexyLootDB = SexyLootDB or {}
    SexyLootDB.frames = SexyLootDB.frames or {}
    SexyLootDB.cfg = SexyLootDB.cfg or {}
    ns.MigrateOldOptions()
    ns.cfg = {}
    for key, def in pairs(ns.defaults) do
        SexyLootDB.frames[key] = SexyLootDB.frames[key] or {}
        -- gespeichert werden nur geänderte Werte; alles andere kommt aus den Standardwerten
        SexyLootDB.cfg[key] = SexyLootDB.cfg[key] or {}
        ns.cfg[key] = setmetatable(SexyLootDB.cfg[key], { __index = def })
    end
    -- Farben sind fest (Quest-Look) und nicht mehr einstellbar; alte gespeicherte Farbwahlen entfallen
    SexyLootDB.colors = nil

    -- frühere Versionen speicherten die Wachstumsrichtung getrennt
    if SexyLootDB.mineGrowDown ~= nil then
        ns.cfg.mine.growDown = SexyLootDB.mineGrowDown and true or false
        SexyLootDB.mineGrowDown = nil
    end

    ns.CreateFrames()
    for _, m in ipairs(ns.modules) do m:Init() end
    ns.SetupEditMode()
    for key in pairs(ns.defaults) do ns.Refresh(key) end
end)

SLASH_SEXYLOOT1 = "/sexyloot"
SLASH_SEXYLOOT2 = "/sl"
SlashCmdList.SEXYLOOT = function(msg)
    local rawMsg = msg or ""
    msg = rawMsg:lower()
    if msg == "roll" then
        ns.Actions.testRoll()
    elseif msg == "loot" then
        ns.Actions.openLoot()
    elseif msg == "feed" then
        ns.Feed:Test()
    elseif msg == "mine" then
        ns.MyLoot:Test()
    elseif msg == "toast" then
        ns.Toast:Test()
    elseif msg == "debug" then
        ns.debug = not ns.debug
        print("|cffe8c26aSexyLoot|r: debug " .. (ns.debug and "an" or "aus"))
    elseif msg == "freeroll" then
        ns.Actions.testFree()
    elseif msg == "winner" then
        ns.Actions.testWinner()
    elseif msg:sub(1, 5) == "price" then
        local link = rawMsg:match("(|c%x+|Hitem:.-|h.-|h|r)")
        local id = msg:match("^price%s+(%d+)")
        if not link and id then link = select(2, ns.GetItemInfo(tonumber(id))) end
        ns.PriceDebug(link)
    elseif msg == "minimap" then
        SexyLoot_ToggleMinimapButton()
    elseif msg == "bags" then
        ns.Bags:Toggle()
    elseif msg == "de" or msg == "disenchant" then
        ns.Disenchant:Toggle()
    elseif msg == "test" then
        ns.Actions.testRoll(); ns.Actions.openLoot(); ns.Feed:Test(); ns.MyLoot:Test(); ns.Toast:Test()
    else
        print("|cffe8c26aSexyLoot|r: /sexyloot test | roll | loot | feed | mine | toast | winner | freeroll | bags | de")
        print(ns.T["Positionen und Optionen: /sem öffnen, dort „Fenster entsperren“ wählen und ein SexyLoot-Fenster anklicken."])
    end
end
