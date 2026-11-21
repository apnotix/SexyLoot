local ADDON, ns = ...
local T = ns.T

-- Töne zur Auswahl: Spielsounds (SOUNDKIT) und, wenn die eingebettete oder eine andere
-- LibSharedMedia Töne kennt, auch diese. Gespeichert wird "NAME" für einen Spielsound oder "lsm:NAME".
-- Die Lautstärke eines einzelnen Tons lässt sich in WoW nicht setzen; sie folgt dem gewählten Tonkanal.
local Sounds = {}
ns.Sounds = Sounds

local KITS = {
    { "IG_QUEST_LIST_OPEN", "Questliste öffnen" },
    { "READY_CHECK", "Bereitschaftscheck" },
    { "RAID_WARNING", "Schlachtzugswarnung" },
    { "ALARM_CLOCK_WARNING_3", "Wecker" },
    { "MAP_PING", "Kartenping" },
    { "UI_QUEST_ROLLING_FORWARD_01", "Quest abgegeben" },
    { "TELL_MESSAGE", "Flüstern" },
    { "AUCTION_WINDOW_OPEN", "Auktionshaus" },
    { "UI_EPICLOOT_TOAST", "Epische Beute" },
    { "IG_PLAYER_INVITE", "Einladung" },
}

function Sounds.Options()
    local list = {}
    for _, k in ipairs(KITS) do
        if SOUNDKIT and SOUNDKIT[k[1]] then list[#list + 1] = { value = k[1], label = T[k[2]] } end
    end
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local names = {}
        for name in pairs(LSM:HashTable("sound")) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            if name ~= "None" then list[#list + 1] = { value = "lsm:" .. name, label = name } end
        end
    end
    return list
end

function Sounds.ChannelOptions()
    return {
        { value = "Master", label = T["Gesamt"] },
        { value = "SFX", label = T["Effekte"] },
        { value = "Dialog", label = T["Dialog"] },
        { value = "Ambience", label = T["Umgebung"] },
    }
end

-- Spielt den gewählten Ton auf dem Kanal; ist er nicht vorhanden, spielt der erste Spielsound
function Sounds.Play(key, channel)
    channel = channel or "Master"
    local played
    if type(key) == "string" and key:sub(1, 4) == "lsm:" then
        local LSM = LibStub("LibSharedMedia-3.0", true)
        local path = LSM and LSM:Fetch("sound", key:sub(5), true)
        if path then played = PlaySoundFile(path, channel) end
    elseif key and SOUNDKIT and SOUNDKIT[key] then
        played = PlaySound(SOUNDKIT[key], channel)
    end
    if not played and SOUNDKIT then PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN or 882, channel) end
end
