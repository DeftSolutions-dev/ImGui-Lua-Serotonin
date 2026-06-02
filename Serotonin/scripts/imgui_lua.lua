

print("[imgui_menu] script start")

local ImGui = {}
ImGui.VERSION = "0.1.0"

local floor, ceil, abs, min, max, sqrt = math.floor, math.ceil, math.abs, math.min, math.max, math.sqrt
local sin, cos, pi, huge = math.sin, math.cos, math.pi, math.huge
local format, sub, len, byte, char = string.format, string.sub, string.len, string.byte, string.char
local insert, remove, concat = table.insert, table.remove, table.concat
local Color3_fromRGB = Color3.fromRGB
local Color3_new = Color3.new

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function point_in_rect(px, py, rx, ry, rw, rh)
    return px >= rx and py >= ry and px < rx + rw and py < ry + rh
end

local g
local set_active_id
local clear_active_id

local function push_clip(x, y, w, h)
    insert(g.clip_stack, { x = x, y = y, w = w, h = h })
end
local function pop_clip()
    remove(g.clip_stack)
end
local function current_clip()
    local s = g.clip_stack[#g.clip_stack]
    if s then return s end
    return { x = -1e9, y = -1e9, w = 2e9, h = 2e9 }
end

local function clip_intersect(x, y, w, h, c)
    local x1 = (x > c.x) and x or c.x
    local y1 = (y > c.y) and y or c.y
    local x2 = (x + w < c.x + c.w) and (x + w) or (c.x + c.w)
    local y2 = (y + h < c.y + c.h) and (y + h) or (c.y + c.h)
    if x2 <= x1 or y2 <= y1 then return nil end
    return x1, y1, x2 - x1, y2 - y1
end

local function clip_line_cs(x1, y1, x2, y2, c)
    local cx1, cy1, cx2, cy2 = c.x, c.y, c.x + c.w, c.y + c.h
    local function code(x, y)
        local r = 0
        if x < cx1 then r = r + 1
        elseif x > cx2 then r = r + 2 end
        if y < cy1 then r = r + 4
        elseif y > cy2 then r = r + 8 end
        return r
    end
    local k1, k2 = code(x1, y1), code(x2, y2)
    for _ = 1, 8 do
        if bit.band(k1, k2) ~= 0 then return nil end
        if k1 == 0 and k2 == 0 then return x1, y1, x2, y2 end
        local out = (k1 ~= 0) and k1 or k2
        local nx, ny
        if bit.band(out, 8) ~= 0 then
            nx = x1 + (x2 - x1) * (cy2 - y1) / (y2 - y1); ny = cy2
        elseif bit.band(out, 4) ~= 0 then
            nx = x1 + (x2 - x1) * (cy1 - y1) / (y2 - y1); ny = cy1
        elseif bit.band(out, 2) ~= 0 then
            ny = y1 + (y2 - y1) * (cx2 - x1) / (x2 - x1); nx = cx2
        else
            ny = y1 + (y2 - y1) * (cx1 - x1) / (x2 - x1); nx = cx1
        end
        if out == k1 then x1, y1 = nx, ny; k1 = code(x1, y1)
        else x2, y2 = nx, ny; k2 = code(x2, y2) end
    end
    return nil
end

local function lerp(a, b, t) return a + (b - a) * t end

local function saturate(v) return clamp(v, 0, 1) end

local function round(v) return floor(v + 0.5) end

local function COL(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1 }
end

local function COL_RGBA(r, g, b, a)
    return { r = r / 255, g = g / 255, b = b / 255, a = (a or 255) / 255 }
end

local function col_mul_alpha(c, m)
    return { r = c.r, g = c.g, b = c.b, a = c.a * m }
end

local function col_lerp(a, b, t)
    return { r = lerp(a.r, b.r, t), g = lerp(a.g, b.g, t), b = lerp(a.b, b.b, t), a = lerp(a.a, b.a, t) }
end

local function to_draw(c)
    return Color3_fromRGB(round(saturate(c.r) * 255), round(saturate(c.g) * 255), round(saturate(c.b) * 255)),
           round(saturate(c.a) * 255)
end

local function hsv_to_rgb(h, s, v)
    if s <= 0 then return v, v, v end
    h = (h - floor(h)) * 6
    local i = floor(h)
    local f = h - i
    local p = v * (1 - s)
    local q = v * (1 - s * f)
    local t = v * (1 - s * (1 - f))
    if i == 0 then return v, t, p
    elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v
    else return v, p, q end
end

local function rgb_to_hsv(r, g, b)
    local mx = max(r, g, b)
    local mn = min(r, g, b)
    local d = mx - mn
    local h, s, v = 0, 0, mx
    if mx > 0 then s = d / mx end
    if d > 0 then
        if mx == r then h = ((g - b) / d) % 6
        elseif mx == g then h = (b - r) / d + 2
        else h = (r - g) / d + 4 end
        h = h / 6
        if h < 0 then h = h + 1 end
    end
    return h, s, v
end

local FNV_OFFSET = 2166136261
local FNV_PRIME  = 16777619
local function fnv1a(s, seed)
    local h = seed or FNV_OFFSET
    for i = 1, #s do
        h = bit.bxor(h, byte(s, i))
        h = bit.tobit(h * FNV_PRIME)
    end
    return h
end

