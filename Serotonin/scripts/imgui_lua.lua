

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

local Col = {}
local C_NAMES = {
    "Text","TextDisabled","WindowBg","ChildBg","PopupBg","Border","BorderShadow",
    "FrameBg","FrameBgHovered","FrameBgActive","TitleBg","TitleBgActive","TitleBgCollapsed",
    "MenuBarBg","ScrollbarBg","ScrollbarGrab","ScrollbarGrabHovered","ScrollbarGrabActive",
    "CheckMark","SliderGrab","SliderGrabActive","Button","ButtonHovered","ButtonActive",
    "Header","HeaderHovered","HeaderActive","Separator","SeparatorHovered","SeparatorActive",
    "ResizeGrip","ResizeGripHovered","ResizeGripActive","Tab","TabHovered","TabActive",
    "TabUnfocused","TabUnfocusedActive","PlotLines","PlotLinesHovered","PlotHistogram",
    "PlotHistogramHovered","TableHeaderBg","TableBorderStrong","TableBorderLight",
    "TableRowBg","TableRowBgAlt","TextSelectedBg","DragDropTarget","NavHighlight",
    "ModalWindowDimBg",
}
for i, n in ipairs(C_NAMES) do Col[n] = i end
ImGui.Col = Col

local function default_dark_theme()
    local t = {}
    t[Col.Text]                  = COL(1.00, 1.00, 1.00, 1.00)
    t[Col.TextDisabled]          = COL(0.50, 0.50, 0.50, 1.00)
    t[Col.WindowBg]              = COL(0.06, 0.06, 0.06, 0.94)
    t[Col.ChildBg]               = COL(0.00, 0.00, 0.00, 0.00)
    t[Col.PopupBg]               = COL(0.08, 0.08, 0.08, 0.94)
    t[Col.Border]                = COL(0.43, 0.43, 0.50, 0.50)
    t[Col.BorderShadow]          = COL(0.00, 0.00, 0.00, 0.00)
    t[Col.FrameBg]               = COL(0.16, 0.29, 0.48, 0.54)
    t[Col.FrameBgHovered]        = COL(0.26, 0.59, 0.98, 0.40)
    t[Col.FrameBgActive]         = COL(0.26, 0.59, 0.98, 0.67)
    t[Col.TitleBg]               = COL(0.04, 0.04, 0.04, 1.00)
    t[Col.TitleBgActive]         = COL(0.16, 0.29, 0.48, 1.00)
    t[Col.TitleBgCollapsed]      = COL(0.00, 0.00, 0.00, 0.51)
    t[Col.MenuBarBg]             = COL(0.14, 0.14, 0.14, 1.00)
    t[Col.ScrollbarBg]           = COL(0.02, 0.02, 0.02, 0.85)
    t[Col.ScrollbarGrab]         = COL(0.45, 0.45, 0.45, 1.00)
    t[Col.ScrollbarGrabHovered]  = COL(0.55, 0.55, 0.55, 1.00)
    t[Col.ScrollbarGrabActive]   = COL(0.70, 0.70, 0.70, 1.00)
    t[Col.CheckMark]             = COL(0.26, 0.59, 0.98, 1.00)
    t[Col.SliderGrab]            = COL(0.24, 0.52, 0.88, 1.00)
    t[Col.SliderGrabActive]      = COL(0.26, 0.59, 0.98, 1.00)
    t[Col.Button]                = COL(0.26, 0.59, 0.98, 0.40)
    t[Col.ButtonHovered]         = COL(0.26, 0.59, 0.98, 1.00)
    t[Col.ButtonActive]          = COL(0.06, 0.53, 0.98, 1.00)
    t[Col.Header]                = COL(0.26, 0.59, 0.98, 0.31)
    t[Col.HeaderHovered]         = COL(0.26, 0.59, 0.98, 0.80)
    t[Col.HeaderActive]          = COL(0.26, 0.59, 0.98, 1.00)
    t[Col.Separator]             = COL(0.43, 0.43, 0.50, 0.50)
    t[Col.SeparatorHovered]      = COL(0.10, 0.40, 0.75, 0.78)
    t[Col.SeparatorActive]       = COL(0.10, 0.40, 0.75, 1.00)
    t[Col.ResizeGrip]            = COL(0.26, 0.59, 0.98, 0.20)
    t[Col.ResizeGripHovered]     = COL(0.26, 0.59, 0.98, 0.67)
    t[Col.ResizeGripActive]      = COL(0.26, 0.59, 0.98, 0.95)
    t[Col.Tab]                   = COL(0.18, 0.35, 0.58, 0.86)
    t[Col.TabHovered]            = COL(0.26, 0.59, 0.98, 0.80)
    t[Col.TabActive]             = COL(0.20, 0.41, 0.68, 1.00)
    t[Col.TabUnfocused]          = COL(0.07, 0.10, 0.15, 0.97)
    t[Col.TabUnfocusedActive]    = COL(0.14, 0.26, 0.42, 1.00)
    t[Col.PlotLines]             = COL(0.61, 0.61, 0.61, 1.00)
    t[Col.PlotLinesHovered]      = COL(1.00, 0.43, 0.35, 1.00)
    t[Col.PlotHistogram]         = COL(0.90, 0.70, 0.00, 1.00)
    t[Col.PlotHistogramHovered]  = COL(1.00, 0.60, 0.00, 1.00)
    t[Col.TableHeaderBg]         = COL(0.19, 0.19, 0.20, 1.00)
    t[Col.TableBorderStrong]     = COL(0.31, 0.31, 0.35, 1.00)
    t[Col.TableBorderLight]      = COL(0.23, 0.23, 0.25, 1.00)
    t[Col.TableRowBg]            = COL(0.00, 0.00, 0.00, 0.00)
    t[Col.TableRowBgAlt]         = COL(1.00, 1.00, 1.00, 0.06)
    t[Col.TextSelectedBg]        = COL(0.26, 0.59, 0.98, 0.35)
    t[Col.DragDropTarget]        = COL(1.00, 1.00, 0.00, 0.90)
    t[Col.NavHighlight]          = COL(0.26, 0.59, 0.98, 1.00)
    t[Col.ModalWindowDimBg]      = COL(0.80, 0.80, 0.80, 0.35)
    return t
end

local Style = {
    Alpha               = 1.0,
    WindowPadding       = { x = 8,  y = 8  },
    WindowRounding      = 0,
    WindowBorderSize    = 1,
    WindowMinSize       = { x = 80, y = 60 },
    WindowTitleHeight   = 22,
    FramePadding        = { x = 4,  y = 3  },
    FrameRounding       = 0,
    FrameBorderSize     = 0,
    ItemSpacing         = { x = 8,  y = 4  },
    ItemInnerSpacing    = { x = 4,  y = 4  },
    IndentSpacing       = 21,
    ScrollbarSize       = 16,
    ScrollbarRounding   = 9,
    GrabMinSize         = 12,
    GrabRounding        = 0,
    TabRounding         = 4,
    PopupRounding       = 0,
    PopupBorderSize     = 1,
    CellPadding         = { x = 4, y = 2 },
    Font                = "Verdana",
    FontHeight          = 14,
    Colors              = default_dark_theme(),
}
ImGui.Style = Style

g = {

    frame_count       = 0,
    time              = 0,
    dt                = 0,

    mouse_x           = 0,
    mouse_y           = 0,
    mouse_dx          = 0,
    mouse_dy          = 0,
    mouse_left_down   = false,
    mouse_left_clicked= false,
    mouse_left_released = false,
    mouse_left_down_prev = false,
    mouse_wheel       = 0,

    key_states        = {},
    key_states_prev   = {},
    chars_queue       = {},

    id_stack          = {},
    last_item_id      = nil,
    last_item_rect    = { x = 0, y = 0, w = 0, h = 0 },
    last_item_hovered = false,
    last_item_clicked = false,
    last_item_active  = false,

    hovered_id        = nil,
    hovered_id_prev   = nil,
    active_id         = nil,
    active_id_window  = nil,
    active_id_rect    = nil,
    active_id_was_just_activated = false,

    clip_stack        = {},

    popup_active      = false,
    popup_rect        = nil,
    popup_active_prev = false,
    popup_rect_prev   = nil,

    popup_stack       = {},
    popup_pending_open= nil,

    draw_layer_stack  = {},

    windows           = {},
    windows_order     = {},
    windows_z_order   = {},
    current_window    = nil,
    window_stack      = {},

    storage           = {},

    next_window_pos        = nil,
    next_window_size       = nil,
    next_window_collapsed  = nil,
    next_window_focus      = false,

    color_stack       = {},

    open_popup        = nil,

    draw_layers       = { {}, {}, {}, {}, {}, {} },

    menu_open         = true,
    toggle_key        = "F8",
    toggle_key_prev   = false,

    user_setup_fn     = nil,

    registered        = false,

    mouse_down_probe  = nil,
}
ImGui._g = g

local MOUSE_DOWN_CANDIDATES = {
    "MouseLeft", "Mouse1", "MOUSE1", "LeftMouse", "LMB", "lmb", "mouse_left",
    "VK_LBUTTON", 1, 0x01,
}
local MOUSE_RDOWN_CANDIDATES = {
    "MouseRight", "Mouse2", "MOUSE2", "RightMouse", "RMB", "rmb", "mouse_right",
    "VK_RBUTTON", 2, 0x02,
}
local _working_mouse_probe   = nil
local _working_rmouse_probe  = nil

local function check_mouse_down_now()
    if _working_mouse_probe ~= nil then
        local ok, v = pcall(keyboard.IsPressed, _working_mouse_probe)
        return ok and v or false
    end
    for _, cand in ipairs(MOUSE_DOWN_CANDIDATES) do
        local ok, v = pcall(keyboard.IsPressed, cand)
        if ok and v == true then
            _working_mouse_probe = cand
            print("[imgui_lua] mouse-down probe locked: " .. tostring(cand))
            return true
        end
    end
    return false
end

local function check_rmouse_down_now()
    if _working_rmouse_probe ~= nil then
        local ok, v = pcall(keyboard.IsPressed, _working_rmouse_probe)
        return ok and v or false
    end
    for _, cand in ipairs(MOUSE_RDOWN_CANDIDATES) do
        local ok, v = pcall(keyboard.IsPressed, cand)
        if ok and v == true then
            _working_rmouse_probe = cand
            print("[imgui_lua] rmouse-down probe locked: " .. tostring(cand))
            return true
        end
    end
    return false
end

local function update_io()

    local pos = utility.GetMousePos()
    local mx, my
    if type(pos) == "table" then
        mx = pos[1] or pos.x or 0
        my = pos[2] or pos.y or 0
    else
        mx, my = 0, 0
    end
    g.mouse_dx = mx - g.mouse_x
    g.mouse_dy = my - g.mouse_y
    g.mouse_x = mx
    g.mouse_y = my

    local just_clicked = false
    local ok_click, clicked = pcall(mouse.IsClicked, "left")
    if ok_click and clicked then just_clicked = true end

    local r_now = check_rmouse_down_now()
    local ok_r, r_click_api = pcall(mouse.IsClicked, "right")
    if ok_r and r_click_api then r_now = true end
    g.mouse_right_clicked = r_now and not g.mouse_right_down_prev
    g.mouse_right_down_prev = r_now

    g.mouse_left_down_prev = g.mouse_left_down

    local probe_down = check_mouse_down_now()
    g.mouse_left_down = probe_down or just_clicked
    g.mouse_left_clicked  = (not g.mouse_left_down_prev) and g.mouse_left_down
    g.mouse_left_released = g.mouse_left_down_prev and (not g.mouse_left_down)

    g.hovered_window_id = nil
    for i = #g.windows_z_order, 1, -1 do
        local wid = g.windows_z_order[i]
        local w   = g.windows[wid]
        if w and point_in_rect(g.mouse_x, g.mouse_y, w.x, w.y, w.w, w.h) then
            g.hovered_window_id = wid
            break
        end
    end

    if g.mouse_left_clicked and not g.popup_active_prev and g.hovered_window_id then
        for i = #g.windows_z_order, 1, -1 do
            if g.windows_z_order[i] == g.hovered_window_id then
                if i ~= #g.windows_z_order then
                    remove(g.windows_z_order, i)
                    insert(g.windows_z_order, g.hovered_window_id)
                end
                break
            end
        end
    end

    if g.mouse_left_clicked and g.active_id and g.active_id_rect then
        local r = g.active_id_rect
        if not point_in_rect(g.mouse_x, g.mouse_y, r.x, r.y, r.w, r.h) then
            clear_active_id()
        end
    end

    if g.popup_active_prev and g.popup_rect_prev and g.active_id and g.active_id_rect then
        local r, p = g.active_id_rect, g.popup_rect_prev
        local mouse_in_popup = (g.mouse_x >= p.x and g.mouse_x < p.x + p.w
                            and g.mouse_y >= p.y and g.mouse_y < p.y + p.h)
        local clear = false
        if mouse_in_popup then
            local fully_inside = (r.x >= p.x and r.y >= p.y
                              and r.x + r.w <= p.x + p.w and r.y + r.h <= p.y + p.h)
            if not fully_inside then clear = true end
        else
            local overlaps = (r.x < p.x + p.w and r.x + r.w > p.x
                          and r.y < p.y + p.h and r.y + r.h > p.y)
            if overlaps then clear = true end
        end
        if clear then clear_active_id() end
    end

    local ok_tk, tk = pcall(keyboard.IsPressed, g.toggle_key)
    tk = ok_tk and tk or false
    if tk and not g.toggle_key_prev then
        g.menu_open = not g.menu_open
    end
    g.toggle_key_prev = tk

    local function any_pressed(names)
        for _, k in ipairs(names) do
            local ok, v = pcall(keyboard.IsPressed, k)
            if ok and v then return true end
        end
        return false
    end
    local u = any_pressed({ "PageUp",   "PgUp", "Prior", 0x21 })
    local d = any_pressed({ "PageDown", "PgDn", "Next",  0x22 })
    g._pg_up_edge   = u and not g._pg_up_prev
    g._pg_down_edge = d and not g._pg_down_prev
    g._pg_up_prev, g._pg_down_prev = u, d

    g.mouse_wheel = g.mouse_wheel or 0
    local ok_w, content = pcall(file.read, "wheel.txt")
    if ok_w and type(content) == "string" and #content > 0 then
        local delta = 0
        for line in content:gmatch("[^\r\n]+") do
            local d2 = tonumber(line)
            if d2 then delta = delta + d2 end
        end
        if delta ~= 0 then g.mouse_wheel = g.mouse_wheel + delta end
        pcall(file.write, "wheel.txt", "")
    end

    local function probe(name)
        local ok, v = pcall(keyboard.IsPressed, name); return ok and v
    end
    local function probe_any(names)
        for _, n in ipairs(names) do if probe(n) then return true end end
        return false
    end
    local nav_blocked = g._input_text_active or false
    local tab_now   = (not nav_blocked) and probe_any({ "Tab", "TAB", 0x09 })
    local shift_now = probe("Shift")
    g.nav_dir = 0
    if tab_now and not g._tab_prev then
        g.nav_dir = shift_now and -1 or 1
    end
    g._tab_prev = tab_now
    if g.nav_dir ~= 0 and g.focus_list_prev and #g.focus_list_prev > 0 then
        local idx = 0
        for i, id in ipairs(g.focus_list_prev) do
            if id == g.nav_id then idx = i; break end
        end
        idx = idx + g.nav_dir
        if idx < 1                  then idx = #g.focus_list_prev end
        if idx > #g.focus_list_prev then idx = 1 end
        g.nav_id = g.focus_list_prev[idx]
    end
    local act_now = (not nav_blocked) and probe_any({ "Enter", "Return", 0x0D, "Space", 0x20 })
    g.nav_activate  = act_now and not g._nav_act_prev
    g._nav_act_prev = act_now

    local dt = utility.GetDeltaTime()
    g.dt = dt or 0
    g.time = g.time + g.dt
    g.frame_count = g.frame_count + 1
end

local function GetID(label)

    local seed = FNV_OFFSET
    local stack = g.id_stack
    for i = 1, #stack do
        seed = fnv1a(tostring(stack[i]), seed)
    end
    return fnv1a(tostring(label), seed)
end
ImGui.GetID = GetID

function ImGui.PushID(v)
    insert(g.id_stack, v)
end

function ImGui.PopID()
    remove(g.id_stack)
end

local function StyleColor(idx)

    for i = #g.color_stack, 1, -1 do
        local s = g.color_stack[i]
        if s.idx == idx then return s.col end
    end
