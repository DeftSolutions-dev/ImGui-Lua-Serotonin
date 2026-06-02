# imgui_lua API reference

`imgui_lua.lua` is a single-file, immediate-mode UI library (a Dear ImGui port) that renders through
the Serotonin `draw` API. Version `0.1.0`.

Load it once and keep the returned table:

```lua
local ImGui = dofile("C:/Serotonin/scripts/imgui_lua.lua")
```

## Contents

- [Lifecycle](#lifecycle)
- [Core concepts](#core-concepts)
- [Windows](#windows)
- [Layout and cursor](#layout-and-cursor)
- [Text](#text)
- [Buttons and basic widgets](#buttons-and-basic-widgets)
- [Sliders and drags](#sliders-and-drags)
- [Inputs](#inputs)
- [Combos, lists, trees](#combos-lists-trees)
- [Tabs, menus, popups, tooltips](#tabs-menus-popups-tooltips)
- [Tables](#tables)
- [Color](#color)
- [Plots and indicators](#plots-and-indicators)
- [Item queries](#item-queries)
- [Mouse and keyboard](#mouse-and-keyboard)
- [Style](#style)
- [Low-level drawing](#low-level-drawing)
- [Utility](#utility)

## Lifecycle

The host calls one paint callback per frame. You register `ImGui._OnPaint` with the sandbox and
hand your draw code to `ImGui.Setup`.

```lua
ImGui.Setup(function()
    -- build your UI here, every frame the menu is open
end)

cheat.Register("onPaint", ImGui._OnPaint)
```

- `ImGui.Setup(fn)` - store the per-frame UI function.
- `ImGui._OnPaint()` - the frame driver. Runs `NewFrame`, calls your function only while the menu is open, then `Render`. Errors are caught and printed once.
- `ImGui.NewFrame()` - begin a frame (reads input, resets per-frame state). Called for you by `_OnPaint`.
- `ImGui.Render()` - flush all draw layers to the screen. Called for you by `_OnPaint`.

Window toggle:

- default toggle key is `F8`.
- `ImGui.SetToggleKey(name)` - change it (any Serotonin key name).
- `ImGui.IsMenuOpen()` / `ImGui.SetMenuOpen(bool)` - read or set open state.

If you drive frames yourself instead of using `Setup`, the order is `NewFrame()` then your widgets
then `Render()`.

## Core concepts

**Immediate mode.** There are no retained widget objects. Every frame you call the widget functions
again; they draw and return their result for that frame.

**Value-return pattern.** Widgets return the updated value. Store it back yourself:

```lua
state.enabled = ImGui.Checkbox("Enabled", state.enabled)   -- bool in, bool out
state.amount  = ImGui.SliderInt("Amount", state.amount, 0, 100)
state.name    = ImGui.InputText("Name", state.name)
```

Action widgets return a boolean for "happened this frame":

```lua
if ImGui.Button("Run") then ... end          -- true on the frame it is clicked
```

**Colors.** Two constructors, both return a color value usable anywhere a `col` is expected:

- `ImGui.RGBA(r, g, b, a)` - components `0..255`.
- `ImGui.ColF(r, g, b, a)` - components `0..1`.

**Coordinates** are screen pixels. `ImGui.GetScreenSize()` returns `w, h`.

**Draw layers.** The low-level draw calls take a `layer` index `1..6`; higher layers paint on top.
The menu uses 1 (background), 2 (content), 3 (popups and overlays).

## Windows

- `ImGui.Begin(title, opts)` - start a window. Returns `visible`. Always pair with `End()`:

```lua
if ImGui.Begin("Title", { no_scrollbar = true }) then
    -- contents
end
ImGui.End()
```

- `ImGui.End()` - close the current window (call it even when `Begin` returned false).
- `ImGui.BeginChild(id, w, h, border)` / `ImGui.EndChild()` - nested scroll region.
- `ImGui.SetNextWindowPos(x, y, cond)` / `ImGui.SetNextWindowSize(w, h, cond)` - place the next window. `cond` may be `"once"`, `"always"`, `"appearing"`.
- `ImGui.SetNextWindowCollapsed(b, cond)` / `ImGui.SetNextWindowFocus()`.
- `ImGui.GetWindowPos()` / `GetWindowSize()` / `GetWindowWidth()` / `GetWindowHeight()`.
- `ImGui.SetWindowPos(x, y)` / `SetWindowSize(w, h)` / `SetWindowCollapsed(b)` / `SetWindowFocus()`.
- `ImGui.IsWindowHovered()` / `IsWindowFocused()`.
- `ImGui.GetContentRegionAvail()` - remaining space `w, h`.
- `ImGui.GetMainViewport()`.

## Layout and cursor

- `ImGui.SameLine(offset_x, spacing)` - keep the next item on the same row.
- `ImGui.NewLine()`, `ImGui.Spacing()`, `ImGui.Dummy(w, h)`.
- `ImGui.Separator()`, `ImGui.SeparatorText(text)`, `ImGui.SeparatorEx(thickness)`.
- `ImGui.Indent(amount)` / `ImGui.Unindent(amount)`.
- `ImGui.BeginGroup()` / `ImGui.EndGroup()`.
- `ImGui.GetCursorPos()` / `SetCursorPos(x, y)` and the `X` / `Y` and `ScreenPos` variants.
- `ImGui.PushItemWidth(w)` / `PopItemWidth()` / `SetNextItemWidth(w)` / `CalcItemWidth()`.
- `ImGui.GetFrameHeight()` / `GetFrameHeightWithSpacing()`.
- `ImGui.AlignTextToFramePadding()`.

## Text

- `ImGui.Text(text)` - plain text.
- `ImGui.TextColored(col, text)` - coloured text.
- `ImGui.TextDisabled(text)`, `ImGui.TextWrapped(text)`.
- `ImGui.LabelText(label, fmt, ...)` - label on the left, value on the right.
- `ImGui.BulletText(text)`, `ImGui.Bullet()`.
- `ImGui.TextLink(label)` - clickable link, returns true on click.
- `ImGui.SeparatorText(text)`.
- `ImGui.CalcTextSize(text)` - returns `w, h`.

## Buttons and basic widgets

- `ImGui.Button(label, w, h)` - returns `pressed` (bool).
- `ImGui.SmallButton(label)`, `ImGui.InvisibleButton(label, w, h)`.
- `ImGui.ImageButton(id, tex_id, w, h, tint, bg)` - returns `pressed`.
- `ImGui.Checkbox(label, value)` - returns the new bool.
- `ImGui.CheckboxFlags(label, flags_int, flag_bit)` - returns the new flags int.
- `ImGui.RadioButton(label, active)` - returns true when picked.
- `ImGui.Selectable(label, selected, w, h)` - returns the new selected bool.
- `ImGui.Image(tex_id, w, h, tint)` - draw a texture inline.
- `ImGui.ProgressBar(fraction, w, h, overlay)`.
- `ImGui.Spinner(label, radius, thickness, color)`.

## Sliders and drags

All return the updated value (the `2`/`3`/`4` variants take and return a table of components).

- `ImGui.SliderFloat(label, v, vmin, vmax, fmt, flags)` and `SliderFloat2/3/4`.
- `ImGui.SliderInt(label, v, vmin, vmax, fmt, flags)` and `SliderInt2/3/4`.
- `ImGui.VSliderFloat(label, w, h, v, vmin, vmax, fmt)`, `ImGui.VSliderInt(...)` - vertical.
- `ImGui.DragFloat(label, v, speed, vmin, vmax, fmt)` and `DragFloat2/3/4`, `DragFloatRange2`.
- `ImGui.DragInt(label, v, speed, vmin, vmax, fmt)` and `DragInt2/3/4`.

`fmt` is a `string.format` pattern, for example `"%.2f"` or `"%d"`.

## Inputs

- `ImGui.InputText(label, value, callback)` - returns the new string.
- `ImGui.InputTextWithHint(label, hint, value)`, `ImGui.InputTextMultiline(label, value, w, h)`.
- `ImGui.InputInt(label, value, step)` / `ImGui.InputIntStep(...)`.
- `ImGui.InputFloat(label, value, step, fmt)` / `ImGui.InputFloatStep(...)` / `ImGui.InputDouble`.
- `ImGui.Hotkey(label, key)` - capture a key bind, returns the new key name.
- `ImGui.SetKeyboardFocusHere()`.

## Combos, lists, trees

- `ImGui.Combo(label, current_idx, items, flags)` - returns the new 1-based index. `items` is a list of strings.
- `ImGui.BeginCombo(label, preview, flags)` / `ImGui.EndCombo()` - custom combo body:

```lua
if ImGui.BeginCombo("Mode", items[current]) then
    for i, it in ipairs(items) do
        if ImGui.Selectable(it, i == current) then current = i end
    end
    ImGui.EndCombo()
end
```

- `ImGui.ListBox(label, current_idx, items, height_in_items)` - returns the new index.
- `ImGui.BeginListBox(label, w, h)` / `ImGui.EndListBox()`.
- `ImGui.TreeNode(label)` / `ImGui.TreeNodeEx(label, flags)` - returns open bool, pair with `TreePop()`.
- `ImGui.CollapsingHeader(label)` - returns open bool.

## Tabs, menus, popups, tooltips

Tabs:

- `ImGui.BeginTabBar(name, flags)` / `ImGui.EndTabBar()`.
- `ImGui.BeginTabItem(label, p_open)` / `ImGui.EndTabItem()`.

Menus:

- `ImGui.BeginMenuBar()` / `ImGui.EndMenuBar()`.
- `ImGui.BeginMenu(label)` / `ImGui.EndMenu()`.
- `ImGui.MenuItem(label, shortcut, selected)`, `ImGui.MenuSeparator()`.

Popups:

- `ImGui.OpenPopup(id)`, `ImGui.BeginPopup(id, flags)` / `ImGui.EndPopup()`, `ImGui.CloseCurrentPopup()`.
- `ImGui.BeginPopupModal(name, p_open, flags)`.
- `ImGui.BeginPopupContextItem(id)` / `ContextWindow` / `ContextVoid`.
- `ImGui.IsPopupOpen(id)`, `ImGui.IsAnyPopupOpen()`.

Tooltips:

- `ImGui.BeginTooltip()` / `ImGui.EndTooltip()`, `ImGui.SetTooltip(text)`.
- `ImGui.HelpMarker(text)` - a `(?)` marker with a hover tooltip.

## Tables

```lua
if ImGui.BeginTable("t", 3, flags) then
    ImGui.TableSetupColumn("A")
    ImGui.TableSetupColumn("B")
    ImGui.TableSetupColumn("C")
    ImGui.TableHeadersRow()
    ImGui.TableNextRow()
    ImGui.TableNextColumn(); ImGui.Text("a")
    ImGui.TableNextColumn(); ImGui.Text("b")
    ImGui.EndTable()
end
```

- `ImGui.BeginTable(id, columns, flags)` / `ImGui.EndTable()`.
- `ImGui.TableSetupColumn(label, flags)`, `ImGui.TableHeadersRow()`, `ImGui.TableHeader(label)`.
- `ImGui.TableNextRow()`, `ImGui.TableNextColumn()`, `ImGui.TableSetColumnIndex(col)`.
- `ImGui.TableGetSortSpecs()`.

## Color

- `ImGui.ColorEdit3(label, r, g, b, flags)` / `ColorEdit4(..., a, flags)` - return the new components.
- `ImGui.ColorPicker3` / `ImGui.ColorPicker4`.
- `ImGui.ColorButton(id, col, w, h)` - returns true on click.

## Plots and indicators

- `ImGui.PlotLines(label, values, overlay, scale_min, scale_max, w, h)`.
- `ImGui.PlotHistogram(label, values, overlay, scale_min, scale_max, w, h)`.
- `ImGui.ProgressBar(fraction, w, h, overlay)`.

## Item queries

Call these right after the widget you want to ask about.

- `ImGui.IsItemHovered()`, `IsItemClicked()`, `IsItemActive()`, `IsItemActivated()`, `IsItemDeactivated()`.
- `ImGui.IsItemFocused()`, `IsItemEdited()`, `IsItemToggledOpen()`, `IsAnyItemActive()`.
- `ImGui.GetItemRectMin()` / `GetItemRectMax()` / `GetItemRectSize()`.

## Mouse and keyboard

- `ImGui.GetMousePos()` returns `x, y`. `ImGui.GetMouseDelta()`, `ImGui.GetMouseDragDelta()`, `ImGui.ResetMouseDragDelta()`.
- `ImGui.IsMouseClicked()`, `IsMouseDown()`, `IsMouseReleased()`, `IsMouseDoubleClicked()`, `IsMouseDragging(threshold)`.
- `ImGui.IsMouseRightClicked()`, `IsMouseRightDown()`.
- `ImGui.IsMouseHoveringRect(x, y, w, h)`.
- `ImGui.IsKeyDown(name)`, `ImGui.IsKeyPressed(name)`, `ImGui.GetKeyName(name)`.
- `ImGui.GetIO()` returns a snapshot table: `MousePos`, `MouseDown`, `MouseClicked`, `MouseReleased`, `DeltaTime`, `FrameCount`.

## Style

- `ImGui.PushStyleColor(idx, col)` / `ImGui.PopStyleColor(n)`.
- `ImGui.PushStyleVar(name, value)` / `ImGui.PushStyleVarVec(name, x, y)` / `ImGui.PopStyleVar(n)`.
- `ImGui.PushFont(font_name)` / `ImGui.PopFont()`.
- `ImGui.StyleColorsDark()` / `StyleColorsLight()` / `StyleColorsClassic()`.
- `ImGui.GetStyleColor(idx)`, `ImGui.Col`, `ImGui.Style` - the color enum and live style table.
- `ImGui.PushID(v)` / `ImGui.PopID()` / `ImGui.GetID(s)` - id scoping for items that share a label.
- `ImGui.BeginDisabled(b)` / `ImGui.EndDisabled()`.

## Low-level drawing

Direct draw-list access. The first argument is the `layer` (`1..6`, higher is on top). Colors come
from `ImGui.RGBA` or `ImGui.ColF`.

- `ImGui.AddRectFilled(layer, x, y, w, h, col, rounding)`.
- `ImGui.AddRect(layer, x, y, w, h, col, thick, rounding)`.
- `ImGui.AddLine(layer, x1, y1, x2, y2, col, thick)`.
- `ImGui.AddCircleFilled(layer, cx, cy, r, col, segs)`.
- `ImGui.AddTriangleFilled(layer, x1, y1, x2, y2, x3, y3, col)`.
- `ImGui.AddGradient(layer, x, y, w, h, c1, c2, horiz)` - 2-stop axis-aligned gradient.
- `ImGui.AddImage(layer, x, y, w, h, tex_id, col, alpha)` - `tex_id` from the host image loader; `col` tints, `alpha` is `0..1`.
- `ImGui.PushClipRect(x, y, w, h)` / `ImGui.PopClipRect()` - clip following draws to a rect.
- `ImGui.SetDrawAlpha(a)` / `ImGui.GetDrawAlpha()` - multiply alpha of following draws (`0..1`).

## Utility

- `ImGui.GetScreenSize()` returns `w, h`.
- `ImGui.GetDeltaTime()`, `ImGui.GetTime()`, `ImGui.GetFrameCount()`.
- `ImGui.GetFontSize()`, `ImGui.GetTextLineHeight()`, `ImGui.GetTextLineHeightWithSpacing()`.
- `ImGui.GetUIScale()` / `ImGui.SetUIScale(s, px, py)` - global scale around a pivot point.
- `ImGui.GetClipboardText()` / `ImGui.SetClipboardText(s)`.
- `ImGui.LoadIniSettings(path)` / `ImGui.SaveIniSettings(path)`.
- `ImGui.VERSION` - library version string.
```

> Some entries are grouped lists rather than full prose. Every name above is a real function on the
> `ImGui` table; signatures are taken straight from `imgui_lua.lua`.
