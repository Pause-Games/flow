# Tutorial 6 — Overlays

Flow provides two overlay systems: `Popup` (centered modal dialog in the current tree) and `flow.bottom_sheet` (a hosted panel rendered by a dedicated gui instance). Both render on top of other content and block input beneath them.

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
    backdrop_color = "#000000b3",
    _visible       = true,
    on_backdrop_click = function()
      params.show_confirm = false
      flow.nav.invalidate()
    end,
    children = {
      Box({
        key   = "dialog",
        color = "#262b38",
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
                color = "#664d4d",
                on_click = function()
                  params.show_confirm = false
                  flow.nav.invalidate()
                end,
                children = { Text({ key = "lbl", text = "Cancel", style = { width = "100%", height = "100%" } }) }
              }),
              Button({
                key = "ok", style = { width = 100, height = 44 },
                color = "#4d8c4d",
                on_click = function()
                  params.show_confirm = false
                  params.confirmed    = true
                  flow.nav.invalidate()
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
    flow.nav.invalidate()
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

## Bottom Sheet Host

Bottom sheets now use `flow.bottom_sheet.*`. The host lives in a dedicated gui script and renders the sheet independently from the current screen tree.

### Host init

```lua
local flow = require "flow/flow"
local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Text = flow.ui.cp.Text

function init(self)
  flow.bottom_sheet.init(self, {
    id = "sample_bottom_sheet",
    background_focus_url = msg.url("main:/go#sample1"),
    open_message_id = hash("sample_bottom_sheet_open"),
    close_message_id = hash("sample_bottom_sheet_close"),
    sheet = {
      backdrop_color = "#0000008c",
      view = function(params, api)
        return Box({
          key = "sheet_content",
          color = "#262b38",
          style = { width = "100%", height = 240, flex_direction = "column", padding = 20, gap = 12 },
          children = {
            Text({ key = "title", text = "Options", style = { height = 32 } }),
            Button({
              key = "close_btn",
              style = { width = 140, height = 44 },
              color = "#4d8c4d",
              on_click = function()
                api.dismiss("Closed from sheet")
              end,
              children = { Text({ key = "lbl", text = "Close", style = { width = "100%", height = "100%" } }) }
            }),
          }
        })
      end,
      on_dismiss = function(params, result)
        msg.post(msg.url("main:/go#sample1"), hash("sample_bottom_sheet_dismissed"), {
          params = params,
          result = result,
        })
      end,
    },
  })
end
```

Call `flow.update`, `flow.on_input`, `flow.on_message`, and `flow.final` from that gui script normally. Once the host is initialized, the top-level flow facade delegates automatically.

### Presenting and dismissing

Open the hosted sheet by posting the configured open message:

```lua
msg.post(msg.url("main:/bottom_sheet_host#bottom_sheet_host"), hash("sample_bottom_sheet_open"), {
  params = {
    sheet_type = "menu",
    sheet_size = "half",
  },
})
```

Dismiss it from the controller:

```lua
msg.post(msg.url("main:/bottom_sheet_host#bottom_sheet_host"), hash("sample_bottom_sheet_close"), {
  result = "Closed from controller",
})
```

### Sheet view contract

`sheet.view(params, api)` receives:

- `params`: a persistent table copied from the open payload
- `api.dismiss(result)`: close the current sheet
- `api.invalidate()`: rebuild the hosted sheet after mutating `params`

This lets the hosted sheet manage internal transitions. The sample menu sheet uses `api.invalidate()` to switch into its merged settings/options sheet without dismissing first.

### Blocking sheets

Backdrop dismissal is enabled by default. Set `dismiss_on_backdrop = false` to require an explicit button press to close the sheet.

---

## Combining Overlays with Screen Content

`Popup` still lives inside the current screen tree. Hosted bottom sheets do not. Instead, the background screen posts open/close messages to the host gui and reacts to `sheet.on_dismiss(...)`.

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
| Hosted sheet content has no `height` | Always set explicit `height` on the sheet content box |
| Treating bottom sheet like a primitive child | Use `flow.bottom_sheet.init(...)` in a dedicated gui script |
| Mutating hosted sheet params without rebuilding | Call `api.invalidate()` after changing hosted params |
| Forgetting to handle results | Use `sheet.on_dismiss(params, result)` to notify the background screen |

---

## Congratulations

You've completed all six tutorials. You now know how to:

1. Build and mount a screen with `Box` and `Text`
2. Control layout with flex direction, justify, align, gap, and padding
3. Navigate between screens with params, transitions, and result callbacks
4. Build interactive UIs with buttons and state mutation
5. Handle large lists efficiently with virtual scrolling
6. Add modal popups and hosted bottom sheets

**Recommended next reads:**
- [Best Practices](../guides/best-practices.md) — key rules to keep your app correct and performant
- [Debugging](../guides/debugging.md) — how to enable debug output and targeted logging
- [API Reference](../../specs/README.md) — full module-level specifications
