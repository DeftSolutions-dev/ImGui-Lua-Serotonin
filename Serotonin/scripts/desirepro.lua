

print("[desirepro] layer start")

local ImGui = dofile("C:/Serotonin/scripts/imgui_lua.lua")
if type(ImGui) ~= "table" then
    print("[desirepro] FATAL: imgui_lua failed to load")
    return nil
end
