local ADDON, ns = ...
local T = ns.T
local SEM = LibStub("SexyEditMode-1.0")

-- Einstellungen: Die Werte stehen in ns.cfg[key] (gespeichert in SexyLootDB.cfg, siehe Core.lua).
local function Check(key, opt, label)
    return { type = "check", name = label, jump = key .. "." .. opt,
        get = function() return ns.cfg[key][opt] and true or false end,
        set = function(v) ns.cfg[key][opt] = v and true or false; ns.Refresh(key) end }
end

local function Slider(key, opt, label, min, max, step, format)
    return { type = "slider", name = label, min = min, max = max, step = step, format = format, jump = key .. "." .. opt,
        get = function() return ns.cfg[key][opt] end,
        set = function(v) ns.cfg[key][opt] = v; ns.Refresh(key) end }
end

-- Deckkraft, Hintergrund- und Randfarbe eines Fensters (Farben als { r, g, b, a }, die Deckkraft als eigener Wert)
local function LookSpecs(key)
    local function Color(field, label)
        return { type = "color", name = label, jump = key .. "." .. field,
            get = function() local c = ns.cfg[key][field]; return c[1], c[2], c[3], 1 end,
            set = function(r, g, b)
                local c = ns.cfg[key][field]
                ns.cfg[key][field] = { r, g, b, c[4] }
                ns.Refresh(key)
            end }
    end
    return {
        { type = "slider", name = T["Deckkraft des Fensters"], min = 30, max = 100, step = 2, jump = key .. ".opacity",
            format = function(v) return v .. " %" end,
            get = function() local c = ns.cfg[key]; return math.floor((c.opacity or c.bg[4]) * 100 + 0.5) end,
            set = function(v) ns.cfg[key].opacity = v / 100; ns.Refresh(key) end },
        Color("bg", T["Hintergrundfarbe"]),
        Color("border", T["Randfarbe"]),
    }
end
-- Farbe als Tabelle { r, g, b } in ns.cfg[key][opt]
local function ColorOpt(key, opt, label)
    return { type = "color", name = label, jump = key .. "." .. opt,
        get = function() local c = ns.cfg[key][opt]; return c[1], c[2], c[3], 1 end,
        set = function(r, g, b) ns.cfg[key][opt] = { r, g, b }; ns.Refresh(key) end }
end
local function Auto(v) return v == 0 and T["Auto"] or v end   -- Schieberegler mit 0 = automatisch
local function Pct(v) return v .. " %" end

-- weitere Darstellungs-Einstellungen für Fenster ohne eigene "Darstellung" (kommen hinter Deckkraft und Farben)
local EXTRA = {
    bags = {
        Slider("bags", "width", T["Breite"], 240, 500, 10),
        Slider("bags", "iconSize", T["Symbolgröße"], 16, 40, 2),
        Check("bags", "showIcon", T["Symbol zeigen"]),
        Check("bags", "showButton", T["Aufräumen-Knopf zeigen"]),
    },
}
local LOOK = { roll = true, winner = true, freeroll = true, loot = true, feed = true, mine = true, wallet = true, bags = true, deButton = true }

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

-- Gruppe 1 ("Darstellung") enthält nur, was die Vorschau verändert; Verhalten, Tests und Aktionen kommen in eine eigene Gruppe
-- dahinter. Einstellungen mit preview = true bleiben vorn, auch wenn sie nur im Hub stehen (behavior).
local function SplitBehavior(settings)
    local head = settings[1]
    if not (head and head.type == "header") then return settings end
    local last = #settings
    for i = 2, #settings do
        if settings[i].type == "header" then last = i - 1 break end
    end
    local visual, behavior = {}, {}
    for i = 2, last do
        local s = settings[i]
        if (s.behavior or s.type == "button" or s.type == "keybind") and not s.preview then
            behavior[#behavior + 1] = s
        else
            visual[#visual + 1] = s
        end
    end
    if #behavior == 0 or #visual == 0 then return settings end
    local out = { head }
    for _, s in ipairs(visual) do out[#out + 1] = s end
    out[#out + 1] = Header(T["Verhalten"], (head.id or "look") .. "_behavior")
    for _, s in ipairs(behavior) do out[#out + 1] = s end
    for i = last + 1, #settings do out[#out + 1] = settings[i] end
    return out
end

-- Fenster im Edit Mode anmelden. Position, Größe und Sichtbarkeit übernimmt die Bibliothek
-- (Daten in SexyLootDB.frames[key]); jedes Fenster bekommt zuletzt den Abschnitt "Andocken".
local function Setup(key, title, settings)
    -- Deckkraft und Farben stehen in der ersten Gruppe; Fenster ohne eigene "Darstellung" (Taschen-Hinweis, Geld) bekommen sie
    if LOOK[key] then
        local head = settings[1]
        local specs = LookSpecs(key)
        if head and head.type == "header" and (head.id == "look" or head.id == "button") then
            for i, spec in ipairs(specs) do table.insert(settings, 1 + i, spec) end
            for i, spec in ipairs(EXTRA[key] or {}) do table.insert(settings, 1 + #specs + i, spec) end
        else
            table.insert(settings, 1, Header(T["Darstellung"], "look"))
            for i, spec in ipairs(specs) do table.insert(settings, 1 + i, spec) end
            for i, spec in ipairs(EXTRA[key] or {}) do table.insert(settings, 1 + #specs + i, spec) end
        end
    end
    settings = SplitBehavior(settings)
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
        sample = ns.Samples and ns.Samples[key],   -- eigenes Fenster mit eigener Logik für die Vorschau (Samples.lua, SamplesMore.lua)
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

-- "Animationen" im Rollfenster: Einschalten spielt die Animation gleich in der Vorschau ab (Samples.lua)
local function AnimateCheck()
    local spec = Check("roll", "animate", T["Animationen"])
    local set = spec.set
    spec.set = function(v)
        set(v)
        if v and ns.Samples and ns.Samples.PlayRoll then ns.Samples.PlayRoll() end
    end
    return spec
end

function ns.SetupEditMode()
    if ns.Live and ns.Live.setup then ns.Live.setup() end
    if SEM.RegisterAddon then SEM:RegisterAddon("SexyLoot", { title = "SexyLoot" }) end
    -- Daten, die zu einem Profil gehören (Einstellungen, Positionen, Andocken, Tasten); ohne die Verläufe und Daten je Charakter
    if SEM.RegisterProfile then
        SEM:RegisterProfile("SexyLoot", { db = function() return SexyLootDB end, keys = { "dock", "frames", "cfg", "hotkey", "deIgnore",
            "priceSource", "freeChannel", "deHotkey", "mineGrowDown", "dePos", "cleanPos", "colors", "minimap" } })
    end

    Setup("roll", T["SexyLoot: Rollfenster"], {
        Header(T["Darstellung"], "look"),
        Check("roll", "hideRolls", T["Würfe am Item ausblenden"]),
        Check("roll", "hideHeader", T["Kopfzeile ausblenden"]),
        { type = "slider", name = T["Deckkraft der Karten"], min = 30, max = 100, step = 2, jump = "roll.cardOpacity",
            format = Pct,
            get = function() return math.floor((ns.cfg.roll.cardOpacity or 1) * 100 + 0.5) end,
            set = function(v) ns.cfg.roll.cardOpacity = v / 100; ns.Refresh("roll") end },
        Slider("roll", "nameSize", T["Schriftgröße Name"], 0, 22, 1, Auto),
        Check("roll", "showArmor", T["Rüstungsetikett zeigen"]),
        Check("roll", "showBound", T["„Bindet beim Aufheben“ zeigen"]),
        Check("roll", "showBar", T["Zeitleiste zeigen"]),
        Check("roll", "showTimer", T["Restzeit zeigen"]),
        Check("roll", "btnLabels", T["Beschriftung der Buttons zeigen"]),
        Check("roll", "showCheck", T["Haken beim Besten zeigen"]),
        Check("roll", "zebra", T["Zeilen abwechselnd tönen"]),
        Slider("roll", "lineGap", T["Zeilenabstand"], 0, 8, 1),
        B(Check("roll", "growUp", T["Neue Fenster nach oben wachsen lassen"])),
        AnimateCheck(),
        Slider("roll", "gap", T["Abstand zwischen Fenstern"], 0, 24, 2),
        Slider("roll", "size", T["Schriftgröße der Würfe"], 10, 20, 1),
        B(Slider("roll", "maxHeight", T["Maximale Höhe der Liste (darüber klappen Zeilen ein)"], 200, 900, 20)),
        B(Slider("roll", "hold", T["Fenster nach dem Wurf anzeigen (Sekunden)"], 3, 30, 1)),
    })

    Setup("winner", T["SexyLoot: Gewinner-Anzeige"], {
        Header(T["Darstellung"], "look"),
        Slider("winner", "size", T["Schriftgröße"], 18, 40, 2),
        Check("winner", "glow", T["Schein um die Karte"]),
        Check("winner", "showPills", T["Etiketten zeigen"]),
        Slider("winner", "iconSize", T["Symbolgröße"], 0, 96, 2, Auto),
        Slider("winner", "itemSize", T["Schriftgröße Gegenstand"], 0, 48, 1, Auto),
        Slider("winner", "whoSize", T["Schriftgröße Name"], 0, 32, 1, Auto),
        Slider("winner", "width", T["Breite"], 300, 700, 10),
        Slider("winner", "cardGap", T["Abstand der Karten"], 8, 48, 2),
        Slider("winner", "slimWidth", T["Breite der schmalen Karten"], 50, 100, 5, Pct),
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
        Check("freeroll", "hideHeader", T["Kopfzeile ausblenden"]),
        B(Slider("freeroll", "hold", T["Liste leeren nach (Sekunden ohne Wurf)"], 5, 120, 5)),
        Slider("freeroll", "rows", T["Maximale Zeilen"], 3, 20, 1),
        Slider("freeroll", "size", T["Schriftgröße"], 10, 22, 1),
        Check("freeroll", "showRank", T["Rang-Etikett zeigen"]),
        Check("freeroll", "showBar", T["Zeitleiste zeigen"]),
        Check("freeroll", "showButton", T["Ansage-Knopf zeigen"]),
        Slider("freeroll", "width", T["Breite"], 200, 400, 10),
        Slider("freeroll", "lineGap", T["Zeilenabstand"], 0, 8, 1),
        Check("freeroll", "showCheck", T["Haken beim Besten zeigen"]),
        Check("freeroll", "zebra", T["Zeilen abwechselnd tönen"]),
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
        Check("loot", "hideHeader", T["Kopfzeile ausblenden"]),
        B(Check("loot", "auto", T["Graue Items automatisch einsammeln"])),
        B(Check("loot", "noAutoMoney", T["Geld nicht automatisch einsammeln"])),
        B({ type = "select", name = T["Gruppenloot-Markierung ab Qualität"], preview = true,
            options = { { value = 2, label = T["Grün"] }, { value = 3, label = T["Blau"] }, { value = 4, label = T["Episch"] } },
            get = function() return ns.cfg.loot.thr end,
            set = function(v) ns.cfg.loot.thr = v; ns.Refresh("loot") end }),
        Slider("loot", "icon", T["Symbolgröße"], 24, 48, 2),
        Check("loot", "showPills", T["Etiketten zeigen"]),
        Check("loot", "showAll", T["Knopf „Alles nehmen“ zeigen"]),
        Slider("loot", "width", T["Breite"], 200, 400, 10),
        Slider("loot", "nameSize", T["Schriftgröße Name"], 0, 20, 1, Auto),
        Slider("loot", "rowGap", T["Zeilenabstand"], 0, 8, 1),
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
        Check("feed", "hideHeader", T["Kopfzeile ausblenden"]),
        Check("feed", "hideStamp", T["Zeitstempel ausblenden"]),
        B(Check("feed", "sortPlayers", T["Wurfdetails nach Spielerreihenfolge sortieren"])),
        B(Check("feed", "noFade", T["Nachrichten nicht ausblenden"])),
        B(Slider("feed", "fade", T["Nachrichten ausblenden nach (Sekunden)"], 5, 120, 5)),
        Slider("feed", "width", T["Breite"], 240, 700, 10),
        Slider("feed", "height", T["Höhe"], 80, 500, 10),
        Slider("feed", "size", T["Schriftgröße"], 8, 20, 1),
        Slider("feed", "lineGap", T["Zeilenabstand"], 0, 8, 1),
        Check("feed", "outline", T["Schrift mit Kontur"]),
        ColorOpt("feed", "stampColor", T["Farbe des Zeitstempels"]),
        B(Button(T["Feed leeren"], ns.Actions.clearFeed)),
    })

    Setup("mine", T["SexyLoot: Meine Beute"], {
        Header(T["Darstellung"], "look"),
        Check("mine", "hideHeader", T["Kopfzeile ausblenden"]),
        B(Check("mine", "growDown", T["Nach unten wachsen"])),
        Check("mine", "hideTime", T["Sitzungsdauer ausblenden"]),
        Check("mine", "hideValue", T["Gesamtwert ausblenden"]),
        Check("mine", "hideItemValue", T["Wert pro Eintrag ausblenden"]),
        B(PriceSource()),
        B(Check("mine", "noStack", T["Gleiche Items nicht stapeln"])),
        Slider("mine", "rows", T["Anzahl Einträge"], 3, 10, 1),
        Slider("mine", "rowH", T["Zeilenhöhe"], 16, 32, 1),
        Check("mine", "showIcons", T["Symbole zeigen"]),
        Slider("mine", "width", T["Breite"], 220, 400, 10),
        Slider("mine", "nameSize", T["Schriftgröße"], 0, 18, 1, Auto),
        Check("mine", "showCount", T["Anzahl zeigen"]),
        B(Button(T["Liste leeren"], ns.Actions.clearMine)),
    })

    Setup("toast", T["SexyLoot: Loot-Einblendung"], {
        Header(T["Darstellung"], "look"),
        Check("toast", "hideValue", T["Wert ausblenden"]),
        Check("toast", "splitMoney", T["Geld einzeln anzeigen"]),
        B(PriceSource()),
        B(Slider("toast", "hold", T["Anzeigedauer (Sekunden)"], 2, 20, 1)),
        Slider("toast", "rows", T["Anzahl Zeilen"], 2, 10, 1),
        Slider("toast", "width", T["Breite"], 240, 500, 10),
        Slider("toast", "rowH", T["Zeilenhöhe"], 30, 56, 2),
        Check("toast", "showStripe", T["Qualitätsstreifen zeigen"]),
        Slider("toast", "gap", T["Abstand der Zeilen"], 0, 12, 1),
        Slider("toast", "iconSize", T["Symbolgröße"], 0, 56, 2, Auto),
        Slider("toast", "nameSize", T["Schriftgröße"], 0, 20, 1, Auto),
        Check("toast", "showCount", T["Anzahl zeigen"]),
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
        Slider("deButton", "size", T["Größe"], 32, 72, 2),
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
        Check("wallet", "showSell", T["Verkaufswert zeigen"]),
        Slider("wallet", "width", T["Breite"], 150, 300, 10),
        Slider("wallet", "fontSize", T["Schriftgröße"], 0, 18, 1, Auto),
        Check("wallet", "showLabels", T["Beschriftung zeigen"]),
        B(PriceSource()),
        B(Button(T["Gespeicherte Charaktere zurücksetzen"], function() ns.Wallet:ResetChars() end)),
    })
end
