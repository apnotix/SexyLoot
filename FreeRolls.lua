local ADDON, ns = ...
local T = ns.T

-- Freie Würfe (/roll), z. B. bei einer Kiste: Würfeln mindestens zwei Spieler,
-- erscheinen ihre Würfe in einem Fenster, der höchste oben. Nach einer
-- einstellbaren Zeit ohne neuen Wurf wird die Liste geleert und das Fenster
-- ausgeblendet. Die Würfe kommen aus der Systemmeldung RANDOM_ROLL_RESULT.

local FR = {}
ns.FreeRolls = FR
table.insert(ns.modules, FR)

local HEAD = ns.HEAD + 8   -- Titelband plus Leiste
local entries = {}   -- echte Würfe der laufenden Runde
local sample = {}    -- Vorschau im Edit Mode
local lastRoll = 0
local preview = false
local panel, lines = nil, {}

-- Muster aus dem Blizzard-Text, funktioniert in jeder Sprache
local PAT, TOKENS = ns.Compile(RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)")
local FIELDS = { "player", "roll", "min", "max" }

local function Distinct(list)
    local names = {}
    for _, e in ipairs(list) do
        local known
        for _, n in ipairs(names) do if ns.SameName(n, e.player) then known = true break end end
        if not known then names[#names + 1] = e.player end
    end
    return #names
end

-- Verglichen wird der Anteil am Würfelbereich, damit 1-100 und 1-50 fair stehen
local function Fraction(e) return (e.roll - (e.min or 1) + 1) / ((e.max or 100) - (e.min or 1) + 1) end

local function GetLine(i)
    local l = lines[i]
    if l then return l end
    l = CreateFrame("Frame", nil, panel)
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
    l.range = l:CreateFontString(nil, "OVERLAY")
    l.range:SetPoint("RIGHT", l.roll, "LEFT", -6, 0)
    l.range:SetJustifyH("RIGHT")
    l.name = l:CreateFontString(nil, "OVERLAY")
    l.name:SetPoint("LEFT", l.rank.tex, "RIGHT", 6, 0)
    l.name:SetPoint("RIGHT", l.range, "LEFT", -6, 0)
    l.name:SetJustifyH("LEFT")
    l.name:SetWordWrap(false)
    lines[i] = l
    return l
end

-- Gewinner ansagen -----------------------------------------------------
-- Kanal: SexyLootDB.freeChannel (per Button im Edit Mode durchgeschaltet), bei
-- "CHANNEL" die Nummer aus cfg.chanNum. Keine Auswahlliste, die sind gesperrt.
local CHANNELS = { "AUTO", "SAY", "PARTY", "RAID", "INSTANCE_CHAT", "GUILD", "YELL", "CHANNEL" }

local function ChannelInfo()
    local key = SexyLootDB.freeChannel or "AUTO"
    local num = ns.cfg.freeroll.chanNum
    if key == "AUTO" then
        local label = T["Automatisch"]
        local resolved
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE or 2) then resolved = "INSTANCE_CHAT"
        elseif IsInRaid() then resolved = "RAID"
        elseif IsInGroup() then resolved = "PARTY"
        else resolved = "SAY" end
        return resolved, nil, label
    elseif key == "CHANNEL" then
        return "CHANNEL", num, T("Kanal Nr. %d", num)
    end
    return key, nil, _G[key] or key
end

function FR:UpdateAnnounce()
    if not panel then return end
    local _, _, label = ChannelInfo()
    panel.btn.text:SetText(T["Gewinner ansagen"] .. " |cffe8c26a(" .. label .. ")|r")
    panel.btn:SetWidth(math.max(120, panel.btn.text:GetStringWidth() + 24))
    panel.btn:SetEnabled(not preview)
    -- Ausgegraut in der Edit-Mode-Vorschau
    local c = preview and ns.TONES.grey.bg or ns.BTN
    panel.btn.bg:SetColorTexture(c[1], c[2], c[3], 1)
end

function FR:NextChannel()
    local cur = SexyLootDB.freeChannel or "AUTO"
    for i, k in ipairs(CHANNELS) do
        if k == cur then
            SexyLootDB.freeChannel = CHANNELS[i % #CHANNELS + 1]
            break
        end
    end
    local _, _, label = ChannelInfo()
    print("|cffe8c26aSexyLoot|r: " .. T("Ansage-Kanal: %s", label))
    self:UpdateAnnounce()
end

function FR:Announce()
    if preview or #entries == 0 then return end
    -- höchster Wurf (Anteil am Bereich), bei Gleichstand alle Gleichen
    local best, winners = nil, {}
    for _, e in ipairs(entries) do
        local f = Fraction(e)
        if not best or f > best then best, winners = f, { e }
        elseif f == best then winners[#winners + 1] = e end
    end
    local w = winners[1]
    local msg
    if #winners == 1 then
        msg = T("%s gewinnt mit %d (%d-%d)", w.player, w.roll, w.min, w.max)
    else
        local names = {}
        for _, e in ipairs(winners) do names[#names + 1] = e.player end
        msg = T("Gleichstand: %s mit %d (%d-%d)", table.concat(names, ", "), w.roll, w.min, w.max)
    end
    local chatType, target = ChannelInfo()
    SendChatMessage(msg, chatType, nil, target)
end

function FR:Refresh()
    if not panel then return end
    local cfg = ns.cfg.freeroll
    ns.ApplyStyle(panel, "freeroll")
    local list = preview and sample or entries
    local visible = #list > 0 and (preview or cfg.single or Distinct(list) >= 2)
    if not visible then
        panel:Hide()
        return
    end

    local sorted = { unpack(list) }
    table.sort(sorted, function(a, b)
        local fa, fb = Fraction(a), Fraction(b)
        if fa ~= fb then return fa > fb end
        return a.time < b.time
    end)
    local top = Fraction(sorted[1])

    local size = cfg.size
    local lh = size + 8
    local n = math.min(#sorted, cfg.rows)
    panel.title:SetText(T("Freie Würfe (%d)", #sorted))

    for i = 1, n do
        local e = sorted[i]
        local l = GetLine(i)
        local best = Fraction(e) == top
        l:SetHeight(lh)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -(HEAD + (i - 1) * lh))
        l:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -(HEAD + (i - 1) * lh))
        l.check:SetSize(size, size)
        l.name:SetFont(ns.FONT_TEXT, size, "")
        l.roll:SetFont(ns.FONT_TEXT, size + 2, "OUTLINE")
        l.range:SetFont(ns.FONT_TEXT, math.max(8, size - 4), "")
        l.rank:Set(best and "warn" or "grey", tostring(i), 24, 16)
        l.name:SetText(ns.ColorName(e.player))
        l.roll:SetText(tostring(e.roll))
        l.roll:SetTextColor(best and 1 or 0.95, best and 0.82 or 0.95, best and 0.2 or 0.95)
        -- Der Bereich steht nur dabei, wenn er nicht 1-100 ist
        local std = (e.min or 1) == 1 and (e.max or 100) == 100
        l.range:SetText(std and "" or ("|cff8a8a8a" .. e.min .. "-" .. e.max .. "|r"))
        l.check:SetShown(best)
        if best then
            l.bg:SetColorTexture(0.91, 0.76, 0.42, 0.20)
        else
            l.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.05 or 0)
        end
        l:Show()
    end
    for i = n + 1, #lines do lines[i]:Hide() end

    self:UpdateAnnounce()
    local height = HEAD + n * lh + 8 + 28   -- Platz für die Ansage-Schaltfläche
    panel:SetHeight(height)
    ns.frames.freeroll:SetHeight(height)
    panel:Show()
end

function FR:OnSystem(msg)
    local caps = { msg:match(PAT) }
    if #caps == 0 then return end
    local t = {}
    for i, tk in ipairs(TOKENS) do t[FIELDS[tk.pos]] = caps[i] end
    local e = {
        player = ns.Short(t.player or "?"),
        roll = tonumber(t.roll), min = tonumber(t.min), max = tonumber(t.max),
        time = GetTime(),
    }
    if not (e.roll and e.min and e.max and e.max >= e.min) then return end
    -- Ist die letzte Runde abgelaufen, fängt eine neue an
    if #entries > 0 and GetTime() - lastRoll > ns.cfg.freeroll.hold then wipe(entries) end
    entries[#entries + 1] = e
    lastRoll = GetTime()
    self:Refresh()
end

-- Wird vom Aufräum-Timer aufgerufen: nach cfg.hold Sekunden ohne Wurf leeren
local function Tick()
    if preview or not panel then return end
    if #entries == 0 then return end
    local left = ns.cfg.freeroll.hold - (GetTime() - lastRoll)
    if left <= 0 then
        wipe(entries)
        FR:Refresh()
        return
    end
    panel.bar:SetMinMaxValues(0, ns.cfg.freeroll.hold)
    panel.bar:SetValue(left)
    panel:SetBadge(T("Schließt in %ds", math.ceil(left)))
end

-- Beispielwürfe für den Test
function FR:Test()
    wipe(entries)
    local now = GetTime()
    local names = { UnitName("player"), "Aldrin", "Mirelle", "Thokk", "Vexa" }
    ns.classByName.Aldrin, ns.classByName.Mirelle, ns.classByName.Thokk, ns.classByName.Vexa =
        "WARRIOR", "PRIEST", "SHAMAN", "ROGUE"
    for i, n in ipairs(names) do
        entries[#entries + 1] = { player = ns.Short(n), roll = math.random(100), min = 1, max = 100, time = now + i * 0.01 }
    end
    lastRoll = now
    self:Refresh()
end

-- Im Edit Mode steht eine Beispielliste, beim Verlassen verschwindet sie
function FR:Preview(active)
    preview = active
    wipe(sample)
    if active then
        local base = GetTime()
        local data = { { "Aldrin", 92 }, { "Mirelle", 77 }, { "Thokk", 61 }, { "Vexa", 34 }, { UnitName("player"), 18 } }
        ns.classByName.Aldrin, ns.classByName.Mirelle, ns.classByName.Thokk, ns.classByName.Vexa =
            "WARRIOR", "PRIEST", "SHAMAN", "ROGUE"
        for i, d in ipairs(data) do
            sample[i] = { player = ns.Short(d[1]), roll = d[2], min = 1, max = 100, time = base + i * 0.01 }
        end
        panel:SetBadge("")
        panel.bar:SetValue(0)
    end
    self:Refresh()
end

ns.Apply.freeroll = function() FR:Refresh() end

function FR:Init()
    panel = ns.FramedPanel(ns.frames.freeroll, T["Freie Würfe"])
    panel:SetPoint("TOPLEFT", ns.frames.freeroll, "TOPLEFT")
    panel:SetPoint("TOPRIGHT", ns.frames.freeroll, "TOPRIGHT")
    panel:Hide()

    -- Leiste unter dem Band: zeigt, wann die Liste nach dem letzten Wurf geleert wird
    panel.bar = CreateFrame("StatusBar", nil, panel)
    panel.bar:SetPoint("TOPLEFT", 2, -ns.HEAD)
    panel.bar:SetPoint("TOPRIGHT", -2, -ns.HEAD)
    panel.bar:SetHeight(3)
    panel.bar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    panel.bar:SetStatusBarColor(0.91, 0.76, 0.42)
    panel.bar.bg = panel.bar:CreateTexture(nil, "BACKGROUND")
    panel.bar.bg:SetAllPoints()
    panel.bar.bg:SetColorTexture(0, 0, 0, 0.6)

    panel.btn = ns.Button(panel)
    panel.btn:SetSize(140, 22)
    panel.btn:SetPoint("BOTTOMRIGHT", -8, 6)
    panel.btn:SetScript("OnClick", function() FR:Announce() end)

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("CHAT_MSG_SYSTEM")
    ev:SetScript("OnEvent", function(_, _, msg) FR:OnSystem(msg) end)
    C_Timer.NewTicker(0.2, Tick)
end
