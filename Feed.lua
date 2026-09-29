local ADDON, ns = ...

-- Gruppen-Feed: wer hat welches Item bekommen. Bei Gruppenwürfen zeigt der
-- Tooltip einer Zeile alle Wahlen und Würfe. Mausrad blättert.

local Feed = {}
ns.Feed = Feed
table.insert(ns.modules, Feed)

local WIDTH = 340
local MAXKEEP = 60
local TEX = {
    need  = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
    greed = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
    pass  = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
}
local LABEL = { need = "Bedarf", greed = "Gier", pass = "Passen" }

local entries, rows, offset = {}, {}, 0
local panel
local recent = {}   -- Gewinner-Nachrichten, damit "erhält" nicht doppelt erscheint

--------------------------------------------------------------------------
-- Lootnachrichten (auch von MyLoot genutzt)
--------------------------------------------------------------------------

local LOOTDEFS = {}
local function Def(global, fields, self_)
    local fmt = _G[global]
    if type(fmt) ~= "string" then return end
    local pat, tokens = ns.Compile(fmt)
    LOOTDEFS[#LOOTDEFS + 1] = { pat = pat, tokens = tokens, fields = fields, self = self_ }
end
-- Varianten mit Anzahl zuerst, sonst frisst das Muster für ein Item die Anzahl mit
Def("LOOT_ITEM_MULTIPLE", { "player", "item", "count" })
Def("LOOT_ITEM_PUSHED_MULTIPLE", { "player", "item", "count" })
Def("LOOT_ITEM_SELF_MULTIPLE", { "item", "count" }, true)
Def("LOOT_ITEM_PUSHED_SELF_MULTIPLE", { "item", "count" }, true)
Def("LOOT_ITEM", { "player", "item" })
Def("LOOT_ITEM_PUSHED", { "player", "item" })
Def("LOOT_ITEM_SELF", { "item" }, true)
Def("LOOT_ITEM_PUSHED_SELF", { "item" }, true)

function ns.ParseLoot(msg)
    for _, d in ipairs(LOOTDEFS) do
        local caps = { msg:match(d.pat) }
        if #caps > 0 then
            local out = { self = d.self }
            for i, tk in ipairs(d.tokens) do out[d.fields[tk.pos]] = caps[i] end
            out.count = tonumber(out.count) or 1
            out.player = ns.Short(out.player or UnitName("player"))
            return out
        end
    end
end

local COLORQ = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6 }
function ns.LinkQuality(link)
    local q = select(3, ns.GetItemInfo(link))
    if q then return q end
    return COLORQ[(link:match("|cff(%x%x%x%x%x%x)") or ""):lower()] or 1
end

--------------------------------------------------------------------------
-- Einträge
--------------------------------------------------------------------------

local function Add(text, link, roll, preview)
    entries[#entries + 1] = { stamp = date("%H:%M"), text = text, link = link, roll = roll, preview = preview }
    if #entries > MAXKEEP then table.remove(entries, 1) end
    offset = 0
    Feed:Refresh()
end

function Feed:NoteWin(player, itemID)
    recent[player .. ":" .. tostring(itemID)] = GetTime()
end

function Feed:AddWin(player, link)
    Add(ns.ColorName(player) .. " gewinnt " .. link, link)
end

function Feed:AddRoll(r)
    local roll = { roster = { unpack(r.roster) }, picks = {}, rolls = {}, winner = r.winner }
    for k, v in pairs(r.picks) do roll.picks[k] = v end
    for k, v in pairs(r.rolls) do roll.rolls[k] = v end
    local text
    if r.winner then
        local pick = r.picks[r.winner] or "greed"
        text = ns.ColorName(r.winner) .. " gewinnt " .. r.link .. " |cff999999· " .. LABEL[pick]
            .. (r.rolls[r.winner] and (" " .. r.rolls[r.winner]) or "") .. "|r"
    else
        text = "Alle passen auf " .. r.link
    end
    Add(text, r.link, roll)
end

function Feed:OnChat(msg)
    local t = ns.ParseLoot(msg)
    if not t then return end
    if t.self then ns.MyLoot:Add(t.item, t.count) end
    if ns.LinkQuality(t.item) < 2 then return end
    local key = t.player .. ":" .. tostring(ns.ItemID(t.item))
    if recent[key] and GetTime() - recent[key] < 10 then
        recent[key] = nil
        return
    end
    Add(ns.ColorName(t.player) .. " erhält " .. t.item .. (t.count > 1 and (" x" .. t.count) or ""), t.item)
end

function Feed:Clear()
    wipe(entries)
    offset = 0
    self:Refresh()
end

local function Samples(preview)
    local function L(id, name, color) return "|cff" .. color .. "|Hitem:" .. id .. "::::::::60:::::|h[" .. name .. "]|h|r" end
    local a = L(14551, "Kappe der Wachsamkeit", "0070dd")
    local b = L(13068, "Mondstoffhandschuhe", "1eff00")
    local c = L(17063, "Ring des Glutkerns", "a335ee")
    ns.classByName.Aldrin, ns.classByName.Mirelle, ns.classByName.Thokk, ns.classByName.Vexa =
        "WARRIOR", "PRIEST", "SHAMAN", "ROGUE"
    Add(ns.ColorName("Mirelle") .. " erhält " .. b, b, nil, preview)
    Add(ns.ColorName("Aldrin") .. " gewinnt " .. a .. " |cff999999· Bedarf 92|r", a, {
        roster = { UnitName("player"), "Aldrin", "Mirelle", "Thokk", "Vexa" },
        picks = { Aldrin = "need", Thokk = "need", Vexa = "greed", Mirelle = "pass", [UnitName("player")] = "pass" },
        rolls = { Aldrin = 92, Thokk = 61, Vexa = 34 }, winner = "Aldrin",
    }, preview)
    Add(ns.ColorName("Vexa") .. " gewinnt " .. c .. " |cff999999· Gier 77|r", c, {
        roster = { UnitName("player"), "Aldrin", "Mirelle", "Thokk", "Vexa" },
        picks = { Vexa = "greed", Thokk = "greed", Aldrin = "pass", Mirelle = "pass", [UnitName("player")] = "pass" },
        rolls = { Vexa = 77, Thokk = 12 }, winner = "Vexa",
    }, preview)
end

function Feed:Test()
    Samples(false)
end

-- Im Edit Mode stehen Beispielzeilen im Feed, beim Verlassen verschwinden sie
function Feed:Preview(active)
    for i = #entries, 1, -1 do
        if entries[i].preview then table.remove(entries, i) end
    end
    if active then Samples(true) end
    offset = 0
    self:Refresh()
end

--------------------------------------------------------------------------
-- Anzeige
--------------------------------------------------------------------------

local function Tip(row)
    local e = row.entry
    if not e then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if e.link then GameTooltip:SetHyperlink(e.link) else GameTooltip:SetText("Loot") end
    if e.roll then
        local d = e.roll
        local list = {}
        for _, n in ipairs(d.roster) do list[#list + 1] = n end
        if not ns.cfg.feed.sortPlayers then
            table.sort(list, function(x, y)
                local px, py = d.picks[x] or "pass", d.picks[y] or "pass"
                local rx = (px == "need" and 1000 or px == "greed" and 500 or 0) + (d.rolls[x] or 0)
                local ry = (py == "need" and 1000 or py == "greed" and 500 or 0) + (d.rolls[y] or 0)
                return rx > ry
            end)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Würfe", 1, 0.82, 0)
        for _, n in ipairs(list) do
            local p = d.picks[n]
            GameTooltip:AddDoubleLine(
                ns.ColorName(n) .. (d.winner == n and "  |TInterface\\RaidFrame\\ReadyCheck-Ready:14|t" or ""),
                p and ("|T" .. TEX[p] .. ":14|t " .. LABEL[p] .. (d.rolls[n] and ("  " .. d.rolls[n]) or "")) or "keine Wahl",
                1, 1, 1, 0.9, 0.9, 0.9)
        end
    end
    GameTooltip:Show()
end

local function MakeRow(i)
    local b = CreateFrame("Button", nil, panel)
    b:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 6, 4)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetAllPoints()
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    b:SetScript("OnEnter", Tip)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", function(self)
        if self.entry and self.entry.link then HandleModifiedItemClick(self.entry.link) end
    end)
    rows[i] = b
    return b
end

function Feed:Refresh()
    if not panel then return end
    local cfg = ns.cfg.feed
    local h = cfg.size + 4
    panel:SetHeight(cfg.lines * h + 8)
    ns.frames.feed:SetHeight(cfg.lines * h + 8)
    local n = #entries
    offset = math.max(0, math.min(offset, math.max(0, n - cfg.lines)))
    for j = 1, math.max(#rows, cfg.lines) do
        local row = rows[j] or MakeRow(j)
        if j <= cfg.lines then
            local e = entries[n - offset - (j - 1)]
            row.entry = e
            row:SetSize(WIDTH - 12, h)
            row:ClearAllPoints()
            row:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 6, 4 + (j - 1) * h)
            row.text:SetFont(STANDARD_TEXT_FONT, cfg.size, "")
            if e then
                row.text:SetText((cfg.hideStamp and "" or ("|cff888888" .. e.stamp .. "|r ")) .. e.text)
                row:Show()
            else
                row:Hide()
            end
        else
            row.entry = nil
            row:Hide()
        end
    end
    if n == 0 then panel:SetAlpha(0) else panel:SetAlpha(1) end
end

ns.Apply.feed = function() Feed:Refresh() end

function Feed:Init()
    panel = ns.Panel(ns.frames.feed)
    panel:SetBackdropColor(0.03, 0.02, 0.01, 0.7)
    panel:SetPoint("BOTTOMLEFT", ns.frames.feed, "BOTTOMLEFT")
    panel:SetPoint("BOTTOMRIGHT", ns.frames.feed, "BOTTOMRIGHT")
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta)
        offset = offset + delta
        Feed:Refresh()
    end)

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("CHAT_MSG_LOOT")
    ev:SetScript("OnEvent", function(_, _, msg) Feed:OnChat(msg) end)
end
