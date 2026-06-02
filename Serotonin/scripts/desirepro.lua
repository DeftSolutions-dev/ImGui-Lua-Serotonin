

print("[desirepro] layer start")

local ImGui = dofile("C:/Serotonin/scripts/imgui_lua.lua")
if type(ImGui) ~= "table" then
    print("[desirepro] FATAL: imgui_lua failed to load")
    return nil
end

local DesirePro = { ImGui = ImGui }

local byte, sub, format = string.byte, string.sub, string.format
local floor = math.floor
