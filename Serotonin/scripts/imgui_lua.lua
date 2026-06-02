

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
    return Style.Colors[idx]
end
ImGui.GetStyleColor = StyleColor

function ImGui.PushStyleColor(idx, col)
    insert(g.color_stack, { idx = idx, col = col })
end

function ImGui.PopStyleColor(n)
    n = n or 1
    for i = 1, n do remove(g.color_stack) end
end

local draw_alpha_mul = 1
function ImGui.SetDrawAlpha(a) draw_alpha_mul = a or 1 end
function ImGui.GetDrawAlpha() return draw_alpha_mul end

local ui_scale, ui_px, ui_py = 1, 0, 0
function ImGui.SetUIScale(s, px, py)
    ui_scale = s or 1
    ui_px = px or 0
    ui_py = py or 0
end
function ImGui.GetUIScale() return ui_scale end

local function push_cmd(layer, cmd)

    cmd.amul = draw_alpha_mul
    local original_layer = layer
    if layer == 2 and #g.draw_layer_stack > 0 then
        layer = g.draw_layer_stack[#g.draw_layer_stack]
    end
    if original_layer == 2 then
        cmd.clip = g.clip_stack[#g.clip_stack]
    end
    if g.current_window then cmd.win_id = g.current_window.id end

    if ui_scale ~= 1 then
        local s, px, py = ui_scale, ui_px, ui_py
        if cmd.x then cmd.x = px + (cmd.x - px) * s end
        if cmd.y then cmd.y = py + (cmd.y - py) * s end
        if cmd.w then cmd.w = cmd.w * s end
        if cmd.h then cmd.h = cmd.h * s end
        if cmd.x1 then cmd.x1 = px + (cmd.x1 - px) * s end
        if cmd.y1 then cmd.y1 = py + (cmd.y1 - py) * s end
        if cmd.x2 then cmd.x2 = px + (cmd.x2 - px) * s end
        if cmd.y2 then cmd.y2 = py + (cmd.y2 - py) * s end
        if cmd.x3 then cmd.x3 = px + (cmd.x3 - px) * s end
        if cmd.y3 then cmd.y3 = py + (cmd.y3 - py) * s end
        if cmd.cx then cmd.cx = px + (cmd.cx - px) * s end
        if cmd.cy then cmd.cy = py + (cmd.cy - py) * s end
        if cmd.r then cmd.r = cmd.r * s end
        if cmd.rounding then cmd.rounding = cmd.rounding * s end
        if cmd.thick then cmd.thick = cmd.thick * s end
        if cmd.max_w then cmd.max_w = cmd.max_w * s end
        if cmd.clip then
            local c = cmd.clip
            cmd.clip = { x = px + (c.x - px) * s, y = py + (c.y - py) * s, w = c.w * s, h = c.h * s }
        end
    end

    insert(g.draw_layers[layer], cmd)
end

local function dr_rect_filled(layer, x, y, w, h, col, rounding)
    push_cmd(layer, { kind = "rectf", x = x, y = y, w = w, h = h, col = col, rounding = rounding or 0 })
end

local function dr_rect(layer, x, y, w, h, col, thick, rounding)
    push_cmd(layer, { kind = "rect", x = x, y = y, w = w, h = h, col = col, thick = thick or 1, rounding = rounding or 0 })
end

local function dr_line(layer, x1, y1, x2, y2, col, thick)
    push_cmd(layer, { kind = "line", x1 = x1, y1 = y1, x2 = x2, y2 = y2, col = col, thick = thick or 1 })
end

local function dr_text(layer, text, x, y, col, font)
    push_cmd(layer, { kind = "text", text = text, x = x, y = y, col = col, font = font or Style.Font })
end

local function dr_text_clip(layer, text, x, y, col, max_w, font)
    push_cmd(layer, { kind = "text_clip", text = text, x = x, y = y, col = col, max_w = max_w, font = font or Style.Font })
end

local function dr_triangle_filled(layer, x1, y1, x2, y2, x3, y3, col)
    push_cmd(layer, { kind = "trif", x1 = x1, y1 = y1, x2 = x2, y2 = y2, x3 = x3, y3 = y3, col = col })
end

local function dr_circle_filled(layer, cx, cy, r, col, segs)
    push_cmd(layer, { kind = "circf", cx = cx, cy = cy, r = r, col = col, segs = segs or 16 })
end

local function dr_gradient(layer, x, y, w, h, c1, c2, horizontal)
    push_cmd(layer, { kind = "grad", x = x, y = y, w = w, h = h, c1 = c1, c2 = c2, horiz = horizontal })
end

local function to_image_tint(col, alpha)

    return Color3_fromRGB(round(saturate(col.r) * 255), round(saturate(col.g) * 255), round(saturate(col.b) * 255)),
           round(saturate((col.a or 1) * (alpha or 1)) * 255)
end

local function dr_image(layer, x, y, w, h, texid, col, alpha)
    push_cmd(layer, { kind = "image", x = x, y = y, w = w, h = h, texid = texid,
                      col = col or COL(1, 1, 1, 1), alpha = alpha or 1 })
end

function ImGui.AddRectFilled(layer, x, y, w, h, col, rounding) dr_rect_filled(layer or 2, x, y, w, h, col, rounding) end
function ImGui.AddRect(layer, x, y, w, h, col, thick, rounding) dr_rect(layer or 2, x, y, w, h, col, thick, rounding) end
function ImGui.AddLine(layer, x1, y1, x2, y2, col, thick) dr_line(layer or 2, x1, y1, x2, y2, col, thick) end
function ImGui.AddGradient(layer, x, y, w, h, c1, c2, horiz) dr_gradient(layer or 2, x, y, w, h, c1, c2, horiz) end
function ImGui.AddCircleFilled(layer, cx, cy, r, col, segs) dr_circle_filled(layer or 2, cx, cy, r, col, segs) end
function ImGui.AddTriangleFilled(layer, x1, y1, x2, y2, x3, y3, col) dr_triangle_filled(layer or 2, x1, y1, x2, y2, x3, y3, col) end
function ImGui.AddImage(layer, x, y, w, h, texid, col, alpha) dr_image(layer or 2, x, y, w, h, texid, col, alpha) end

function ImGui.RGBA(r, g, b, a) return COL_RGBA(r, g, b, a) end
function ImGui.ColF(r, g, b, a) return COL(r, g, b, a) end
function ImGui.GetScreenSize() return draw.GetScreenSize() end

local function text_size(s, font)
    font = font or Style.Font
    if type(s) ~= "string" then s = tostring(s) end
    local ok, w, h = pcall(draw.GetTextSize, s, font)
    if ok and type(w) == "number" then return w, h or Style.FontHeight end

    return #s * 7, Style.FontHeight
end
ImGui.CalcTextSize = text_size

set_active_id = function(id, win, rect)
    g.active_id = id
    g.active_id_window = win
    g.active_id_was_just_activated = true
    if rect then
        g.active_id_rect = { x = rect.x, y = rect.y, w = rect.w, h = rect.h }
    else
        g.active_id_rect = nil
    end
end

clear_active_id = function()
    g.active_id = nil
    g.active_id_window = nil
    g.active_id_rect = nil
end

local function ItemHoverable(x, y, w, h, id)
    if not g.menu_open then return false end
    if g._disabled_depth and g._disabled_depth > 0 then return false end

    if g.current_window and g.hovered_window_id
       and g.current_window.id ~= g.hovered_window_id
       and not g.current_window._is_popup
       and not g.current_window._is_tooltip then
        return false
    end

    if g.popup_active_prev and g.popup_rect_prev then
        local p = g.popup_rect_prev
        local mouse_in_popup = (g.mouse_x >= p.x and g.mouse_x < p.x + p.w
                            and g.mouse_y >= p.y and g.mouse_y < p.y + p.h)
        if mouse_in_popup then
            local fully_inside = (x >= p.x and y >= p.y
                              and x + w <= p.x + p.w and y + h <= p.y + p.h)
            if not fully_inside then return false end
        else
            local overlaps = (x < p.x + p.w and x + w > p.x
                          and y < p.y + p.h and y + h > p.y)
            if overlaps then return false end
        end
    end
    if not point_in_rect(g.mouse_x, g.mouse_y, x, y, w, h) then return false end
    if g.mouse_left_clicked and g.active_id ~= nil and g.active_id ~= id then
        clear_active_id()
    end
    if g.active_id ~= nil and g.active_id ~= id then return false end
    g.hovered_id = id
    return true
end

local function ButtonBehavior(x, y, w, h, id)
    local hovered = ItemHoverable(x, y, w, h, id)
    local pressed = false
    local held = false
    if hovered and g.mouse_left_clicked then
        set_active_id(id, g.current_window, { x = x, y = y, w = w, h = h })
    end
    if g.active_id == id then
        held = g.mouse_left_down
        if g.mouse_left_released then
            if hovered then pressed = true end
            clear_active_id()
        end
    end
    return pressed, hovered, held
end
ImGui.ButtonBehavior = ButtonBehavior

local function anim_get(win, id)
    if not win then return 0 end
    local s = g.storage[win.id]; if not s then return 0 end
    return s["anim_" .. tostring(id)] or 0
end
local function anim_set(win, id, v)
    if not win then return end
    g.storage[win.id] = g.storage[win.id] or {}
    g.storage[win.id]["anim_" .. tostring(id)] = v
end

local function anim_step(win, id, target, speed)
    speed = speed or 12
    local cur = anim_get(win, id)
    local dt  = g.dt or 0.016
    cur = cur + (target - cur) * min(1, dt * speed)
    anim_set(win, id, cur)
    return cur
end

local function record_item(id, x, y, w, h, hovered, clicked, active)
    g.last_item_id = id
    local r = g.last_item_rect
    r.x, r.y, r.w, r.h = x, y, w, h
    g.last_item_hovered = hovered
    g.last_item_clicked = clicked
    g.last_item_active  = active
end

function ImGui.IsItemHovered() return g.last_item_hovered end
function ImGui.IsItemClicked() return g.last_item_clicked end
function ImGui.IsItemActive()  return g.last_item_active end
function ImGui.IsItemFocused() return g.last_item_id == g.active_id and g.active_id ~= nil end
function ImGui.IsAnyItemActive() return g.active_id ~= nil end
function ImGui.IsItemDeactivated()
    return g.last_item_id == g.hovered_id_prev and g.last_item_id ~= g.active_id
end
function ImGui.IsItemActivated()
    return g.last_item_id == g.active_id and g.active_id_was_just_activated
end
function ImGui.IsItemToggledOpen()

    return g._toggled_id == g.last_item_id
end
function ImGui.IsItemEdited()

    return g.last_item_clicked
end

function ImGui.IsWindowHovered()
    local win = g.current_window; if not win then return false end
    return point_in_rect(g.mouse_x, g.mouse_y, win.x, win.y, win.w, win.h)
end
function ImGui.IsWindowFocused()
    local win = g.current_window; if not win then return false end
    local last = g.windows_z_order[#g.windows_z_order]
    return last == win.id
end

function ImGui.GetMousePos()
    if ui_scale ~= 1 then
        return ui_px + (g.mouse_x - ui_px) / ui_scale, ui_py + (g.mouse_y - ui_py) / ui_scale
    end
    return g.mouse_x, g.mouse_y
end
function ImGui.GetMouseDelta()
    if ui_scale ~= 1 then return g.mouse_dx / ui_scale, g.mouse_dy / ui_scale end
    return g.mouse_dx, g.mouse_dy
end
function ImGui.IsMouseDown()       return g.mouse_left_down end
function ImGui.IsMouseClicked()    return g.mouse_left_clicked end
function ImGui.IsMouseReleased()   return g.mouse_left_released end
function ImGui.IsMouseRightClicked() return g.mouse_right_clicked end
function ImGui.IsMouseRightDown()  return g.mouse_right_down_prev end
function ImGui.GetTime()           return g.time end
function ImGui.GetDeltaTime()      return g.dt end
function ImGui.GetFrameCount()     return g.frame_count end
function ImGui.GetItemRectMin()
    local r = g.last_item_rect; return r.x, r.y
end
function ImGui.GetItemRectMax()
    local r = g.last_item_rect; return r.x + r.w, r.y + r.h
end
function ImGui.GetItemRectSize()
    local r = g.last_item_rect; return r.w, r.h
end

local function focus_window(win)

    for i, wid in ipairs(g.windows_z_order) do
        if wid == win.id then remove(g.windows_z_order, i); break end
    end
    insert(g.windows_z_order, win.id)
end

local function get_or_create_window(id, title)
    local w = g.windows[id]
    if w then return w end
    w = {
        id           = id,
        title        = title,
        x            = 60 + (#g.windows_order * 24),
        y            = 60 + (#g.windows_order * 24),
        w            = 320,
        h            = 240,
        collapsed    = false,
        scroll_y     = 0,
        scroll_max_y = 0,
        cursor_x     = 0,
        cursor_y     = 0,
        cursor_start_x = 0,
        cursor_start_y = 0,
        cursor_max_x = 0,
        cursor_max_y = 0,
        line_h       = Style.FontHeight,
        prev_line_h  = Style.FontHeight,
        indent_x     = 0,
        content_w    = 0,
        content_h    = 0,
        active       = false,
        opened       = true,
        flags        = {},
        groups       = {},
    }
    g.windows[id] = w
    insert(g.windows_order, id)
    insert(g.windows_z_order, id)
    g.storage[id] = g.storage[id] or {}

    if g._pending_window_settings and g._pending_window_settings[title] then
        local p = g._pending_window_settings[title]
        if p.x then w.x = p.x end
        if p.y then w.y = p.y end
        if p.w then w.w = p.w end
        if p.h then w.h = p.h end
        if p.collapsed ~= nil then w.collapsed = p.collapsed end
        g._pending_window_settings[title] = nil
    end
    return w
end

local function store_get(win, key, default_v)
    local s = g.storage[win.id]
    local v = s[key]
    if v == nil then return default_v end
    return v
end

local function store_set(win, key, value)
    g.storage[win.id][key] = value
end
ImGui._store_get = store_get
ImGui._store_set = store_set

function ImGui.SetNextWindowPos(x, y, cond)
    g.next_window_pos = { x = x, y = y, cond = cond or "always" }
end
function ImGui.SetNextWindowSize(w, h, cond)
    g.next_window_size = { w = w, h = h, cond = cond or "always" }
end
function ImGui.SetNextWindowCollapsed(b, cond)
    g.next_window_collapsed = { value = b, cond = cond or "always" }
end
function ImGui.SetNextWindowFocus() g.next_window_focus = true end

function ImGui.Begin(title, opts_or_p_open, maybe_opts)

    local p_open, opts
    if type(opts_or_p_open) == "boolean" or opts_or_p_open == nil and type(maybe_opts) == "table" then
        p_open, opts = opts_or_p_open, maybe_opts or {}
    elseif type(opts_or_p_open) == "table" then
        p_open, opts = nil, opts_or_p_open
    else
        opts = {}
    end
    local id = fnv1a(title)
    local win = get_or_create_window(id, title)
    win.flags = opts
    win.title = title
    win._has_close = (p_open ~= nil)

    win._close_clicked = false

    local first_use = not win._created
    win._created = true
    if g.next_window_pos then
        local h = g.next_window_pos
        if h.cond == "always" or first_use then win.x, win.y = h.x, h.y end
        g.next_window_pos = nil
    end
    if g.next_window_size then
        local h = g.next_window_size
        if h.cond == "always" or first_use then win.w, win.h = h.w, h.h end
        g.next_window_size = nil
    end
    if g.next_window_collapsed then
        local h = g.next_window_collapsed
        if h.cond == "always" or first_use then win.collapsed = h.value end
        g.next_window_collapsed = nil
    end

    g.current_window = win
    insert(g.window_stack, win)

    win._id_stack_save = #g.id_stack
    insert(g.id_stack, "win:" .. tostring(id))

    local title_h = (opts.no_title and 0) or Style.WindowTitleHeight

    if not opts.no_title then
        local tx, ty, tw, th = win.x, win.y, win.w, title_h
        local close_reserve  = win._has_close and 22 or 0

        local arrow_id = fnv1a("collapse", id)
        local ax, ay, aw, ah = tx + 4, ty + 3, 16, 16
        local pressed_arrow, hov_arrow = ButtonBehavior(ax, ay, aw, ah, arrow_id)
        if pressed_arrow then win.collapsed = not win.collapsed end

        if not opts.no_move then
            local drag_id = fnv1a("titlebar", id)
            local dx, dy, dw, dh = tx + 20, ty, tw - 20 - close_reserve, th
            local _, hov, held = ButtonBehavior(dx, dy, dw, dh, drag_id)
            if held then
                win.x = win.x + g.mouse_dx
                win.y = win.y + g.mouse_dy
            end
        end

        if win._has_close then
            local close_id = fnv1a("close", id)
            local cx = tx + tw - 14
            local cy = ty + th * 0.5
            local cb_pressed, cb_hov = ButtonBehavior(cx - 7, cy - 7, 14, 14, close_id)
            local lc = cb_hov and StyleColor(Col.ButtonHovered) or StyleColor(Col.Text)

            dr_line(2, cx - 4, cy - 4, cx + 4, cy + 4, lc, 2)
            dr_line(2, cx + 4, cy - 4, cx - 4, cy + 4, lc, 2)
            if cb_pressed then win._close_clicked = true end
        end
    end

    if not opts.no_resize and not win.collapsed then
        local grip_size = 14
        local hot       = 4

        local rid_r = fnv1a("resize_r", id)
        local _, _, held_r = ButtonBehavior(
            win.x + win.w - hot, win.y + title_h,
            hot, win.h - title_h - grip_size, rid_r)
        if held_r then
            win.w = max(Style.WindowMinSize.x, win.w + g.mouse_dx)
        end

        local bid = fnv1a("resize_b", id)
        local _, _, held_b = ButtonBehavior(
            win.x, win.y + win.h - hot,
            win.w - grip_size, hot, bid)
        if held_b then
            win.h = max(Style.WindowMinSize.y, win.h + g.mouse_dy)
        end

        local rid = fnv1a("resize", id)
        local rx = win.x + win.w - grip_size
        local ry = win.y + win.h - grip_size
        local _, hov, held = ButtonBehavior(rx, ry, grip_size, grip_size, rid)
        if held then
            win.w = max(Style.WindowMinSize.x, win.w + g.mouse_dx)
            win.h = max(Style.WindowMinSize.y, win.h + g.mouse_dy)
        end
        win._grip_hovered = hov
        win._grip_held = held
    end

    if not opts.no_scroll and not win.collapsed then
        local ok_ctrl, ctrl_held = pcall(keyboard.IsPressed, "Control")
        ctrl_held = ok_ctrl and ctrl_held or false
        if ctrl_held then
            local cs_id = fnv1a("ctrl_scroll", id)
            local _, hov, held = ButtonBehavior(win.x, win.y + title_h,
                                                win.w, win.h - title_h, cs_id)
            if held then
                win.scroll_y = (win.scroll_y or 0) - g.mouse_dy
            end
        end
    end

    local target_ct = win.collapsed and 1 or 0
    win._collapse_t = win._collapse_t or target_ct
    local _dt = g.dt or 0.016
    win._collapse_t = win._collapse_t + (target_ct - win._collapse_t) * min(1, _dt * 14)
    if abs(win._collapse_t - target_ct) < 0.005 then win._collapse_t = target_ct end
    local body_full_h = max(0, win.h - title_h)
    local body_anim_h = body_full_h * (1 - win._collapse_t)
    local effective_h = title_h + body_anim_h
    win._effective_h  = effective_h

    local bg_col = StyleColor(Col.WindowBg)
    if not opts.no_bg and body_anim_h > 0 then
        dr_rect_filled(1, win.x, win.y + title_h, win.w, body_anim_h, bg_col, Style.WindowRounding)
    end
    if not opts.no_title then
        local title_col = (win == g.window_stack[#g.window_stack]) and StyleColor(Col.TitleBgActive) or StyleColor(Col.TitleBg)
        if win.collapsed then title_col = StyleColor(Col.TitleBgCollapsed) end
        dr_rect_filled(1, win.x, win.y, win.w, title_h, title_col, Style.WindowRounding)

        local ax, ay = win.x + 8, win.y + title_h * 0.5
        local arrow_col = StyleColor(Col.Text)
        if win.collapsed then

            dr_triangle_filled(2, ax, ay - 4, ax, ay + 4, ax + 6, ay, arrow_col)
        else
            dr_triangle_filled(2, ax - 3, ay - 2, ax + 5, ay - 2, ax + 1, ay + 4, arrow_col)
        end

        dr_text(2, title, win.x + 22, win.y + (title_h - Style.FontHeight) * 0.5, StyleColor(Col.Text))
    end
    if Style.WindowBorderSize > 0 and not opts.no_bg then
        dr_rect(3, win.x, win.y, win.w, effective_h, StyleColor(Col.Border), Style.WindowBorderSize, Style.WindowRounding)
    end

    local pad = Style.WindowPadding

    local sb_reserve = Style.ScrollbarSize
    win.cursor_start_x = win.x + pad.x
    win.cursor_start_y = win.y + title_h + pad.y - win.scroll_y
    win.cursor_x       = win.cursor_start_x
    win.cursor_y       = win.cursor_start_y
    win.cursor_max_x   = win.cursor_start_x
    win.cursor_max_y   = win.cursor_start_y
    win.line_h         = Style.FontHeight
    win.prev_line_h    = Style.FontHeight
    win.indent_x       = 0
    win._title_h       = title_h
    win._content_x0    = win.x + pad.x
    win._content_y0    = win.y + title_h + pad.y
    win._content_x1    = win.x + win.w - pad.x - sb_reserve

    win._content_y1    = win.y + effective_h - pad.y
