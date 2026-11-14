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
local function Header(label, id, collapsed) return { type = "header", name = label, id = id, collapsed = collapsed } end

-- Fenster im Edit Mode anmelden. Position, Größe und Sichtbarkeit übernimmt die Bibliothek
-- (Daten in SexyLootDB.frames[key]); jedes Fenster bekommt zuletzt den Abschnitt "Andocken".
local function Setup(key, title, settings)
    for i, link in ipairs(Links(key)) do table.insert(settings, i, link) end
    settings[#settings + 1] = Header(T["Andocken"], "dock", true)
    settings[#settings + 1] = Button(T["Andocken: Ziel wechseln"], function() ns.Dock:NextTarget(key) end)
    settings[#settings + 1] = Button(T["Andocken: Seite wechseln"], function() ns.Dock:NextSide(key) end)
    SEM:Register(ns.frames[key], {
        name = title,
        db = SexyLootDB.frames[key],
        settings = settings,
        -- jedes Fenster meldet den Wechsel; die Vorschau der Module läuft nur einmal
        onEditMode = function(active)
            if ns.editing ~= active then ns.SetEditMode(active) end
        end,
    })
    ns.Dock:Hook(key)   -- Ziehen löst das Andocken
end

function ns.SetupEditMode()

    Setup("roll", T["SexyLoot: Rollfenster"], {
        Header(T["Darstellung"], "look"),
        Check("roll", "hideRolls", T["Würfe am Item ausblenden"]),
        Check("roll", "growUp", T["Neue Fenster nach oben wachsen lassen"]),
        Slider("roll", "gap", T["Abstand zwischen Fenstern"], 0, 24, 2),
        Slider("roll", "size", T["Schriftgröße der Würfe"], 10, 20, 1),
        Slider("roll", "maxHeight", T["Maximale Höhe der Liste (darüber klappen Zeilen ein)"], 200, 900, 20),
        Slider("roll", "hold", T["Fenster nach dem Wurf anzeigen (Sekunden)"], 3, 30, 1),
        Button(T["Testwurf starten"], ns.Actions.testRoll),
    })

    Setup("winner", T["SexyLoot: Gewinner-Anzeige"], {
        Header(T["Darstellung"], "look"),
        Slider("winner", "size", T["Schriftgröße"], 18, 40, 2),
        Slider("winner", "hold", T["Anzeigedauer (Sekunden)"], 2, 15, 1),
        Slider("winner", "max", T["Gleichzeitig angezeigte Gewinner"], 1, 5, 1),
        Button(T["Test-Gewinner anzeigen"], ns.Actions.testWinner),
    })

    -- Freie Würfe (/roll, z. B. bei einer Kiste)
    Setup("freeroll", T["SexyLoot: Freie Würfe"], {
        Header(T["Darstellung"], "look"),
        Check("freeroll", "single", T["Schon bei einem Würfler anzeigen"]),
        Slider("freeroll", "hold", T["Liste leeren nach (Sekunden ohne Wurf)"], 5, 120, 5),
        Slider("freeroll", "rows", T["Maximale Zeilen"], 3, 20, 1),
        Slider("freeroll", "size", T["Schriftgröße"], 10, 22, 1),
        Header(T["Ansage"], "announce", true),
        Button(T["Ansage-Kanal wechseln"], function() ns.FreeRolls:NextChannel() end),
        Slider("freeroll", "chanNum", T["Kanal-Nummer (für „Kanal Nr.“)"], 1, 10, 1),
        Button(T["Test-Würfe starten"], ns.Actions.testFree),
    })

    Setup("loot", T["SexyLoot: Beutefenster"], {
        Header(T["Darstellung"], "look"),
        Check("loot", "auto", T["Graue Items automatisch einsammeln"]),
        Check("loot", "noAutoMoney", T["Geld nicht automatisch einsammeln"]),
        Slider("loot", "thr", T["Gruppenloot-Markierung ab Qualität (2 grün, 3 blau, 4 episch)"], 2, 4, 1),
        Slider("loot", "icon", T["Symbolgröße"], 24, 48, 2),
        Header(T["Hotkey"], "hotkey", true),
        Button(T["Hotkey für „Alles nehmen“ festlegen"], function() ns.LootWindow:CaptureHotkey() end),
        Button(T["Hotkey entfernen"], function() ns.LootWindow:ClearHotkey() end),
        Button(T["Testbeute öffnen"], ns.Actions.openLoot),
    })

    Setup("feed", T["SexyLoot: Gruppen-Feed"], {
        Header(T["Darstellung"], "look"),
        Check("feed", "hideStamp", T["Zeitstempel ausblenden"]),
        Check("feed", "sortPlayers", T["Wurfdetails nach Spielerreihenfolge sortieren"]),
        Check("feed", "noFade", T["Nachrichten nicht ausblenden"]),
        Slider("feed", "fade", T["Nachrichten ausblenden nach (Sekunden)"], 5, 120, 5),
        Slider("feed", "width", T["Breite"], 240, 700, 10),
        Slider("feed", "height", T["Höhe"], 80, 500, 10),
        Slider("feed", "size", T["Schriftgröße"], 8, 20, 1),
        Button(T["Feed leeren"], ns.Actions.clearFeed),
    })

    Setup("mine", T["SexyLoot: Meine Beute"], {
        Header(T["Darstellung"], "look"),
        Check("mine", "growDown", T["Nach unten wachsen"]),
        Check("mine", "hideTime", T["Sitzungsdauer ausblenden"]),
        Check("mine", "hideValue", T["Gesamtwert ausblenden"]),
        Check("mine", "hideItemValue", T["Wert pro Eintrag ausblenden"]),
        PriceSource(),
        Check("mine", "noStack", T["Gleiche Items nicht stapeln"]),
        Slider("mine", "rows", T["Anzahl Einträge"], 3, 10, 1),
        Button(T["Liste leeren"], ns.Actions.clearMine),
    })

    Setup("toast", T["SexyLoot: Loot-Einblendung"], {
        Header(T["Darstellung"], "look"),
        Check("toast", "hideValue", T["Wert ausblenden"]),
        Check("toast", "splitMoney", T["Geld einzeln anzeigen"]),
        PriceSource(),
        Slider("toast", "hold", T["Anzeigedauer (Sekunden)"], 2, 20, 1),
        Slider("toast", "rows", T["Anzahl Zeilen"], 2, 10, 1),
        Button(T["Test-Beute anzeigen"], function() ns.Toast:Test() end),
    })

    -- Hinweis bei fast vollem Inventar und Aufräum-Dialog
    Setup("bags", T["SexyLoot: Taschen-Hinweis"], {
        Header(T["Hinweis"], "hint"),
        Check("bags", "disabled", T["Hinweis ausschalten"]),
        Check("bags", "noAutoOpen", T["Dialog bei vollem Inventar nicht automatisch öffnen"]),
        Slider("bags", "threshold", T["Hinweis bei höchstens so vielen freien Plätzen"], 1, 20, 1),
        Header(T["Aufräum-Dialog"], "clean"),
        Slider("bags", "rows", T["Sichtbare Zeilen im Dialog"], 5, 20, 1),
        Check("bags", "onlyJunk", T["Nur Junk (graue Items) anzeigen"]),
        Check("bags", "ignoreProf", T["Berufs-Items ignorieren"]),
        Slider("bags", "maxQuality", T["Höchste Qualität im Dialog"], 0, 4, 1,
            function(v) return _G["ITEM_QUALITY" .. v .. "_DESC"] or tostring(v) end),
        Check("bags", "showNoValue", T["Items ohne Preis anzeigen"]),
        PriceSource(),
        Button(T["Aufräum-Dialog öffnen"], function() ns.Bags:Open() end),
        Header(T["Entzaubern"], "disenchant", true),
        Slider("disenchant", "rows", T["Sichtbare Zeilen im Dialog"], 5, 20, 1),
        Slider("disenchant", "minQuality", T["Niedrigste Qualität"], 2, 4, 1,
            function(v) return _G["ITEM_QUALITY" .. v .. "_DESC"] or tostring(v) end),
        Slider("disenchant", "maxQuality", T["Höchste Qualität"], 2, 4, 1,
            function(v) return _G["ITEM_QUALITY" .. v .. "_DESC"] or tostring(v) end),
        Check("disenchant", "protectSets", T["Items aus Ausrüstungssets schützen"]),
        Button(T["Ausgeblendete Items wieder anzeigen"], function() ns.Disenchant:ResetIgnored() end),
        Button(T["Entzauber-Fenster öffnen"], function() ns.Disenchant:Open() end),
    })

    -- Knopf zum Öffnen des Entzauber-Fensters
    Setup("deButton", T["SexyLoot: Entzauber-Knopf"], {
        Header(T["Knopf"], "button"),
        Check("deButton", "hidden", T["Knopf ausblenden (Fenster weiter mit /sl de)"]),
        Check("deButton", "showCount", T["Anzahl entzauberbarer Items anzeigen"]),
        Check("deButton", "onlyWithItems", T["Nur anzeigen, wenn Items entzauberbar sind"]),
        Button(T["Entzauber-Fenster öffnen"], function() ns.Disenchant:Open() end),
    })

    -- Geld und Verkaufswert
    Setup("wallet", T["SexyLoot: Geld"], {
        PriceSource(),
        Button(T["Gespeicherte Charaktere zurücksetzen"], function() ns.Wallet:ResetChars() end),
    })
end
