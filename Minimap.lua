-- Minimap-Knopf (LibDBIcon): Linksklick öffnet das Einstellungsfenster (Addon SexyEditMode) beim ersten Bereich
-- von SexyLoot, Rechtsklick öffnet bzw. schließt den Edit Mode. Ohne SexyEditMode öffnet auch Linksklick den Edit Mode. Ein-/Ausblenden: /sl minimap
local DE = GetLocale() == "deDE"

local function ToggleEditMode()
    -- mit SexyEditMode nur für die Fenster dieses Addons, sonst Blizzards Edit Mode wie er ist
    local SEM = LibStub("SexyEditMode-1.0", true)
    if SEM and SEM.ToggleEditMode then SEM:ToggleEditMode("SexyLoot") return end
    local m = _G.EditModeManagerFrame
    if not m then return end
    if m:IsShown() then HideUIPanel(m) else ShowUIPanel(m) end
end

local function Settings()
    local db = _G.SexyLootDB
    if not db then return end
    db.minimap = db.minimap or {}
    -- eigener Startwinkel je Addon, damit die Knöpfe nicht übereinanderliegen (verschiebbar per Ziehen)
    if not db.minimap.minimapPos then db.minimap.minimapPos = 180 end
    return db.minimap
end

function SexyLoot_ToggleMinimapButton()
    local icon = LibStub("LibDBIcon-1.0", true)
    local s = Settings()
    if not (icon and s) then return end
    s.hide = not s.hide
    if s.hide then icon:Hide("SexyLoot") else icon:Show("SexyLoot") end
    print("|cffe8c26aSexyLoot|r: " .. (DE and (s.hide and "Minimap-Knopf ausgeblendet" or "Minimap-Knopf eingeblendet")
        or (s.hide and "minimap button hidden" or "minimap button shown")))
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    local ldb = LibStub("LibDataBroker-1.1", true)
    local icon = LibStub("LibDBIcon-1.0", true)
    local s = Settings()
    if not (ldb and icon and s) then return end
    local obj = ldb:NewDataObject("SexyLoot", {
        type = "launcher",
        label = "SexyLoot",
        text = "SexyLoot",
        icon = "Interface/AddOns/SexyLoot/icon.tga",
        OnClick = function(_, button)
            local SEM = LibStub("SexyEditMode-1.0", true)
            if button == "RightButton" or not (SEM and SEM.OpenHub) then
                ToggleEditMode()
            else
                SEM:OpenHub("SexyLoot")
            end
        end,
        OnTooltipShow = function(tip)
            if not (tip and tip.AddLine) then return end
            tip:AddLine("SexyLoot")
            tip:AddLine(DE and "Linksklick: Einstellungen" or "Left click: settings", 1, 1, 1)
            tip:AddLine(DE and "Rechtsklick: Edit Mode" or "Right click: Edit Mode", 1, 1, 1)
        end,
    })
    if obj and not icon:IsRegistered("SexyLoot") then icon:Register("SexyLoot", obj, s) end
end)
