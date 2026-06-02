

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
            local nx = sw - w - 22 + n.x * (w + 44)
            DesirePro.shadow_rect(3, nx, y, w, h, DesirePro.with_alpha(ImGui.RGBA(0, 0, 0, 255), 1), 0.5, 18)
            ImGui.AddRectFilled(3, nx, y, w, h, DesirePro.with_alpha(DesirePro.col.bg, 0.97), 8)
            ImGui.AddRectFilled(3, nx, y, w, h, DesirePro.with_alpha(DesirePro.col.window_bg, 0.5), 8)
            ImGui.AddRect(3, nx, y, w, h, DesirePro.col.child_stroke, 1, 8)
            DesirePro.icon_scaled(3, nx + 32, y + h / 2, n.icon, 35, 24, DesirePro.col.active, 1)
            DesirePro.text_in(3, nx + 58, y, h, n.text, "poppins_medium_16", DesirePro.col.label_active, 1)
            y = y + h + 12
        end
    end
end

DesirePro.ICON_SIZES = { 16, 18, 23, 27, 35 }
function DesirePro.icon_scaled(layer, cx, cy, key, atlas_size, target_px, col, alpha)
    local cp = type(key) == "number" and key or DesirePro.ICON[key]
    if not cp then return end

    local best = 35
    for _, sz in ipairs(DesirePro.ICON_SIZES) do
        if sz >= target_px then best = sz; break end
    end
    local im = META.icons[best] or META.icons[atlas_size]
    if not im then return end
    local g = im.glyphs[cp]
    if not g or not g.f then return end
    local tex = load_tex(ROOT .. "/" .. im.dir .. "/" .. g.f)
    if not tex then return end
    local s = target_px / best
    local w, h = g.w * s, g.h * s
    ImGui.AddImage(layer, floor(cx - w / 2 + 0.5), floor(cy - h / 2 + 0.5),
                   floor(w + 0.5), floor(h + 0.5), tex, col, alpha)
end

function DesirePro.icon_gradient(layer, cx, cy, key, target_px, alpha)
    local cp = type(key) == "number" and key or DesirePro.ICON[key]
    if not cp then return end
    local best = 35
    for _, sz in ipairs(DesirePro.ICON_SIZES) do
        if sz >= target_px then best = sz; break end
    end
    local im = META.icons[best]
    if not im then return end
    local g = im.glyphs[cp]
    if not g or not g.f then return end
    local tex = load_tex(ROOT .. "/icon_grad/" .. best .. "/" .. g.f)
    if not tex then
        return DesirePro.icon_scaled(layer, cx, cy, key, 35, target_px, DesirePro.accent_at(cy), alpha or 1)
    end
    local s = target_px / best
    local w, h = g.w * s, g.h * s
    ImGui.AddImage(layer, floor(cx - w / 2 + 0.5), floor(cy - h / 2 + 0.5),
                   floor(w + 0.5), floor(h + 0.5), tex, ImGui.ColF(1, 1, 1, 1), alpha or 1)
end

function DesirePro.text_centered(layer, cx, y, str, font_key, color, alpha)
    local w = DesirePro.text_size(str, font_key)
    return DesirePro.text(layer, floor(cx - w / 2 + 0.5), y, str, font_key, color, alpha)
end

function DesirePro.text_in(layer, x, box_top, box_h, str, font_key, color, alpha)
    local fm = META.fonts[font_key]
    local cap = fm and fm.cap_height or 12
    local asc = fm and fm.ascent or 14
    local top = box_top + (box_h + cap) / 2 - asc
    return DesirePro.text(layer, x, floor(top + 0.5), str, font_key, color, alpha)
end

function DesirePro.text_mid(layer, cx, cy, str, font_key, color, alpha)
    local w = DesirePro.text_size(str, font_key)
    local fm = META.fonts[font_key]
    local cap = fm and fm.cap_height or 12
    local asc = fm and fm.ascent or 14
    return DesirePro.text(layer, floor(cx - w / 2 + 0.5), floor(cy + cap / 2 - asc + 0.5),
                  str, font_key, color, alpha)
end

DesirePro.US = 0.9
DesirePro.WINDOW_W = floor(735 * DesirePro.US)
DesirePro.WINDOW_H = floor(700 * DesirePro.US)
DesirePro.TAB_BAND = floor(90 * DesirePro.US)
DesirePro.HEADER_H = floor(60 * DesirePro.US)

DesirePro.tabs = {
    { icon = "CAR_FILL",            name = "Car" },
    { icon = "EYE_2_FILL",          name = "ESP" },
    { icon = "TRANSLATE_2_AI_LINE", name = "Lang" },
    { icon = "GROUP_3_FILL",        name = "Players" },
    { icon = "COMPASS_FILL",        name = "Radar" },
    { icon = "EARTH_2_FILL",        name = "World" },
    { icon = "MIC_AI_FILL",         name = "Misc" },
    { icon = "BOMB_FILL",           name = "Exploits" },
}

DesirePro.active_tab = 0
DesirePro.dock = 0
local tab_anim = {}

local function tab_label(tab)
    return DesirePro.translate(tab.name)
end

local function draw_square_tab(i, tab, bx, by, bw, bh)
    local st = tab_anim[i]
    if not st then
        st = { fa = 0, ia = 0.5, isz = 25, toff = 5, ta = 1 }
        tab_anim[i] = st
    end

    local mx, my = ImGui.GetMousePos()
    local hovered = point_in_rect(mx, my, bx, by, bw, bh) and not (DesirePro.drag and DesirePro.drag.moved)
    local selected = (DesirePro.active_tab == i)
    if hovered and ImGui.IsMouseClicked() and not DesirePro._modal and not DesirePro._input_block then
        DesirePro.active_tab = i
    end

    local f_target = selected and 0.30 or (hovered and 0.15 or 0.0)
    local i_target = selected and 1.0 or (hovered and 0.8 or 0.5)
    local s_target = selected and 35 or 25
    local o_target = selected and -7 or 5
    st.fa  = DesirePro.anim(st.fa, f_target, 12)
    st.ia  = DesirePro.anim(st.ia, i_target, 12)
    st.isz = 25 + DesirePro.ease_toggle(st, "iszE", selected, 15) * 10
    st.toff = DesirePro.anim(st.toff, o_target, 12)

    if st.fa > 0.002 then
        ImGui.AddRectFilled(2, bx, by, bw, bh, DesirePro.with_alpha(DesirePro.col.active, st.fa), 6)
    end

    local cx = bx + bw / 2
    local cy = by + bh / 2 - 6
    DesirePro.icon_gradient(2, cx, cy - st.toff, tab.icon, st.isz, st.ia)

    local lab = tab_label(tab)
    local lcol, la
    if selected then lcol, la = DesirePro.col.label_active, 0
    elseif hovered then lcol, la = DesirePro.col.label_hover, 1
    else lcol, la = DesirePro.col.label, 1 end
    if la > 0 then
        DesirePro.text_centered(2, cx, by + bh - 20, lab, "poppins_medium_18", lcol, la)
    end
end

local function draw_tab(i, tab, bx, by, bw, bh)
    local st = tab_anim["v" .. i]
    if not st then st = { fa = 0, ia = 0.5, toff = 5 }; tab_anim["v" .. i] = st end
    local mx, my = ImGui.GetMousePos()
    local dragging = DesirePro.drag and DesirePro.drag.moved
    local hovered = point_in_rect(mx, my, bx, by, bw, bh) and not dragging
    local selected = (DesirePro.active_tab == i)
    if hovered and ImGui.IsMouseClicked() and not DesirePro._modal and not DesirePro._input_block then DesirePro.active_tab = i end

    st.fa = DesirePro.anim(st.fa, selected and 0.30 or (hovered and 0.15 or 0), 12)
    st.ia = DesirePro.anim(st.ia, selected and 1.0 or (hovered and 0.8 or 0.5), 12)
    st.toff = DesirePro.anim(st.toff, selected and 6 or 0, 12)

    if st.fa > 0.002 then
        ImGui.AddRectFilled(2, bx, by, bw, bh, DesirePro.with_alpha(DesirePro.col.active, st.fa), 6)
    end
    DesirePro.icon_gradient(2, bx + 24, by + bh / 2, tab.icon, 22, st.ia)
    local lcol = selected and DesirePro.col.label_active or (hovered and DesirePro.col.label_hover or DesirePro.col.label)
    DesirePro.text_in(2, bx + 46 + st.toff, by, bh, tab_label(tab), "poppins_medium_18", lcol, 1)
end

local function draw_header(mx, my, mw)

    DesirePro.icon_gradient(2, mx + 35, my + 30, "TETHER_USDT_FILL", 30, 1)

    DesirePro.text(2, mx + 60, my + 11, "DesirePro", "poppins_semibold_18", DesirePro.col.label_active, 1)
    DesirePro.text(2, mx + 60, my + 32, DesirePro.translate("Fine-tuning for sure wins"), "poppins_medium_15", DesirePro.col.desc, 1)

    local sx = mx + mw - 70
    local sy = my + 30
    local msx, msy = ImGui.GetMousePos()
    DesirePro._gear_rect = { x = sx - 17, y = sy - 17, w = 34, h = 34 }
    local tx = sx - 40
    local h0 = point_in_rect(msx, msy, tx - 17, sy - 17, 34, 34)
    local h1 = point_in_rect(msx, msy, sx - 17, sy - 17, 34, 34)
    local h2 = point_in_rect(msx, msy, sx + 23, sy - 17, 34, 34)

    local hclk = ImGui.IsMouseClicked() and not DesirePro._input_block
    if h0 and hclk and not DesirePro._modal then
        DesirePro.theme = not DesirePro.theme
        DesirePro.notify(DesirePro.theme and "Light theme" or "Dark theme", DesirePro.theme and "SUN_2_FILL" or "MOONLIGHT_FILL")
    end
    if h1 and hclk then DesirePro.settings_open = not DesirePro.settings_open end
    if h2 and hclk and not DesirePro._modal then ImGui.SetMenuOpen(false) end

    DesirePro.icon_scaled(2, tx, sy, DesirePro.theme and "SUN_2_FILL" or "MOONLIGHT_FILL", 35, 20,
        h0 and DesirePro.col.label_active or DesirePro.col.desc, 1)
    DesirePro.icon_scaled(2, sx, sy, "SETTINGS_4_FILL", 35, 22, h1 and DesirePro.col.label_active or DesirePro.col.desc, 1)
    DesirePro.icon_scaled(2, sx + 40, sy, "CLOSE_FILL", 35, 22, h2 and DesirePro.col.label_active or DesirePro.col.desc, 1)
end

local widget_states = {}
local function widget_state(id, init)
    local s = widget_states[id]
    if not s then s = init or {}; widget_states[id] = s end
    return s
end

DesirePro.vars = {}
local function var(id, default)
    if DesirePro.vars[id] == nil then DesirePro.vars[id] = default end
    return DesirePro.vars[id]
end

local function col_lerp_rgb(a, b, t)
    return { r = DesirePro.lerp(a.r, b.r, t), g = DesirePro.lerp(a.g, b.g, t), b = DesirePro.lerp(a.b, b.b, t), a = 1 }
end

local function hsv2rgb(h, s, v, a)
    if s <= 0 then return { r = v, g = v, b = v, a = a or 1 } end
    h = (h - floor(h)) * 6
    local i = floor(h)
    local f = h - i
    local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    local r, g, b
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    else r, g, b = v, p, q end
    return { r = r, g = g, b = b, a = a or 1 }
end
DesirePro.hsv2rgb = hsv2rgb

local function clamp01(x) if x < 0 then return 0 elseif x > 1 then return 1 end return x end

local function rotate_point(cx, cy, px, py, a)
    local sn, cs = math.sin(a), math.cos(a)
    local dx, dy = px - cx, py - cy
    return cx + dx * cs - dy * sn, cy + dx * sn + dy * cs
end

local active_drag = nil
local open_combo = nil
local open_color = nil
local color_drag = nil
local popup = nil
local popup_rect = nil
DesirePro._input_block = false

local function mouse_pos() return ImGui.GetMousePos() end
local function raw_clicked() return ImGui.IsMouseClicked() end
local function clicked()
    if not ImGui.IsMouseClicked() then return false end
    if DesirePro._input_block then return false end
    if DesirePro._modal and not DesirePro._modal_active then return false end
    return true
end
local function mouse_down() return ImGui.IsMouseDown() end
local function right_clicked()
    if not ImGui.IsMouseRightClicked() then return false end
    if DesirePro._input_block then return false end
    if DesirePro._modal and not DesirePro._modal_active then return false end
    return true
end
local function in_popup(mx, my)
    return popup_rect ~= nil and point_in_rect(mx, my, popup_rect.x, popup_rect.y, popup_rect.w, popup_rect.h)
end

local function split_desc(s)
    local c = s:find(":")
    if not c then return s, "" end
    local a = s:sub(1, c - 1):gsub("%s+$", "")
    local b = s:sub(c + 1):gsub("^%s+", "")
    return a, b
end

local appear_state = {}
function DesirePro.appear(id, center_y)
    if DesirePro.no_appear or DesirePro.no_anim then return 0, 1 end
    local fc = ImGui.GetFrameCount() or 0
    local s = appear_state[id]
    local restart = false
    if not s then
        s = { off = 0, alpha = 1, timer = 0, seen = fc }
        appear_state[id] = s
        restart = true
    elseif s.seen < fc - 1 then

        restart = true
    end
    s.seen = fc
    if restart then
        s.off = -((DesirePro._win and DesirePro._win.w) or 400)
        s.alpha = 0
        s.timer = 0
    end
    s.timer = s.timer + delta_time()
    local wy = (DesirePro._win and DesirePro._win.y) or 0
    local wh = (DesirePro._win and DesirePro._win.h) or 700
    local rel = (center_y - wy) / wh
    if rel < 0 then rel = 0 elseif rel > 1 then rel = 1 end
    local delay = 0.1 + rel * 0.9
    local t = (s.timer - delay) / 0.3
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    s.off = DesirePro.lerp(s.off, 0, delta_time() * t * 4)
    s.alpha = DesirePro.lerp(s.alpha, 1, delta_time() * t * 3)
    if t >= 1 and s.off > -0.5 then s.off = 0 end
    return s.off, s.alpha
end

local function appear_xy(id, ctx, rowh)
    local off, al = DesirePro.appear(id, ctx.cy + (rowh or 20) / 2)
    ImGui.SetDrawAlpha(al)
    return ctx.x + off, ctx.x1 + off
end

local CARD_HEADER = floor(55 * DesirePro.US)
function DesirePro.begin_card(name, x, y, w, body_h, icon)
    body_h = floor(body_h * DesirePro.US)
    local id = "card:" .. name
    local cs = widget_state(id, { on = true, t = 1, h = body_h })

    local _, al = DesirePro.appear(id, y + (CARD_HEADER + body_h) / 2)
    ImGui.SetDrawAlpha(al)
    local bx = x
    local r = 4

    local mx, my = mouse_pos()
    local pw, ph = 36, 20
    local pill_l, pill_t = floor(x + w - 48), floor(y + CARD_HEADER / 2 - 10)
    if point_in_rect(mx, my, pill_l, pill_t, pw, ph) and clicked() then cs.on = not cs.on end
    cs.t = DesirePro.anim(cs.t, cs.on and 1 or 0, 12)
    cs.h = DesirePro.anim(cs.h, cs.on and body_h or 0, 12)
    local total = CARD_HEADER + cs.h

    ImGui.AddRectFilled(2, x, y, w, total + 2, DesirePro.col.child_bg, r)
    ImGui.AddRectFilled(2, x, y, w, CARD_HEADER, DesirePro.col.anim_default, r)
    ImGui.AddRect(2, x, y, w, total + 2, DesirePro.col.child_stroke, 1, r)

    local ptex = load_tex(ROOT .. "/img/grad_pill.png")
    if ptex then
        ImGui.AddImage(2, pill_l, pill_t, pw, ph, ptex, ImGui.ColF(0.13, 0.13, 0.15, 1), 1)
        if cs.t > 0.01 then
            ImGui.AddImage(2, pill_l, pill_t, pw, ph, ptex, ImGui.ColF(1, 1, 1, 1), cs.t)
        end
    end
    ImGui.AddRect(2, pill_l, pill_t, pw, ph, DesirePro.col.second, 1.5, ph / 2)
    local knob_cx = pill_l + 10 + (pw - 20) * cs.t
    local knob_cy = pill_t + ph / 2
    local kc = 0.6 + 0.4 * cs.t
    DesirePro.shadow_circle(2, knob_cx, knob_cy, 7, DesirePro.with_alpha(ImGui.RGBA(0, 0, 0, 255), 1), 0.45)
    ImGui.AddRectFilled(2, floor(knob_cx - 7), floor(knob_cy - 7), 14, 14, ImGui.ColF(kc, kc, kc, 1), 7)

    local title, desc = split_desc(DesirePro.translate(name))
    DesirePro.text(2, x + 55, y + 8, title, "poppins_semibold_18", DesirePro.col.label_active, 1)
    if desc ~= "" then
        DesirePro.text(2, x + 55, y + 30, desc, "poppins_medium_15", DesirePro.col.desc, 1)
    end
    if icon then
        DesirePro.icon_gradient(2, x + 28, y + 28, icon, 24, 1)
    end

    ImGui.PushClipRect(bx, y + CARD_HEADER, w, cs.h + 2)

    return { x = bx + 13, cy = y + CARD_HEADER + 13, w = w - 26, x1 = bx + w - 13,
             on = cs.h > 5, total = total, idp = name }
end

function DesirePro.end_card(ctx)
    ImGui.PopClipRect()
end

function DesirePro.checkbox(ctx, label)
    local id = "cb:" .. ctx.idp .. label
    local v = var(id, false)
    local s = widget_state(id, { check = v and 1 or 0, lab = 0 })
    local box = floor(20 * DesirePro.US)
    local x = appear_xy(id, ctx, box)
    local y = ctx.cy
    local disp = DesirePro.translate(label)
    local lw = DesirePro.text_size(disp, "poppins_medium_18")
    local mx, my = mouse_pos()
    local hovered = point_in_rect(mx, my, x, y, box + 14 + lw, box)
    if hovered and clicked() then v = not v; DesirePro.vars[id] = v; DesirePro.spawn_particles(x + box / 2, y + box / 2, 16) end

    s.check = DesirePro.ease_toggle(s, "checkE", v, 30)
    s.hovg = DesirePro.anim(s.hovg or 0, (hovered and v) and 1 or 0, 20)
    s.lab = DesirePro.anim(s.lab, hovered and 1 or 0, 12)
    local lcol = v and DesirePro.col.label_active or (hovered and DesirePro.col.label_hover or DesirePro.col.label)

    local r = 4
    local grow = s.hovg * 6
    local bxx, byy, bs = floor(x - grow / 2), floor(y - grow / 2), floor(box + grow)
    local cc = s.check; if cc > 1 then cc = 1 elseif cc < 0 then cc = 0 end
    ImGui.AddRectFilled(2, bxx, byy, bs, bs, DesirePro.col.anim_default, r)
    if cc > 0.01 then
        DesirePro.grad_rrect(2, bxx, byy, bs, bs, r, DesirePro.with_alpha(DesirePro.col.dark, cc), DesirePro.with_alpha(DesirePro.col.active, cc))
    end
    if s.check > 0.05 then
        local cx, cy = bxx + bs / 2, byy + bs / 2
        local k = (bs / box) * s.check
        local a = DesirePro.with_alpha(DesirePro.col.label_active, cc)
        ImGui.AddLine(2, cx - 4.5 * k, cy + 0.5 * k, cx - 1.5 * k, cy + 3.5 * k, a, 2)
        ImGui.AddLine(2, cx - 1.5 * k, cy + 3.5 * k, cx + 4.5 * k, cy - 3.5 * k, a, 2)
    end
    DesirePro.text_in(2, x + box + floor(14 * DesirePro.US), y, box, disp, "poppins_medium_18", lcol, 1)

    ctx.cy = ctx.cy + box + floor(11 * DesirePro.US)
    return v
end

function DesirePro.featurebox(ctx, label, content_fn)
    local id = "fx:" .. ctx.idp .. label
    local row_y = ctx.cy
    local v = DesirePro.checkbox(ctx, label)

    local st = widget_state(id, { gh = 0 })
    local gx, gy = ctx.x1 - 11, row_y + 10
    local mx, my = mouse_pos()
    local hov = point_in_rect(mx, my, gx - 13, gy - 13, 26, 26)
    local opened = (DesirePro._feature and DesirePro._feature.id == id)
    if hov and clicked() then
        if opened then
            DesirePro._feature = nil
        else
            DesirePro._feature = { id = id, content = content_fn, ax = ctx.x1, ay = row_y, idp = id }
        end
    end
    st.gh = DesirePro.anim(st.gh, (hov or opened) and 1 or 0, 12)
    local gcol = (hov or opened) and DesirePro.col.label_active or DesirePro.col.label
    DesirePro.icon_scaled(2, gx, gy, "SETTINGS_4_FILL", 18, 13 + st.gh * 2, gcol, 1)
    return v
end

function DesirePro.slider(ctx, label, vmin, vmax, is_int)
    local id = "sl:" .. ctx.idp .. label
    local v = var(id, vmin + (vmax - vmin) * 0.4)
    local s = widget_state(id, { slow = 0, grab = 0 })
    local US = DesirePro.US
    local x = appear_xy(id, ctx, floor(44 * US))
    local y, w = ctx.cy, ctx.w
    local label_h = floor(16 * US)
    local btn = floor(16 * US)
    local tmin_x = x + btn + floor(6 * US)
    local tmax_x = x + w - btn - floor(6 * US)
    local tmin_y = y + floor(13 * US) + label_h
    local tmax_y = y + floor(39 * US)
    local tw = tmax_x - tmin_x
    local th = tmax_y - tmin_y
    local mid_y = (tmin_y + tmax_y) / 2
    local step = is_int and 1 or ((vmax - vmin) / 100)

    local mx, my = mouse_pos()
    local minus_hit = point_in_rect(mx, my, x, mid_y - btn / 2, btn, btn)
    local plus_hit = point_in_rect(mx, my, x + w - btn, mid_y - btn / 2, btn, btn)
    if minus_hit and clicked() then
        v = v - step; if v < vmin then v = vmin end; if is_int then v = floor(v + 0.5) end; DesirePro.vars[id] = v
    end
    if plus_hit and clicked() then
        v = v + step; if v > vmax then v = vmax end; if is_int then v = floor(v + 0.5) end; DesirePro.vars[id] = v
    end

    local over = point_in_rect(mx, my, tmin_x - 6, tmin_y - 6, tw + 12, th + 12)
    if over and clicked() then active_drag = id end
    if active_drag == id then
        if mouse_down() then
            local frac = (mx - tmin_x) / tw
            if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
            v = vmin + frac * (vmax - vmin)
            if is_int then v = floor(v + 0.5) end
            DesirePro.vars[id] = v
        else
            active_drag = nil
        end
    end

    local frac = (v - vmin) / (vmax - vmin)
    s.slow = DesirePro.anim(s.slow, frac * tw, 25)
    s.grab = DesirePro.ease_toggle(s, "grabE", over or active_drag == id, 20)
    local grab_cx = tmin_x + s.slow
    if grab_cx < tmin_x + 8 then grab_cx = tmin_x + 8 elseif grab_cx > tmax_x - 7 then grab_cx = tmax_x - 7 end

    DesirePro.text(2, x, y, DesirePro.translate(label), "poppins_medium_15", DesirePro.col.label, 1)
    local vs = is_int and tostring(floor(v)) or string.format("%.2f", v)
    local vw = DesirePro.text_size(vs, "poppins_medium_15")
    DesirePro.text(2, x + w - vw, y, vs, "poppins_medium_15", DesirePro.col.label_active, 1)

    DesirePro.text_mid(2, x + btn / 2, mid_y, "-", "poppins_semibold_18", minus_hit and DesirePro.col.label_active or DesirePro.col.label, 1)
    DesirePro.text_mid(2, x + w - btn / 2, mid_y, "+", "poppins_semibold_18", plus_hit and DesirePro.col.label_active or DesirePro.col.label, 1)

    DesirePro.pill(2, tmin_x, tmin_y, tw, th, DesirePro.col.anim_default)
    if s.slow > 1 then
        local fw = (s.slow < th) and th or s.slow
        DesirePro.grad_rrect(2, tmin_x, tmin_y, fw, th, th / 2, DesirePro.col.dark, DesirePro.col.active)
    end

    local grow = s.grab * 3
    local gw = floor(18 * US + grow)
    local gh = floor(17 * US + grow)
    local gx, gy = floor(grab_cx - gw / 2), floor(mid_y - gh / 2)
    DesirePro.shadow_rect(2, gx, gy, gw, gh, DesirePro.with_alpha(ImGui.RGBA(0, 0, 0, 255), 1), 0.35, 7)
    local gc = 0.75 + 0.25 * s.grab
    ImGui.AddRectFilled(2, gx, gy, gw, gh, ImGui.ColF(gc, gc, gc, 1), 3)
    ImGui.AddRect(2, gx, gy, gw, gh, ImGui.ColF(0, 0, 0, 0.15 + 0.1 * s.grab), 1, 3)
    local lw, sp, pad = 2, 3, 2
    local sx = gx + (gw - (3 * lw + 2 * sp)) / 2
    for i = 0, 2 do
        ImGui.AddRectFilled(2, floor(sx + i * (lw + sp)), gy + pad, lw, gh - 2 * pad, ImGui.ColF(0, 0, 0, 0.35), 1)
    end

    ctx.cy = ctx.cy + floor(44 * US) + floor(9 * US)
    return v
end

function DesirePro.button(ctx, label, h)
    h = floor((h or 35) * DesirePro.US)
    local id = "bt:" .. ctx.idp .. label
    local s = widget_state(id, { hov = 0, press = 0, text = 0 })
    local x = appear_xy(id, ctx, h)
    local y, w = ctx.cy, ctx.w
    local mx, my = mouse_pos()
    local hovered = point_in_rect(mx, my, x, y, w, h)
    local pressed = hovered and clicked()
    if pressed then DesirePro.spawn_particles(x + w / 2, y + h / 2, 22) end

    s.hov = DesirePro.ease_toggle(s, "hovE", hovered, 23)
    s.press = DesirePro.ease_toggle(s, "pressE", hovered and mouse_down(), 30)
    s.text = DesirePro.ease_toggle(s, "textE", hovered, 20)

    local sc = 1 - s.press * 0.08
    local aw, ah = w * sc, h * sc
    local bx, by = x + (w - aw) / 2, y + (h - ah) / 2

    ImGui.AddRectFilled(2, bx, by, aw, ah, DesirePro.col.anim_default, 6)
    local hv = s.hov; if hv > 1 then hv = 1 elseif hv < 0 then hv = 0 end
    if hv > 0.01 then
        local gw, gh = aw * hv, ah
        DesirePro.grad_rrect(2, bx + (aw - gw) / 2, by + (ah - gh) / 2, gw, gh, 6, DesirePro.col.dark, DesirePro.col.active)
    end
    local tcol = col_lerp_rgb(DesirePro.col.label, DesirePro.col.label_active, s.text)
    DesirePro.text_mid(2, x + w / 2, y + h / 2, DesirePro.translate(label), "poppins_semibold_17", tcol, 1)

    ctx.cy = ctx.cy + h + floor(9 * DesirePro.US)
    return pressed
end

function DesirePro.combo(ctx, label, items)
    local id = "co:" .. ctx.idp .. label
    local sel = var(id, 0)
    local s = widget_state(id, { lab = 0 })
    local h = floor(28 * DesirePro.US)
    local x0 = appear_xy(id, ctx, h)
    local y = ctx.cy
    local opened = (open_combo == id)
    local preview = DesirePro.translate(items[sel + 1] or "?")
    local pw = DesirePro.text_size(preview, "poppins_medium_16")
    local box_min = x0 + ctx.w - (pw + 55)
    local box_max = x0 + ctx.w
    local bw = box_max - box_min
    local mx, my = mouse_pos()
    local hovered = point_in_rect(mx, my, box_min, y, bw, h)
    if hovered and clicked() then
        open_combo = opened and nil or id
        opened = not opened
    end
    s.lab = DesirePro.anim(s.lab, hovered and 1 or 0, 12)
    s.open = DesirePro.anim(s.open or 0, opened and 1 or 0, 15)
    s.roll = DesirePro.anim(s.roll or 0, opened and 1 or 0, 6)
    local lcol = opened and DesirePro.col.label_active or (hovered and DesirePro.col.label_hover or DesirePro.col.label)

    DesirePro.text_in(2, x0, y, h, DesirePro.translate(label), "poppins_medium_16", lcol, 1)
    ImGui.AddRectFilled(2, box_min, y, bw, h, DesirePro.col.anim_default, 3)
    DesirePro.text_in(2, box_min + 10, y, h, preview, "poppins_medium_16", DesirePro.col.label_active, 1)

    local acx, acy = box_max - 14, y + h / 2
    local ang = s.roll * 3.14159
    local lx1, ly1 = rotate_point(acx, acy, acx - 4, acy - 2, ang)
    local lx2, ly2 = rotate_point(acx, acy, acx, acy + 3, ang)
    local lx3, ly3 = rotate_point(acx, acy, acx + 4, acy - 2, ang)
    ImGui.AddLine(2, lx1, ly1, lx2, ly2, DesirePro.col.label, 1.5)
    ImGui.AddLine(2, lx2, ly2, lx3, ly3, DesirePro.col.label, 1.5)

    if opened or s.open > 0.01 then
        local maxw = bw
