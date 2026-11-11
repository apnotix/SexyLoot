local ADDON, ns = ...

-- Standardwerte. Sie stehen hier, weil Schieberegler ihr onChanged
-- beim Laden nur mit gespeicherten Werten aufrufen.
-- Checkboxen sind im Standard immer false.
-- Farben (r, g, b, Deckkraft). Sie stehen in ns.cfg[key].bg / .border und
-- werden zusätzlich in SexyLootDB.colors gespeichert, weil EditModeExpanded
-- Farbwahlen nicht ablegt.
-- Fenster im Look von SexyQuestHelper: dunkelbraune Fläche, Goldrand
local PANEL_BG = { 0.08, 0.065, 0.05, 0.96 }
local GOLD = { 0.42, 0.34, 0.15, 1 }
ns.defaults = {
    roll = { hideRolls = false, growUp = false, gap = 10, size = 14, hold = 12, maxHeight = 440,
        bg = PANEL_BG, border = GOLD },
    freeroll = { single = false, size = 14, hold = 30, rows = 10, chanNum = 1,
        bg = PANEL_BG, border = GOLD },
    winner = { size = 28, hold = 6, max = 3,
        bg = PANEL_BG, border = GOLD },
    loot = { auto = false, noAutoMoney = false, thr = 2, icon = 34,
        bg = PANEL_BG, border = GOLD },
    feed = { hideStamp = false, sortPlayers = false, noFade = false, fade = 20, width = 340, height = 160, size = 15,
        bg = { 0.08, 0.065, 0.05, 0.88 }, border = GOLD },
    mine = { growDown = false, hideTime = false, hideValue = false, hideItemValue = false, noStack = false, rows = 7,
        bg = PANEL_BG, border = GOLD },
    toast = { hideValue = false, hold = 6, rows = 6 },
    wallet = { bg = PANEL_BG, border = GOLD },
}

ns.frames  = {}   -- Anker-Fenster, die im Edit Mode bewegt werden
ns.Apply   = {}   -- ns.Apply[key](cfg) wendet die Einstellungen an
ns.modules = {}   -- Module mit :Init()

-- roll: Platz für etwa vier Rollzeilen, damit der Edit-Mode-Rahmen alle Zeilen umfasst
local SIZES = { roll = { 300, 460 }, winner = { 480, 110 }, freeroll = { 260, 200 }, loot = { 250, 220 }, feed = { 340, 160 }, mine = { 280, 150 }, wallet = { 200, 44 }, toast = { 300, 252 } }
local START = {
    roll = { 240, 520 },
    freeroll = { 1000, 400 },
    winner = { 720, 640 },      -- ungefähr Bildschirmmitte, oberhalb des Zentrums
    loot = { 900, 420 },
    feed = { 30, 190 },
    mine = { 900, 190 },
    wallet = { 900, 130 },
    toast = { 520, 560 },
}

function ns.CreateFrames()
    for key, size in pairs(SIZES) do
        local f = CreateFrame("Frame", "SexyLoot" .. key .. "Anchor", UIParent)
        f:SetSize(size[1], size[2])
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", START[key][1], START[key][2])
        f:SetClampedToScreen(true)
        -- EME erwartet BOTTOMLEFT-Bildschirmkoordinaten in db.x / db.y. Ist die
        -- Tabelle leer, kann die Bibliothek das Fenster ohne Ankerpunkt zurücklassen
        -- (unsichtbar auch im Edit Mode). Darum die Startposition selbst eintragen.
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
ns.BTN = { 0.184, 0.42, 0.235 }            -- grüner Aktionsknopf
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

-- Flaches Fenster im Look des Questfensters: Fläche, 2px Goldrand und (mit Titel)
-- ein Titelband mit Badge rechts. f.fill = Fläche, f.accent = Rand, f.band = Band,
-- f.title = Titeltext, f:SetBadge(text) = Badge ("" blendet es aus). Rechts vom
-- Badge bleibt f.badgeInset Pixel frei (Standard 6, z. B. für einen Schließen-Knopf).
function ns.FramedPanel(parent, title)
    local f = CreateFrame("Frame", nil, parent)
    f.fill = f:CreateTexture(nil, "BACKGROUND")
    f.fill:SetAllPoints()
    f.fill:SetColorTexture(0.08, 0.065, 0.05, 0.96)
    f.accent = ns.Edges(f, 2, "BORDER")
    f.accent:SetColorTexture(0.42, 0.34, 0.15, 1)
    if title then
        f.band = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        f.band:SetPoint("TOPLEFT", 2, -2)
        f.band:SetPoint("TOPRIGHT", -2, -2)
        f.band:SetHeight(ns.HEAD - 2)
        f.band:SetColorTexture(0.15, 0.12, 0.07, 0.96)
        f.title = f:CreateFontString(nil, "OVERLAY", "SexyLootTitle")
        f.title:SetPoint("LEFT", f.band, "LEFT", 8, 0)
        f.title:SetText(title)
    end
    function f:SetBadge(text)
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
        local show = text and text ~= ""
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
function ns.Button(parent)
    local b = CreateFrame("Button", nil, parent)
    b:RegisterForClicks("LeftButtonUp")
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(ns.BTN[1], ns.BTN[2], ns.BTN[3], 1)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.25)
    b.text = b:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
    b.text:SetAllPoints()
    return b
end

-- Auf dem Forever-Client fehlen manche Item-Globals, daher C_Item bevorzugen.
function ns.GetItemInfo(...)
    local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if f then return f(...) end
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
    panel.fill:SetColorTexture(bg[1], bg[2], bg[3], bg[4])
    panel.accent:SetColorTexture(bd[1], bd[2], bd[3], bd[4])
    if panel.band then panel.band:SetColorTexture(0.15, 0.12, 0.07, bg[4]) end
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

function ns.HookEditMode()
    if not EditModeManagerFrame then return end
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function() ns.SetEditMode(true) end)
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function() ns.SetEditMode(false) end)
    local active = EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive()
        or EditModeManagerFrame.editModeActive
    if active then ns.SetEditMode(true) end
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
    ns.cfg = {}
    for key, def in pairs(ns.defaults) do
        -- EME braucht pro Fenster eine bereits vorhandene Tabelle
        SexyLootDB.frames[key] = SexyLootDB.frames[key] or {}
        ns.cfg[key] = CopyTable(def)
    end
    -- Gespeicherte Farben über die Standardfarben legen
    SexyLootDB.colors = SexyLootDB.colors or {}
    for key, saved in pairs(SexyLootDB.colors) do
        if ns.cfg[key] then
            for _, k in ipairs({ "bg", "border" }) do
                if type(saved[k]) == "table" and #saved[k] == 4 then ns.cfg[key][k] = CopyTable(saved[k]) end
            end
        end
    end

    -- Wachstumsrichtung von "Zuletzt gelootet": gilt für alle Edit-Mode-Layouts
    -- (EME-Checkboxen sind pro Layout), darum eigener Schalter in SexyLootDB
    ns.cfg.mine.growDown = SexyLootDB.mineGrowDown and true or false

    ns.CreateFrames()
    for _, m in ipairs(ns.modules) do m:Init() end
    ns.SetupEditMode()
    for key in pairs(ns.defaults) do ns.Refresh(key) end
    ns.HookEditMode()
end)

SLASH_SEXYLOOT1 = "/sexyloot"
SLASH_SEXYLOOT2 = "/sl"
SlashCmdList.SEXYLOOT = function(msg)
    msg = (msg or ""):lower()
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
    elseif msg == "test" then
        ns.Actions.testRoll(); ns.Actions.openLoot(); ns.Feed:Test(); ns.MyLoot:Test(); ns.Toast:Test()
    else
        print("|cffe8c26aSexyLoot|r: /sexyloot test | roll | loot | feed | mine | toast | winner | freeroll")
        print(ns.T["Positionen und Optionen: Edit Mode öffnen und ein SexyLoot-Fenster anklicken."])
    end
end
