# Tutorial 3 — Navigation

Flow includes a stack-based navigation system. Think of it like a browser history: you push screens onto the stack and pop them off to go back. Each screen on the stack has its own `params` table that persists across re-renders.

---

## Registering Screens

Define each screen as a table with a `view` function, then register them all with `flow.init`:

```lua
local flow = require "flow/flow"
local Box  = flow.ui.cp.Box
local Text = flow.ui.cp.Text

local screens = {
  home = {
    view = function(params, nav)
      return Box({ key = "root", style = { width = "100%", height = "100%" },
        children = {
          Text({ key = "title", text = "Home", style = { height = 40 } }),
        }
      })
    end,
  },

  detail = {
    view = function(params, nav)
      return Box({ key = "root", style = { width = "100%", height = "100%" },
        children = {
          Text({ key = "title", text = params.title or "Detail", style = { height = 40 } }),
        }
      })
    end,
  },
}

function init(self)
  flow.init(self, { screens = screens, initial_screen = "home" })
end
```

---

## Pushing a Screen

Call `flow.nav.push(screen_id, params, options)` to navigate forward:

```lua
-- From inside a button's on_click:
on_click = function()
  flow.nav.push("detail", { title = "Item 42" })
end
```

The pushed screen receives the params table as the first argument to `view()`.

---

## Popping Back

Call `flow.nav.pop()` to return to the previous screen:

```lua
on_click = function()
  flow.nav.pop()
end
```

You can pass result data back to the calling screen:

```lua
flow.nav.pop({ saved = true, name = "edited value" })
```

---

## Receiving Results

Provide an `on_result` callback in the push options:

```lua
flow.nav.push("profile_editor", { user = current_user }, {
  on_result = function(result)
    if result and result.saved then
      current_user = result.user
      flow.nav.invalidate()
    end
  end,
})
```

`on_result` fires when the pushed screen pops (with or without data).

---

## Transitions

Pass a `transition` option to control the animation:

```lua
flow.nav.push("detail", params, { transition = "slide_left" })
flow.nav.pop(nil, "slide_right")
```

| Transition | Effect |
|------------|--------|
| `"none"` | Instant switch |
| `"fade"` | Cross-fade (default) |
| `"slide_left"` | New screen slides in from the right |
| `"slide_right"` | New screen slides in from the left |

For `pop`, use the mirror of the push transition:

```lua
-- Push forward:  slide_left
-- Pop back:      slide_right (or just omit — parent still visible)
```

---

## Replace and Reset

### Replace

Swaps the current screen without adding to the stack:

```lua
flow.nav.replace("other_screen", params)
```

Use this for login → home transitions where you don't want back navigation.

### Reset

Clears the entire stack and starts fresh:

```lua
flow.nav.reset("home", {})
```

---

## Accessing Screen Params

Inside `view()`, use the injected `params` argument:

```lua
view = function(params, nav)
  params.count = params.count or 0   -- initialize once

  return Text({ key = "count", text = tostring(params.count), style = { height = 40 } })
end
```

Mutating `params` directly is fine — it persists as long as the screen is on the stack.

You can also read params from outside `view()`:

```lua
flow.nav.get_data("count")                       -- current screen
flow.nav.get_data({ screen_id = "home" })        -- a specific screen
flow.nav.get_data("count", { screen_id = "home" }) -- field of a specific screen
```

---

## Lifecycle Hooks

Screens can declare optional hooks that fire on navigation events:

```lua
local my_screen = {
  view = function(params, nav) ... end,

  on_enter  = function(params, nav) flow.log.debug("nav", "entered %s", nav.current() and nav.current().id or "unknown") end,
  on_exit   = function(params, nav) flow.log.debug("nav", "exited %s", nav.current() and nav.current().id or "unknown") end,
  on_pause  = function(params, nav) flow.log.debug("nav", "covered by new screen") end,
  on_resume = function(params, nav) flow.log.debug("nav", "uncovered") end,
}
```

Hooks fire when the navigation action begins, not after a transition animation completes.

---

## Navigation State

```lua
flow.nav.current()      -- returns the current stack entry
flow.nav.stack_depth()  -- number of screens on the stack
flow.nav.is_busy()      -- true during an active transition
```

Use `flow.nav.current().id` when you need the current screen id.

---

## Message-Driven Navigation

You can also navigate by posting Defold messages — useful from game scripts:

```lua
msg.post("main:/ui#gui_script", "navigation_push", {
  id     = "inventory",
  params = { tab = "equipment" },
  options = { transition = "slide_left" },
})

msg.post("main:/ui#gui_script", "navigation_pop", {
  result = { saved = true },
})
```

Supported message ids: `navigation_push`, `navigation_pop`, `navigation_replace`, `navigation_reset`, `navigation_back`, `navigation_invalidate`.

Make sure `flow.on_message` is wired in your gui_script:

```lua
function on_message(self, message_id, message, sender)
  return flow.on_message(self, message_id, message, sender)
end
```

---

## Full Example

```lua
local flow   = require "flow/flow"
local Box    = flow.ui.cp.Box
local Text   = flow.ui.cp.Text
local Button = flow.ui.cp.Button

local WHITE = vmath.vector4(1, 1, 1, 1)
local BLUE  = vmath.vector4(0.2, 0.4, 0.9, 1)
local DARK  = vmath.vector4(0.1, 0.12, 0.15, 1)

local screens = {
  home = {
    view = function(params, nav)
      return Box({
        key = "root", color = DARK,
        style = { width = "100%", height = "100%", align_items = "center", justify_content = "center", gap = 16 },
        children = {
          Text({ key = "title", text = "Home", color = WHITE, style = { height = 48 } }),
          Button({
            key = "go_btn",
            color = BLUE,
            style = { width = 200, height = 48 },
            on_click = function()
              flow.nav.push("detail", { item = "Widget #1" }, { transition = "slide_left" })
            end,
            children = { Text({ key = "lbl", text = "Open Detail", style = { width = "100%", height = "100%" } }) }
          }),
        }
      })
    end,
  },

  detail = {
    view = function(params, nav)
      return Box({
        key = "root", color = DARK,
        style = { width = "100%", height = "100%", align_items = "center", justify_content = "center", gap = 16 },
        children = {
          Text({ key = "title", text = params.item or "Detail", color = WHITE, style = { height = 48 } }),
          Button({
            key = "back_btn",
            color = BLUE,
            style = { width = 160, height = 48 },
            on_click = function()
              flow.nav.pop(nil, "slide_right")
            end,
            children = { Text({ key = "lbl", text = "Back", style = { width = "100%", height = "100%" } }) }
          }),
        }
      })
    end,
  },
}

function init(self)
  flow.init(self, { screens = screens, initial_screen = "home" })
end
-- ... final, update, on_input, on_message as usual
```

---

## Next

[Tutorial 4 — Interactive UI](04-interactive-ui.md): learn how to use buttons, toggle state, and trigger re-renders correctly.
