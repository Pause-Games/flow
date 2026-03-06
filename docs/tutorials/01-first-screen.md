# Tutorial 1 — First Screen

In this tutorial you'll build a simple screen with a title, a subtitle, and a colored background panel. Along the way you'll learn how Flow's declarative tree works and how the renderer updates Defold GUI nodes.

**Prerequisites**: Complete [Getting Started](../getting-started.md) first.

---

## What You'll Build

A centered card with:
- A dark background
- A bold title
- A muted subtitle

---

## Step 1 — The Minimal Screen

A Flow screen is a Lua table with a `view` function that returns an element tree:

```lua
local flow = require "flow/flow"
local Box  = flow.ui.cp.Box
local Text = flow.ui.cp.Text

local my_screen = {
  view = function(params, nav)
    return Box({
      key   = "root",
      style = { width = "100%", height = "100%" },
    })
  end,
}
```

`Box` is the basic container — like a `<div>`. Every element needs a **`key`**: a stable string that the renderer uses to cache and reuse Defold GUI nodes.

---

## Step 2 — Add Children

Elements are nested via the `children` table:

```lua
return Box({
  key   = "root",
  style = { width = "100%", height = "100%" },
  children = {
    Text({ key = "title", text = "Flow UI", style = { height = 40 } }),
    Text({ key = "sub",   text = "Tutorial 1", style = { height = 28 } }),
  }
})
```

A few things to note:
- `Text` always needs a `height` (Flow doesn't measure text intrinsically).
- Children stack **top-to-bottom** by default (`flex_direction = "column"`).
- `width = "100%"` on a child stretches it to the parent's inner width.

---

## Step 3 — Add Color

Both `Box` and `Text` accept a `color` field (a `vmath.vector4`):

```lua
local WHITE  = vmath.vector4(1, 1, 1, 1)
local MUTED  = vmath.vector4(0.7, 0.7, 0.7, 1)
local DARK   = vmath.vector4(0.1, 0.12, 0.15, 1)
```

```lua
return Box({
  key   = "root",
  color = DARK,
  style = { width = "100%", height = "100%", padding = 40 },
  children = {
    Text({ key = "title", text = "Flow UI",    color = WHITE, style = { height = 48 } }),
    Text({ key = "sub",   text = "Tutorial 1", color = MUTED, style = { height = 28 } }),
  }
})
```

---

## Step 4 — Center the Content

Use `align_items` and `justify_content` on the root box to center children:

```lua
style = {
  width           = "100%",
  height          = "100%",
  flex_direction  = "column",
  align_items     = "center",
  justify_content = "center",
  gap             = 12,
}
```

- `align_items = "center"` — centers children on the **cross axis** (horizontal in a column).
- `justify_content = "center"` — centers children on the **main axis** (vertical in a column).
- `gap = 12` — adds 12px between each child.

---

## Step 5 — Build a Card

Wrap the text in a card box with its own background and padding:

```lua
local CARD = vmath.vector4(0.18, 0.2, 0.25, 1)

return Box({
  key   = "root",
  color = DARK,
  style = {
    width           = "100%",
    height          = "100%",
    align_items     = "center",
    justify_content = "center",
  },
  children = {
    Box({
      key   = "card",
      color = CARD,
      style = {
        width          = 320,
        height         = 160,
        flex_direction = "column",
        align_items    = "center",
        justify_content = "center",
        gap            = 12,
        padding        = 24,
      },
      children = {
        Text({ key = "title", text = "Flow UI",    color = WHITE, style = { height = 40 } }),
        Text({ key = "sub",   text = "Tutorial 1", color = MUTED, style = { height = 24 } }),
      }
    })
  }
})
```

---

## Step 6 — Register and Run

Register this screen with Flow:

```lua
function init(self)
  flow.init(self, {
    screens = {
      home = my_screen,
    },
    initial_screen = "home",
  })
end
```

Run the project. You should see a centered dark card with title and subtitle on a darker background.

---

## What You Learned

| Concept | Detail |
|---------|--------|
| `Box` | Generic container, maps to a Defold box node |
| `Text` | Text label; always needs explicit `height` |
| `key` | Required on every element; must be stable and unique |
| `style` | Flex layout properties |
| `color` | `vmath.vector4` fill color |
| `children` | Ordered list of child elements |
| `flex_direction` | Stack direction: `"column"` (default) or `"row"` |
| `align_items` | Cross-axis alignment: `"center"`, `"start"`, `"end"`, `"stretch"` |
| `justify_content` | Main-axis distribution: `"center"`, `"start"`, `"end"`, `"space-between"`, … |
| `gap` | Pixels of space between children |
| `padding` | Inner inset (uniform or per-side) |

---

## Next

[Tutorial 2 — Layout & Style](02-layout-and-style.md): explore the full layout system with rows, percentages, and cross-axis alignment in depth.
