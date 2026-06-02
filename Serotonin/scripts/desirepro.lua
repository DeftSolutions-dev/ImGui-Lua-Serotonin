

print("[desirepro] layer start")

local ImGui = dofile("C:/Serotonin/scripts/imgui_lua.lua")
if type(ImGui) ~= "table" then
    print("[desirepro] FATAL: imgui_lua failed to load")
    return nil
end

local DesirePro = { ImGui = ImGui }

local byte, sub, format = string.byte, string.sub, string.format
local floor = math.floor
local sin, cos, abs = math.sin, math.cos, math.abs

local function point_in_rect(px, py, rx, ry, rw, rh)
    return px >= rx and py >= ry and px < rx + rw and py < ry + rh
end

local META = nil
do
    local ok, src = pcall(file.read, "desirepro/metrics.lua")
    if ok and type(src) == "string" and #src > 0 then
        local chunk = loadstring(src, "desirepro_metrics")
        if chunk then
            local ok2, tbl = pcall(chunk)
            if ok2 and type(tbl) == "table" then META = tbl end
        end
    end
end
if not META then
    print("[desirepro] FATAL: could not load desirepro/metrics.lua (run build_desirepro_assets.py)")
    return nil
end
DesirePro.meta = META
local ROOT = "desirepro"

do
    local nf = 0
    for _ in pairs(META.fonts) do nf = nf + 1 end
    print(format("[desirepro] metrics ok: %d font sizes, icons + %d images", nf,
        (function() local n = 0 for _ in pairs(META.images or {}) do n = n + 1 end return n end)()))
end

local LOCALE = {}
do
    local ok, src = pcall(file.read, "desirepro/localization.lua")
    if ok and type(src) == "string" and #src > 0 then
        local chunk = loadstring(src, "desirepro_locale")
        if chunk then
            local ok2, t = pcall(chunk)
            if ok2 and type(t) == "table" then LOCALE = t end
        end
    end
end
DesirePro.lang = 0
DesirePro.LANG_KEYS = { "en", "ru", "zh", "ja", "vi", "id" }
DesirePro.LANG_NAMES = { "English", "\208\160\209\131\209\129\209\129\208\186\208\184\208\185",
                 "\228\184\173\230\150\135", "\230\151\165\230\156\172\232\170\158",
                 "Ti\225\186\191ng Vi\225\187\135t", "Indonesia" }
function DesirePro.translate(en)
    if DesirePro.lang == 0 or not en or en == "" then return en end
    local e = LOCALE[en]
    if not e then return en end
    return e[DesirePro.LANG_KEYS[DesirePro.lang + 1]] or en
end

local tex_cache = {}
local function load_tex(rel)
    local v = tex_cache[rel]
    if v ~= nil then
        if v == false then return nil end
