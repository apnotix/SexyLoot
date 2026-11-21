local ADDON, ns = ...
local T = ns.T
local SEM = LibStub("SexyEditMode-1.0")

-- Einstellungen: Die Werte stehen in ns.cfg[key] (gespeichert in SexyLootDB.cfg, siehe Core.lua).
local function Check(key, opt, label)
    return { type = "check", name = label,
        get = function() return ns.cfg[key][opt] and true or false end,
        set = function(v) ns.cfg[key][opt] = v and true or false; ns.Refresh(key) end }
end

local function Slider(key, opt, label, min, max, step, format)
    return { type = "slider", name = label, min = min, max = max, step = step, format = format,
        get = function() return ns.cfg[key][opt] end,
        set = function(v) ns.cfg[key][opt] = v; ns.Refresh(key) end }
end

-- Preisquelle für Verkaufswerte (gilt für alle Fenster)
local function PriceSource()
    return { type = "select", name = T["Preisquelle"],
        options = {
            { value = "auction", label = T["Auktionspreis (Preis-Addon)"] },
            { value = "vendor", label = T["Händlerpreis"] },
        },
        get = function() return SexyLootDB.priceSource or "auction" end,
        set = function(v)
            SexyLootDB.priceSource = v
            for _, k in ipairs({ "toast", "mine", "wallet" }) do ns.Refresh(k) end
        end }
end

-- Zusammengehörige Fenster verweisen oben im Dialog aufeinander (Klick zeigt deren Einstellungen)
local RELATED = {
    { "roll", "winner", "freeroll", "feed" },     -- Würfe und Gruppenbeute
    { "loot", "toast", "mine", "wallet", "bags", "deButton" }, -- eigene Beute, Geld, Taschen und Entzauber-Knopf
}
local SHORT = {
    roll = "Rollfenster", winner = "Gewinner-Anzeige", freeroll = "Freie Würfe", feed = "Gruppen-Feed",
    loot = "Beutefenster", toast = "Loot-Einblendung", mine = "Meine Beute", wallet = "Geld", bags = "Taschen-Hinweis", deButton = "Entzauber-Knopf",
}

local function Links(key)
    local list = {}
    for _, group in ipairs(RELATED) do
        for _, k in ipairs(group) do
            if k == key then
                for _, other in ipairs(group) do
                    if other ~= key then
                        list[#list + 1] = { type = "link", name = T[SHORT[other]],
                            frame = function() return ns.frames[other] end }
                    end
                end
            end
        end
    end
    return list
end

local function Button(label, fn) return { type = "button", name = label, onClick = fn } end
-- Verhalten statt Aussehen: erscheint nur im Einstellungsfenster (/sem), nicht im Edit-Mode-Dialog der Fenster
local function B(spec) spec.behavior = true; return spec end
local function Header(label, id, collapsed) return { type = "header", name = label, id = id, collapsed = collapsed } end

-- Einsortierung und Beschreibung im gemeinsamen Einstellungsfenster (SexyEditMode-Hub)
local CATEGORY = {
    loot = "Beute", toast = "Beute", mine = "Beute", wallet = "Beute",
    roll = "Gruppe", winner = "Gruppe", freeroll = "Gruppe", feed = "Gruppe",
    bags = "Werkzeuge", deButton = "Werkzeuge",
}
local DESCRIPTION = {
    loot = "Ersetzt das Blizzard-Beutefenster. Position und Größe stellst du im Edit Mode ein.",
    toast = "Kleine Einblendung für neue Beute mit Verkaufswert.",
    mine = "Liste der zuletzt gelooteten Items mit Sitzungsdauer und Gesamtwert.",
    wallet = "Geld und Verkaufswert, auch von deinen anderen Charakteren.",
    roll = "Ersetzt Blizzards Würfelfenster und zeigt die Würfe am Item.",
    winner = "Schmale Einblendung mit dem Gewinner eines Wurfs.",
    freeroll = "Liste der freien Würfe (/roll), zum Beispiel bei einer Kiste.",
    feed = "Chatfenster mit der Beute deiner Gruppe.",
    bags = "Hinweis bei fast vollem Inventar und Aufräum-Dialog.",
    deButton = "Knopf und Fenster zum Entzaubern: Liste, Qualität, Taste.",
}

-- Zusammengehörige Fenster bekommen im Edit-Mode-Dialog Tabs: { Gruppe, Name }
local GROUP = {
    roll = { "rolls", "Würfe" }, winner = { "rolls", "Würfe" }, freeroll = { "rolls", "Würfe" }, feed = { "rolls", "Würfe" },
    loot = { "loot", "Beute" }, mine = { "loot", "Beute" }, toast = { "loot", "Beute" }, wallet = { "loot", "Beute" },
    bags = { "tools", "Werkzeuge" }, deButton = { "tools", "Werkzeuge" },
}

-- Fenster im Edit Mode anmelden. Position, Größe und Sichtbarkeit übernimmt die Bibliothek
-- (Daten in SexyLootDB.frames[key]); jedes Fenster bekommt zuletzt den Abschnitt "Andocken".
local function Setup(key, title, settings)
    -- Mit den Tabs im Dialog (Addon SexyEditMode) sind die Verweise überflüssig
    if not SEM.HubStyle then
        for i, link in ipairs(Links(key)) do table.insert(settings, i, link) end
    end
    settings[#settings + 1] = Header(T["Andocken"], "dock", true)
    settings[#settings + 1] = { type = "select", name = T["Andocken an"],
        options = function() return ns.Dock:TargetOptions(key) end,
        get = function() return ns.Dock:GetTarget(key) end,
        set = function(v) ns.Dock:SetTarget(key, v) end }
    settings[#settings + 1] = { type = "select", name = T["Seite"],
        options = function() return ns.Dock:SideOptions() end,
        get = function() return ns.Dock:GetSide(key) end,
        set = function(v) ns.Dock:SetSide(key, v) end }
    settings[#settings + 1] = { type = "select", name = T["Ausrichtung"],
        options = function() return ns.Dock:AlignOptions(key) end,
        get = function() return ns.Dock:GetAlign(key) end,
        set = function(v) ns.Dock:SetAlign(key, v) end }
    SEM:Register(ns.frames[key], {
        name = title,
        addon = "SexyLoot",
        dock = false,   -- SexyLoot hat eigenes Andocken (Dock.lua)
        group = GROUP[key] and GROUP[key][1],
        groupName = GROUP[key] and T[GROUP[key][2]],
        category = CATEGORY[key] and T[CATEGORY[key]],
        description = DESCRIPTION[key] and T[DESCRIPTION[key]],   -- erscheint im gemeinsamen Einstellungsfenster (/sem), falls das Addon SexyEditMode installiert ist
        db = SexyLootDB.frames[key],
        settings = settings,
        -- reiner Container: ausgeblendet oder im Kampf versteckt wird er ganz, damit seine Fenster
        -- (auch unsichtbare) keine Mausklicks auf Gegner und Leichen darunter abfangen
        hideWhenInvisible = true,
        -- nach dem Verschieben gilt die Position für die aktuelle Höhe des Ankers (siehe LootWindow:Draw)
        onMoved = function(frame) SexyLootDB.frames[key].anchoredHeight = frame:GetHeight() end,
        -- jedes Fenster meldet den Wechsel; die Vorschau der Module läuft nur einmal
        onEditMode = function(active)
            if ns.editing ~= active then ns.SetEditMode(active) end
        end,
    })
    ns.Dock:Hook(key)   -- Ziehen löst das Andocken
end

function ns.SetupEditMode()
    if SEM.RegisterAddon then SEM:RegisterAddon("SexyLoot", { title = "SexyLoot" }) end

    Setup("roll", T["SexyLoot: Rollfenster"], {
        Header(T["Darstellung"], "look"),
        Check("roll", "hideRolls", T["Würfe am Item ausblenden"]),
        Check("roll", "growUp", T["Neue Fenster nach oben wachsen lassen"]),
        Check("roll", "animate", T["Animationen"]),
        Slider("roll", "gap", T["Abstand zwischen Fenstern"], 0, 24, 2),
        Slider("roll", "size", T["Schriftgröße der Würfe"], 10, 20, 1),
        Slider("roll", "maxHeight", T["Maximale Höhe der Liste (darüber klappen Zeilen ein)"], 200, 900, 20),
        B(Slider("roll", "hold", T["Fenster nach dem Wurf anzeigen (Sekunden)"], 3, 30, 1)),
        Button(T["Testwurf starten"], ns.Actions.testRoll),
    })

    Setup("winner", T["SexyLoot: Gewinner-Anzeige"], {
        Header(T["Darstellung"], "look"),
        Slider("winner", "size", T["Schriftgröße"], 18, 40, 2),
        B(Slider("winner", "hold", T["Anzeigedauer (Sekunden)"], 2, 15, 1)),
        B(Check("winner", "sound", T["Ton, wenn ich gewinne"])),
        B({ type = "select", name = T["Ton"], options = function() return ns.Sounds.Options() end,
            get = function() return ns.cfg.winner.soundKey end,
            set = function(v) ns.cfg.winner.soundKey = v; ns.Sounds.Play(v, ns.cfg.winner.soundChannel) end }),
        B({ type = "select", name = T["Lautstärke (Tonkanal)"], options = function() return ns.Sounds.ChannelOptions() end,
            get = function() return ns.cfg.winner.soundChannel end,
            set = function(v) ns.cfg.winner.soundChannel = v; ns.Sounds.Play(ns.cfg.winner.soundKey, v) end }),
        Slider("winner", "max", T["Gleichzeitig angezeigte Gewinner"], 1, 5, 1),
        Button(T["Test-Gewinner anzeigen"], ns.Actions.testWinner),
    })

    -- Freie Würfe (/roll, z. B. bei einer Kiste)
    Setup("freeroll", T["SexyLoot: Freie Würfe"], {
        Header(T["Darstellung"], "look"),
        B(Check("freeroll", "single", T["Schon bei einem Würfler anzeigen"])),
        B(Slider("freeroll", "hold", T["Liste leeren nach (Sekunden ohne Wurf)"], 5, 120, 5)),
        Slider("freeroll", "rows", T["Maximale Zeilen"], 3, 20, 1),
        Slider("freeroll", "size", T["Schriftgröße"], 10, 22, 1),
        Header(T["Ansage"], "announce", true),
        B({ type = "select", name = T["Ansage-Kanal"],
            options = function() return ns.FreeRolls:ChannelOptions() end,
            get = function() return ns.FreeRolls:GetChannel() end,
            set = function(v) ns.FreeRolls:SetChannel(v) end }),
        B(Slider("freeroll", "chanNum", T["Kanal-Nummer (für „Kanal Nr.“)"], 1, 10, 1)),
        Button(T["Test-Würfe starten"], ns.Actions.testFree),
    })

    Setup("loot", T["SexyLoot: Beutefenster"], {
        Header(T["Darstellung"], "look"),
        B(Check("loot", "auto", T["Graue Items automatisch einsammeln"])),
        B(Check("loot", "noAutoMoney", T["Geld nicht automatisch einsammeln"])),
        B({ type = "select", name = T["Gruppenloot-Markierung ab Qualität"],
            options = { { value = 2, label = T["Grün"] }, { value = 3, label = T["Blau"] }, { value = 4, label = T["Episch"] } },
            get = function() return ns.cfg.loot.thr end,
            set = function(v) ns.cfg.loot.thr = v; ns.Refresh("loot") end }),
        Slider("loot", "icon", T["Symbolgröße"], 24, 48, 2),
        Button(T["Testbeute öffnen"], ns.Actions.openLoot),
        Header(T["Hotkey"], "hotkey", true),
        B({ type = "keybind", name = T["Hotkey für „Alles nehmen“"],
            get = function() return ns.LootWindow:HotkeyText() end,
            waiting = function() return ns.LootWindow:IsCapturing() end,
            onClick = function() ns.LootWindow:CaptureHotkey() end,
            onClear = function() ns.LootWindow:ClearHotkey() end }),
    })

    Setup("feed", T["SexyLoot: Gruppen-Feed"], {
        Header(T["Darstellung"], "look"),
        Check("feed", "hideStamp", T["Zeitstempel ausblenden"]),
        Check("feed", "sortPlayers", T["Wurfdetails nach Spielerreihenfolge sortieren"]),
        B(Check("feed", "noFade", T["Nachrichten nicht ausblenden"])),
        B(Slider("feed", "fade", T["Nachrichten ausblenden nach (Sekunden)"], 5, 120, 5)),
        Slider("feed", "width", T["Breite"], 240, 700, 10),
        Slider("feed", "height", T["Höhe"], 80, 500, 10),
        Slider("feed", "size", T["Schriftgröße"], 8, 20, 1),
        B(Button(T["Feed leeren"], ns.Actions.clearFeed)),
    })

    Setup("mine", T["SexyLoot: Meine Beute"], {
        Header(T["Darstellung"], "look"),
        Check("mine", "growDown", T["Nach unten wachsen"]),
        Check("mine", "hideTime", T["Sitzungsdauer ausblenden"]),
        Check("mine", "hideValue", T["Gesamtwert ausblenden"]),
        Check("mine", "hideItemValue", T["Wert pro Eintrag ausblenden"]),
        B(PriceSource()),
        B(Check("mine", "noStack", T["Gleiche Items nicht stapeln"])),
        Slider("mine", "rows", T["Anzahl Einträge"], 3, 10, 1),
        B(Button(T["Liste leeren"], ns.Actions.clearMine)),
    })

    Setup("toast", T["SexyLoot: Loot-Einblendung"], {
        Header(T["Darstellung"], "look"),
        Check("toast", "hideValue", T["Wert ausblenden"]),
        Check("toast", "splitMoney", T["Geld einzeln anzeigen"]),
        B(PriceSource()),
        B(Slider("toast", "hold", T["Anzeigedauer (Sekunden)"], 2, 20, 1)),
        Slider("toast", "rows", T["Anzahl Zeilen"], 2, 10, 1),
        Button(T["Test-Beute anzeigen"], function() ns.Toast:Test() end),
    })

    -- Hinweis bei fast vollem Inventar und Aufräum-Dialog
    Setup("bags", T["SexyLoot: Taschen-Hinweis"], {
        Header(T["Hinweis"], "hint"),
        B(Check("bags", "disabled", T["Hinweis ausschalten"])),
        B(Check("bags", "noAutoOpen", T["Dialog bei vollem Inventar nicht automatisch öffnen"])),
        B(Slider("bags", "threshold", T["Hinweis bei höchstens so vielen freien Plätzen"], 1, 20, 1)),
        Header(T["Aufräum-Dialog"], "clean"),
        Slider("bags", "rows", T["Sichtbare Zeilen im Dialog"], 5, 20, 1),
        B(Check("bags", "onlyJunk", T["Nur Junk (graue Items) anzeigen"])),
        B(Check("bags", "ignoreProf", T["Berufs-Items ignorieren"])),
        B(Slider("bags", "maxQuality", T["Höchste Qualität im Dialog"], 0, 4, 1,
            function(v) return _G["ITEM_QUALITY" .. v .. "_DESC"] or tostring(v) end)),
        B(Check("bags", "showNoValue", T["Items ohne Preis anzeigen"])),
        B(PriceSource()),
        B(Button(T["Aufräum-Dialog öffnen"], function() ns.Bags:Open() end)),
    })

    -- Knopf zum Öffnen des Entzauber-Fensters
    Setup("deButton", T["SexyLoot: Entzauber-Knopf"], {
        Header(T["Knopf"], "button"),
        Check("deButton", "hidden", T["Knopf ausblenden (Fenster weiter mit /sl de)"]),
        Check("deButton", "showCount", T["Anzahl entzauberbarer Items anzeigen"]),
        B(Check("deButton", "onlyWithItems", T["Nur anzeigen, wenn Items entzauberbar sind"])),
        Header(T["Entzaubern"], "disenchant", true),
        Slider("disenchant", "rows", T["Sichtbare Zeilen im Dialog"], 5, 20, 1),
        B(Slider("disenchant", "minQuality", T["Niedrigste Qualität"], 2, 4, 1,
            function(v) return _G["ITEM_QUALITY" .. v .. "_DESC"] or tostring(v) end)),
        B(Slider("disenchant", "maxQuality", T["Höchste Qualität"], 2, 4, 1,
            function(v) return _G["ITEM_QUALITY" .. v .. "_DESC"] or tostring(v) end)),
        B(Check("disenchant", "protectSets", T["Items aus Ausrüstungssets schützen"])),
        B({ type = "keybind", name = T["Taste für „Alle entzaubern“"],
            get = function() return ns.Disenchant:HotkeyText() end,
            waiting = function() return ns.Disenchant:IsCapturing() end,
            onClick = function() ns.Disenchant:CaptureHotkey() end,
            onClear = function() ns.Disenchant:ClearHotkey() end }),
        B(Button(T["Ausgeblendete Items wieder anzeigen"], function() ns.Disenchant:ResetIgnored() end)),
        B(Button(T["Entzauber-Fenster öffnen"], function() ns.Disenchant:Open() end)),
    })

    -- Geld und Verkaufswert
    Setup("wallet", T["SexyLoot: Geld"], {
        B(PriceSource()),
        B(Button(T["Gespeicherte Charaktere zurücksetzen"], function() ns.Wallet:ResetChars() end)),
    })
end
