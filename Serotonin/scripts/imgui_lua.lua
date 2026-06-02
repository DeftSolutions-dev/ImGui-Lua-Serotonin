

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
    win._inner_x0      = win.x
    win._inner_y0      = win.y + title_h
    win._inner_x1      = win.x + win.w
    win._inner_y1      = win.y + effective_h

    local out_open
    if p_open ~= nil then out_open = p_open and not win._close_clicked end

    if win.collapsed and win._collapse_t > 0.99 then
        if p_open ~= nil then return false, out_open end
        return false
    end

    push_clip(win._content_x0, win._content_y0,
              win._content_x1 - win._content_x0,
              win._content_y1 - win._content_y0)

    if not opts.no_resize then
        local gs = 14
        local gx = win.x + win.w
        local gy = win.y + win.h
        local grip_col = StyleColor(Col.ResizeGrip)
        if win._grip_held then grip_col = StyleColor(Col.ResizeGripActive)
        elseif win._grip_hovered then grip_col = StyleColor(Col.ResizeGripHovered) end
        dr_triangle_filled(3, gx - gs, gy, gx, gy - gs, gx, gy, grip_col)
    end

    if p_open ~= nil then return true, out_open end
    return true
end

local render_scrollbar
local open_popup_window

function ImGui.End()
    local win = g.current_window
    if not win then return end

    win.content_w = win.cursor_max_x - win.cursor_start_x
    win.content_h = win.cursor_max_y - win.cursor_start_y

    if win.flags and win.flags.auto_resize then
        local pad = Style.WindowPadding
        local title_h = win._title_h or 0
        win.w = max(Style.WindowMinSize.x,
                    (win.cursor_max_x - win.x) + pad.x + Style.ScrollbarSize)
        win.h = max(Style.WindowMinSize.y,
                    (win.cursor_max_y - win.y) + pad.y)
    end

    local visible_h = win.h - win._title_h - Style.WindowPadding.y * 2
    win.scroll_max_y = max(0, win.content_h - visible_h)
    win.scroll_y = clamp(win.scroll_y, 0, win.scroll_max_y)

    if not win.collapsed then pop_clip() end

    render_scrollbar(win)

    while #g.id_stack > win._id_stack_save do remove(g.id_stack) end
    remove(g.window_stack)
    g.current_window = g.window_stack[#g.window_stack]
end

local function ItemSize(w, h)
    local win = g.current_window
    if not win then return end

    g.last_item_rect.x = win.cursor_x
    g.last_item_rect.y = win.cursor_y
    g.last_item_rect.w = w
    g.last_item_rect.h = h
    win.line_h   = max(win.line_h, h)
    win.cursor_max_x = max(win.cursor_max_x, win.cursor_x + w)
    win.cursor_max_y = max(win.cursor_max_y, win.cursor_y + win.line_h)
    win.prev_line_h  = win.line_h
    win.cursor_x = win.cursor_start_x + win.indent_x
    win.cursor_y = win.cursor_y + win.line_h + Style.ItemSpacing.y
    win.line_h   = Style.FontHeight
end
ImGui._ItemSize = ItemSize

local function ItemAdd(x, y, w, h)
    local win = g.current_window
    if not win then return false end
    if y + h < win._inner_y0 then return false end
    if y > win._inner_y1 then return false end
    return true
end
ImGui._ItemAdd = ItemAdd

local function auto_wrap(w)
    local win = g.current_window
    if not win then return end
    if win.cursor_x + w > win._content_x1 and win.cursor_x > win.cursor_start_x + win.indent_x then
        win.cursor_y = win.cursor_y + win.prev_line_h + Style.ItemSpacing.y
        win.cursor_x = win.cursor_start_x + win.indent_x
        win.line_h   = Style.FontHeight
    end
end

function ImGui.SameLine(offset_x, spacing)
    local win = g.current_window; if not win then return end
    win.cursor_y = win.cursor_y - win.prev_line_h - Style.ItemSpacing.y
    if offset_x and offset_x > 0 then
        win.cursor_x = win.cursor_start_x + offset_x
    else
        local r = g.last_item_rect
        win.cursor_x = (r.x + r.w) + (spacing or Style.ItemInnerSpacing.x)
    end
    win.line_h = win.prev_line_h
end

function ImGui.NewLine()
    ItemSize(0, Style.FontHeight)
end

function ImGui.Spacing()

    local win = g.current_window; if not win then return end
    win.cursor_y = win.cursor_y + Style.ItemSpacing.y
    if win.cursor_max_y < win.cursor_y then win.cursor_max_y = win.cursor_y end
end

function ImGui.Dummy(w, h)
    ItemSize(w, h)
end

function ImGui.Indent(amount)
    local win = g.current_window; if not win then return end
    amount = amount or Style.IndentSpacing
    win.indent_x = win.indent_x + amount
    win.cursor_x = win.cursor_start_x + win.indent_x
end

function ImGui.Unindent(amount)
    local win = g.current_window; if not win then return end
    amount = amount or Style.IndentSpacing
    win.indent_x = max(0, win.indent_x - amount)
    win.cursor_x = win.cursor_start_x + win.indent_x
end

function ImGui.Separator()
    local win = g.current_window; if not win then return end
    local x = win.cursor_x
    local y = win.cursor_y + 2
    local w = win._content_x1 - x
    dr_line(2, x, y, x + w, y, StyleColor(Col.Separator), 1)
    ItemSize(w, 4)
end

function ImGui.SeparatorText(text)
    local win = g.current_window; if not win then return end
    local tw, th = text_size(text)
    local x = win.cursor_x
    local y = win.cursor_y + math.floor(th * 0.5)
    local total_w = win._content_x1 - x
    local pad = 6
    local left_w = 8
    local col = StyleColor(Col.Separator)
    dr_line(2, x, y, x + left_w, y, col, 1)
    dr_text(2, text, x + left_w + pad, win.cursor_y, StyleColor(Col.Text))
    dr_line(2, x + left_w + pad + tw + pad, y, x + total_w, y, col, 1)
    ItemSize(total_w, th + 2)
end

function ImGui.BeginGroup()
    local win = g.current_window; if not win then return end
    insert(win.groups, {
        cursor_x_save = win.cursor_x,
        cursor_y_save = win.cursor_y,
        max_x_save    = win.cursor_max_x,
        max_y_save    = win.cursor_max_y,
        indent_save   = win.indent_x,

        group_max_x   = win.cursor_x,
        group_max_y   = win.cursor_y,
    })

    win.cursor_max_x = win.cursor_x
    win.cursor_max_y = win.cursor_y
end

function ImGui.EndGroup()
    local win = g.current_window; if not win then return end
    local s = remove(win.groups); if not s then return end

    local gw = win.cursor_max_x - s.cursor_x_save
    local gh = win.cursor_max_y - s.cursor_y_save

    win.cursor_max_x = max(s.max_x_save, win.cursor_max_x)
    win.cursor_max_y = max(s.max_y_save, win.cursor_max_y)

    win.cursor_x = s.cursor_x_save
    win.cursor_y = s.cursor_y_save

    local gid = fnv1a("group", #win.groups)
    record_item(gid, s.cursor_x_save, s.cursor_y_save, gw, gh,
                point_in_rect(g.mouse_x, g.mouse_y, s.cursor_x_save, s.cursor_y_save, gw, gh),
                false, false)
    ItemSize(gw, gh)
end

function ImGui.Text(text)
    local win = g.current_window; if not win then return end
    text = tostring(text or "")
    local tw, th = text_size(text)
    if ItemAdd(win.cursor_x, win.cursor_y, tw, th) then
        dr_text(2, text, win.cursor_x, win.cursor_y, StyleColor(Col.Text))
    end
    ItemSize(tw, th)
end

function ImGui.TextColored(col, text)
    local win = g.current_window; if not win then return end
    text = tostring(text or "")
    local tw, th = text_size(text)
    if ItemAdd(win.cursor_x, win.cursor_y, tw, th) then
        dr_text(2, text, win.cursor_x, win.cursor_y, col)
    end
    ItemSize(tw, th)
end

function ImGui.TextDisabled(text)
    ImGui.TextColored(StyleColor(Col.TextDisabled), text)
end

function ImGui.TextWrapped(text)
    local win = g.current_window; if not win then return end
    text = tostring(text or "")
    local font = Style.Font
    local total_w = win._content_x1 - win.cursor_x
    local lines = {}

    local cur = ""
    for word in text:gmatch("(%S+)") do
        local trial = (cur == "") and word or (cur .. " " .. word)
        local tw = text_size(trial, font)
        if tw > total_w and cur ~= "" then
            insert(lines, cur); cur = word
        else
            cur = trial
        end
    end
    if cur ~= "" then insert(lines, cur) end
    if #lines == 0 then insert(lines, "") end
    for _, line in ipairs(lines) do
        local _, th = text_size(line, font)
        if ItemAdd(win.cursor_x, win.cursor_y, total_w, th) then
            dr_text(2, line, win.cursor_x, win.cursor_y, StyleColor(Col.Text))
        end
        ItemSize(total_w, th)
    end
end

function ImGui.HelpMarker(text)
    ImGui.TextDisabled("(?)")
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.TextWrapped(text)
        ImGui.EndTooltip()
    end
end

function ImGui.BulletText(text)
    local win = g.current_window; if not win then return end
    text = tostring(text or "")
    local tw, th = text_size(text)
    local cx = win.cursor_x + 4
    local cy = win.cursor_y + th * 0.5
    dr_circle_filled(2, cx, cy, 2, StyleColor(Col.Text), 6)
    if ItemAdd(win.cursor_x, win.cursor_y, tw + 12, th) then
        dr_text(2, text, win.cursor_x + 12, win.cursor_y, StyleColor(Col.Text))
    end
    ItemSize(tw + 12, th)
end

local function button_internal(label, w_override, h_override)
    local win = g.current_window; if not win then return false end
    local id = GetID("btn:" .. label)
    insert(g.focus_list, id)
    local tw, th = text_size(label)
    local pad = Style.FramePadding
    local w = w_override or (tw + pad.x * 2)
    local h = h_override or (th + pad.y * 2)
    auto_wrap(w)
    local x, y = win.cursor_x, win.cursor_y
    local visible = ItemAdd(x, y, w, h)
    local pressed, hovered, held = ButtonBehavior(x, y, w, h, id)
    if g.nav_id == id and g.nav_activate then pressed = true end
    if visible then

        local nav_focused = (g.nav_id == id)
        local target = (held and hovered) and 2 or ((hovered or nav_focused) and 1 or 0)
        local t = anim_step(win, id, target, 14)
        local col_a = StyleColor(Col.Button)
        local col_b = StyleColor(Col.ButtonHovered)
        local col_c = StyleColor(Col.ButtonActive)
        local col
        if t <= 1 then
            col = col_lerp(col_a, col_b, t)
        else
            col = col_lerp(col_b, col_c, t - 1)
        end
        dr_rect_filled(2, x, y, w, h, col, Style.FrameRounding)
        if Style.FrameBorderSize > 0 then
            dr_rect(2, x, y, w, h, StyleColor(Col.Border), Style.FrameBorderSize, Style.FrameRounding)
        end
        if nav_focused then
            dr_rect(2, x - 2, y - 2, w + 4, h + 4, StyleColor(Col.NavHighlight), 2, Style.FrameRounding)
        end
        local tx = x + (w - tw) * 0.5
        local ty = y + (h - th) * 0.5
        dr_text(2, label, tx, ty, StyleColor(Col.Text))
    end
    record_item(id, x, y, w, h, hovered, pressed, held)
    ItemSize(w, h)
    return pressed
end

function ImGui.Button(label, w, h)        return button_internal(label, w, h) end
function ImGui.SmallButton(label)         return button_internal(label, nil, Style.FontHeight + 2) end

function ImGui.InvisibleButton(label, w, h)
    local win = g.current_window; if not win then return false end
    local id = GetID("invbtn:" .. label)
    local x, y = win.cursor_x, win.cursor_y
    local pressed, hovered, held = ButtonBehavior(x, y, w, h, id)
    record_item(id, x, y, w, h, hovered, pressed, held)
    ItemSize(w, h)
    return pressed
end

function ImGui.Checkbox(label, value)
    local win = g.current_window; if not win then return value end
    local id = GetID("chk:" .. label)
    insert(g.focus_list, id)
    local box_sz = Style.FontHeight + Style.FramePadding.y * 2
    local tw, th = text_size(label)
    local x, y = win.cursor_x, win.cursor_y
    local total_w = box_sz + Style.ItemInnerSpacing.x + tw
    local visible = ItemAdd(x, y, total_w, box_sz)
    local pressed, hovered, held = ButtonBehavior(x, y, total_w, box_sz, id)
    if g.nav_id == id and g.nav_activate then pressed = true end
    if pressed then value = not value end
    if visible then

        local nav_focused = (g.nav_id == id)
        local target = (held and hovered) and 2 or ((hovered or nav_focused) and 1 or 0)
        local t = anim_step(win, id, target, 14)
        local cA = StyleColor(Col.FrameBg)
        local cB = StyleColor(Col.FrameBgHovered)
        local cC = StyleColor(Col.FrameBgActive)
        local bg = (t <= 1) and col_lerp(cA, cB, t) or col_lerp(cB, cC, t - 1)
        dr_rect_filled(2, x, y, box_sz, box_sz, bg, Style.FrameRounding)
        if nav_focused then
            dr_rect(2, x - 2, y - 2, box_sz + 4, box_sz + 4, StyleColor(Col.NavHighlight), 2, Style.FrameRounding)
        end

        local check_t = anim_step(win, fnv1a("chkmark", id), value and 1 or 0, 18)
        if check_t > 0.05 then
            local cm = col_mul_alpha(StyleColor(Col.CheckMark), check_t)
            local pad_in = box_sz * 0.2
            local x0 = x + pad_in
            local y0 = y + box_sz * 0.55
            local x1 = x + box_sz * 0.42
            local y1 = y + box_sz - pad_in
            local x2 = x + box_sz - pad_in
            local y2 = y + pad_in + 1
            dr_line(2, x0, y0, x1, y1, cm, 2)
            dr_line(2, x1, y1, x2, y2, cm, 2)
        end
        dr_text(2, label, x + box_sz + Style.ItemInnerSpacing.x, y + (box_sz - th) * 0.5, StyleColor(Col.Text))
    end
    record_item(id, x, y, total_w, box_sz, hovered, pressed, held)
    ItemSize(total_w, box_sz)
    return value, pressed
end

function ImGui.RadioButton(label, active)
    local win = g.current_window; if not win then return false end
    local id = GetID("radio:" .. label)
    insert(g.focus_list, id)
    local sz = Style.FontHeight + Style.FramePadding.y * 2
    local tw, th = text_size(label)
    local x, y = win.cursor_x, win.cursor_y
    local total_w = sz + Style.ItemInnerSpacing.x + tw
    local visible = ItemAdd(x, y, total_w, sz)
    local pressed, hovered, held = ButtonBehavior(x, y, total_w, sz, id)
    if visible then
        local bg = StyleColor(Col.FrameBg)
        if held and hovered then bg = StyleColor(Col.FrameBgActive)
        elseif hovered then bg = StyleColor(Col.FrameBgHovered) end
        local cx = x + sz * 0.5
        local cy = y + sz * 0.5
        local r = sz * 0.5 - 1
        dr_circle_filled(2, cx, cy, r, bg, 16)
        if active then
            dr_circle_filled(2, cx, cy, r * 0.5, StyleColor(Col.CheckMark), 12)
        end
        dr_text(2, label, x + sz + Style.ItemInnerSpacing.x, y + (sz - th) * 0.5, StyleColor(Col.Text))
    end
    record_item(id, x, y, total_w, sz, hovered, pressed, held)
    ItemSize(total_w, sz)
    return pressed
end

local function slider_internal(label, value, vmin, vmax, fmt, is_int, flags)
    flags = flags or {}
    local logarithmic = flags.logarithmic and vmin > 0 and vmax > 0
    if flags.always_clamp then value = clamp(value, vmin, vmax) end
    if g.current_window then insert(g.focus_list, GetID("sld:" .. label)) end
    local win = g.current_window; if not win then return value end
    local id = GetID("sld:" .. label)
    local tw_lbl, th = text_size(label)
    local pad = Style.FramePadding
    local frame_h = th + pad.y * 2
    local total_w = win._content_x1 - win.cursor_x
    local label_part = (tw_lbl > 0) and (tw_lbl + Style.ItemInnerSpacing.x) or 0
    local slider_w = max(40, total_w - label_part)
    local x, y = win.cursor_x, win.cursor_y

    local visible = ItemAdd(x, y, slider_w, frame_h)
    local hovered = (not flags.no_input) and ItemHoverable(x, y, slider_w, frame_h, id) or false
    if hovered and g.mouse_left_clicked then
        set_active_id(id, win, { x = x, y = y, w = slider_w, h = frame_h })
    end
    local active = (g.active_id == id) and not flags.no_input

    if active then
        if g.mouse_left_down then

            local t = (slider_w > 0) and clamp((g.mouse_x - x) / slider_w, 0, 1) or 0
            local newv
            if logarithmic and vmax > vmin then
                newv = vmin * (vmax / vmin) ^ t
            else
                newv = vmin + (vmax - vmin) * t
            end
            if is_int then newv = floor(newv + 0.5) end
            value = newv
        else
            clear_active_id()
        end
    end

    if visible then

        local target = active and 2 or (hovered and 1 or 0)
        local at = anim_step(win, id, target, 14)
        local cA = StyleColor(Col.FrameBg)
        local cB = StyleColor(Col.FrameBgHovered)
        local cC = StyleColor(Col.FrameBgActive)
        local bg = (at <= 1) and col_lerp(cA, cB, at) or col_lerp(cB, cC, at - 1)
        dr_rect_filled(2, x, y, slider_w, frame_h, bg, Style.FrameRounding)

        local t
        if logarithmic and vmin > 0 and value > 0 and vmax > vmin then
            local denom = math.log(vmax / vmin)
            if abs(denom) > 1e-9 then
                t = math.log(value / vmin) / denom
            else
                t = 0
            end
        else
            t = (vmax > vmin) and ((value - vmin) / (vmax - vmin)) or 0
        end
        t = clamp(t, 0, 1)
        local grab_w = max(Style.GrabMinSize, slider_w * 0.05)
        local grab_x = x + t * (slider_w - grab_w)
        local grab_col = col_lerp(StyleColor(Col.SliderGrab), StyleColor(Col.SliderGrabActive), at * 0.5)
        dr_rect_filled(2, grab_x, y + 1, grab_w, frame_h - 2, grab_col, Style.GrabRounding)

        local vtext = format(fmt or (is_int and "%d" or "%.3f"), value)
        local vtw, _ = text_size(vtext)
        dr_text(2, vtext, x + (slider_w - vtw) * 0.5, y + (frame_h - th) * 0.5, StyleColor(Col.Text))

        if tw_lbl > 0 then
            dr_text(2, label, x + slider_w + Style.ItemInnerSpacing.x, y + (frame_h - th) * 0.5, StyleColor(Col.Text))
        end
    end
    record_item(id, x, y, slider_w + label_part, frame_h, hovered, false, active)
    ItemSize(slider_w + label_part, frame_h)
    return value, active
end

function ImGui.SliderFloat(label, v, vmin, vmax, fmt, flags) return slider_internal(label, v, vmin, vmax, fmt or "%.3f", false, flags) end
function ImGui.SliderInt(label, v, vmin, vmax, fmt, flags)   return slider_internal(label, v, vmin, vmax, fmt or "%d",  true,  flags) end

local function drag_internal(label, value, speed, vmin, vmax, fmt, is_int)
    local win = g.current_window; if not win then return value end
    local id = GetID("drg:" .. label)
    insert(g.focus_list, id)
    local tw_lbl, th = text_size(label)
    local pad = Style.FramePadding
    local frame_h = th + pad.y * 2
    local total_w = win._content_x1 - win.cursor_x
    local label_part = (tw_lbl > 0) and (tw_lbl + Style.ItemInnerSpacing.x) or 0
    local drag_w = max(40, total_w - label_part)
    local x, y = win.cursor_x, win.cursor_y

    local visible = ItemAdd(x, y, drag_w, frame_h)
    local hovered = ItemHoverable(x, y, drag_w, frame_h, id)
    if hovered and g.mouse_left_clicked then
        set_active_id(id, win, { x = x, y = y, w = drag_w, h = frame_h })
    end
    local active = (g.active_id == id)

    if active then
        if g.mouse_left_down then
            value = value + g.mouse_dx * (speed or 1)
            if vmin and vmax then value = clamp(value, vmin, vmax) end
            if is_int then value = floor(value + 0.5) end
        else
            clear_active_id()
        end
    end

    if visible then
        local bg = StyleColor(Col.FrameBg)
        if active then bg = StyleColor(Col.FrameBgActive)
        elseif hovered then bg = StyleColor(Col.FrameBgHovered) end
        dr_rect_filled(2, x, y, drag_w, frame_h, bg, Style.FrameRounding)
        local vtext = format(fmt or (is_int and "%d" or "%.3f"), value)
        local vtw, _ = text_size(vtext)
        dr_text(2, vtext, x + (drag_w - vtw) * 0.5, y + (frame_h - th) * 0.5, StyleColor(Col.Text))
        if tw_lbl > 0 then
            dr_text(2, label, x + drag_w + Style.ItemInnerSpacing.x, y + (frame_h - th) * 0.5, StyleColor(Col.Text))
        end
    end
    record_item(id, x, y, drag_w + label_part, frame_h, hovered, false, active)
    ItemSize(drag_w + label_part, frame_h)
    return value, active
end

function ImGui.DragFloat(label, v, speed, vmin, vmax, fmt) return drag_internal(label, v, speed or 1, vmin, vmax, fmt or "%.3f", false) end
function ImGui.DragInt(label, v, speed, vmin, vmax, fmt)   return drag_internal(label, v, speed or 1, vmin, vmax, fmt or "%d",  true) end

function ImGui.ProgressBar(fraction, w, h, overlay)
    local win = g.current_window; if not win then return end
    fraction = clamp(fraction or 0, 0, 1)
    local th = Style.FontHeight
    local frame_h = h or (th + Style.FramePadding.y * 2)
    local frame_w = w or (win._content_x1 - win.cursor_x)
    local x, y = win.cursor_x, win.cursor_y
    if ItemAdd(x, y, frame_w, frame_h) then
        dr_rect_filled(2, x, y, frame_w, frame_h, StyleColor(Col.FrameBg), Style.FrameRounding)
        dr_rect_filled(2, x, y, frame_w * fraction, frame_h, StyleColor(Col.PlotHistogram), Style.FrameRounding)
        local label = overlay or format("%.0f%%", fraction * 100)
        local lw, _ = text_size(label)
        dr_text(2, label, x + (frame_w - lw) * 0.5, y + (frame_h - th) * 0.5, StyleColor(Col.Text))
    end
    ItemSize(frame_w, frame_h)
end

function ImGui.Selectable(label, selected, w_override, h_override)
    local win = g.current_window; if not win then return false end
    local id = GetID("sel:" .. label)
    insert(g.focus_list, id)
    local tw, th = text_size(label)
    local w = w_override or (win._content_x1 - win.cursor_x)
    local h = h_override or (th + Style.FramePadding.y)
    local x, y = win.cursor_x, win.cursor_y
    local visible = ItemAdd(x, y, w, h)
    local pressed, hovered, held = ButtonBehavior(x, y, w, h, id)
    if visible then
        local col
        if selected then col = StyleColor(Col.HeaderActive)
        elseif held and hovered then col = StyleColor(Col.HeaderActive)
        elseif hovered then col = StyleColor(Col.HeaderHovered) end
        if col then
            dr_rect_filled(2, x, y, w, h, col, 0)
        end
        dr_text(2, label, x + 4, y + (h - th) * 0.5, StyleColor(Col.Text))
    end
    record_item(id, x, y, w, h, hovered, pressed, held)
    ItemSize(w, h)
    return pressed
end

function ImGui.Combo(label, current_idx, items, flags)
    flags = flags or {}
    if ImGui.BeginCombo(label, items[current_idx] or "", flags) then

        local visible_rows
        if flags.height_small then visible_rows = 4
        elseif flags.height_large then visible_rows = 12
        elseif flags.height_largest then visible_rows = 20
        else visible_rows = 8 end
        local row_h = ImGui.GetFrameHeight() + 1
        local need_scroll = #items > visible_rows
        if need_scroll then
            ImGui.BeginChild("##cmb_scroll_" .. label, 0, visible_rows * row_h, false)
        end
        for i, it in ipairs(items) do
            if ImGui.Selectable(tostring(it), current_idx == i) then
                current_idx = i
                ImGui.CloseCurrentPopup()
            end
        end
        if need_scroll then ImGui.EndChild() end
        ImGui.EndCombo()
    end
    return current_idx
end

function ImGui.ListBox(label, current_idx, items, height_in_items)
    local win = g.current_window; if not win then return current_idx end
    local id = GetID("lst:" .. label)
    local th = Style.FontHeight
    local row_h = th + 4
    local visible_rows = height_in_items or min(#items, 6)
    local total_w = win._content_x1 - win.cursor_x
    local box_h = visible_rows * row_h + 4
    local x, y = win.cursor_x, win.cursor_y

    dr_rect_filled(2, x, y, total_w, box_h, StyleColor(Col.FrameBg), Style.FrameRounding)
    dr_rect(2, x, y, total_w, box_h, StyleColor(Col.Border), 1, Style.FrameRounding)
    for i, it in ipairs(items) do
        local iy = y + 2 + (i - 1) * row_h
        if iy >= y and iy + row_h <= y + box_h then
            local ix = x + 2
            local iw = total_w - 4
            local ih = row_h
            local iid = fnv1a("listitem_" .. tostring(i), id)
            local hov = ItemHoverable(ix, iy, iw, ih, iid)
            if i == current_idx then
                dr_rect_filled(2, ix, iy, iw, ih, StyleColor(Col.Header), 0)
            elseif hov then
                dr_rect_filled(2, ix, iy, iw, ih, StyleColor(Col.HeaderHovered), 0)
            end
            dr_text(2, tostring(it), ix + 4, iy + (ih - th) * 0.5, StyleColor(Col.Text))
            if hov and g.mouse_left_clicked then current_idx = i end
        end
    end
    ItemSize(total_w, box_h)
    return current_idx
end

local function get_picker_state(id, r, g_, b)
    local win = g.current_window
    local key = "picker_" .. tostring(id)
    local s = store_get(win, key)
    if not s then
        local h, s2, v = rgb_to_hsv(r, g_, b)
        s = { h = h, s = s2, v = v, open = false, last_r = r, last_g = g_, last_b = b }
        store_set(win, key, s)
        return s
    end

    local eps = 0.001
    if abs((s.last_r or -1) - r) > eps
       or abs((s.last_g or -1) - g_) > eps
       or abs((s.last_b or -1) - b)  > eps then
        local nh, ns, nv = rgb_to_hsv(r, g_, b)

        if ns > 0 then s.h = nh end
        s.s, s.v = ns, nv
        s.last_r, s.last_g, s.last_b = r, g_, b
    end
    return s
end

local function picker_state_commit(s, r, g_, b)
    s.last_r, s.last_g, s.last_b = r, g_, b
end

function ImGui.ColorEdit3(label, r, g_, b, flags)
    flags = flags or {}
    local win = g.current_window; if not win then return r, g_, b end
    local id = GetID("col:" .. label)
    local tw_lbl, th = text_size(label)
    local frame_h = th + Style.FramePadding.y * 2
    local sq_w = (flags.no_small_preview) and 0 or frame_h * 1.6
    local x, y = win.cursor_x, win.cursor_y
    local visible = ItemAdd(x, y, sq_w + 1, frame_h)
    local pressed, hovered, held = ButtonBehavior(x, y, sq_w, frame_h, id)
    if pressed and not flags.no_picker then
        local s = get_picker_state(id, r, g_, b)
        s.open = not s.open
    end
    if visible and not flags.no_small_preview then
        dr_rect_filled(2, x, y, sq_w, frame_h, COL(r, g_, b, 1), Style.FrameRounding)
        dr_rect(2, x, y, sq_w, frame_h, StyleColor(Col.Border), 1, Style.FrameRounding)
    end
    if tw_lbl > 0 and not flags.no_label then
        dr_text(2, label, x + sq_w + Style.ItemInnerSpacing.x, y + (frame_h - th) * 0.5, StyleColor(Col.Text))
    end
    record_item(id, x, y, sq_w + tw_lbl, frame_h, hovered, pressed, held)
    ItemSize(sq_w + tw_lbl + Style.ItemInnerSpacing.x, frame_h)

    local s = get_picker_state(id, r, g_, b)

    local popup_str = "##colpicker_" .. tostring(id)
    if pressed and not flags.no_picker then
        if ImGui.IsPopupOpen(popup_str) then
            ImGui.CloseCurrentPopup()
        else
            local pid = fnv1a("popup:" .. popup_str)
            g.popup_pending_open = { str_id = popup_str, id = pid, x = x, y = y + frame_h + 2 }
        end
    end
    if ImGui.BeginPopup(popup_str) then
        local pwin = g.current_window
        local sv_size = 140
        local hue_w   = 16
        local pad_in  = 6
        local sv_x = pwin.cursor_x
        local sv_y = pwin.cursor_y

        local sv_id = fnv1a("sv", id)
        local sv_hover = ItemHoverable(sv_x, sv_y, sv_size, sv_size, sv_id)
        if sv_hover and g.mouse_left_clicked then
            set_active_id(sv_id, pwin, { x = sv_x, y = sv_y, w = sv_size, h = sv_size })
        end
        if g.active_id == sv_id then
            if g.mouse_left_down then
                s.s = clamp((g.mouse_x - sv_x) / sv_size, 0, 1)
                s.v = clamp(1 - (g.mouse_y - sv_y) / sv_size, 0, 1)
            else
                clear_active_id()
            end
        end

        local hr, hg, hb = hsv_to_rgb(s.h, 1, 1)
        local sv_rows = 64
        local row_h = sv_size / sv_rows
        for i = 0, sv_rows - 1 do
            local v = 1 - (i + 0.5) / sv_rows
            local cL = COL(v,        v,        v,        1)
            local cR = COL(v * hr,   v * hg,   v * hb,   1)
            dr_gradient(2, sv_x, sv_y + i * row_h, sv_size, row_h + 1, cL, cR, true)
        end

        local sc_x = sv_x + s.s * sv_size
        local sc_y = sv_y + (1 - s.v) * sv_size
        dr_circle_filled(2, sc_x, sc_y, 4, COL(1, 1, 1, 1), 16)
        dr_circle_filled(2, sc_x, sc_y, 2, COL(0, 0, 0, 1), 12)

        local hb_x = sv_x + sv_size + pad_in
        local hb_y = sv_y
        local hb_h = sv_size
        local hue_id = fnv1a("hue", id)
        local hue_hover = ItemHoverable(hb_x, hb_y, hue_w, hb_h, hue_id)
        if hue_hover and g.mouse_left_clicked then
            set_active_id(hue_id, pwin, { x = hb_x, y = hb_y, w = hue_w, h = hb_h })
        end
        if g.active_id == hue_id then
            if g.mouse_left_down then
                s.h = clamp((g.mouse_y - hb_y) / hb_h, 0, 1)
            else
                clear_active_id()
            end
        end
        local hue_n    = 32
        local hue_step = hb_h / hue_n
        for i = 0, hue_n - 1 do
            local h0 = i / hue_n
            local h1 = (i + 1) / hue_n
            local r0, g0, b0 = hsv_to_rgb(h0, 1, 1)
            local r1, g1, b1 = hsv_to_rgb(h1, 1, 1)
            dr_gradient(2, hb_x, hb_y + i * hue_step, hue_w, hue_step + 1,
                        COL(r0, g0, b0, 1), COL(r1, g1, b1, 1), false)
        end
        local hc_y = hb_y + s.h * hb_h
        dr_line(2, hb_x, hc_y, hb_x + hue_w, hc_y, COL(1, 1, 1, 1), 2)
        dr_triangle_filled(2, hb_x - 2, hc_y - 3, hb_x - 2, hc_y + 3, hb_x + 2, hc_y, COL(1, 1, 1, 1))
        dr_triangle_filled(2, hb_x + hue_w + 2, hc_y - 3, hb_x + hue_w + 2, hc_y + 3, hb_x + hue_w - 2, hc_y, COL(1, 1, 1, 1))

        r, g_, b = hsv_to_rgb(s.h, s.s, s.v)
        picker_state_commit(s, r, g_, b)

        ImGui.Dummy(sv_size + pad_in + hue_w, sv_size)
        if not flags.no_inputs then
            ImGui.Text(string.format("R %3d  G %3d  B %3d",
                                     round(r * 255), round(g_ * 255), round(b * 255)))
            ImGui.Text(string.format("#%02X%02X%02X",
                                     round(r * 255), round(g_ * 255), round(b * 255)))
        end
        ImGui.EndPopup()
    end

    return r, g_, b
end

function ImGui.ColorEdit4(label, r, g_, b, a, flags)
    flags = flags or {}
    r, g_, b = ImGui.ColorEdit3(label, r, g_, b, flags)
    a = ImGui.SliderFloat("##" .. label .. "_alpha", a or 1, 0, 1, "A %.2f")
    return r, g_, b, a
end

ImGui.ColorPicker3 = ImGui.ColorEdit3
ImGui.ColorPicker4 = ImGui.ColorEdit4

function ImGui.BeginTabBar(name, flags)
    flags = flags or {}
    local win = g.current_window; if not win then return false end
    local id = GetID("tabbar:" .. name)
    insert(g.id_stack, "tabbar:" .. tostring(id))
    local tab_h = Style.FontHeight + Style.FramePadding.y * 2
    win._tabbar = {
        id          = id,
        x           = win.cursor_x,
        y           = win.cursor_y,
        w           = win._content_x1 - win.cursor_x,
        tab_h       = tab_h,
        row_y       = win.cursor_y,
        next_x      = win.cursor_x,
        bottom_y    = win.cursor_y + tab_h,
        selected    = store_get(win, "tabbar_" .. tostring(id), nil),
        first_tab   = nil,
        scroll      = store_get(win, "tabbar_scroll_" .. tostring(id), 0),
        items_w     = 0,
        btn_reserve = 0,

        reorderable = flags.reorderable == true,
        label_order = store_get(win, "tabbar_order_"   .. tostring(id), nil) or {},
        tab_widths  = store_get(win, "tabbar_widths_"  .. tostring(id), nil) or {},
        label_seen  = {},
    }
    return true
end

function ImGui.BeginTabItem(label, p_open)
    local win = g.current_window; if not win then return false end
    local tb = win._tabbar; if not tb then return false end
    local id = GetID("tab:" .. label)
    local tw, th = text_size(label)
    local pad = Style.FramePadding
    local close_w = (p_open ~= nil) and 16 or 0
    local tab_w = tw + pad.x * 2 + 8 + close_w
    local tab_h = tb.tab_h

    tb.label_seen[label] = true

    local x, y = tb.row_y, tb.row_y
    if tb.reorderable then
        local pos
        for i, lbl in ipairs(tb.label_order) do
            if lbl == label then pos = i; break end
        end
        if not pos then insert(tb.label_order, label); pos = #tb.label_order end
        local computed_x = tb.x - (tb.scroll or 0)
        for i = 1, pos - 1 do
            computed_x = computed_x + (tb.tab_widths[tb.label_order[i]] or 80) + 2
        end
        x = computed_x
        y = tb.row_y
        tb.tab_widths[label] = tab_w
        tb.items_w = tb.items_w + tab_w + 2
    else
        x = tb.next_x - (tb.scroll or 0)
        y = tb.row_y
        tb.next_x  = tb.next_x + tab_w + 2
        tb.items_w = tb.items_w + tab_w + 2
    end
    tb.first_tab = tb.first_tab or label
    if tb.selected == nil then tb.selected = label end

    local visible_left  = tb.x
    local visible_right = tb.x + tb.w - 56
    local on_screen = (x + tab_w >= visible_left) and (x <= visible_right)

    local hovered = on_screen and ItemHoverable(x, y, tab_w - close_w, tab_h, id) or false
    if hovered and g.mouse_left_clicked then
        if tb.selected ~= label then
            tb.selected = label
            store_set(win, "tabbar_" .. tostring(tb.id), label)

            win.scroll_y = 0
        end
        if tb.reorderable then
            set_active_id(id, win, { x = x, y = y, w = tab_w, h = tab_h })
        end
    end

    if tb.reorderable and g.active_id == id and g.mouse_left_down then
        local pos
        for i, lbl in ipairs(tb.label_order) do
            if lbl == label then pos = i; break end
        end
        if pos then
            local left_lbl  = tb.label_order[pos - 1]
            local right_lbl = tb.label_order[pos + 1]

            if left_lbl and g.mouse_x < x - (tb.tab_widths[left_lbl] or 80) * 0.5 then
                tb.label_order[pos], tb.label_order[pos - 1] =
                    tb.label_order[pos - 1], tb.label_order[pos]
            elseif right_lbl and g.mouse_x > x + tab_w + (tb.tab_widths[right_lbl] or 80) * 0.5 then
                tb.label_order[pos], tb.label_order[pos + 1] =
                    tb.label_order[pos + 1], tb.label_order[pos]
            end
        end
    end

    local is_selected = (tb.selected == label)
    local closed_now  = false

    if on_screen then

        local target = is_selected and 2 or (hovered and 1 or 0)
        local t = anim_step(win, id, target, 14)
        local cA = StyleColor(Col.Tab)
        local cB = StyleColor(Col.TabHovered)
        local cC = StyleColor(Col.TabActive)
        local col = (t <= 1) and col_lerp(cA, cB, t) or col_lerp(cB, cC, t - 1)
        dr_rect_filled(2, x, y, tab_w, tab_h, col, Style.TabRounding)
        dr_text(2, label, x + (tab_w - close_w - tw) * 0.5, y + (tab_h - th) * 0.5, StyleColor(Col.Text))

        if p_open ~= nil then
            local cid = GetID("tabclose:" .. label)
            local cx = x + tab_w - 14
            local cy = y + tab_h * 0.5
            local cb_pressed, cb_hov = ButtonBehavior(cx - 6, cy - 6, 12, 12, cid)
            local lc = cb_hov and StyleColor(Col.ButtonHovered) or StyleColor(Col.Text)
            dr_line(2, cx - 4, cy - 4, cx + 4, cy + 4, lc, 1)
            dr_line(2, cx + 4, cy - 4, cx - 4, cy + 4, lc, 1)
            if cb_pressed then closed_now = true end
        end
    end

    local sel = false
    if is_selected and not closed_now then
        win.cursor_x = win.cursor_start_x + win.indent_x
        win.cursor_y = tb.bottom_y + 4
        sel = true
    end
    if p_open ~= nil then
        return sel, (not closed_now) and p_open
    end
    return sel
end

function ImGui.EndTabItem()
end

function ImGui.EndTabBar()
    local win = g.current_window; if not win then return end
    local tb = win._tabbar
    if tb and tb.reorderable then

        for i = #tb.label_order, 1, -1 do
            if not tb.label_seen[tb.label_order[i]] then
                tb.tab_widths[tb.label_order[i]] = nil
                remove(tb.label_order, i)
            end
        end
        store_set(win, "tabbar_order_"  .. tostring(tb.id), tb.label_order)
        store_set(win, "tabbar_widths_" .. tostring(tb.id), tb.tab_widths)
    end
    if tb then

        if tb.items_w > tb.w then
            local btn_w   = 24
            local pair_x  = tb.x + tb.w - btn_w * 2 - 4

            dr_rect_filled(2, pair_x - 2, tb.y, btn_w * 2 + 6, tb.tab_h,
                           StyleColor(Col.WindowBg), 0)

            local lid = fnv1a("tab_left", tb.id)
            local lp, lh = ButtonBehavior(pair_x, tb.y, btn_w, tb.tab_h, lid)
            local lc = lh and StyleColor(Col.ButtonHovered) or StyleColor(Col.Tab)
            dr_rect_filled(2, pair_x, tb.y, btn_w, tb.tab_h, lc, Style.TabRounding)
            dr_text(2, "<", pair_x + btn_w * 0.5 - 3, tb.y + 4, StyleColor(Col.Text))

            local rid  = fnv1a("tab_right", tb.id)
            local rx   = pair_x + btn_w + 4
            local rp, rh = ButtonBehavior(rx, tb.y, btn_w, tb.tab_h, rid)
            local rc = rh and StyleColor(Col.ButtonHovered) or StyleColor(Col.Tab)
            dr_rect_filled(2, rx, tb.y, btn_w, tb.tab_h, rc, Style.TabRounding)
            dr_text(2, ">", rx + btn_w * 0.5 - 3, tb.y + 4, StyleColor(Col.Text))

            local step = 80
            local max_scroll = max(0, tb.items_w - tb.w + btn_w * 2 + 8)
            if lp then tb.scroll = max(0, (tb.scroll or 0) - step) end
            if rp then tb.scroll = min(max_scroll, (tb.scroll or 0) + step) end
            store_set(win, "tabbar_scroll_" .. tostring(tb.id), tb.scroll)
        end

        dr_line(2, tb.x, tb.bottom_y, tb.x + tb.w, tb.bottom_y, StyleColor(Col.Border), 1)
        win.cursor_y = max(win.cursor_y, tb.bottom_y + 2)
        win.cursor_x = win.cursor_start_x + win.indent_x
        win.cursor_max_y = max(win.cursor_max_y, win.cursor_y)
    end
    win._tabbar = nil
    remove(g.id_stack)
end

function ImGui.TreeNodeEx(label, flags)
    flags = flags or {}
    local win = g.current_window; if not win then return false end
    local id = GetID("tree:" .. label)
    local key = "tree_" .. tostring(id)
    local open = store_get(win, key, flags.default_open and true or false)
    if flags.leaf then open = false end

    local th = Style.FontHeight
    local h = th + Style.FramePadding.y * 2
    local x, y = win.cursor_x, win.cursor_y
    local tw, _ = text_size(label)
    local total_w = (flags.framed or flags.span_full) and (win._content_x1 - x) or (16 + tw + 4)

    local hov = ItemHoverable(x, y, total_w, h, id)
    local pressed = hov and g.mouse_left_clicked
    if pressed and not flags.leaf then
        open = not open
        store_set(win, key, open)
        g._toggled_id = id
    end

    if flags.framed then
        local col
        if hov and g.mouse_left_down then col = StyleColor(Col.HeaderActive)
        elseif hov                       then col = StyleColor(Col.HeaderHovered)
        else                                  col = StyleColor(Col.Header) end
        dr_rect_filled(2, x, y, total_w, h, col, Style.FrameRounding)
    elseif flags.selected or (hov and (g.mouse_left_down or g.mouse_left_clicked)) or hov then
        local col = flags.selected and StyleColor(Col.Header)
                  or (hov and g.mouse_left_down) and StyleColor(Col.HeaderActive)
                  or StyleColor(Col.HeaderHovered)
        dr_rect_filled(2, x, y, total_w, h, col, 0)
    end

    local cx = x + 10
    local cy = y + h * 0.5
    local mk = StyleColor(Col.Text)
    if flags.bullet then
        dr_circle_filled(2, cx, cy, 2, mk, 8)
    elseif flags.leaf then

    elseif open then
        dr_triangle_filled(2, cx - 4, cy - 2, cx + 4, cy - 2, cx, cy + 4, mk)
    else
        dr_triangle_filled(2, cx - 2, cy - 4, cx + 4, cy, cx - 2, cy + 4, mk)
    end

    dr_text(2, label, x + 22, y + (h - th) * 0.5, StyleColor(Col.Text))
    record_item(id, x, y, total_w, h, hov, pressed, false)
    ItemSize(total_w, h)
    if open and not flags.no_tree_push then ImGui.Indent() end
    return open
end

function ImGui.TreeNode(label)
    local win = g.current_window; if not win then return false end
    local id = GetID("tree:" .. label)
    local key = "tree_" .. tostring(id)
    local open = store_get(win, key, false)
    local th = Style.FontHeight
    local h = th + Style.FramePadding.y * 2
    local x, y = win.cursor_x, win.cursor_y
    local tw, _ = text_size(label)
    local total_w = 16 + tw
    local hov = ItemHoverable(x, y, total_w, h, id)
    local pressed = hov and g.mouse_left_clicked
    if pressed then
        open = not open
        store_set(win, key, open)
        g._toggled_id = id
    end

    local cx = x + 8
    local cy = y + h * 0.5
    local arr = StyleColor(Col.Text)
    if open then
        dr_triangle_filled(2, cx - 4, cy - 2, cx + 4, cy - 2, cx, cy + 4, arr)
    else
        dr_triangle_filled(2, cx - 2, cy - 4, cx + 4, cy, cx - 2, cy + 4, arr)
    end
    dr_text(2, label, x + 16, y + (h - th) * 0.5, StyleColor(Col.Text))
    record_item(id, x, y, total_w, h, hov, pressed, false)
    ItemSize(total_w, h)
    if open then
        ImGui.Indent()
    end
    return open
end

function ImGui.TreePop()
    ImGui.Unindent()
end

function ImGui.CollapsingHeader(label)
    local win = g.current_window; if not win then return false end
    local id = GetID("hdr:" .. label)
    local key = "header_" .. tostring(id)
    local open = store_get(win, key, false)
    local th = Style.FontHeight
    local h = th + Style.FramePadding.y * 2
    local x, y = win.cursor_x, win.cursor_y
    local w = win._content_x1 - x
    local hov = ItemHoverable(x, y, w, h, id)
    local pressed = hov and g.mouse_left_clicked
    if pressed then
        open = not open
        store_set(win, key, open)
        g._toggled_id = id
    end
    local col
    if hov and g.mouse_left_down then col = StyleColor(Col.HeaderActive)
    elseif hov then col = StyleColor(Col.HeaderHovered)
    else col = StyleColor(Col.Header) end
    dr_rect_filled(2, x, y, w, h, col, Style.FrameRounding)
    local cx, cy = x + 10, y + h * 0.5
    local arr = StyleColor(Col.Text)
    if open then
        dr_triangle_filled(2, cx - 4, cy - 2, cx + 4, cy - 2, cx, cy + 4, arr)
    else
        dr_triangle_filled(2, cx - 2, cy - 4, cx + 4, cy, cx - 2, cy + 4, arr)
    end
    dr_text(2, label, x + 22, y + (h - th) * 0.5, StyleColor(Col.Text))
    record_item(id, x, y, w, h, hov, pressed, false)
    ItemSize(w, h)
    return open
end

local INPUT_KEYS = {}
do
    for i = 0, 25 do
        INPUT_KEYS[#INPUT_KEYS + 1] = { key = char(65 + i), emit = char(65 + i), letter = true }
    end

    for i = 0, 9 do
        INPUT_KEYS[#INPUT_KEYS + 1] = { key = "Numpad" .. i, emit = tostring(i) }
        INPUT_KEYS[#INPUT_KEYS + 1] = { key = "NumPad" .. i, emit = tostring(i) }
        INPUT_KEYS[#INPUT_KEYS + 1] = { key = "Num" .. i,    emit = tostring(i) }
        INPUT_KEYS[#INPUT_KEYS + 1] = { key = "D" .. i,      emit = tostring(i) }
        INPUT_KEYS[#INPUT_KEYS + 1] = { key = 0x30 + i,      emit = tostring(i) }
        INPUT_KEYS[#INPUT_KEYS + 1] = { key = 0x60 + i,      emit = tostring(i) }
    end
    INPUT_KEYS[#INPUT_KEYS + 1] = { key = "Space",     emit = " " }
    INPUT_KEYS[#INPUT_KEYS + 1] = { key = "Backspace", emit = "\b" }
    INPUT_KEYS[#INPUT_KEYS + 1] = { key = "Period",    emit = "." }
    INPUT_KEYS[#INPUT_KEYS + 1] = { key = "Decimal",   emit = "." }
    INPUT_KEYS[#INPUT_KEYS + 1] = { key = "Minus",     emit = "-" }
    INPUT_KEYS[#INPUT_KEYS + 1] = { key = "Subtract",  emit = "-" }
end

local function poll_typed_chars()
    if g.mouse_left_clicked then
        for _, k in ipairs(INPUT_KEYS) do g.key_states_prev[k.key] = g.key_states[k.key] end
        return {}, false, false
    end
    local out = {}
    for _, k in ipairs(INPUT_KEYS) do
        local ok, pressed = pcall(keyboard.IsPressed, k.key)
        if ok and pressed and not g.key_states_prev[k.key] then
            insert(out, k.emit)
        end
        g.key_states[k.key] = ok and pressed or false
    end
    local ok_shift, shift = pcall(keyboard.IsPressed, "Shift")
    local ok_ctrl, ctrl   = pcall(keyboard.IsPressed, "Control")

    local paste = false
    local ok_v, v = pcall(keyboard.IsPressed, "V")
    if (ok_ctrl and ctrl) and (ok_v and v) and not g._paste_prev then
        paste = true
    end
    g._paste_prev = ok_v and v or false
    return out, ok_shift and shift or false, paste
end

function ImGui.InputText(label, value, callback)
    local win = g.current_window; if not win then return value end
    local id = GetID("inp:" .. label)
    insert(g.focus_list, id)
    local th = Style.FontHeight
    local pad = Style.FramePadding
    local frame_h = th + pad.y * 2
    local total_w = win._content_x1 - win.cursor_x
    local tw_lbl, _ = text_size(label)
    local label_part = (tw_lbl > 0) and (tw_lbl + Style.ItemInnerSpacing.x) or 0
    local input_w = max(40, total_w - label_part)
    local x, y = win.cursor_x, win.cursor_y

    local hovered = ItemHoverable(x, y, input_w, frame_h, id)
    if hovered and g.mouse_left_clicked then
        set_active_id(id, win, { x = x, y = y, w = input_w, h = frame_h })
    end
    if g.mouse_left_clicked and not hovered and g.active_id == id then clear_active_id() end
    local active = (g.active_id == id)
    if active then g._input_text_was_active = true end

    if active then
        local typed, shift, paste = poll_typed_chars()
        if paste then
            local ok_clip, cb = pcall(utility.GetClipboard)
            if ok_clip and type(cb) == "string" then
                value = value .. cb
            end
        end
        for _, ch in ipairs(typed) do
            if ch == "\b" then
                value = sub(value, 1, -2)
            elseif #ch == 1 then
                if ch >= "A" and ch <= "Z" and not shift then
                    ch = string.lower(ch)
                end

                local accept = true
                if callback then
                    local r = callback("char", { char = ch, value = value })
                    if r == false then accept = false end
                end
                if accept then value = value .. ch end
            else
                value = value .. ch
            end
        end
        for _, k in ipairs(INPUT_KEYS) do g.key_states_prev[k.key] = g.key_states[k.key] end

        if callback and ImGui.IsKeyPressed("Tab") then
            local r = callback("completion", { value = value })
            if type(r) == "string" then value = r end
        end

        if callback then
            if ImGui.IsKeyPressed("Up") then
                local r = callback("history", { value = value, dir = -1 })
                if type(r) == "string" then value = r end
            end
            if ImGui.IsKeyPressed("Down") then
                local r = callback("history", { value = value, dir = 1 })
                if type(r) == "string" then value = r end
            end
        end
    end

    local bg = StyleColor(Col.FrameBg)
    if active then bg = StyleColor(Col.FrameBgActive)
    elseif hovered then bg = StyleColor(Col.FrameBgHovered) end
    dr_rect_filled(2, x, y, input_w, frame_h, bg, Style.FrameRounding)
    local display = value or ""
    if active and (g.frame_count % 60) < 30 then display = display .. "|" end
    dr_text(2, display, x + 4, y + (frame_h - th) * 0.5, StyleColor(Col.Text))
    if tw_lbl > 0 then
        dr_text(2, label, x + input_w + Style.ItemInnerSpacing.x, y + (frame_h - th) * 0.5, StyleColor(Col.Text))
    end
    record_item(id, x, y, input_w + label_part, frame_h, hovered, false, active)
    ItemSize(input_w + label_part, frame_h)
    return value, active
end

function ImGui.InputInt(label, value, step)
    step = step or 1
    local v_str = tostring(value or 0)
    local new_str = ImGui.InputText(label, v_str)
    return tonumber(new_str) or value
end

function ImGui.InputFloat(label, value, step, fmt)
    step = step or 0.1
    local v_str = format(fmt or "%.3f", value or 0)
    local new_str = ImGui.InputText(label, v_str)
    return tonumber(new_str) or value
end

function ImGui.SetTooltip(text)
    local mx, my = g.mouse_x + 14, g.mouse_y + 8
    local tw, th = text_size(text)
    local pad = 6
    dr_rect_filled(5, mx, my, tw + pad * 2, th + pad * 2, StyleColor(Col.PopupBg), Style.FrameRounding)
    dr_rect(5, mx, my, tw + pad * 2, th + pad * 2, StyleColor(Col.Border), 1, Style.FrameRounding)
    dr_text(5, text, mx + pad, my + pad, StyleColor(Col.Text))
end

local function text_clip(s, max_w, font)
    if max_w <= 0 then return "" end
    local w, _ = text_size(s, font)
    if w <= max_w then return s end

    local ell = "..."
    local ew, _ = text_size(ell, font)
    if ew >= max_w then return "" end
    local target = max_w - ew
    local lo, hi = 0, #s
    while lo < hi do
        local mid = floor((lo + hi + 1) / 2)
        local sub_s = sub(s, 1, mid)
        local sw, _ = text_size(sub_s, font)
        if sw <= target then lo = mid else hi = mid - 1 end
    end
    return sub(s, 1, lo) .. ell
end
ImGui.TextClip = text_clip

render_scrollbar = function(win)
    if not win or win.collapsed then return end
    local visible_h = win.h - win._title_h - Style.WindowPadding.y * 2
    local content_h = win.cursor_max_y - win.cursor_start_y
    win.scroll_max_y = max(0, content_h - visible_h)

    if point_in_rect(g.mouse_x, g.mouse_y, win.x, win.y, win.w, win.h) then
        if g._pg_up_edge   then win.scroll_y = max(0, win.scroll_y - visible_h * 0.9) end
        if g._pg_down_edge then win.scroll_y = win.scroll_y + visible_h * 0.9 end

        if g.mouse_wheel and g.mouse_wheel ~= 0 and not g._wheel_consumed then
            local notch_px = 60
            win.scroll_y = win.scroll_y - g.mouse_wheel * notch_px
            g._wheel_consumed = true
            g.mouse_wheel    = 0
        end
    end

    if win.scroll_max_y <= 0 then return end
    win.scroll_y = clamp(win.scroll_y, 0, win.scroll_max_y)

    local sb_w = Style.ScrollbarSize
    local sb_x = win.x + win.w - sb_w - 1
    local sb_y = win.y + win._title_h + 1
    local sb_h = win.h - win._title_h - 2

    dr_rect_filled(3, sb_x, sb_y, sb_w, sb_h, StyleColor(Col.ScrollbarBg), Style.ScrollbarRounding)

    local grab_h = max(Style.GrabMinSize, sb_h * (visible_h / content_h))
    local grab_y_range = sb_h - grab_h
    local t = (win.scroll_y / win.scroll_max_y)
    local grab_y = sb_y + t * grab_y_range

    if g.mouse_left_clicked
       and point_in_rect(g.mouse_x, g.mouse_y, sb_x, sb_y, sb_w, sb_h)
       and not point_in_rect(g.mouse_x, g.mouse_y, sb_x, grab_y, sb_w, grab_h) then
        if g.mouse_y < grab_y then
            win.scroll_y = max(0, win.scroll_y - visible_h * 0.9)
        else
            win.scroll_y = win.scroll_y + visible_h * 0.9
        end
        win.scroll_y = clamp(win.scroll_y, 0, win.scroll_max_y)
    end

    local sid = fnv1a("scroll", win.id)
    local hov = ItemHoverable(sb_x, grab_y, sb_w, grab_h, sid)
    if hov and g.mouse_left_clicked then
        set_active_id(sid, win, { x = sb_x, y = sb_y, w = sb_w, h = sb_h })
    end
    local active = (g.active_id == sid)
    if active then
        if g.mouse_left_down then
            local new_t = clamp((g.mouse_y - sb_y - grab_h * 0.5) / grab_y_range, 0, 1)
            win.scroll_y = new_t * win.scroll_max_y
        else
            clear_active_id()
        end
    end

    local col = StyleColor(Col.ScrollbarGrab)
    if active then col = StyleColor(Col.ScrollbarGrabActive)
    elseif hov then col = StyleColor(Col.ScrollbarGrabHovered) end
    dr_rect_filled(3, sb_x, grab_y, sb_w, grab_h, col, Style.ScrollbarRounding)
end

function ImGui.BeginChild(str_id, w, h, border)
    local win = g.current_window; if not win then return false end
    local pid = GetID("child:" .. tostring(str_id))

    local cw = (w and w > 0) and w or (win._content_x1 - win.cursor_x)
    local ch = (h and h > 0) and h or 100
    local cx, cy = win.cursor_x, win.cursor_y
    auto_wrap(cw)
    cx, cy = win.cursor_x, win.cursor_y

    if border then
        dr_rect_filled(2, cx, cy, cw, ch, StyleColor(Col.ChildBg), 0)
        dr_rect(2, cx, cy, cw, ch, StyleColor(Col.Border), 1, 0)
    end

    win._child_stack = win._child_stack or {}
    insert(win._child_stack, {
        cursor_start_x = win.cursor_start_x,
        cursor_start_y = win.cursor_start_y,
        content_x0     = win._content_x0,
        content_y0     = win._content_y0,
        content_x1     = win._content_x1,
        content_y1     = win._content_y1,
        inner_x0       = win._inner_x0,
        inner_y0       = win._inner_y0,
        inner_x1       = win._inner_x1,
        inner_y1       = win._inner_y1,
        cursor_x       = win.cursor_x,
        cursor_y       = win.cursor_y,
        cursor_max_x   = win.cursor_max_x,
        cursor_max_y   = win.cursor_max_y,
        indent_x       = win.indent_x,
        cw             = cw,
        ch             = ch,
        cx             = cx,
        cy             = cy,
        scroll_y       = win._child_scroll_y_save,
    })

    local sk = "child_scroll_" .. tostring(pid)
    local sy = store_get(win, sk, 0)

    win.cursor_start_x = cx + 4
    win.cursor_start_y = cy + 4 - sy
    win.cursor_x       = win.cursor_start_x
    win.cursor_y       = win.cursor_start_y
    win.cursor_max_x   = win.cursor_start_x
    win.cursor_max_y   = win.cursor_start_y
    win._content_x0    = cx + 4
    win._content_y0    = cy + 4
    win._content_x1    = cx + cw - 4
    win._content_y1    = cy + ch - 4
    win._inner_x0      = cx
    win._inner_y0      = cy
    win._inner_x1      = cx + cw
    win._inner_y1      = cy + ch
    win.indent_x       = 0
    win._child_scroll_key = sk
    win._child_scroll_y   = sy

    pop_clip()
    push_clip(cx + 4, cy + 4, cw - 8, ch - 8)
    return true
end

function ImGui.EndChild()
    local win = g.current_window; if not win then return end
    local stack = win._child_stack
    if not stack or #stack == 0 then return end
    local s = remove(stack)

    pop_clip()
    push_clip(s.content_x0, s.content_y0, s.content_x1 - s.content_x0, s.content_y1 - s.content_y0)

    if win._child_scroll_key then
        store_set(win, win._child_scroll_key, win._child_scroll_y or 0)
    end

    win.cursor_start_x = s.cursor_start_x
    win.cursor_start_y = s.cursor_start_y
    win._content_x0    = s.content_x0
    win._content_y0    = s.content_y0
    win._content_x1    = s.content_x1
    win._content_y1    = s.content_y1
    win._inner_x0      = s.inner_x0
    win._inner_y0      = s.inner_y0
    win._inner_x1      = s.inner_x1
    win._inner_y1      = s.inner_y1
    win.indent_x       = s.indent_x
    win.cursor_x       = s.cursor_x
    win.cursor_y       = s.cursor_y
    win.cursor_max_x   = s.cursor_max_x
    win.cursor_max_y   = s.cursor_max_y

    ItemSize(s.cw, s.ch)
end

function ImGui.Image(tex_id, w, h, tint)
    local win = g.current_window; if not win then return end
    auto_wrap(w)
    local x, y = win.cursor_x, win.cursor_y
    if ItemAdd(x, y, w, h) then
        dr_image(2, x, y, w, h, tex_id, tint or COL(1, 1, 1, 1), 1)
    end
    ItemSize(w, h)
end

function ImGui.ImageButton(str_id, tex_id, w, h, tint, bg)
    local win = g.current_window; if not win then return false end
    local id = GetID("imgbtn:" .. tostring(str_id))
    auto_wrap(w + 4)
    local x, y = win.cursor_x, win.cursor_y
    local visible = ItemAdd(x, y, w + 4, h + 4)
    local pressed, hovered, held = ButtonBehavior(x, y, w + 4, h + 4, id)
    if visible then
        local frame = bg or StyleColor(Col.Button)
        if held and hovered then frame = StyleColor(Col.ButtonActive)
        elseif hovered then frame = StyleColor(Col.ButtonHovered) end
        dr_rect_filled(2, x, y, w + 4, h + 4, frame, Style.FrameRounding)
        dr_image(2, x + 2, y + 2, w, h, tex_id, tint or COL(1, 1, 1, 1), 1)
    end
    record_item(id, x, y, w + 4, h + 4, hovered, pressed, held)
    ItemSize(w + 4, h + 4)
    return pressed
end

local function plot_internal(label, values, overlay, scale_min, scale_max, plot_w, plot_h, kind)
    local win = g.current_window; if not win then return end
    local th = Style.FontHeight
    local count = #values
    plot_h = plot_h or 60
    plot_w = plot_w or (win._content_x1 - win.cursor_x - 80)
    auto_wrap(plot_w)
    local x, y = win.cursor_x, win.cursor_y

    if not scale_min or not scale_max then
        local mn, mx = huge, -huge
        for i = 1, count do
            local v = values[i]
            if v < mn then mn = v end
            if v > mx then mx = v end
        end
        scale_min = scale_min or mn
        scale_max = scale_max or mx
        if scale_max <= scale_min then scale_max = scale_min + 1 end
    end

    local hovered = ItemHoverable(x, y, plot_w, plot_h, fnv1a("plot:" .. label))
    if ItemAdd(x, y, plot_w, plot_h) then
        dr_rect_filled(2, x, y, plot_w, plot_h, StyleColor(Col.FrameBg), Style.FrameRounding)
        if count >= 2 then
            local col = (kind == "hist") and StyleColor(Col.PlotHistogram) or StyleColor(Col.PlotLines)
            local function tx(i) return x + (i - 1) / (count - 1) * plot_w end
            local function ty(v) return y + plot_h - ((v - scale_min) / (scale_max - scale_min)) * plot_h end
            if kind == "hist" then
                local bar_w = plot_w / count
                for i = 1, count do
                    local v = values[i]
                    local by = ty(v)
                    dr_rect_filled(2, x + (i - 1) * bar_w, by, bar_w - 1, y + plot_h - by, col, 0)
                end
            else
                for i = 1, count - 1 do
                    dr_line(2, tx(i), ty(values[i]), tx(i + 1), ty(values[i + 1]), col, 1)
                end
            end

            if hovered then
                local idx
                if kind == "hist" then
                    idx = floor((g.mouse_x - x) / (plot_w / count)) + 1
                else
                    idx = floor((g.mouse_x - x) / plot_w * (count - 1)) + 1
                end
                idx = clamp(idx, 1, count)
                local px = tx(idx)
                dr_line(2, px, y, px, y + plot_h, StyleColor(Col.PlotLinesHovered), 1)
                ImGui.BeginTooltip()
                ImGui.Text(string.format("[%d] = %.3f", idx, values[idx]))
                ImGui.EndTooltip()
            end
        end
        if overlay and overlay ~= "" then
            local ow, _ = text_size(overlay)
            dr_text(2, overlay, x + (plot_w - ow) * 0.5, y + 2, StyleColor(Col.Text))
        end
    end

    local lw, _ = text_size(label)
    if lw > 0 then
        dr_text(2, label, x + plot_w + Style.ItemInnerSpacing.x, y + (plot_h - th) * 0.5, StyleColor(Col.Text))
    end
    ItemSize(plot_w + ((lw > 0) and (Style.ItemInnerSpacing.x + lw) or 0), plot_h)
end

function ImGui.PlotLines(label, values, overlay, scale_min, scale_max, w, h)
    plot_internal(label, values, overlay, scale_min, scale_max, w, h, "lines")
end
function ImGui.PlotHistogram(label, values, overlay, scale_min, scale_max, w, h)
    plot_internal(label, values, overlay, scale_min, scale_max, w, h, "hist")
end

function ImGui.GetCursorPos()
    local win = g.current_window
    if not win then return 0, 0 end
    return win.cursor_x - win.x, win.cursor_y - win.y
end
function ImGui.GetCursorPosX()
    local win = g.current_window; if not win then return 0 end
    return win.cursor_x - win.x
end
function ImGui.GetCursorPosY()
    local win = g.current_window; if not win then return 0 end
    return win.cursor_y - win.y
end
function ImGui.SetCursorPos(x, y)
    local win = g.current_window; if not win then return end
    win.cursor_x = win.x + x
    win.cursor_y = win.y + y
end
function ImGui.SetCursorPosX(x)
    local win = g.current_window; if not win then return end
    win.cursor_x = win.x + x
end
function ImGui.SetCursorPosY(y)
    local win = g.current_window; if not win then return end
    win.cursor_y = win.y + y
end
function ImGui.GetCursorScreenPos()
    local win = g.current_window; if not win then return 0, 0 end
    return win.cursor_x, win.cursor_y
end
function ImGui.SetCursorScreenPos(x, y)
    local win = g.current_window; if not win then return end
    win.cursor_x = x; win.cursor_y = y
end
function ImGui.GetContentRegionAvail()
    local win = g.current_window; if not win then return 0, 0 end
    return win._content_x1 - win.cursor_x, win._content_y1 - win.cursor_y
end
function ImGui.GetWindowPos()
    local win = g.current_window; if not win then return 0, 0 end
    return win.x, win.y
end
function ImGui.GetWindowSize()
    local win = g.current_window; if not win then return 0, 0 end
    return win.w, win.h
end
function ImGui.GetWindowWidth()  local w = g.current_window; return w and w.w or 0 end
function ImGui.GetWindowHeight() local w = g.current_window; return w and w.h or 0 end

function ImGui.SetWindowPos(x, y)
    local w = g.current_window; if not w then return end
    w.x, w.y = x, y
end
function ImGui.SetWindowSize(w_, h_)
    local w = g.current_window; if not w then return end
    w.w = max(Style.WindowMinSize.x, w_)
    w.h = max(Style.WindowMinSize.y, h_)
end
function ImGui.SetWindowCollapsed(b) local w = g.current_window; if w then w.collapsed = b end end
function ImGui.SetWindowFocus()
    local w = g.current_window; if not w then return end

    for i, wid in ipairs(g.windows_z_order) do
        if wid == w.id then remove(g.windows_z_order, i); break end
    end
    insert(g.windows_z_order, w.id)
end
function ImGui.GetFontSize()                 return Style.FontHeight end
function ImGui.GetFrameHeight()              return Style.FontHeight + Style.FramePadding.y * 2 end
function ImGui.GetTextLineHeight()           return Style.FontHeight end
function ImGui.GetTextLineHeightWithSpacing()return Style.FontHeight + Style.ItemSpacing.y end
function ImGui.GetFrameHeightWithSpacing()   return Style.FontHeight + Style.FramePadding.y * 2 + Style.ItemSpacing.y end
function ImGui.CalcItemWidth()
    local win = g.current_window
    if win and win._item_width_stack and #win._item_width_stack > 0 then
        return win._item_width_stack[#win._item_width_stack]
    end
    return win and (win._content_x1 - win.cursor_x) or 0
end

local _next_item_width = nil
function ImGui.PushItemWidth(w)
    local win = g.current_window; if not win then return end
    win._item_width_stack = win._item_width_stack or {}
    insert(win._item_width_stack, w)
end
function ImGui.PopItemWidth()
    local win = g.current_window; if not win then return end
    if win._item_width_stack and #win._item_width_stack > 0 then
        remove(win._item_width_stack)
    end
end
function ImGui.SetNextItemWidth(w) _next_item_width = w end
local function get_item_width(default_w)
    if _next_item_width ~= nil then
        local w = _next_item_width; _next_item_width = nil; return w
    end
    local win = g.current_window
    if win and win._item_width_stack and #win._item_width_stack > 0 then
        return win._item_width_stack[#win._item_width_stack]
    end
    return default_w
end
ImGui._GetItemWidth = get_item_width

function ImGui.BeginDisabled(disabled)
    if disabled == nil then disabled = true end
    if disabled then
        g._disabled_depth = (g._disabled_depth or 0) + 1
        local function dim(c) return col_mul_alpha(c, 0.5) end
        ImGui.PushStyleColor(Col.Text,           StyleColor(Col.TextDisabled))
        ImGui.PushStyleColor(Col.Button,         dim(StyleColor(Col.Button)))
        ImGui.PushStyleColor(Col.ButtonHovered,  dim(StyleColor(Col.Button)))
        ImGui.PushStyleColor(Col.ButtonActive,   dim(StyleColor(Col.Button)))
        ImGui.PushStyleColor(Col.FrameBg,        dim(StyleColor(Col.FrameBg)))
        ImGui.PushStyleColor(Col.FrameBgHovered, dim(StyleColor(Col.FrameBg)))
        ImGui.PushStyleColor(Col.FrameBgActive,  dim(StyleColor(Col.FrameBg)))
        ImGui.PushStyleColor(Col.CheckMark,      dim(StyleColor(Col.CheckMark)))
    end
    g._disabled_stack = g._disabled_stack or {}
    insert(g._disabled_stack, disabled)
end
function ImGui.EndDisabled()
    local s = g._disabled_stack
    if s and #s > 0 then
        local was = remove(s)
        if was then
            g._disabled_depth = max(0, (g._disabled_depth or 0) - 1)
            ImGui.PopStyleColor(8)
        end
    end
end
local function is_disabled() return (g._disabled_depth or 0) > 0 end
ImGui._IsDisabled = is_disabled

function ImGui.AlignTextToFramePadding()
    local win = g.current_window; if not win then return end
    win.cursor_y = win.cursor_y + Style.FramePadding.y
end

function ImGui.LabelText(label, fmt, ...)
