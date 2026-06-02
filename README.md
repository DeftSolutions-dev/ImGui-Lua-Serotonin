# ImGui Lua Serotonin

A Dear ImGui-style UI written in pure Lua for the Serotonin scripting sandbox. Everything is drawn
on top of the sandbox `draw` API, with no native windows and no external UI library. The repo ships
two things:

- `imgui_lua.lua` - a single-file immediate-mode UI library (a Dear ImGui port). See [docs/imgui_lua.md](docs/imgui_lua.md).
- **DesirePro** - a full, themed menu built on that library (`desirepro.lua` + assets).

## Quick start (DesirePro menu)

1. install the files (see Install below)
2. in the Serotonin scripting tab, run `desirepro_menu.lua`
3. press `F8` to toggle the menu

## Features (DesirePro)

- widgets: cards, sliders, toggles, combos, multi-combos, colour picker, keybinds, text input
- ESP preview with drag-to-reposition labels and per-label colour
- 6 languages (en, ru, zh, ja, vi, id), switchable live in the Lang tab
- light / dark theme, window dockable to any of the 4 screen edges
- particle and slide-in animations, red to blue gradient accent

## Layout

```
Serotonin/
  scripts/
    desirepro_menu.lua    entry point, load this one
    desirepro.lua         menu and widget layer
    imgui_lua.lua         the ImGui library (engine)
  files/
    desirepro/
      metrics.lua         glyph and icon atlas metrics (read at startup)
      localization.lua    translations: en, ru, zh, ja, vi, id
      glyph/              baked text glyphs (all weights, all 6 languages)
      icon/               baked UI icons (full set, all sizes)
      icon_grad/          accent icons with the red-blue gradient
      img/                esp background, toggle capsule
      shadow/             soft-shadow sprites
docs/
  imgui_lua.md            library API reference
```

The whole icon set and all 6-language glyphs are included, even ones the current menu does not use
yet. Only build inputs are left out (source `.ttf` fonts and `metrics.json`; the runtime reads
`metrics.lua`).

## Install

1. copy `Serotonin\scripts\*` into `C:\Serotonin\scripts\`
2. copy `Serotonin\files\desirepro\` into `C:\Serotonin\files\desirepro\`
3. in the Serotonin scripting tab, run `desirepro_menu.lua`
4. press `F8` to toggle the menu

If Serotonin is installed somewhere other than `C:\Serotonin`, edit the two `dofile(...)` paths at
the top of `desirepro_menu.lua` and `desirepro.lua`.

## Localization

Translations live in `files/desirepro/localization.lua`, as
`["English"] = { ru = ..., zh = ..., ja = ..., vi = ..., id = ... }`. Missing keys fall back to
English. New non-Latin characters must be re-baked into the glyph atlas.

## Using the library on its own

```lua
local ImGui = dofile("C:/Serotonin/scripts/imgui_lua.lua")

local state = { enabled = false, amount = 50 }

ImGui.Setup(function()
    if ImGui.Begin("My Window") then
        state.enabled = ImGui.Checkbox("Enabled", state.enabled)
        state.amount  = ImGui.SliderInt("Amount", state.amount, 0, 100)
        if ImGui.Button("Run") then print("run", state.amount) end
        ImGui.End()
    end
end)

cheat.Register("onPaint", ImGui._OnPaint)
```

Press `F8` to toggle the window. Full API in [docs/imgui_lua.md](docs/imgui_lua.md).

## Credits

- UI design - **Lyapos**
