local _, ns = ...

-- Kleine Animations-Hilfen für das Rollfenster: ein Treiber (OnUpdate) für alle Übergänge, ausschaltbar mit
-- ns.cfg.roll.animate = false (dann springen alle Werte sofort auf das Ziel).
local M = {}
ns.Motion = M

local list = {}     -- laufende Übergänge
local driver = CreateFrame("Frame")
driver:Hide()

function M.On()
    local c = ns.cfg and ns.cfg.roll
    return not (c and c.animate == false)
end

local function Ease(p) return 1 - (1 - p) ^ 3 end   -- schnell los, sanft am Ziel

local function Drop(obj, name)
    for i = #list, 1, -1 do
        if list[i].obj == obj and list[i].name == name then table.remove(list, i) end
    end
end

-- Läuft von "from" nach "to" in "dur" Sekunden; step(wert) je Bild, done() am Ende. Gleiches obj+name ersetzt den alten Übergang.
function M.Tween(obj, name, from, to, dur, step, done)
    Drop(obj, name)
    if not M.On() or not dur or dur <= 0 then
        step(to)
        if done then done() end
        return
    end
    list[#list + 1] = { obj = obj, name = name, from = from, to = to, dur = dur, t = 0, step = step, done = done }
    step(from)
    driver:Show()
end

function M.Cancel(obj, name)
    if name then return Drop(obj, name) end
    for i = #list, 1, -1 do
        if list[i].obj == obj then table.remove(list, i) end
    end
end

driver:SetScript("OnUpdate", function(_, dt)
    local finished
    for i = #list, 1, -1 do
        local tw = list[i]
        if tw then
            tw.t = tw.t + dt
            local p = math.min(1, tw.t / tw.dur)
            tw.step(tw.from + (tw.to - tw.from) * Ease(p))
            if p >= 1 then
                -- nur entfernen, wenn step nicht schon einen neuen Übergang mit gleichem Schlüssel gesetzt hat
                if list[i] == tw then table.remove(list, i) end
                if tw.done then finished = finished or {}; finished[#finished + 1] = tw.done end
            end
        end
    end
    if finished then for _, f in ipairs(finished) do f() end end
    if #list == 0 then driver:Hide() end
end)

-- Zahl zählt von 0 bis value hoch (text: FontString)
function M.CountTo(obj, fs, value, dur)
    M.Tween(obj, "count", 0, value, dur or 0.5, function(v) fs:SetText(tostring(math.floor(v + 0.5))) end)
end

-- Heller Streifen, der einmal (oder times-mal) über ein Fenster zieht. Der Streifen liegt in einem eigenen Rahmen
-- über dem Inhalt und wird am Rand abgeschnitten.
function M.NewSweep(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    f:SetFrameLevel(parent:GetFrameLevel() + 30)
    f:EnableMouse(false)
    if f.SetClipsChildren then f:SetClipsChildren(true) end
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetTexture(ns.MEDIA .. "glow128.tga")
    t:SetBlendMode("ADD")
    t:SetVertexColor(0.91, 0.76, 0.42)
    t:Hide()
    return { frame = f, tex = t }
end

function M.Sweep(sw, width, dur, alpha, times)
    if not M.On() then return end
    local f, t = sw.frame, sw.tex
    local function run(n)
        t:Show()
        M.Tween(sw, "sweep", 0, 1, dur, function(p)
            local x = -width + (f:GetWidth() + width) * p
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", f, "TOPLEFT", x, 0)
            t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 0)
            t:SetWidth(width)
            t:SetAlpha(alpha * math.sin(math.pi * p))
        end, function()
            t:Hide()
            if n > 1 then run(n - 1) end
        end)
    end
    run(times or 1)
end
