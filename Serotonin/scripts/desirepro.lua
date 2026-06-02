

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
        return v
    end
    local ok, data = pcall(file.read, rel)
    if not ok or type(data) ~= "string" or #data == 0 then
        tex_cache[rel] = false
        return nil
    end
    local ok2, id = pcall(utility.LoadImage, data)
    if not ok2 or type(id) ~= "number" then
        tex_cache[rel] = false
        return nil
    end
    tex_cache[rel] = id
    return id
end
DesirePro.load_tex = load_tex

local function utf8_iter(s)
    local i, n = 1, #s
    return function()
        if i > n then return nil end
        local c = byte(s, i)
        local cp, size
        if c < 0x80 then cp, size = c, 1
        elseif c < 0xE0 then cp, size = c % 0x20, 2
        elseif c < 0xF0 then cp, size = c % 0x10, 3
        else cp, size = c % 0x08, 4 end
        for k = 1, size - 1 do
            local cc = byte(s, i + k) or 0
            cp = cp * 0x40 + (cc % 0x40)
        end
        i = i + size
        return cp
    end
end
DesirePro.utf8_iter = utf8_iter

function DesirePro.text(layer, x, y, str, font_key, color, alpha)
    local fm = META.fonts[font_key]
    if not fm then return 0 end
    local ascent = fm.ascent
    local dir = ROOT .. "/" .. fm.dir .. "/"
    local pen = x
    for cp in utf8_iter(tostring(str)) do
        local g = fm.glyphs[cp]
        if g then
            if g.f then
                local tex = load_tex(dir .. g.f)
                if tex then
                    ImGui.AddImage(layer, floor(pen + g.bx + 0.5), floor(y + ascent - g.by + 0.5),
                                   g.w, g.h, tex, color, alpha)
                end
            end
            pen = pen + (g.adv or 0)
        end
    end
    return pen - x
end

function DesirePro.text_size(str, font_key)
    local fm = META.fonts[font_key]
    if not fm then return 0, 0 end
    local w = 0
    for cp in utf8_iter(tostring(str)) do
        local g = fm.glyphs[cp]
        if g then w = w + (g.adv or 0) end
    end
    return w, fm.line_height
end

function DesirePro.font(font_key) return META.fonts[font_key] end
function DesirePro.font_height(font_key)
    local fm = META.fonts[font_key]
    return fm and fm.line_height or 0
end

DesirePro.ICON = {
    KEYBOARD_FILL = 0xEED9, KEYBOARD_LINE = 0xEEDA, DOWN_FILL = 0xEC6B,
    DOWN_LINE = 0xEC6C, BOMB_FILL = 0xEA31, TRANSLATE_2_AI_LINE = 0xF384,
    TETHER_USDT_FILL = 0xF31F, SWORD_FILL = 0xF2ED, SETTINGS_4_FILL = 0xF217,
    PALETTE_LINE = 0xF072, NOTIFICATION_FILL = 0xF03F, MIC_AI_FILL = 0xEFD3,
    GROUP_3_FILL = 0xEE21, EYE_2_FILL = 0xECE9, EYE_FILL = 0xECED,
    EARTH_2_FILL = 0xEC93, COMPASS_FILL = 0xEB8D, CAR_FILL = 0xEADB,
    TARGET_FILL = 0xF307, SUN_2_FILL = 0xF2D5, PIC_AI_FILL = 0xF0C3,
    MOONLIGHT_FILL = 0xF007, CLOSE_FILL = 0xEB59, ARROWS_RIGHT_LINE = 0xE99E,
    ARROWS_LEFT_LINE = 0xE99C,
}

function DesirePro.icon(layer, x, y, key, size, color, alpha)
    local im = META.icons[size]
    if not im then return 0 end
    local cp = type(key) == "number" and key or DesirePro.ICON[key]
    if not cp then return 0 end
    local g = im.glyphs[cp]
    if not g or not g.f then return 0 end
    local tex = load_tex(ROOT .. "/" .. im.dir .. "/" .. g.f)
    if tex then
        ImGui.AddImage(layer, floor(x + (g.bx or 0) + 0.5), floor(y + (im.off or 0) + 0.5),
                       g.w, g.h, tex, color, alpha)
    end
    return g.w
end

function DesirePro.icon_size(key, size)
    local im = META.icons[size]
    if not im then return 0, 0 end
    local cp = type(key) == "number" and key or DesirePro.ICON[key]
    local g = cp and im.glyphs[cp]
    if not g then return 0, 0 end
    return g.w, g.h
end

function DesirePro.image(layer, x, y, w, h, name, color, alpha)
    local info = META.images[name]
    if not info then return end
    local tex = load_tex(ROOT .. "/" .. info.f)
    if tex then ImGui.AddImage(layer, x, y, w, h, tex, color or ImGui.ColF(1, 1, 1, 1), alpha or 1) end
end

function DesirePro.image_info(name) return META.images[name] end

function DesirePro.shadow_rect(layer, x, y, w, h, color, alpha, spread)
    local tex = load_tex(ROOT .. "/shadow/rect.png")
    if not tex then return end
    local m = spread or 18
    ImGui.AddImage(layer, x - m, y - m, w + 2 * m, h + 2 * m, tex,
                   color or ImGui.RGBA(0, 0, 0, 255), alpha or 0.55)
end

function DesirePro.shadow_circle(layer, cx, cy, r, color, alpha)
    local tex = load_tex(ROOT .. "/shadow/circle.png")
    if not tex then return end
    local s = r * 2.2
    ImGui.AddImage(layer, cx - s, cy - s, s * 2, s * 2, tex,
                   color or ImGui.RGBA(0, 0, 0, 255), alpha or 0.5)
end

function DesirePro.preload_font(font_key)
    local fm = META.fonts[font_key]
    if not fm then return 0 end
    local dir = ROOT .. "/" .. fm.dir .. "/"
    local n = 0
    for _, g in pairs(fm.glyphs) do
        if g.f and load_tex(dir .. g.f) then n = n + 1 end
    end
    return n
end

function DesirePro.preload_icons(size)
    local im = META.icons[size]
    if not im then return 0 end
    local n = 0
    for _, g in pairs(im.glyphs) do
        if g.f and load_tex(ROOT .. "/" .. im.dir .. "/" .. g.f) then n = n + 1 end
    end
    return n
end

function DesirePro.preload(spec)
    local total = 0

    local fonts = spec and spec.fonts
    if not fonts then
        fonts = {}
        for k in pairs(META.fonts) do fonts[#fonts + 1] = k end
    end
    for _, k in ipairs(fonts) do total = total + DesirePro.preload_font(k) end

    local names = (spec and spec.icon_names) or {}
    local isizes = (spec and spec.icon_sizes) or { 18, 35 }
    for _, size in ipairs(isizes) do
        local im = META.icons[size]
        if im then
            for _, name in ipairs(names) do
                local cp = DesirePro.ICON[name]
                local g = cp and im.glyphs[cp]
                if g and g.f and load_tex(ROOT .. "/" .. im.dir .. "/" .. g.f) then total = total + 1 end
                if g and g.f and load_tex(ROOT .. "/icon_grad/" .. size .. "/" .. g.f) then total = total + 1 end
            end
        end
    end

    local imgs = (spec and spec.images) or {}
    for _, name in ipairs(imgs) do
        local info = META.images[name]
        if info and load_tex(ROOT .. "/" .. info.f) then total = total + 1 end
    end

    if load_tex(ROOT .. "/shadow/rect.png") then total = total + 1 end
    if load_tex(ROOT .. "/shadow/circle.png") then total = total + 1 end
    if load_tex(ROOT .. "/img/grad_pill.png") then total = total + 1 end

    print("[desirepro] preloaded " .. total .. " textures")
    return total
end

local R = ImGui.RGBA

DesirePro.col_dark = {
    active        = R(88, 116, 245, 255), dark          = R(228, 58, 72, 255),
    second        = R(22, 22, 24, 255),   background    = R(22, 22, 27, 255),
    window_bg     = R(14, 14, 16, 200),   bg            = R(14, 14, 16, 255),
    separator     = R(40, 42, 52, 255),   anim_default  = R(27, 27, 32, 200),
    child_top     = R(28, 30, 36, 200),   child_bg      = R(19, 19, 23, 200),
    child_stroke  = R(47, 48, 55, 60),    page_active   = R(37, 39, 53, 255),
    page          = R(31, 33, 40, 255),   page_text_hov = R(240, 240, 240, 255),
    page_text     = R(224, 224, 224, 255), elem_hov     = R(44, 46, 52, 255),
    elem          = R(39, 41, 47, 255),   checkmark     = R(59, 130, 246, 255),
    label_active  = R(255, 255, 255, 255), label_hover  = R(235, 235, 240, 255),
    label         = R(185, 185, 185, 255), desc_active  = R(180, 180, 185, 255),
    desc_hover    = R(160, 160, 170, 255), desc         = R(140, 140, 150, 255),
}
DesirePro.col_light = {
    active        = R(88, 116, 245, 255), dark          = R(228, 58, 72, 255),
    second        = R(240, 240, 240, 200), background   = R(250, 250, 250, 180),
    window_bg     = R(255, 255, 255, 180), bg           = R(245, 245, 245, 200),
    separator     = R(200, 200, 200, 180), anim_default = R(215, 215, 215, 200),
    child_top     = R(255, 255, 255, 120), child_bg     = R(255, 255, 255, 120),
    child_stroke  = R(230, 230, 240, 180), page_active  = R(255, 255, 255, 200),
    page          = R(240, 240, 240, 200), page_text_hov = R(70, 100, 255, 255),
    page_text     = R(60, 90, 255, 255),  elem_hov      = R(220, 220, 220, 200),
    elem          = R(210, 210, 210, 200), checkmark    = R(0, 120, 255, 255),
    label_active  = R(0, 0, 0, 255),      label_hover   = R(20, 20, 20, 255),
    label         = R(50, 50, 50, 255),   desc_active   = R(90, 90, 90, 255),
    desc_hover    = R(100, 100, 100, 255), desc         = R(120, 120, 120, 255),
}
DesirePro.col = {}
for k, v in pairs(DesirePro.col_dark) do DesirePro.col[k] = { r = v.r, g = v.g, b = v.b, a = v.a } end
DesirePro.theme = false

function DesirePro.update_theme()
