local ADDON, ns = ...
local T = ns.T

-- Eigene Vorschau-Fenster für die übrigen Fenster (siehe Samples.lua für das Rollfenster): Jedes Fenster baut sich mit denselben
-- Bausteinen wie das echte (ns.FramedPanel, ns.Pill, ns.Button), mit ausgedachten Beispielen, folgt den Einstellungen und meldet
-- seine Teile als Klickbereiche (jump = Einstellung, "Schlüssel.Option" oder Name der Einstellung).
-- Aufruf: ns.Samples[key](host, cache) -> { w, h, parts = { { name, x, y, w, h, jump }, ... } }

local S = ns.Samples
local CARD = { 0.145, 0.125, 0.10, 1 }
local MEDIA = ns.MEDIA or "Interface/AddOns/SexyLoot/media/"

local function Coins(copper, size)
    if GetCoinTextureString then return GetCoinTextureString(copper, size) end
    return GetMoneyString(copper)
end

-- Klassenfarben der ausgedachten Spieler
ns.classByName.Aldrin, ns.classByName.Mirelle, ns.classByName.Thokk, ns.classByName.Vexa =
    "WARRIOR", "PRIEST", "SHAMAN", "ROGUE"
ns.classByName.Bryn, ns.classByName.Cael, ns.classByName.Dova, ns.classByName.Elric, ns.classByName.Fenna, ns.classByName.Gorm =
    "MAGE", "DRUID", "HUNTER", "PALADIN", "WARLOCK", "WARRIOR"

local function Panel(host, c, title, key)
    if not c.win then
        c.win = ns.FramedPanel(host, title)
        c.win:SetPoint("TOPLEFT", host, "TOPLEFT")
    end
    if key then ns.ApplyStyle(c.win, key) end
    return c.win
end

local function Add(parts, name, x, y, w, h, jump)
    parts[#parts + 1] = { name = name, x = x, y = y, w = w, h = h, jump = jump }
end

local function RGB(q) return ns.QualityColor(q) end

-- Platz eines Teils relativ zum Fenster (nil, solange das Layout noch nicht berechnet ist)
local function Rel(w, region)
    if not (region and region:IsShown()) then return end
    local fl, ft = w:GetLeft(), w:GetTop()
    local l, t, r, b = region:GetLeft(), region:GetTop(), region:GetRight(), region:GetBottom()
    if not (fl and ft and l and t and r and b) then return end
    return l - fl, ft - t, r - l, t - b
end

local function Redraw()
    local SEM = LibStub("SexyEditMode-1.0", true)
    if SEM and SEM.RedrawSample then SEM:RedrawSample() end
end

-- Teil messen und melden; ist das Layout noch nicht berechnet, wird einmal kurz danach neu gezeichnet
-- text = true: Breite des Textes statt der ganzen Fläche
local function Region(parts, c, w, region, name, jump, pad, text)
    local x, y, rw, rh = Rel(w, region)
    if not x then
        if region and region:IsShown() and GetTime() - (c.retryAt or 0) > 0.5 then
            c.retryAt = GetTime()
            C_Timer.After(0.1, Redraw)
        end
        return
    end
    if text and region.GetStringWidth then
        local tw = region:GetStringWidth()
        if tw and tw > 0 and tw < rw then rw = tw end
    end
    pad = pad or 0
    Add(parts, name, x - pad, y - pad, rw + 2 * pad, rh + 2 * pad, jump)
end

-- Deckkraft (linker Rand), Hintergrundfarbe (Innenfläche unten) und Randfarbe (unterer Rand) eines Fensters
local function Look(parts, key, W, H)
    Add(parts, T["Deckkraft des Fensters"], 0, 0, 5, H, key .. ".opacity")
    Add(parts, T["Hintergrundfarbe"], 5, H - 11, W - 10, 6, key .. ".bg")
    Add(parts, T["Randfarbe"], 0, H - 5, W, 5, key .. ".border")
end

-- Freie Würfe -----------------------------------------------------------------------------------------------------------

local FREE = { { "Aldrin", 92 }, { "Mirelle", 77 }, { "Thokk", 61 }, { "Vexa", 34 }, { "Bryn", 28 }, { "Cael", 22 },
    { "Dova", 17 }, { "Elric", 12 }, { "Fenna", 8 }, { "Gorm", 4 } }
local FREE_HOLD = 12   -- Sekunden, nach denen die Vorschau-Liste "ausläuft" und von vorn beginnt

function S.freeroll(host, c)
    local cfg = ns.cfg.freeroll
    local W = cfg.width or 260

    if not c.win then
        local w = Panel(host, c, T["Freie Würfe"], nil)
        w.lines = {}
        w.bar = CreateFrame("StatusBar", nil, w)
        w.bar:SetHeight(3)
        w.bar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
        w.bar:SetStatusBarColor(0.91, 0.76, 0.42)
        w.bar.bg = w.bar:CreateTexture(nil, "BACKGROUND")
        w.bar.bg:SetAllPoints()
        w.bar.bg:SetColorTexture(0, 0, 0, 0.6)
        local SEM = LibStub("SexyEditMode-1.0", true)
        if SEM and SEM.ShineBar then SEM:ShineBar(w.bar) end
        w.btn = ns.Button(w)
        w.btn:SetSize(140, 22)
        w.btn:SetPoint("BOTTOMRIGHT", -8, 6)
        c.t0 = GetTime()
        local shown = -1
        w:SetScript("OnUpdate", function()
            local left = FREE_HOLD - ((GetTime() - c.t0) % FREE_HOLD)
            w.bar:SetMinMaxValues(0, FREE_HOLD)
            w.bar:SetValue(left)
            local s = math.ceil(left)
            if s ~= shown then
                shown = s
                w:SetBadge(T("Schließt in %ds", s))
            end
        end)
    end
    local w = Panel(host, c, nil, "freeroll")
    w:SetHeaderShown(not cfg.hideHeader)
    local head = w.headH + 8
    w.bar:SetShown(cfg.showBar ~= false)
    w.bar:ClearAllPoints()
    w.bar:SetPoint("TOPLEFT", ns.INSET, -w.headH)
    w.bar:SetPoint("TOPRIGHT", -ns.INSET, -w.headH)

    local size = cfg.size
    local lh = size + 8 + (cfg.lineGap or 0)
    local n = math.min(#FREE, cfg.rows)
    w.title:SetText(T("Freie Würfe (%d)", #FREE))

    for i = 1, n do
        local d = FREE[i]
        local l = w.lines[i]
        if not l then
            l = CreateFrame("Frame", nil, w)
            l.bg = l:CreateTexture(nil, "BACKGROUND")
            l.bg:SetAllPoints()
            l.rank = ns.Pill(l)
            l.rank.tex:SetPoint("LEFT", 6, 0)
            l.check = l:CreateTexture(nil, "OVERLAY")
            l.check:SetTexture("Interface/RaidFrame/ReadyCheck-Ready")
            l.check:SetPoint("RIGHT", -6, 0)
            l.roll = l:CreateFontString(nil, "OVERLAY")
            l.roll:SetPoint("RIGHT", l.check, "LEFT", -4, 0)
            l.roll:SetJustifyH("RIGHT")
            l.name = l:CreateFontString(nil, "OVERLAY")
            l.name:SetPoint("LEFT", l.rank.tex, "RIGHT", 6, 0)
            l.name:SetJustifyH("LEFT")
            l.name:SetWordWrap(false)
            w.lines[i] = l
        end
        local best = i == 1
        l:SetHeight(lh)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", w, "TOPLEFT", 6, -(head + (i - 1) * lh))
        l:SetPoint("TOPRIGHT", w, "TOPRIGHT", -6, -(head + (i - 1) * lh))
        l.check:SetSize(size, size)
        l.name:SetFont(ns.FONT_TEXT, size, "")
        l.roll:SetFont(ns.FONT_TEXT, size + 2, "OUTLINE")
        l.name:SetPoint("RIGHT", l.roll, "LEFT", -6, 0)
        local rank = cfg.showRank ~= false
        if rank then l.rank:Set(best and "warn" or "grey", tostring(i), 24, 16) else l.rank:Hide() end
        l.name:ClearAllPoints()
        l.name:SetPoint("LEFT", rank and l.rank.tex or l, rank and "RIGHT" or "LEFT", 6, 0)
        l.name:SetPoint("RIGHT", l.roll, "LEFT", -6, 0)
        l.name:SetText(ns.ColorName(d[1]))
        l.roll:SetText(tostring(d[2]))
        l.roll:SetTextColor(best and 1 or 0.95, best and 0.82 or 0.95, best and 0.2 or 0.95)
        l.check:SetShown(best and cfg.showCheck ~= false)
        if best then
            l.bg:SetColorTexture(0.91, 0.76, 0.42, 0.20)
        else
            l.bg:SetColorTexture(1, 1, 1, (cfg.zebra ~= false and i % 2 == 0) and 0.05 or 0)
        end
        l:Show()
    end
    for i = n + 1, #w.lines do w.lines[i]:Hide() end

    w.btn.text:SetText(T["Gewinner ansagen"])
    w.btn:SetWidth(math.max(120, w.btn.text:GetStringWidth() + 24))
    local g = ns.TONES.grey.bg
    w.btn.bg:SetColorTexture(g[1], g[2], g[3], 1)   -- ausgegraut wie in der Vorschau des echten Fensters

    w.btn:SetShown(cfg.showButton ~= false)
    local H = head + n * lh + 8 + (cfg.showButton ~= false and 28 or 0)
    w:SetSize(W, H)

    local parts = {}
    local gap = cfg.lineGap or 0
    Add(parts, T["Fenster"], 0, 0, W, H, "_pos")
    Look(parts, "freeroll", W, H)
    Add(parts, T["Kopfzeile"], 0, 0, W, w.headH, "freeroll.hideHeader")
    Add(parts, T["Schriftgröße"], 6, head, W - 12, n * lh, "freeroll.size")
    Add(parts, T["Maximale Zeilen"], 6, head + n * lh, W - 12, 8, "freeroll.rows")
    Add(parts, T["Breite"], W - 5, 0, 5, H, "freeroll.width")
    if gap > 0 then
        for i = 1, n - 1 do Add(parts, T["Zeilenabstand"], 6, head + i * lh - gap, W - 12, gap, "freeroll.lineGap") end
    end
    if cfg.showBar ~= false then
        Region(parts, c, w, w.bar, T["Liste leeren nach (Sekunden ohne Wurf)"], "freeroll.hold", 3)
    end
    if cfg.showRank ~= false then
        for i = 1, n do Region(parts, c, w, w.lines[i].rank.tex, T["Rang-Etikett zeigen"], "freeroll.showRank", 1) end
    end
    if cfg.showCheck ~= false then
        Region(parts, c, w, w.lines[1].check, T["Haken beim Besten zeigen"], "freeroll.showCheck", 2)
    end
    if cfg.showButton ~= false then
        Region(parts, c, w, w.btn, T["Ansage-Knopf zeigen"], "freeroll.showButton")
    end
    return { w = W, h = H, parts = parts }
end

-- Beutefenster ----------------------------------------------------------------------------------------------------------

local LOOT = {
    { quality = 4, name = "Ring des Glutkerns", icon = "Interface\\Icons\\INV_Jewelry_Ring_36", item = true },
    { quality = 3, name = "Kettenkappe der Wachsamkeit", icon = "Interface\\Icons\\INV_Helmet_08", item = true },
    { quality = 1, qty = 3, name = "Leinenstoff", icon = "Interface\\Icons\\INV_Fabric_Linen_01", item = true },
    { quality = 0, name = "Zerrissene Wolfshaut", icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", item = true },
    { name = "1 Silber 24 Kupfer", icon = "Interface\\Icons\\INV_Misc_Coin_01", item = false },
}

function S.loot(host, c)
    local cfg = ns.cfg.loot
    local W, FOOT = cfg.width or 250, 32

    if not c.win then
        local w = ns.FramedPanel(host, T["Testbeute"])
        w:SetPoint("TOPLEFT", host, "TOPLEFT")
        c.win = w
        w.rows = {}
        w.title:SetPoint("RIGHT", w.band, "RIGHT", -110, 0)
        w.title:SetJustifyH("LEFT")
        w.title:SetWordWrap(false)
        w.badgeInset = 28
        w.closeBtn = CreateFrame("Button", nil, w, "UIPanelCloseButton")
        w.closeBtn:SetPoint("TOPRIGHT", 2, 2)
        w.closeBtn:SetScale(0.8)
        w.closeBtn:EnableMouse(false)
        w.foot = w:CreateTexture(nil, "BACKGROUND", nil, 1)
        w.foot:SetPoint("BOTTOMLEFT", ns.INSET, ns.INSET)
        w.foot:SetPoint("BOTTOMRIGHT", -ns.INSET, ns.INSET)
        w.foot:SetHeight(FOOT - ns.INSET)
        w.foot:SetColorTexture(0.114, 0.078, 0.05, 1)
        w.footLine = w:CreateTexture(nil, "BACKGROUND", nil, 2)
        w.footLine:SetColorTexture(0.24, 0.185, 0.122, 1)
        w.footLine:SetPoint("BOTTOMLEFT", w.foot, "TOPLEFT")
        w.footLine:SetPoint("BOTTOMRIGHT", w.foot, "TOPRIGHT")
        w.footLine:SetHeight(1)
        w.all = ns.Button(w)
        w.all:SetSize(100, 22)
        w.all:SetPoint("BOTTOMRIGHT", -8, 6)
        w.all.text:SetText(T["Alles nehmen"])
    end
    local w = c.win
    ns.ApplyStyle(w, "loot")
    w:SetHeaderShown(not cfg.hideHeader)
    local head = w.headH + 8
    local h = cfg.icon
    local gap = cfg.rowGap or 0
    local thr = cfg.thr

    for i, d in ipairs(LOOT) do
        local row = w.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, w)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(CARD[1], CARD[2], CARD[3], 1)
            row.divider = row:CreateTexture(nil, "BORDER")
            row.divider:SetPoint("TOPLEFT")
            row.divider:SetPoint("TOPRIGHT")
            row.divider:SetHeight(1)
            row.divider:SetColorTexture(0.21, 0.19, 0.14, 1)
            row.qual = row:CreateTexture(nil, "BACKGROUND", nil, 1)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            row.count = row:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
            row.count:SetJustifyH("RIGHT")
            row.name = row:CreateFontString(nil, "OVERLAY", "SexyLootText")
            row.name:SetJustifyH("LEFT")
            row.name:SetWordWrap(false)
            row.pill = ns.Pill(row)
            w.rows[i] = row
        end
        row:SetSize(W - 2 * ns.INSET, h + 4)
        row.bg:SetColorTexture(CARD[1], CARD[2], CARD[3], cfg.opacity or 1)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", w, "TOPLEFT", ns.INSET, -(head + (i - 1) * (h + 4 + gap)))
        row.qual:SetSize(h + 2, h + 2)
        row.qual:ClearAllPoints()
        row.qual:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.icon:SetSize(h, h)
        row.icon:ClearAllPoints()
        row.icon:SetPoint("CENTER", row.qual, "CENTER")
        row.icon:SetTexture(d.icon)
        local r, g, b = 0.3, 0.26, 0.2
        if d.item then r, g, b = RGB(d.quality) end
        row.qual:SetColorTexture(r, g, b, 1)
        row.count:ClearAllPoints()
        row.count:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", -1, 1)
        row.count:SetText((d.qty or 1) > 1 and d.qty or "")
        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", row.qual, "TOPRIGHT", 6, -1)
        row.name:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.name:SetText(T[d.name])
        if (cfg.nameSize or 0) > 0 then row.name:SetFont(ns.FONT_TEXT, cfg.nameSize, "") end
        if d.item then row.name:SetTextColor(r, g, b) else row.name:SetTextColor(1, 0.85, 0.3) end
        row.pill.tex:ClearAllPoints()
        row.pill.tex:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
        if d.item and cfg.showPills ~= false then
            if d.quality >= thr then row.pill:Set("they", T["Gruppenloot"], nil, 14)
            else row.pill:Set("grey", T["Freie Beute"], nil, 14) end
        else
            row.pill:Hide()
        end
        row:Show()
    end

    local n = #LOOT
    local showAll = cfg.showAll ~= false
    w.foot:SetShown(showAll)
    w.footLine:SetShown(showAll)
    w.all:SetShown(showAll)
    local H = head + n * (h + 4 + gap) + (showAll and FOOT + 6 or 6)
    w:SetBadge(n .. " " .. T["Beutestücke"])
    w:SetSize(W, H)

    local parts = {}
    Add(parts, T["Fenster"], 0, 0, W, H, "_pos")
    Look(parts, "loot", W, H)
    Add(parts, T["Kopfzeile"], 0, 0, W, w.headH, "loot.hideHeader")
    Add(parts, T["Breite"], W - 5, 0, 5, H, "loot.width")
    for i = 1, n do
        local row = w.rows[i]
        local d = LOOT[i]
        Region(parts, c, w, row.qual, T["Symbolgröße"], "loot.icon", 1)
        Region(parts, c, w, row.name, T["Schriftgröße Name"], "loot.nameSize", 1, true)
        if d.item and cfg.showPills ~= false then
            Region(parts, c, w, row.pill.tex, T["Gruppenloot-Markierung ab Qualität"], T["Gruppenloot-Markierung ab Qualität"], 1)
        end
        if gap > 0 and i < n then
            Add(parts, T["Zeilenabstand"], ns.INSET, head + i * (h + 4 + gap) - gap, W - 2 * ns.INSET, gap, "loot.rowGap")
        end
    end
    if showAll then
        Region(parts, c, w, w.all, T["Knopf „Alles nehmen“ zeigen"], "loot.showAll")
    end
    return { w = W, h = H, parts = parts }
end

-- Gruppen-Feed ----------------------------------------------------------------------------------------------------------

function S.feed(host, c)
    local cfg = ns.cfg.feed
    local W, Hh = cfg.width, cfg.height

    if not c.win then
        local w = Panel(host, c, T["Gruppenbeute"], nil)
        w.rows = {}
    end
    local w = Panel(host, c, nil, "feed")
    w:SetHeaderShown(not cfg.hideHeader)
    local size = cfg.size
    local gap = cfg.lineGap or 0
    local h = size + 4 + gap
    local lines = math.max(1, math.floor((Hh - w.headH - 6) / h))

    local function L(color, name) return "|cff" .. color .. "[" .. T[name] .. "]|r" end
    local text = {
        T("%s erhält %s", ns.ColorName("Mirelle"), L("1eff00", "Mondstoffhandschuhe")),
        T("%s gewinnt %s", ns.ColorName("Aldrin"), L("0070dd", "Kappe der Wachsamkeit")) .. " |cff999999· " .. (NEED or "Need") .. " 92|r",
        T("%s gewinnt %s", ns.ColorName("Vexa"), L("a335ee", "Ring des Glutkerns")) .. " |cff999999· " .. (GREED or "Greed") .. " 77|r",
        T("%s erhält %s", ns.ColorName("Thokk"), L("ffffff", "Leinenstoff")),
        T("%s erhält %s", ns.ColorName("Bryn"), L("1eff00", "Mondstoffhandschuhe")),
        T("%s gewinnt %s", ns.ColorName("Cael"), L("0070dd", "Kappe der Wachsamkeit")) .. " |cff999999· " .. (NEED or "Need") .. " 64|r",
        T("%s erhält %s", ns.ColorName("Dova"), L("ffffff", "Leinenstoff")),
    }
    local stamps = { "12:04", "12:05", "12:06", "12:08", "12:09", "12:11", "12:12" }

    for j = 1, math.max(#w.rows, lines) do
        local row = w.rows[j]
        if not row then
            row = CreateFrame("Frame", nil, w)
            row.stamp = row:CreateFontString(nil, "OVERLAY")
            row.stamp:SetPoint("LEFT")
            row.text = row:CreateFontString(nil, "OVERLAY")
            row.text:SetJustifyH("LEFT")
            row.text:SetWordWrap(false)
            w.rows[j] = row
        end
        local idx = #text - (j - 1)   -- Zeile 1 (unten) ist die neueste
        if j <= lines and text[idx] then
            row:SetSize(W - 16, h)
            row:ClearAllPoints()
            row:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 8, 4 + (j - 1) * h)
            row.stamp:SetFont(ns.FONT_TEXT, size, "")
            local sc = cfg.stampColor
            row.stamp:SetText(("|cff%02x%02x%02x"):format(sc[1] * 255, sc[2] * 255, sc[3] * 255) .. stamps[idx] .. "|r")
            row.stamp:SetShown(not cfg.hideStamp)
            row.text:SetFont(ns.FONT_TEXT, size, cfg.outline and "OUTLINE" or "")
            row.text:ClearAllPoints()
            row.text:SetPoint("LEFT", cfg.hideStamp and row or row.stamp, cfg.hideStamp and "LEFT" or "RIGHT", cfg.hideStamp and 0 or 4, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT")
            row.text:SetText(text[idx])
            row:Show()
        else
            row:Hide()
        end
    end
    w:SetSize(W, Hh)

    local parts = {}
    Add(parts, T["Fenster"], 0, 0, W, Hh, "_pos")
    Look(parts, "feed", W, Hh)
    Add(parts, T["Kopfzeile"], 0, 0, W, w.headH, "feed.hideHeader")
    Add(parts, T["Schriftgröße"], 8, w.headH, W - 16, Hh - w.headH - 4, "feed.size")
    Add(parts, T["Breite"], W - 5, 0, 5, Hh, "feed.width")
    Add(parts, T["Höhe"], 0, Hh - 7, W, 5, "feed.height")
    for j = 1, #w.rows do
        local row = w.rows[j]
        if row:IsShown() then
            Region(parts, c, w, row.text, T["Schriftgröße"], "feed.size", 0, true)
            if not cfg.hideStamp then
                Region(parts, c, w, row.stamp, j == 2 and T["Farbe des Zeitstempels"] or T["Zeitstempel ausblenden"],
                    j == 2 and "feed.stampColor" or "feed.hideStamp", 1, true)
            end
            if gap > 0 and j > 1 then
                Add(parts, T["Zeilenabstand"], 8, Hh - 4 - (j - 1) * h, W - 16, gap, "feed.lineGap")
            end
        end
    end
    return { w = W, h = Hh, parts = parts }
end

-- Meine Beute -----------------------------------------------------------------------------------------------------------

local MINE = {
    { "Leinenstoff", "ffffff", 5, 13, "INV_Fabric_Linen_01" },
    { "Kupfererz", "ffffff", 2, 25, "INV_Ore_Copper_01" },
    { "Schwacher Heiltrank", "ffffff", 1, 40, "INV_Potion_50" },
    { "Zerrissene Wolfshaut", "9d9d9d", 3, 8, "INV_Misc_Pelt_Wolf_01" },
    { "Questgegenstand", "ffffff", 1, 0, "INV_Misc_Note_01", true },
    { "Roher Wolfsfleisch", "ffffff", 4, 6, "INV_Misc_Food_14" },
    { "Wollstoff", "ffffff", 6, 22, "INV_Fabric_Wool_01" },
    { "Mondstoffhandschuhe", "1eff00", 1, 310, "INV_Gauntlets_14" },
    { "Eisenbarren", "ffffff", 2, 90, "INV_Ingot_Iron" },
    { "Heilkraut", "ffffff", 3, 30, "INV_Misc_Herb_01" },
}

function S.mine(host, c)
    local cfg = ns.cfg.mine
    local W, FOOT = cfg.width or 280, 24

    if not c.win then
        local w = Panel(host, c, T["Zuletzt gelootet"], nil)
        w.rows = {}
        w.footer = w:CreateTexture(nil, "BACKGROUND", nil, 1)
        w.footer:SetPoint("BOTTOMLEFT", ns.INSET, ns.INSET)
        w.footer:SetPoint("BOTTOMRIGHT", -ns.INSET, ns.INSET)
        w.footer:SetHeight(FOOT - ns.INSET)
        w.footer:SetColorTexture(0.15, 0.12, 0.07, 0.96)
        w.footerLabel = w:CreateFontString(nil, "OVERLAY", "SexyLootDim")
        w.footerLabel:SetPoint("LEFT", w.footer, "LEFT", 8, 0)
        w.footerLabel:SetText(T["Wert gesamt"])
        w.total = w:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
        w.total:SetPoint("RIGHT", w.footer, "RIGHT", -8, 0)
        c.t0 = GetTime()
        local shown = -1
        w:SetScript("OnUpdate", function()
            local s = math.floor(42 + GetTime() - c.t0)
            if s ~= shown and not ns.cfg.mine.hideTime then
                shown = s
                w:SetBadge(("%d:%02d"):format(math.floor(s / 60) % 60, s % 60))
            end
        end)
    end
    local w = Panel(host, c, nil, "mine")
    w:SetHeaderShown(not cfg.hideHeader)
    if cfg.hideTime then w:SetBadge("") end

    local shown = math.min(cfg.rows, #MINE)
    local rh = cfg.rowH or 20
    local sum = 0
    for i = 1, shown do sum = sum + MINE[i][4] * MINE[i][3] end
    local showTotal = not (cfg.hideValue or sum == 0)
    w.total:SetText(showTotal and Coins(sum) or "")
    w.footer:SetShown(showTotal)
    w.footerLabel:SetShown(showTotal)

    for i = 1, math.max(#w.rows, shown) do
        local row = w.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, w)
            row:SetSize(W - 16, 20)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(16, 16)
            row.icon:SetPoint("LEFT", 0, 0)
            row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            row.quest = row:CreateTexture(nil, "OVERLAY")
            row.quest:SetTexture("Interface/GossipFrame/AvailableQuestIcon")
            row.quest:SetSize(14, 14)
            row.quest:SetPoint("CENTER", row.icon, "TOPLEFT", 1, -1)
            row.value = row:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
            row.value:SetPoint("RIGHT", 0, 0)
            row.value:SetWidth(92)
            row.value:SetJustifyH("RIGHT")
            row.count = row:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
            row.count:SetPoint("RIGHT", row.value, "LEFT", -4, 0)
            row.name = row:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
            row.name:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
            row.name:SetJustifyH("LEFT")
            row.name:SetWordWrap(false)
            w.rows[i] = row
        end
        local d = MINE[i]
        if i <= shown and d then
            row:SetHeight(rh)
            row.icon:SetSize(rh - 4, rh - 4)
            row.icon:SetShown(cfg.showIcons ~= false)
            row.name:ClearAllPoints()
            if cfg.showIcons ~= false then row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0) else row.name:SetPoint("LEFT", row, "LEFT", 0, 0) end
            local showCount = cfg.showCount ~= false
            row.count:SetShown(showCount)
            row.name:SetPoint("RIGHT", showCount and row.count or row.value, "LEFT", -4, 0)
            row:SetWidth(W - 16)
            if (cfg.nameSize or 0) > 0 then
                for _, fs in ipairs({ row.name, row.count, row.value }) do fs:SetFont(ns.FONT_TEXT, cfg.nameSize, "") end
            end
            row.icon:SetTexture("Interface\\Icons\\" .. d[5])
            row.quest:SetShown((d[6] and cfg.showIcons ~= false) and true or false)
            row.name:SetText("|cff" .. d[2] .. "[" .. T[d[1]] .. "]|r")
            row.count:SetText(d[3] > 1 and ("x" .. d[3]) or "")
            local value = d[4] * d[3]
            row.value:SetText((cfg.hideItemValue or value == 0) and "" or Coins(value))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", w, "TOPLEFT", 8, -(w.headH + 2 + (i - 1) * rh))
            row:Show()
        else
            row:Hide()
        end
    end

    local H = w.headH + 4 + shown * rh + (showTotal and FOOT or 0)
    w:SetSize(W, H)

    local parts = {}
    Add(parts, T["Fenster"], 0, 0, W, H, "_pos")
    Look(parts, "mine", W, H)
    Add(parts, T["Kopfzeile"], 0, 0, W, w.headH, "mine.hideHeader")
    Add(parts, T["Anzahl Einträge"], 8, w.headH + 2, W - 16, shown * rh, "mine.rows")
    Add(parts, T["Zeilenhöhe"], ns.INSET, w.headH + 2, 5, shown * rh, "mine.rowH")
    Add(parts, T["Breite"], W - 5, 0, 5, H, "mine.width")
    for i = 1, shown do
        local row = w.rows[i]
        if cfg.showIcons ~= false then Region(parts, c, w, row.icon, T["Symbole zeigen"], "mine.showIcons", 1) end
        Region(parts, c, w, row.name, T["Schriftgröße"], "mine.nameSize", 1, true)
        if cfg.showCount ~= false and row.count:GetText() ~= "" then
            Region(parts, c, w, row.count, T["Anzahl zeigen"], "mine.showCount", 1, true)
        end
        if not cfg.hideItemValue and row.value:GetText() ~= "" then
            Region(parts, c, w, row.value, T["Wert pro Eintrag ausblenden"], "mine.hideItemValue", 1, true)
        end
    end
    if not cfg.hideTime and not cfg.hideHeader then
        Region(parts, c, w, w.badgeBg, T["Sitzungsdauer ausblenden"], "mine.hideTime", 1)
    end
    if showTotal then
        Region(parts, c, w, w.footer, T["Gesamtwert ausblenden"], "mine.hideValue")
    end
    return { w = W, h = H, parts = parts }
end

-- Geld ------------------------------------------------------------------------------------------------------------------

function S.wallet(host, c)
    local cfg = ns.cfg.wallet
    local W = cfg.width or 200
    local H = cfg.showSell ~= false and 44 or 28
    if not c.win then
        local w = ns.FramedPanel(host)
        w:SetPoint("TOPLEFT", host, "TOPLEFT")
        c.win = w
        local l1 = w:CreateFontString(nil, "OVERLAY", "SexyLootDim")
        l1:SetPoint("TOPLEFT", 10, -7)
        l1:SetText(T["Geld"])
        w.moneyLabel = l1
        local l2 = w:CreateFontString(nil, "OVERLAY", "SexyLootDim")
        l2:SetPoint("TOPLEFT", 10, -23)
        l2:SetText(T["Verkaufswert"])
        w.sellLabel = l2
        w.money = w:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
        w.money:SetPoint("TOPRIGHT", -10, -7)
        w.money:SetJustifyH("RIGHT")
        w.sell = w:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
        w.sell:SetPoint("TOPRIGHT", -10, -23)
        w.sell:SetJustifyH("RIGHT")
        w.sell:SetTextColor(0.53, 0.8, 1)
    end
    local w = c.win
    ns.ApplyStyle(w, "wallet")
    w:SetSize(W, H)
    w.sellLabel:SetShown(cfg.showSell ~= false and cfg.showLabels ~= false)
    w.moneyLabel:SetShown(cfg.showLabels ~= false)
    w.sell:SetShown(cfg.showSell ~= false)
    if (cfg.fontSize or 0) > 0 then
        w.money:SetFont(ns.FONT_TEXT, cfg.fontSize, "")
        w.sell:SetFont(ns.FONT_TEXT, cfg.fontSize, "")
    end
    w.money:SetText(Coins(1234567))
    w.sell:SetText(Coins(23456))
    local parts = {}
    Add(parts, T["Fenster"], 0, 0, W, H, "_pos")
    Look(parts, "wallet", W, H)
    Add(parts, T["Breite"], W - 5, 0, 5, H, "wallet.width")
    Region(parts, c, w, w.money, T["Schriftgröße"], "wallet.fontSize", 1, true)
    if cfg.showSell ~= false then
        Region(parts, c, w, w.sell, T["Verkaufswert zeigen"], "wallet.showSell", 1, true)
    end
    if cfg.showLabels ~= false then
        Region(parts, c, w, w.moneyLabel, T["Beschriftung zeigen"], "wallet.showLabels", 1, true)
        if cfg.showSell ~= false then
            Region(parts, c, w, w.sellLabel, T["Beschriftung zeigen"], "wallet.showLabels", 1, true)
        end
    end
    return { w = W, h = H, parts = parts }
end

-- Loot-Einblendung ------------------------------------------------------------------------------------------------------

local TOAST = {
    { money = true, copper = 123456 },
    { name = "Schwacher Heiltrank", color = 1, count = 1, price = 40, icon = "INV_Potion_50" },
    { name = "Kupfererz", color = 1, count = 2, price = 25, icon = "INV_Ore_Copper_01" },
    { name = "Leinenstoff", color = 1, count = 13, price = 13, icon = "INV_Fabric_Linen_01" },
    { name = "Questgegenstand", color = 1, count = 1, price = 0, icon = "INV_Misc_Note_01", quest = true },
    { name = "Mondstoffhandschuhe", color = 2, count = 1, price = 310, icon = "INV_Gauntlets_14" },
    { name = "Wollstoff", color = 1, count = 6, price = 22, icon = "INV_Fabric_Wool_01" },
    { name = "Heilkraut", color = 1, count = 3, price = 30, icon = "INV_Misc_Herb_01" },
    { name = "Eisenbarren", color = 1, count = 2, price = 90, icon = "INV_Ingot_Iron" },
    { money = true, copper = 2345 },
}

function S.toast(host, c)
    local cfg = ns.cfg.toast
    local W, ROWH, GAP = cfg.width or 300, cfg.rowH or 40, cfg.gap or 2

    if not c.win then
        c.win = CreateFrame("Frame", nil, host)
        c.win:SetPoint("TOPLEFT", host, "TOPLEFT")
        c.win.rows = {}
        c.t0 = GetTime()
        -- Die unterste Zeile fliegt alle sechs Sekunden neu ein (neue Items hängen unten an, wie im echten Fenster)
        c.win:SetScript("OnUpdate", function()
            local r = c.win.rows[c.firstItem or 1]
            if not (r and r:IsShown()) then return end
            local t = (GetTime() - c.t0) % 6
            local k = math.min(1, t / 0.28)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", c.win, "TOPLEFT", 28 * (1 - k), -(c.firstY or 0))
            r:SetAlpha(k)
        end)
    end
    local w = c.win

    -- Geld als eigener Bereich oben (eine Zeile, bei "Geld einzeln anzeigen" bis zu drei), darunter die Items bis zur Zeilenzahl,
    -- getrennt durch einen kleinen Abstand (wie im echten Fenster)
    local MONEY_GAP = 8
    local list, moneyRows, itemRows = {}, 0, 0
    for _, e in ipairs(TOAST) do
        if e.money and moneyRows < (cfg.splitMoney and 3 or 1) then
            moneyRows = moneyRows + 1
            list[#list + 1] = e
        end
    end
    for _, e in ipairs(TOAST) do
        if not e.money and itemRows < cfg.rows then
            itemRows = itemRows + 1
            list[#list + 1] = e
        end
    end
    local n = #list
    local function Y(i) return (i - 1) * (ROWH + GAP) + ((moneyRows > 0 and i > moneyRows) and MONEY_GAP or 0) end
    -- das neueste Item hängt unten an: die letzte Zeile fliegt neu ein
    c.firstItem, c.firstY = n, Y(n)

    for i = 1, math.max(#w.rows, n) do
        local r = w.rows[i]
        if not r then
            r = CreateFrame("Frame", nil, w)
            r:SetSize(W, ROWH)
            r.bg = r:CreateTexture(nil, "BACKGROUND")
            r.bg:SetAllPoints()
            r.bg:SetColorTexture(0.08, 0.065, 0.05, 0.94)
            ns.Edges(r, 1):SetColorTexture(0.21, 0.19, 0.14, 1)
            r.bar = r:CreateTexture(nil, "BORDER")
            r.bar:SetPoint("TOPLEFT")
            r.bar:SetPoint("BOTTOMLEFT")
            r.bar:SetWidth(3)
            r.icon = r:CreateTexture(nil, "ARTWORK")
            r.icon:SetSize(ROWH - 8, ROWH - 8)
            r.icon:SetPoint("LEFT", 9, 0)
            r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            r.iborder = r:CreateTexture(nil, "BACKGROUND", nil, 1)
            r.iborder:SetPoint("TOPLEFT", r.icon, "TOPLEFT", -1, 1)
            r.iborder:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 1, -1)
            r.quest = r:CreateTexture(nil, "OVERLAY")
            r.quest:SetTexture("Interface/GossipFrame/AvailableQuestIcon")
            r.quest:SetSize(18, 18)
            r.quest:SetPoint("CENTER", r.icon, "TOPLEFT", 2, -2)
            r.value = r:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
            r.value:SetWidth(110)
            r.value:SetJustifyH("RIGHT")
            r.value:SetWordWrap(false)
            r.count = r:CreateFontString(nil, "OVERLAY", "SexyLootText")
            r.count:SetPoint("RIGHT", r, "RIGHT", -(8 + 110 + 4), 0)
            r.count:SetJustifyH("RIGHT")
            r.count:SetTextColor(0.61, 0.57, 0.5)
            r.pill = ns.Pill(r)
            r.pill.tex:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
            r.name = r:CreateFontString(nil, "OVERLAY", "SexyLootText")
            r.name:SetJustifyH("LEFT")
            r.name:SetWordWrap(false)
            w.rows[i] = r
        end
        local e = list[i]
        r:SetSize(W, ROWH)
        local iconPx = (cfg.iconSize or 0) > 0 and cfg.iconSize or (ROWH - 8)
        r.icon:SetSize(iconPx, iconPx)
        r.bar:SetShown(cfg.showStripe ~= false)
        r.count:SetShown(cfg.showCount ~= false)
        if (cfg.nameSize or 0) > 0 then
            r.name:SetFont(ns.FONT_TEXT, cfg.nameSize, "")
            r.count:SetFont(ns.FONT_TEXT, cfg.nameSize, "")
            r.value:SetFont(ns.FONT_TEXT, math.max(8, cfg.nameSize - 2), "")
        end
        if i <= n and e then
            -- alle Zeilen außer der einfliegenden Item-Zeile (die setzt die Animation selbst)
            if i ~= c.firstItem then
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", w, "TOPLEFT", 0, -Y(i))
                r:SetAlpha(1)
            end
            r.name:ClearAllPoints()
            r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
            r.value:ClearAllPoints()
            if e.money then
                r.bar:SetColorTexture(0.91, 0.76, 0.42, 1)
                r.iborder:SetColorTexture(0.91, 0.76, 0.42, 1)
                r.icon:SetTexture("Interface/Icons/INV_Misc_Coin_01")
                r.name:SetText(T["Geld"])
                r.name:SetTextColor(0.91, 0.76, 0.42)
                r.name:SetPoint("RIGHT", r.value, "LEFT", -6, 0)
                r.quest:Hide()
                r.pill:Hide()
                r.count:SetText("")
                r.value:SetPoint("RIGHT", -8, 0)
                r.value:SetText(Coins(e.copper, 11))
                r.value:SetTextColor(0.95, 0.92, 0.86)
            else
                local cr, cg, cb = RGB(e.color)
                r.bar:SetColorTexture(cr, cg, cb, 1)
                r.iborder:SetColorTexture(cr, cg, cb, 1)
                r.icon:SetTexture("Interface\\Icons\\" .. e.icon)
                r.name:SetText(T[e.name])
                r.name:SetTextColor(cr, cg, cb)
                r.quest:SetShown(e.quest and true or false)
                if e.quest then
                    r.pill:Set("warn", T["Quest"], nil, 16)
                    r.name:SetPoint("RIGHT", r.pill.tex, "LEFT", -6, 0)
                else
                    r.pill:Hide()
                    r.name:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
                end
                r.count:SetText(e.count > 1 and ("×" .. e.count) or "")
                local value = e.price * e.count
                r.value:SetPoint("RIGHT", -8, 0)
                r.value:SetText((cfg.hideValue or value == 0) and "" or Coins(value, 11))
                r.value:SetTextColor(0.95, 0.92, 0.86)
            end
            r:Show()
        else
            r:Hide()
        end
    end

    local H = Y(n) + ROWH
    w:SetSize(W, H)

    local parts = {}
    Add(parts, T["Fenster"], 0, 0, W, H, "_pos")
    Add(parts, T["Anzahl Zeilen"], 0, 0, W, H, "toast.rows")
    Add(parts, T["Breite"], W - 5, 0, 5, H, "toast.width")
    for i = 1, n do
        local e = list[i]
        local r = w.rows[i]
        local y = Y(i)
        Add(parts, T["Zeilenhöhe"], 12, y + ROWH - 4, W - 24, 4, "toast.rowH")
        if i < n then Add(parts, T["Abstand der Zeilen"], 0, y + ROWH, W, math.max(GAP, 3), "toast.gap") end
        if cfg.showStripe ~= false then Region(parts, c, w, r.bar, T["Qualitätsstreifen zeigen"], "toast.showStripe", 2) end
        Region(parts, c, w, r.icon, T["Symbolgröße"], "toast.iconSize", 1)
        if e.money then
            Region(parts, c, w, r.name, T["Geld einzeln anzeigen"], "toast.splitMoney", 1, true)
        else
            Region(parts, c, w, r.name, T["Schriftgröße"], "toast.nameSize", 1, true)
            if cfg.showCount ~= false and r.count:GetText() ~= "" then
                Region(parts, c, w, r.count, T["Anzahl zeigen"], "toast.showCount", 1, true)
            end
        end
        if not cfg.hideValue and r.value:GetText() ~= "" then
            Region(parts, c, w, r.value, T["Wert ausblenden"], "toast.hideValue", 1, true)
        end
    end
    return { w = W, h = H, parts = parts }
end

-- Gewinner-Anzeige ------------------------------------------------------------------------------------------------------

local WINNERS = {
    { who = "you", name = "Ring des Glutkerns", q = 4, icon = "INV_Jewelry_Ring_36", pick = "need", roll = 88 },
    { who = "Aldrin", name = "Kettenkappe der Wachsamkeit", q = 3, icon = "INV_Helmet_08", pick = "need", roll = 92 },
    { who = "Mirelle", name = "Kappe der Wachsamkeit", q = 3, icon = "INV_Helmet_08", pick = "greed", roll = 77 },
    { who = "Thokk", name = "Mondstoffhandschuhe", q = 2, icon = "INV_Gauntlets_14", pick = "need", roll = 61 },
    { who = "Vexa", name = "Leinenstoff", q = 1, icon = "INV_Fabric_Linen_01", pick = "greed", roll = 34 },
}
local W_TONE = { need = "ok", greed = "warn", pass = "grey" }
local W_LABEL = { need = NEED or "Need", greed = GREED or "Greed", pass = PASS or "Pass" }

function S.winner(host, c)
    local cfg = ns.cfg.winner
    local W = cfg.width or 480
    local CARD_H, GAP, SLIM_H, SLIM_GAP, SLIM_W = 112, cfg.cardGap or 28, 46, 8, (cfg.slimWidth or 75) / 100

    if not c.win then
        c.win = CreateFrame("Frame", nil, host)
        c.win:SetPoint("TOPLEFT", host, "TOPLEFT")
        c.win.cards = {}
    end
    local w = c.win
    local n = math.min(cfg.max, #WINNERS)

    -- Karten anlegen: große Karte (du gewinnst) oder schmale (jemand anderes)
    local function NewCard(i, slim)
        local card = ns.FramedPanel(w, not slim and T["Gewinner"] or nil)
        card.slim = slim
        card.icon = card:CreateTexture(nil, "ARTWORK", nil, 1)
        card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        card.iborder = card:CreateTexture(nil, "ARTWORK")
        card.item = card:CreateFontString(nil, "OVERLAY")
        card.item:SetJustifyH("LEFT")
        card.item:SetWordWrap(false)
        card.who = card:CreateFontString(nil, "OVERLAY")
        card.who:SetJustifyH("LEFT")
        card.pick = ns.Pill(card)
        card.rollPill = ns.Pill(card)
        if slim then
            card.icon:SetSize(30, 30)
            card.icon:SetPoint("LEFT", card, "LEFT", 10, 0)
            card.iborder:SetPoint("TOPLEFT", card.icon, "TOPLEFT", -1, 1)
            card.iborder:SetPoint("BOTTOMRIGHT", card.icon, "BOTTOMRIGHT", 1, -1)
            card.item:SetFont(ns.FONT_TEXT, 13, "")
            card.item:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 8, 1)
            card.item:SetPoint("RIGHT", card, "RIGHT", -10, 0)
            card.who:SetFont(ns.FONT_TEXT, 11, "")
            card.who:SetPoint("BOTTOMLEFT", card.icon, "BOTTOMRIGHT", 8, -1)
        else
            card.icon:SetPoint("LEFT", card, "LEFT", 20, -ns.HEAD / 2)
            card.iborder:SetPoint("TOPLEFT", card.icon, "TOPLEFT", -2, 2)
            card.iborder:SetPoint("BOTTOMRIGHT", card.icon, "BOTTOMRIGHT", 2, -2)
            card.item:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 14, -2)
            card.item:SetPoint("RIGHT", card, "RIGHT", -18, 0)
            card.item:SetShadowColor(0, 0, 0, 1)
            card.item:SetShadowOffset(1, -1)
            card.who:SetPoint("TOPLEFT", card.item, "BOTTOMLEFT", 0, -10)
            -- weicher Schein, pulsiert
            card.glow = CreateFrame("Frame", nil, card)
            card.glow:SetAllPoints(card)
            card.glowCard = ns.NineSlice(card.glow, card, MEDIA .. "glow128.tga", 128, 48, 48, 32, "BACKGROUND", 0)
            local ag = card.glow:CreateAnimationGroup()
            local a = ag:CreateAnimation("Alpha")
            if a.SetFromAlpha then a:SetFromAlpha(1); a:SetToAlpha(0.45) else a:SetChange(-0.55) end
            a:SetDuration(0.9)
            a:SetSmoothing("IN_OUT")
            ag:SetLooping("BOUNCE")
            ag:Play()
        end
        w.cards[i] = { frame = card, slim = slim }
        return card
    end

    -- Karten nach Reihenfolge der Beispiele
    local y = 0
    local parts = {}
    local geo = {}
    for i = 1, math.max(#w.cards, n) do
        local d = WINNERS[i]
        local entry = w.cards[i]
        if i <= n and d then
            local slim = d.who ~= "you"
            if entry and entry.slim ~= slim then entry.frame:Hide(); entry = nil end
            local card = entry and entry.frame or NewCard(i, slim)
            ns.ApplyStyle(card, "winner")
            local s = cfg.size
            local cw = slim and W * SLIM_W or W
            local ch = slim and SLIM_H or CARD_H
            card:SetSize(cw, ch)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", w, "TOPLEFT", slim and W * (1 - SLIM_W) / 2 or 0, -y)
            if not slim then
                local icon = (cfg.iconSize or 0) > 0 and cfg.iconSize or math.min(64, s * 2 + 8)
                card.icon:SetSize(icon, icon)
                card.item:SetFont(ns.FONT_TITLE, (cfg.itemSize or 0) > 0 and cfg.itemSize or math.max(14, s - 4), "OUTLINE")
                card.who:SetFont(ns.FONT_TEXT, (cfg.whoSize or 0) > 0 and cfg.whoSize or math.max(12, s - 12), "")
            end
            local r, g, b = RGB(d.q)
            if not slim then
                card.glowCard:SetColor(0.2, 1, 0.45, 1)
                card.iborder:SetColorTexture(0.2, 1, 0.45, 1)
            else
                card.accent:SetColorTexture(r, g, b, 1)
                card.iborder:SetColorTexture(r, g, b, 1)
            end
            card.icon:SetTexture("Interface\\Icons\\" .. d.icon)
            card.item:SetText("|cff" .. string.format("%02x%02x%02x", r * 255, g * 255, b * 255) .. T[d.name] .. "|r")
            card.who:SetText(slim and ns.ColorName(d.who) or ("|cff33ff66" .. T["Du gewinnt!"] .. "|r"))
            card.pick.tex:ClearAllPoints()
            card.pick.tex:SetPoint("LEFT", card.who, "RIGHT", slim and 8 or 10, 0)
            card.pick:Set(W_TONE[d.pick], W_LABEL[d.pick], nil, slim and 14 or 18)
            if not slim then card.glow:SetShown(cfg.glow ~= false) end
            card.rollPill.tex:ClearAllPoints()
            card.rollPill.tex:SetPoint("LEFT", card.pick.tex, "RIGHT", 6, 0)
            card.rollPill:Set("grey", tostring(d.roll), nil, slim and 14 or 18)
            if cfg.showPills == false then card.pick:Hide(); card.rollPill:Hide() end
            card:SetBadge(n > 1 and (i .. "/" .. n) or "")
            card:Show()
            geo[i] = { y = y, h = ch, slim = slim, x = slim and W * (1 - SLIM_W) / 2 or 0, w = cw }
            local nextD = WINNERS[i + 1]
            local nextSlim = nextD and i + 1 <= n and nextD.who ~= "you"
            y = y + ch + ((slim and nextSlim) and SLIM_GAP or GAP)
        elseif entry then
            entry.frame:Hide()
        end
    end

    local H = math.max(y - GAP, 1)
    w:SetSize(W, H)

    Add(parts, T["Fenster"], 0, 0, W, H, "_pos")
    Add(parts, T["Breite"], W - 5, 0, 5, H, "winner.width")
    local last
    for i, g in pairs(geo) do
        local card = w.cards[i].frame
        last = i
        if g.slim then
            Add(parts, T["Breite der schmalen Karten"], g.x - 6, g.y, 6, g.h, "winner.slimWidth")
            Add(parts, T["Schriftgröße"], g.x + 8, g.y + 4, g.w - 16, g.h - 8, "winner.size")
            Region(parts, c, w, card.icon, T["Schriftgröße"], "winner.size", 1)
            Region(parts, c, w, card.item, T["Schriftgröße"], "winner.size", 1, true)
            Region(parts, c, w, card.who, T["Schriftgröße"], "winner.size", 1, true)
        else
            Add(parts, T["Schein um die Karte"], g.x - 10, g.y, 10, g.h, "winner.glow")
            Add(parts, T["Schriftgröße"], g.x + 14, g.y + 30, g.w - 28, 70, "winner.size")
            Region(parts, c, w, card.icon, T["Symbolgröße"], "winner.iconSize", 2)
            Region(parts, c, w, card.item, T["Schriftgröße Gegenstand"], "winner.itemSize", 1, true)
            Region(parts, c, w, card.who, T["Schriftgröße Name"], "winner.whoSize", 1, true)
        end
        if cfg.showPills ~= false then
            Region(parts, c, w, card.pick.tex, T["Etiketten zeigen"], "winner.showPills", 1)
            Region(parts, c, w, card.rollPill.tex, T["Etiketten zeigen"], "winner.showPills", 1)
        end
        if geo[i + 1] then
            Add(parts, T["Abstand der Karten"], g.x, g.y + g.h, g.w, math.max(GAP, SLIM_GAP), "winner.cardGap")
        end
    end
    local g = last and geo[last]
    if g then
        Add(parts, T["Gleichzeitig angezeigte Gewinner"], g.x, g.y + g.h - 6, g.w, 6, "winner.max")
    end
    return { w = W, h = H, parts = parts }
end

-- Taschen-Hinweis -------------------------------------------------------------------------------------------------------

function S.bags(host, c)
    local cfg = ns.cfg.bags
    local W, H = cfg.width or 300, 46
    if not c.win then
        local b = ns.FramedPanel(host)
        b:SetPoint("TOPLEFT", host, "TOPLEFT")
        b:SetSize(W, H)
        c.win = b
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(28, 28)
        b.icon:SetPoint("LEFT", 12, 0)
        b.icon:SetTexture("Interface/Icons/INV_Misc_Bag_08")
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.text = b:CreateFontString(nil, "OVERLAY", "SexyLootSmall")
        b.text:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 8, 1)
        b.text:SetText(T["Inventar fast voll"])
        b.pill = ns.Pill(b)
        b.pill.tex:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 8, 0)
        b.pill:Set("warn", T("%d frei", 3), nil, 16)
        b.open = ns.Button(b)
        b.open:SetSize(84, 22)
        b.open:SetPoint("RIGHT", -32, 0)
        b.open.text:SetText(T["Aufräumen"])
        b.close = CreateFrame("Button", nil, b, "UIPanelCloseButton")
        b.close:SetSize(24, 24)
        b.close:SetPoint("TOPRIGHT", 1, 1)
        b.close:EnableMouse(false)
    end
    ns.ApplyStyle(c.win, "bags")
    do
        local b = c.win
        b:SetSize(W, H)
        local size = cfg.iconSize or 28
        b.icon:SetSize(size, size)
        b.icon:SetShown(cfg.showIcon ~= false)
        b.text:ClearAllPoints()
        b.pill.tex:ClearAllPoints()
        if cfg.showIcon ~= false then
            b.text:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 8, 1)
            b.pill.tex:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 8, 0)
        else
            b.text:SetPoint("TOPLEFT", b, "TOPLEFT", 12, -8)
            b.pill.tex:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 12, 8)
        end
        b.open:SetShown(cfg.showButton ~= false)
    end
    local parts = {}
    Add(parts, T["Fenster"], 0, 0, W, H, "_pos")
    Look(parts, "bags", W, H)
    Add(parts, T["Breite"], W - 5, 0, 5, H, "bags.width")
    if cfg.showIcon ~= false then
        Region(parts, c, c.win, c.win.icon, T["Symbol zeigen"], "bags.showIcon", 1)
        local ix, iy, iw, ih = Rel(c.win, c.win.icon)
        if ix then Add(parts, T["Symbolgröße"], ix, iy + ih - 5, iw, 7, "bags.iconSize") end
    end
    Region(parts, c, c.win, c.win.pill.tex, T["Hinweis bei höchstens so vielen freien Plätzen"], "bags.threshold", 1)
    if cfg.showButton ~= false then
        Region(parts, c, c.win, c.win.open, T["Aufräumen-Knopf zeigen"], "bags.showButton")
    end
    return { w = W, h = H, parts = parts }
end

-- Entzauber-Knopf -------------------------------------------------------------------------------------------------------

function S.deButton(host, c)
    local cfg = ns.cfg.deButton
    local W = cfg.size or 44
    local H = W
    if not c.win then
        local p = ns.FramedPanel(host)
        p:SetPoint("TOPLEFT", host, "TOPLEFT")
        p:SetSize(W, H)
        c.win = p
        p.icon = p:CreateTexture(nil, "ARTWORK")
        p.icon:SetPoint("TOPLEFT", ns.INSET + 3, -(ns.INSET + 3))
        p.icon:SetPoint("BOTTOMRIGHT", -(ns.INSET + 3), ns.INSET + 3)
        p.icon:SetTexture("Interface/Icons/INV_Enchant_Disenchant")
        p.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        local badge = CreateFrame("Frame", nil, p)
        badge:SetFrameLevel(p:GetFrameLevel() + 5)
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
        badge.text:SetText("3")
        badge:SetWidth(math.max(18, badge.text:GetStringWidth() + 10))
        p.badge = badge
    end
    local p = c.win
    ns.ApplyStyle(p, "deButton")
    p:SetSize(W, H)
    p.badge:SetShown(cfg.showCount and true or false)
    local parts = {}
    Add(parts, T["Entzaubern"], 0, 0, W, H, "_pos")
    Look(parts, "deButton", W, H)
    Add(parts, T["Größe"], W - 5, 0, 5, H, "deButton.size")
    if cfg.showCount then
        Region(parts, c, p, p.badge, T["Anzahl entzauberbarer Items anzeigen"], "deButton.showCount", 1)
    end
    return { w = W, h = H, parts = parts }
end
