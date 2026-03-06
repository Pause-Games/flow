# Debugging

Flow provides two complementary tools for runtime observability: **debug mode** (input and hit-test tracing) and **structured logging** (leveled, context-scoped output).

---

## Debug Mode

Debug mode traces input events: where the pointer lands, what gets hit, and the coordinate conversion steps.

### Enable

```lua
flow.ui.set_debug(self, true)
```

Or pass it during mount:

```lua
flow.ui.mount(self, { debug = true })
```

### What it prints

On every `action.pressed` event:

```
[flow][DEBUG][ui.input] touch pressed
  gui:    (234.0, 410.0)
  layout: (234.0, 230.0)
  window: (960, 640)  gui: (960, 640)  scale: (1.0, 1.0)
  hit:    "item_7"  bounds: {x=16, y=218, w=928, h=60}
```

This tells you:
- Input coordinates in GUI space and converted layout space.
- Window and GUI dimensions and the scale factor between them.
- The key of the hit element and its layout rectangle.

### Disable

```lua
flow.ui.set_debug(self, false)
```

Debug mode is stored per renderer instance (`self.ui`) and is not shared across GUI scripts.

---

## Structured Logging

`flow.log` is the library's runtime observability surface. It uses leveled output with per-context overrides, so you can turn up verbosity for one subsystem without flooding the console.

### Import

```lua
local flow = require "flow/flow"
local log  = flow.log
```

### Log levels

| Level | What it shows |
|-------|--------------|
| `"none"` | Nothing |
| `"error"` | Errors only |
| `"warn"` | Warnings + errors |
| `"info"` | Info + warn + errors |
| `"debug"` | Everything |

### Set global level

```lua
flow.log.set_level("warn")   -- warnings and errors
flow.log.set_level("debug")  -- everything
flow.log.set_level("none")   -- silence all output
```

The library starts with the global level set to `"none"`. Apps opt into visibility by calling `set_level(...)` or setting per-context overrides.

### Override level for a specific context

```lua
-- Show debug from input handling only, keep everything else at warn
flow.log.set_level("warn")
flow.log.set_context_level("ui.input", "debug")
```

Restore a context to the global level:

```lua
flow.log.clear_context_level("ui.input")
```

---

## Log Contexts

| Context | What it covers |
|---------|----------------|
| `flow` | Top-level facade events |
| `ui` | Renderer lifecycle |
| `ui.input` | Input routing, hit testing |
| `ui.renderer` | Node creation and updates |
| `ui.scroll` | Scroll physics, bounds, momentum |
| `nav` | Navigation push/pop/replace/reset, transitions |
| `nav.messages` | Message-driven navigation dispatch |
| `nav.proxy` | Collection-proxy preload/enable/disable |
| `nav.runtime` | Non-GUI runtime bootstrap |

### Recipes

**Debug scroll physics:**

```lua
flow.log.set_level("warn")
flow.log.set_context_level("ui.scroll", "debug")
```

**Debug navigation transitions:**

```lua
flow.log.set_context_level("nav", "debug")
```

**Debug hit testing when a button doesn't respond:**

```lua
flow.log.set_context_level("ui.input", "debug")
flow.ui.set_debug(self, true)
```

**Silence everything except errors:**

```lua
flow.log.set_level("error")
```

---

## Custom Log Sink

By default, log entries go to `print()`. Provide your own sink for custom output or test capture:

```lua
flow.log.set_sink(function(entry)
  -- entry.level   → "debug" | "info" | "warn" | "error"
  -- entry.context → "ui.input" etc.
  -- entry.message → formatted string
  -- entry.line    → source line number
  my_logger:write(entry.level, entry.context, entry.message)
end)
```

Restore the default:

```lua
flow.log.set_sink(nil)
```

---

## Common Debugging Scenarios

### Button doesn't respond to clicks

1. Enable debug mode and click on the button area.
2. Check the printed hit result. If it's `nil`, nothing was hit at those coordinates.
3. Possible causes:
   - The button's parent has `height = 0` (missing explicit height on a wrapper box).
   - The button is covered by an invisible overlay (a `Popup` with `_visible = true` left in the tree).
   - Input focus not acquired — make sure `msg.post(".", "acquire_input_focus")` is called in `init()` (handled automatically by `flow.init`).

### Layout looks wrong

1. Print `node.layout` on the suspect element after rendering:
   ```lua
   -- Temporarily in view():
   local my_box = Box({ key = "suspect", ... })
   -- After flow.update:
   -- flow.ui.update internally calls layout.compute, so layout is written to the tree
   print(my_box.layout and my_box.layout.w or "no layout yet")
   ```
2. Check that every ancestor has an explicit `width` and `height` (or `flex_grow`). A parent with height 0 collapses all children.

### Virtual scrolling shows wrong items

1. Print `flow.nav.get_scroll_offset("your_scroll_key")` each frame.
2. Verify `_virtual_height` is set correctly on the `Scroll` node.
3. Check `first_render` / `last_render` calculations — off-by-one errors here shift which items are visible.

### Nodes accumulating (approaching 512 limit)

1. Enable renderer logging:
   ```lua
   flow.log.set_context_level("ui.renderer", "debug")
   ```
2. Look for keys that appear in creation logs but not in deletion logs.
3. Cause: a key that was in the tree before is no longer in the new tree but wasn't cleaned up — usually because the key changed (random key bug).

### Scroll position resets unexpectedly

Scroll state is saved in `current.params.scroll_state` by the navigation GUI adapter. It is restored each time the screen's `view()` is called. If the scroll position resets:

- Ensure you are not calling `flow.nav.reset(...)` unintentionally.
- Check if the screen is being replaced instead of remaining on the stack.
- If you clear `params` manually, make sure to preserve `params.scroll_state`.

---

## Log Output Format

Default format:

```
[flow][WARN][nav] screen id not found: inventory
[flow][DEBUG][ui.input] hit "btn_ok" at layout {x=400, y=280, w=120, h=44}
```

Fields: `[flow]` prefix, level in brackets, context in brackets, then the message.
