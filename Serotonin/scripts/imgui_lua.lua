

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
