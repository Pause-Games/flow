# Tutorial 4 — Interactive UI

Flow UIs are declarative: `view()` returns a tree, and Flow renders it. Making a UI interactive means mutating state and triggering a re-render. This tutorial covers the full pattern.

---

## The Button Component

`Button` is a clickable box with an `on_click` callback and a pressed visual state:

```lua
local Button = flow.ui.cp.Button
local Text   = flow.ui.cp.Text

Button({
  key      = "my_btn",
  style    = { width = 160, height = 48 },
  color    = vmath.vector4(0.2, 0.4, 0.9, 1),
  on_click = function()
    print("clicked!")
  end,
  children = {
    Text({ key = "lbl", text = "Click me", style = { width = "100%", height = "100%" } })
  }
})
```

Key fields:

| Field | Description |
|-------|-------------|
| `key` | Required |
| `style` | Layout properties |
| `color` | Normal color |
| `pressed_color` | Color while pressed. Defaults to 70% brightness of `color` |
| `image` | Optional GUI atlas animation id for an image-backed button background |
| `texture` | Optional GUI texture name for `image` (defaults to `"icons"`) |
| `border` | Optional slice-9 inset for image-backed buttons; number or `{ left, top, right, bottom }` |
| `on_click` | Called on release when the pointer is still over the button |
| `children` | Visual content (typically a `Text` label or `Icon`) |

When `image` is set, `Button` still behaves exactly like a normal button. The only difference is that its background comes from a GUI texture/atlas instead of a flat color.
On desktop-style pointer move events, `Button` also applies a tiny hover scale automatically.

Hover does not require a special input action in `game.input_binding`. In Defold desktop builds, Flow reads the regular mouse-move callback data automatically.

```lua
function on_input(self, action_id, action)
  return flow.on_input(self, action_id, action)
end
```

---

## Rounded and Textured Buttons

You can keep using `Button` and add a textured background plus slice-9 border:

```lua
Button({
  key      = "play_round",
  image    = "button_rounded",
  texture  = "button_shapes",
  border   = 18,
  style    = { width = 180, height = 52, padding_left = 18, padding_right = 18 },
  color    = vmath.vector4(0.2, 0.5, 0.9, 1),
  on_click = function()
    print("play")
  end,
  children = {
    Text({ key = "lbl", text = "Play", style = { width = "100%", height = "100%" } })
  }
})
```

Use this when you want the same text/icon-button behavior, but with a curved or decorative background image. For rounded backgrounds, add horizontal padding so text does not sit against the slice-9 corners.

---

## ButtonImage

`ButtonImage` is a convenience wrapper over `Button` for image-backed buttons. It requires `image` and keeps the same click behavior and pressed-state feedback.

```lua
local ButtonImage = flow.ui.cp.ButtonImage

ButtonImage({
  key      = "promo",
  image    = "castle_siege",
  texture  = "guide",
  style    = { width = 220, height = 100, justify_content = "end", padding_bottom = 10 },
  on_click = function()
    print("promo clicked")
  end,
  children = {
    Text({ key = "promo_lbl", text = "Open Guide", style = { height = 24 } })
  }
})
```

Use `ButtonImage` when the image itself is the button. Use `Button` with `image`/`border` when you want a shaped button background.

---

## Mutating State

Each screen on the navigation stack has a persistent `params` table. This is where you store screen-local state.

The pattern:
1. Initialize fields in `params` with `or` guards at the top of `view()`.
2. Mutate them inside `on_click`.
3. Call `flow.nav.invalidate()` to schedule a re-render.

```lua
view = function(params, nav)
  params.count = params.count or 0

  return Box({
    key = "root",
    style = { width = "100%", height = "100%", align_items = "center", justify_content = "center", gap = 16 },
    children = {
      Text({ key = "counter", text = "Count: " .. params.count, style = { height = 40 } }),
      Button({
        key      = "inc",
        style    = { width = 120, height = 44 },
        color    = vmath.vector4(0.2, 0.6, 0.3, 1),
        on_click = function()
          params.count = params.count + 1
          flow.nav.invalidate()
        end,
        children = { Text({ key = "lbl", text = "+1", style = { width = "100%", height = "100%" } }) }
      }),
    }
  })
end
```

`flow.nav.invalidate()` flags the navigation system to rebuild the active screen's tree on the next frame. The new `view()` call will see the updated `params.count`.

---

## Toggle State

The same pattern works for boolean toggles:

```lua
local ON_COLOR  = vmath.vector4(0.2, 0.7, 0.3, 1)
local OFF_COLOR = vmath.vector4(0.4, 0.4, 0.4, 1)

view = function(params, nav)
  params.enabled = params.enabled ~= false  -- default true

  return Button({
    key      = "toggle",
    style    = { width = 140, height = 44 },
    color    = params.enabled and ON_COLOR or OFF_COLOR,
    on_click = function()
      params.enabled = not params.enabled
      flow.nav.invalidate()
    end,
    children = {
      Text({ key = "lbl", text = params.enabled and "ON" or "OFF", style = { width = "100%", height = "100%" } })
    }
  })
end
```

---

## Selectable List Items

For a list of selectable items, store the selected index in params:

```lua
local items = { "Apple", "Banana", "Cherry" }

local SELECTED   = vmath.vector4(0.2, 0.4, 0.8, 1)
local UNSELECTED = vmath.vector4(0.2, 0.2, 0.25, 1)

view = function(params, nav)
  params.selected = params.selected or 1

  local rows = {}
  for i, name in ipairs(items) do
    local idx = i  -- capture loop variable
    table.insert(rows, Button({
      key      = "item_" .. i,
      style    = { height = 52, padding_left = 16, align_items = "center" },
      color    = (params.selected == idx) and SELECTED or UNSELECTED,
      on_click = function()
        params.selected = idx
        flow.nav.invalidate()
      end,
      children = { Text({ key = "lbl_" .. i, text = name, style = { height = 24 } }) }
    }))
  end

  return Box({
    key      = "root",
    style    = { width = "100%", height = "100%", flex_direction = "column", gap = 4, padding = 16 },
    children = rows,
  })
end
```

---

## Text Alignment in Buttons

Button text alignment is controlled by the button's `justify_content` and the text node's `align`:

```lua
-- Left-aligned label
Button({
  key   = "btn",
  style = { height = 52, flex_direction = "row", justify_content = "start", padding_left = 16 },
  children = { Text({ key = "lbl", text = "Left", style = { height = 24 } }) }
})

-- Centered label
Button({
  key   = "btn",
  style = { height = 52, flex_direction = "row", justify_content = "center" },
  children = { Text({ key = "lbl", text = "Center", align = "center", style = { height = 24 } }) }
})

-- Right-aligned label
Button({
  key   = "btn",
  style = { height = 52, flex_direction = "row", justify_content = "end", padding_right = 16 },
  children = { Text({ key = "lbl", text = "Right", align = "right", style = { height = 24 } }) }
})
```

---

## Icon Buttons

Combine `Icon` and `Text` for a labeled icon button:

```lua
local Icon = flow.ui.cp.Icon

Button({
  key   = "settings_btn",
  style = { width = 140, height = 48, flex_direction = "row", align_items = "center",
            justify_content = "center", gap = 8 },
  color = vmath.vector4(0.2, 0.2, 0.25, 1),
  on_click = function()
    flow.nav.push("settings", {})
  end,
  children = {
    Icon({ key = "icon",  image = "icon_settings", style = { width = 24, height = 24 } }),
    Text({ key = "label", text = "Settings",       style = { height = 24 } }),
  }
})
```

The `icon` primitive requires the atlas to be registered in your `.gui` file. The default texture name is `"icons"`.

---

## Disabling a Button

Flow doesn't have a built-in disabled state, but you can implement it:

```lua
local ACTIVE   = vmath.vector4(0.2, 0.5, 0.9, 1)
local DISABLED = vmath.vector4(0.3, 0.3, 0.35, 1)

Button({
  key   = "submit",
  style = { width = 160, height = 48 },
  color = params.can_submit and ACTIVE or DISABLED,
  on_click = function()
    if not params.can_submit then return end
    -- proceed
  end,
  children = { Text({ key = "lbl", text = "Submit", style = { width = "100%", height = "100%" } }) }
})
```

---

## Re-render Timing

`flow.nav.invalidate()` is **lazy** — it schedules a re-render for the next frame. Multiple calls in the same frame are collapsed into a single re-render. This means you can safely call it from several `on_click` handlers without triggering extra renders.

---

## Next

[Tutorial 5 — Scroll & Lists](05-scroll-and-lists.md): add scrollable containers and handle large lists efficiently with virtual scrolling.
