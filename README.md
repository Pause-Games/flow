# Flow — Flex UI Library for Defold

Flow is a Defold library that implements a CSS Flexbox-inspired UI system in pure Lua.
No native extensions. No HTML. Just runtime-created GUI nodes with layout computed in Lua.

## Install

Add Flow as a Defold library dependency in your game's `game.project`:

```ini
[project]
dependencies#0 = https://github.com/Pause-Games/flow/archive/refs/heads/main.zip
```

Or pin a tag:

```ini
[project]
dependencies#0 = https://github.com/Pause-Games/flow/archive/refs/tags/v1.0.0.zip
```

This repository exports the `flow/` directory through Defold's `[library] include_dirs`, so after fetching libraries you can require:

```lua
local flow = require "flow/flow"
```

Input bindings are not applied automatically from a dependency. Add `touch`, `scroll_up`, and `scroll_down` in your own project's input binding file.

## Quick Start

```lua
local flow = require "flow/flow"

function init(self)
  flow.init(self, {
    initial_screen = "hub",
    screens = require "sample/screens",
  })
end

function final(self)
  flow.final(self)
end

function update(self, dt)
  flow.update(self, dt)
end

function on_input(self, action_id, action)
  return flow.on_input(self, action_id, action)
end

function on_message(self, message_id, message, sender)
  return flow.on_message(self, message_id, message, sender)
end
```

For Defold lifecycle callbacks, prefer `flow.init`, `flow.update`, `flow.on_input`, and `flow.on_message`.
For low-level renderer helpers, use `flow.ui.*`.
For primitive UI constructors, use `flow.ui.cp.*`.
For navigation helpers, message transport, and non-GUI runtime helpers, use `flow.nav.*`.
For centralized logging, use `flow.log.*`.

## Modules

**Library** (`flow/`):

- `flow/flow.lua` — main facade: wires renderer, navigation, logging, and all components; exposes `flow.ui`, `flow.ui.cp`, `flow.nav`, and `flow.log`
- `flow/ui.lua` — low-level renderer, input, and animation dispatcher behind `flow.ui`
- `flow/layout.lua` — pure Flexbox layout computation (no Defold deps)
- `flow/flex.lua` — Yoga-compatible imperative API, exposed as `flow.ui.Flex`
- `flow/navigation` — stack-based navigation with animated transitions behind `flow.nav`
  - `flow/navigation/init.lua` — singleton facade used by `flow.nav`
  - `flow/navigation/core.lua` — pure router (push/pop/replace/reset)
  - `flow/navigation/gui.lua` — GUI adapter available as `flow.nav.gui`
  - `flow/navigation/messages.lua` — message transport helper exposed on `flow.nav`
  - `flow/navigation/proxy.lua` — optional runtime helper exposed as `flow.nav.proxy`
  - `flow/navigation/runtime.lua` — non-GUI bootstrap exposed as `flow.nav.runtime`
- `flow/components/` — UI components (box, text, button, icon, scroll, popup, bottom_sheet, markdown)
- `flow/types.lua` — LuaLS type definitions

**Sample** (`sample/`):

- `sample/screens.lua` — demo screens
- `sample/navigation_bootstrap.script` — example `.script` integration

## Navigation Outside GUI

For screens driven by a plain `.script` (e.g. a gameplay controller with a collection proxy):

```lua
local flow = require "flow/flow"

function init(self)
  flow.nav.runtime.init(self, {
    screens = {
      gameplay = {
        url = msg.url("main:/gameplay_controller#script"),
        proxy_url = msg.url("main:/gameplay_proxy#collectionproxy"),
        preload = true,
      },
    },
    initial_screen = "gameplay",
  })
end

function final(self)
  flow.nav.runtime.final(self)
end

function on_message(self, message_id, message, sender)
  if flow.nav.runtime.on_message(self, message_id, message, sender) then
    return
  end
end
```

## Components

```lua
local flow = require "flow/flow"

local Box         = flow.ui.cp.Box
local Text        = flow.ui.cp.Text
local Button      = flow.ui.cp.Button
local ButtonImage = flow.ui.cp.ButtonImage
local Icon        = flow.ui.cp.Icon
local Scroll      = flow.ui.cp.Scroll
local Popup       = flow.ui.cp.Popup
local BottomSheet = flow.ui.cp.BottomSheet
local Markdown    = flow.ui.cp.Markdown
```

Example:

```lua
local flow = require "flow/flow"
local Box = flow.ui.cp.Box
local Text = flow.ui.cp.Text
local Button = flow.ui.cp.Button
local ButtonImage = flow.ui.cp.ButtonImage

return Box({
  key = "root",
  style = { width = "100%", height = "100%", padding = 20 },
  children = {
    Text({ key = "title", text = "Hello", style = { height = 32 } }),
    Text({ key = "subtitle", text = "Brand", font = "heading", style = { height = 28 } }),
    Button({
      key = "cta",
      style = { width = 180, height = 56 },
      on_click = function() print("clicked") end,
      children = {
        Text({ key = "cta_label", text = "Continue", style = { width = "100%", height = "100%" } })
      }
    }),
    Button({
      key = "cta_round",
      image = "button_rounded",
      texture = "button_shapes",
      border = 18,
      color = "#3885e6",
      style = { width = 220, height = 56 },
      on_click = function() print("rounded clicked") end,
      children = {
        Text({ key = "cta_round_label", text = "Rounded Button", style = { width = "100%", height = "100%" } })
      }
    }),
    ButtonImage({
      key = "cta_image",
      image = "castle_siege",
      texture = "guide",
      style = { width = 220, height = 96, justify_content = "end", padding_bottom = 10 },
      on_click = function() print("image clicked") end,
      children = {
        Text({ key = "cta_image_label", text = "ButtonImage", style = { height = 24 } })
      }
    })
  }
})
```

## Notes

- Primitive constructors live under `flow.ui.cp.*`.
- `flow.ui.components.*` is also available as a longer alias for the same constructors.
- `Text` accepts `font = "name"` for any font registered in the owning `.gui`; it falls back to `"default"`.
- Color props accept CSS-like strings such as `"#778899"` and `"rgba(119, 136, 153, 0.5)"`, plus helper values from `flow.color.rgb(...)` / `flow.color.rgba(...)`.
- `Button` can use a texture/image background and slice-9 border via `image`, `texture`, and `border`.
- `ButtonImage` is a convenience wrapper around `Button` for image-backed buttons.
- Component behaviors are self-registered; simply requiring the component module is enough.
- Layout is GUI-space only. Window-space mode is intentionally internal.

## Documentation

| | |
|-|-|
| [Getting Started](docs/getting-started.md) | Install Flow as a dependency and build your first screen |
| [Architecture](docs/architecture.md) | How the three layers fit together |
| **Tutorials** | |
| [1 — First Screen](docs/tutorials/01-first-screen.md) | `Box`, `Text`, mounting a GUI |
| [2 — Layout & Style](docs/tutorials/02-layout-and-style.md) | Flex direction, justify, align, gap, padding |
| [3 — Navigation](docs/tutorials/03-navigation.md) | Screens, push/pop, params, transitions |
| [4 — Interactive UI](docs/tutorials/04-interactive-ui.md) | Buttons, ButtonImage, rounded backgrounds, hover, state mutation |
| [5 — Scroll & Lists](docs/tutorials/05-scroll-and-lists.md) | Scroll containers and virtual scrolling |
| [6 — Overlays](docs/tutorials/06-overlays.md) | Popup, bottom sheet, animated slide-in |
| **Guides** | |
| [Best Practices](docs/guides/best-practices.md) | Keys, node budget, dirty tracking, patterns |
| [Debugging](docs/guides/debugging.md) | Debug mode, log levels, context overrides |
| **API Reference** | |
| [specs/](specs/README.md) | Module-level API specs |
