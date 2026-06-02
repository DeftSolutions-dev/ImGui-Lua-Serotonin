

print("[imgui_menu] script start")

local ImGui = {}
ImGui.VERSION = "0.1.0"

local floor, ceil, abs, min, max, sqrt = math.floor, math.ceil, math.abs, math.min, math.max, math.sqrt
local sin, cos, pi, huge = math.sin, math.cos, math.pi, math.huge
local format, sub, len, byte, char = string.format, string.sub, string.len, string.byte, string.char
local insert, remove, concat = table.insert, table.remove, table.concat
local Color3_fromRGB = Color3.fromRGB
local Color3_new = Color3.new

