

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
    local src = DesirePro.theme and DesirePro.col_light or DesirePro.col_dark
    local step = (ImGui.GetDeltaTime() or 0.016) * 12
    if DesirePro.no_anim or step > 1 then step = 1 end
    for k, tgt in pairs(src) do
        local c = DesirePro.col[k]
        c.r = c.r + (tgt.r - c.r) * step
        c.g = c.g + (tgt.g - c.g) * step
        c.b = c.b + (tgt.b - c.b) * step
        c.a = c.a + (tgt.a - c.a) * step
    end
end

function DesirePro.accent_at(y)
    local win = DesirePro._win
    local t = 0.5
    if win and win.h > 0 then
        t = (y - win.y) / win.h
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
    end
    local a, d = DesirePro.col.active, DesirePro.col.dark
    return { r = a.r + (d.r - a.r) * t, g = a.g + (d.g - a.g) * t, b = a.b + (d.b - a.b) * t, a = 1 }
end

local function delta_time() return ImGui.GetDeltaTime() or 0.016 end

function DesirePro.lerp(a, b, t)
    if t > 1 then t = 1 elseif t < 0 then t = 0 end
    return a + (b - a) * t
end

function DesirePro.anim(cur, target, mul)
    if DesirePro.no_anim then return target end
    return DesirePro.lerp(cur, target, delta_time() * (mul or 12))
end

function DesirePro.with_alpha(col, a)
    return { r = col.r, g = col.g, b = col.b, a = a }
end

function DesirePro.pill(layer, x, y, w, h, col)
    local r = (w < h and w or h) / 2
    ImGui.AddRectFilled(layer, x, y, w, h, col, r)
end

function DesirePro.rrect(layer, x, y, w, h, r, col)
    ImGui.AddRectFilled(layer, x, y, w, h, col, r or 0)
end

function DesirePro.grad_rrect(layer, x, y, w, h, r, c1, c2)
    if not r or r <= 0.5 then ImGui.AddGradient(layer, x, y, w, h, c1, c2, true); return end
    if r > w / 2 then r = w / 2 end
    if r > h / 2 then r = h / 2 end
    ImGui.AddRectFilled(layer, x, y, 2 * r, 2 * r, c1, r)
    ImGui.AddRectFilled(layer, x + w - 2 * r, y, 2 * r, 2 * r, c2, r)
    if h > 2 * r then
        ImGui.AddRectFilled(layer, x, y + h - 2 * r, 2 * r, 2 * r, c1, r)
        ImGui.AddRectFilled(layer, x + w - 2 * r, y + h - 2 * r, 2 * r, 2 * r, c2, r)
        ImGui.AddRectFilled(layer, x, y + r, r, h - 2 * r, c1, 0)
        ImGui.AddRectFilled(layer, x + w - r, y + r, r, h - 2 * r, c2, 0)
    end
    if w > 2 * r then ImGui.AddGradient(layer, x + r, y, w - 2 * r, h, c1, c2, true) end
end

local C1, C3 = 1.70158, 2.70158
function DesirePro.ease_back(t)
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    return 1 + C3 * (t - 1) ^ 3 + C1 * (t - 1) ^ 2
end

function DesirePro.ease_toggle(st, key, on, speed)
    if DesirePro.no_anim then return on and 1 or 0 end
    local rec = st[key]
    if type(rec) ~= "table" then rec = { t = 1, on = on }; st[key] = rec end
    if rec.on ~= on then rec.on = on; rec.t = 0 end
    rec.t = rec.t + 0.1 * delta_time() * (speed or 12)
    if rec.t > 1 then rec.t = 1 end
    local e = DesirePro.ease_back(rec.t)
    return on and e or (1 - e)
end

local _seed = 2463534242
local function random_unit()
    local x = _seed
    x = bit.bxor(x, bit.lshift(x, 13))
    x = bit.bxor(x, bit.rshift(x, 17))
    x = bit.bxor(x, bit.lshift(x, 5))
    _seed = x
    return bit.band(x, 0xFFFFFF) / 0x1000000
end

DesirePro.particles = {}
function DesirePro.spawn_particles(cx, cy, n)
    if #DesirePro.particles > 300 then return end
    for i = 1, n do
        local a = random_unit() * 6.28318
        local sp = 25 + random_unit() * 95
        DesirePro.particles[#DesirePro.particles + 1] = {
            x = cx, y = cy, vx = cos(a) * sp, vy = sin(a) * sp - 35,
            life = 0.45 + random_unit() * 0.35, max = 0.8, sz = 1.3 + random_unit() * 1.8,
            col = (i % 2 == 0) and DesirePro.col.active or DesirePro.col.dark,
        }
    end
end

function DesirePro.update_particles()
    local d = delta_time()
    for i = #DesirePro.particles, 1, -1 do
        local p = DesirePro.particles[i]
        p.life = p.life - d
        if p.life <= 0 then
            table.remove(DesirePro.particles, i)
        else
            p.vy = p.vy + 150 * d
            p.x = p.x + p.vx * d
            p.y = p.y + p.vy * d
            ImGui.AddCircleFilled(3, p.x, p.y, p.sz, DesirePro.with_alpha(p.col, p.life / p.max), 8)
        end
    end
end

DesirePro.notifs = {}
function DesirePro.notify(text, icon)
    DesirePro.notifs[#DesirePro.notifs + 1] = { text = text, icon = icon or "NOTIFICATION_FILL", t = 0, x = 1 }
end

function DesirePro.update_notifications()
    if #DesirePro.notifs == 0 then return end
    local sw = ImGui.GetScreenSize()
    local d = delta_time()
    local y = 24
    for i = #DesirePro.notifs, 1, -1 do
        local n = DesirePro.notifs[i]
        n.t = n.t + d
        local target = (n.t < 3.5) and 0 or 1
        n.x = DesirePro.lerp(n.x, target, d * 11)
        if n.t > 3.5 and n.x > 0.98 then
            table.remove(DesirePro.notifs, i)
        else
            local w, h = 280, 58
