# Tutorial 6 — Overlays

Flow provides two overlay primitives: `Popup` (centered modal dialog) and `BottomSheet` (panel that slides up from the bottom). Both render on top of all other content and block input to elements beneath them.

---

## Popup

A `Popup` covers the full screen with a semi-transparent backdrop. Content is positioned inside it using flex layout.

### Basic usage

```lua
local Popup = flow.ui.cp.Popup

-- Conditionally include the popup in the tree
if params.show_confirm then
  table.insert(children, Popup({
    key            = "confirm",
    style          = { width = "100%", height = "100%", align_items = "center", justify_content = "center" },
    backdrop_color = vmath.vector4(0, 0, 0, 0.7),
    _visible       = true,
    on_backdrop_click = function()
      params.show_confirm = false
      flow.nav.mark_dirty()
    end,
    children = {
      Box({
        key   = "dialog",
        color = vmath.vector4(0.15, 0.17, 0.22, 1),
        style = { width = 320, height = 180, flex_direction = "column",
                  align_items = "center", justify_content = "center", gap = 20, padding = 24 },
        children = {
          Text({ key = "msg",  text = "Are you sure?", style = { height = 32 } }),
          Box({
            key   = "btns",
            style = { height = 44, flex_direction = "row", gap = 12 },
            children = {
              Button({
                key = "cancel", style = { width = 100, height = 44 },
                color = vmath.vector4(0.4, 0.3, 0.3, 1),
                on_click = function()
                  params.show_confirm = false
                  flow.nav.mark_dirty()
                end,
                children = { Text({ key = "lbl", text = "Cancel", style = { width = "100%", height = "100%" } }) }
              }),
              Button({
                key = "ok", style = { width = 100, height = 44 },
                color = vmath.vector4(0.3, 0.55, 0.3, 1),
                on_click = function()
                  params.show_confirm = false
                  params.confirmed    = true
                  flow.nav.mark_dirty()
                end,
                children = { Text({ key = "lbl", text = "OK", style = { width = "100%", height = "100%" } }) }
              }),
            }
          }),
        }
      })
    }
  }))
end
```

### Opening the popup

```lua
Button({
  key      = "open_btn",
  on_click = function()
    params.show_confirm = true
    flow.nav.mark_dirty()
  end,
  ...
})
```

### Key rules for Popup

- The `Popup` itself must be added as a **sibling** of other content, not a child of a flex container that constrains its size. It bypasses flex layout and always fills its parent bounds.
- Content boxes (the `"dialog"` box above) **must have an explicit `height`**. Auto/intrinsic heights are not supported.
- Set `_visible = false` (or omit the popup from the tree) to hide it — nodes are cleaned up automatically.

### Popup layout patterns

| Intent | `style` on Popup |
|--------|-----------------|
| Centered dialog | `align_items = "center", justify_content = "center"` |
| Top sheet | `align_items = "stretch", justify_content = "start"` |
| Bottom sheet (static) | `align_items = "stretch", justify_content = "end"` |

---

## Bottom Sheet

`BottomSheet` is an overlay anchored to the bottom of the screen. It has two operating modes.

### Legacy mode (`_visible`)

Nodes are created/destroyed based on `_visible`. No animation.

```lua
local BottomSheet = flow.ui.cp.BottomSheet

BottomSheet({
  key            = "actions",
  backdrop_color = vmath.vector4(0, 0, 0, 0.5),
  _visible       = params.show_sheet,
  on_backdrop_click = function()
    params.show_sheet = false
    flow.nav.mark_dirty()
  end,
  children = {
    Box({
      key   = "sheet_content",
      color = vmath.vector4(0.15, 0.17, 0.22, 1),
      style = { width = "100%", height = 220, flex_direction = "column", gap = 0 },
      children = {
        -- Handle bar
        Box({
          key   = "handle_wrap",
          color = vmath.vector4(0, 0, 0, 0),
          style = { height = 24, align_items = "center", justify_content = "center" },
          children = {
            Box({ key = "handle", color = vmath.vector4(0.4, 0.4, 0.4, 1),
                  style = { width = 40, height = 5 } }),
          }
        }),
        Button({
          key   = "share", style = { height = 52, padding_left = 20, align_items = "center" },
          color = vmath.vector4(0.2, 0.2, 0.25, 1),
          on_click = function()
            params.show_sheet = false; flow.nav.mark_dirty()
          end,
          children = { Text({ key = "lbl", text = "Share", style = { height = 28 } }) }
        }),
        Button({
          key   = "delete", style = { height = 52, padding_left = 20, align_items = "center" },
          color = vmath.vector4(0.3, 0.15, 0.15, 1),
          on_click = function()
            params.show_sheet = false; flow.nav.mark_dirty()
          end,
          children = { Text({ key = "lbl", text = "Delete", style = { height = 28 } }) }
        }),
      }
    })
  }
})
```

### Animated mode (`_open`)

When `_open` is provided, the sheet always has nodes in the tree and uses a spring animation to slide in and out. The animation state must be persisted across re-renders via `_on_anim_update`.

```lua
BottomSheet({
  key            = "actions",
  backdrop_color = vmath.vector4(0, 0, 0, 0.5),
  _open          = params.show_sheet,           -- true = open, false = closed
  _anim_y        = params.sheet_anim_y,         -- persisted animation position
  _anim_velocity = params.sheet_anim_vel,       -- persisted animation velocity
  _on_anim_update = function(anim_y, velocity)
    params.sheet_anim_y   = anim_y
    params.sheet_anim_vel = velocity
    flow.nav.mark_dirty()
  end,
  on_backdrop_click = function()
    params.show_sheet = false
    flow.nav.mark_dirty()
  end,
  children = {
    Box({
      key   = "sheet_content",
      color = vmath.vector4(0.15, 0.17, 0.22, 1),
      style = { width = "100%", height = 240, flex_direction = "column", padding = 20, gap = 12 },
      children = {
        Text({ key = "title",  text = "Options",  style = { height = 32 } }),
        Text({ key = "detail", text = "Choose an action below", style = { height = 24 } }),
      }
    })
  }
})
```

**Important**: When the window resizes, the animation position resets. Clear `sheet_anim_y` and `sheet_anim_vel` from params in that case to avoid visual glitches.

---

## Combining Overlays with Screen Content

Both `Popup` and `BottomSheet` must be added **at the top level of your tree** as siblings of other content boxes. They bypass normal flex layout and always receive the full parent bounds.

```lua
view = function(params, nav)
  local children = {
    -- Normal screen content
    Box({ key = "header", ... }),
    Box({ key = "body",   ... }),
  }

  -- Conditionally append overlays
  if params.show_popup then
    table.insert(children, Popup({ key = "confirm", ... }))
  end

  if params.show_sheet then
    table.insert(children, BottomSheet({ key = "actions", ... }))
  end

  return Box({
    key      = "root",
    style    = { width = "100%", height = "100%", flex_direction = "column" },
    children = children,
  })
end
```

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Content box has no `height` | Always set explicit `height` on direct children of overlays |
| Overlay is nested inside a sized container | Overlays must be top-level children |
| Animation state not persisted | Use `_on_anim_update` to store `anim_y`/`velocity` in params |
| Forgetting `mark_dirty()` after closing | Always call `flow.nav.mark_dirty()` after changing `show_popup` / `show_sheet` |

---

## Congratulations

You've completed all six tutorials. You now know how to:

1. Build and mount a screen with `Box` and `Text`
2. Control layout with flex direction, justify, align, gap, and padding
3. Navigate between screens with params, transitions, and result callbacks
4. Build interactive UIs with buttons and state mutation
5. Handle large lists efficiently with virtual scrolling
6. Add modal popups and animated bottom sheets

**Recommended next reads:**
- [Best Practices](../guides/best-practices.md) — key rules to keep your app correct and performant
- [Debugging](../guides/debugging.md) — how to enable debug output and targeted logging
- [API Reference](../../specs/README.md) — full module-level specifications
