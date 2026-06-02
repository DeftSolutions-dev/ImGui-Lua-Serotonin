

print("[desirepro_menu] start")

local DesirePro = dofile("C:/Serotonin/scripts/desirepro.lua")
if type(DesirePro) ~= "table" then
    print("[desirepro_menu] FATAL: desirepro.lua failed to load")
    return
end

local ImGui = DesirePro.ImGui

