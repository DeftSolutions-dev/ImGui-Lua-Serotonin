

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

