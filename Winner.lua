local ADDON, ns = ...

-- Gewinner-Anzeige: Wenn ein Wurf entschieden ist, steht der Gewinner mit Item
-- gut sichtbar auf dem Bildschirm (Position im Edit Mode einstellbar).

local W = {}
ns.Winner = W
table.insert(ns.modules, W)

local LABEL = { need = "Bedarf", greed = "Gier", pass = "Passen" }
local SAMPLE = "|cffa335ee|Hitem:17063::::::::60:::::|h[Ring des Glutkerns]|h|r"
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local panel
local gen = 0   -- macht ältere Ausblend-Timer wirkungslos

local function Style()
    if not panel then return end
    ns.ApplyStyle(panel, "winner")
    local s = ns.cfg.winner.size
    local icon = math.min(64, s * 2 + 8)
    panel.icon:SetSize(icon, icon)
    panel.qual:SetSize(icon + 4, icon + 4)
    panel.title:SetFont(STANDARD_TEXT_FONT, s, "OUTLINE")
    panel.item:SetFont(STANDARD_TEXT_FONT, math.max(12, s - 6), "OUTLINE")
    panel.detail:SetFont(STANDARD_TEXT_FONT, math.max(11, s - 12), "")
end

-- sticky: bleibt stehen (Edit-Mode-Vorschau), sonst nach cfg.hold Sekunden weg
function W:Display(player, link, pick, roll, sticky)
    if not panel or not link then return end
    Style()
    local me = player == UnitName("player")
    panel.title:SetText(me and "|cff33ff66Du gewinnst!|r" or (ns.ColorName(player) .. " gewinnt!"))
    panel.item:SetText(link)
    panel.detail:SetText(pick and ("|cffbbbbbb" .. LABEL[pick] .. (roll and (" " .. roll) or "") .. "|r") or "")

    local tex = select(5, ns.GetItemInfoInstant(link))
    panel.icon:SetTexture(tex or FALLBACK_ICON)
    local q = ns.LinkQuality(link)
    local r, g, b = ns.QualityColor(q)
    panel.qual:SetColorTexture(r, g, b, 1)

    panel:Show()
    gen = gen + 1
    if sticky then return end
    local mine = gen
    C_Timer.After(ns.cfg.winner.hold, function()
        if mine == gen then panel:Hide() end
    end)
end

function W:Test()
    self:Display("Aldrin", SAMPLE, "need", 92)
end

-- Im Edit Mode steht ein Beispielgewinner, beim Verlassen verschwindet er
function W:Preview(active)
    if active then
        self:Display("Aldrin", SAMPLE, "need", 92, true)
    else
        gen = gen + 1
        if panel then panel:Hide() end
    end
end

ns.Apply.winner = function() Style() end

function W:Init()
    panel = ns.Panel(ns.frames.winner)
    panel:SetAllPoints(ns.frames.winner)
    panel:EnableMouse(false)
    panel:Hide()

    panel.qual = panel:CreateTexture(nil, "BACKGROUND")
    panel.qual:SetPoint("LEFT", 12, 0)
    panel.icon = panel:CreateTexture(nil, "ARTWORK")
    panel.icon:SetPoint("CENTER", panel.qual, "CENTER")
    panel.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    panel.title = panel:CreateFontString(nil, "OVERLAY")
    panel.title:SetPoint("TOPLEFT", panel.qual, "TOPRIGHT", 14, 0)
    panel.title:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
    panel.title:SetJustifyH("LEFT")
    panel.title:SetWordWrap(false)

    panel.item = panel:CreateFontString(nil, "OVERLAY")
    panel.item:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -2)
    panel.item:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
    panel.item:SetJustifyH("LEFT")
    panel.item:SetWordWrap(false)

    panel.detail = panel:CreateFontString(nil, "OVERLAY")
    panel.detail:SetPoint("TOPLEFT", panel.item, "BOTTOMLEFT", 0, -2)
    panel.detail:SetJustifyH("LEFT")

    Style()
end
