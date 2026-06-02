

print("[desirepro_menu] start")

local DesirePro = dofile("C:/Serotonin/scripts/desirepro.lua")
if type(DesirePro) ~= "table" then
    print("[desirepro_menu] FATAL: desirepro.lua failed to load")
    return
end

local ImGui = DesirePro.ImGui

DesirePro.preload({
    fonts = {
        "poppins_semibold_18", "poppins_semibold_17", "poppins_medium_18",
        "poppins_medium_16", "poppins_medium_15",
    },
    icon_names = {
        "CAR_FILL", "EYE_2_FILL", "TRANSLATE_2_AI_LINE", "GROUP_3_FILL",
        "COMPASS_FILL", "EARTH_2_FILL", "MIC_AI_FILL", "BOMB_FILL",
        "TETHER_USDT_FILL", "SETTINGS_4_FILL", "CLOSE_FILL",
        "SWORD_FILL", "TARGET_FILL", "PIC_AI_FILL", "EYE_FILL",
        "PALETTE_LINE", "KEYBOARD_FILL", "NOTIFICATION_FILL", "SUN_2_FILL", "MOONLIGHT_FILL",
