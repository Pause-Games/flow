# Getting Started

This guide walks you from zero to a working Flow screen inside a Defold project.

---

## Prerequisites

- A Defold project (version 1.6+ recommended)
- Basic familiarity with Defold GUI scripts and collections

---

## 1. Add Flow to Your Project

Preferred: add Flow as a Defold library dependency in your game's `game.project`:

```ini
[project]
dependencies#0 = https://github.com/Pause-Games/flow/archive/refs/heads/main.zip
```

Or pin a release tag:

```ini
[project]
dependencies#0 = https://github.com/Pause-Games/flow/archive/refs/tags/v1.0.0.zip
```

After that, run `Project -> Fetch Libraries` in the Defold editor.

Flow exports only the `flow/` directory through Defold's library mechanism, so your own project stays clean and you can require it directly:

```lua
local flow = require "flow/flow"
```

Manual alternative: copy the `flow/` directory into your Defold project root. Your project tree should look like:

```
my_game/
  flow/
    flow.lua
    layout.lua
    ui.lua
    flex.lua
    navigation/
    components/
    ...
  main.collection
  game.project
```

No native extensions, no external dependencies. Flow is pure Lua.

---

## 2. Create a GUI Scene

Add a `.gui` file (e.g. `ui/main.gui`) in the Defold editor and attach a gui script to it.

Flow creates its runtime GUI nodes itself, so you do not need to add a root box node such as `ui_root`. The `.gui` must only provide the fonts, textures, and material that your components need.

If you want to use `Text({ font = "heading" })`, register that font name in the `.gui` first:

```text
fonts {
  name: "default"
  font: "/builtins/fonts/default.font"
}
fonts {
  name: "heading"
  font: "/main/fonts/heading.font"
}
```

---

## 3. Wire Up the GUI Script

Create `ui/main.gui_script` and paste:

```lua
local flow = require "flow/flow"

local SCREENS = {
  home = {
    view = function(params, nav)
      local Box  = flow.ui.cp.Box
      local Text = flow.ui.cp.Text

      return Box({
        key   = "root",
        style = { width = "100%", height = "100%", padding = 32 },
        children = {
          Text({ key = "hello", text = "Hello, Flow!", font = "heading", style = { height = 40 } }),
          Text({ key = "body", text = "Registered GUI fonts can be selected per label.", style = { height = 28 } }),
        }
      })
    end,
  },
}

function init(self)
  flow.init(self, {
    screens        = SCREENS,
    initial_screen = "home",
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

Attach this script to your GUI scene.

`Text.font` is optional. When omitted, Flow uses the `.gui` font named `"default"`.

---

## 4. Add Input Binding

Open `input/game.input_binding` (or create one) and add:

| Trigger | Action |
|---------|--------|
| `Mouse Button 1` | `touch` |
| `Mouse Wheel Up` | `scroll_up` |
| `Mouse Wheel Down` | `scroll_down` |

Flow's input system uses the `touch`, `scroll_up`, and `scroll_down` action names. Desktop hover on buttons uses Defold's regular mouse-move events automatically; no extra action binding is needed.

---

## 5. Run It

Build and run in the Defold editor (`Cmd+B` on macOS, `F5` on Windows). You should see "Hello, Flow!" rendered in the top-left corner of the screen.

---

## What Just Happened

`flow.init` did three things:

1. Acquired input focus (`msg.post(".", "acquire_input_focus")`).
2. Mounted the renderer state on the gui script instance and prepared runtime node caching.
3. Registered your screens and navigated to `"home"`.

Each frame, `flow.update` calls the active screen's `view()` function, computes flex layout, and updates Defold GUI nodes — creating new ones or reusing cached ones based on their `key`.

---

## Next Steps

- [Tutorial 1 — First Screen](tutorials/01-first-screen.md): deeper walkthrough of `Box`, `Text`, and style properties
- [Tutorial 2 — Layout & Style](tutorials/02-layout-and-style.md): flex direction, justify, alignment, gap, and padding
- [Tutorial 3 — Navigation](tutorials/03-navigation.md): push/pop screens with params and transitions
