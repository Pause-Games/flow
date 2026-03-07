# navigation.lua — App-Wide Navigation

`flow.nav` is the recommended app-wide navigation facade for consumers.
It is exposed from `require "flow/flow"`.

Under the hood, `flow.nav` forwards to `flow/navigation/init.lua`, which is backed by a pure router in `flow/navigation/core.lua`.

`flow.nav` also exposes the message transport helpers from `flow/navigation/messages.lua`.
`flow.nav.proxy` exposes the optional proxy runtime helper for screens that declare `proxy_url` and `preload = true`.
`flow.nav.runtime` exposes the non-GUI runtime helper for plain `.script` integration.

`flow.nav` is a singleton service. It is intended to be reachable from GUI scripts and plain scripts without passing a router instance around. For low-level direct imports, use `require "flow/navigation/init"` explicitly instead of relying on folder-module resolution.

## Public API

```lua
local flow = require "flow/flow"
local navigation = flow.nav
```

Core operations:

- `navigation.register(id, screen_def)`
- `navigation.push(id, params, options)`
- `navigation.pop(result_data, options)`
- `navigation.replace(id, params, options)`
- `navigation.reset(id, params, options)`
- `navigation.back(result_data, options)`

State access:

- `navigation.current()`
- `navigation.peek(offset)`
- `navigation.stack_depth()`
- `navigation.get_data()`
- `navigation.get_data(key)`
- `navigation.get_data({ screen_id = "..." })`
- `navigation.get_data(key, { screen_id = "..." })`
- `navigation.set_data(key, value)`
- `navigation.set_data(key, value, { screen_id = "..." })`
- `navigation.get_scroll_offset(key)`

Render/invalidation helpers:

- `navigation.invalidate()`
- `navigation.is_invalidated()`
- `navigation.clear_invalidation()`

Listeners and transition coordination:

- `navigation.on(event, fn)`
- `navigation.off(event, fn)`
- `navigation.is_busy()`
- `navigation.begin_transition(meta)`
- `navigation.complete_transition()`
- `navigation.get_transition()`

Message transport:

- `navigation.on_message(message_id, message)`
- `navigation.PUSH`, `POP`, `REPLACE`, `RESET`, `BACK`, `INVALIDATE`

## Screen Definition

GUI screen:

```lua
local flow = require "flow/flow"
local Box = flow.ui.cp.Box

local my_screen = {
  view = function(params, navigation)
    params.count = params.count or 0

    return Box({
      key = "root",
      style = { width = "100%", height = "100%" },
      children = { ... }
    })
  end,
}
```

Non-GUI screen:

```lua
local my_screen = {
  url = msg.url("main:/gameplay_controller#script"),
  proxy_url = msg.url("main:/gameplay_proxy#collectionproxy"),
  focus_url = msg.url("main:/player_input#script"),
  preload = true,
}
```

Hybrid screen:

```lua
local my_screen = {
  view = function(params, navigation)
    return tree
  end,
  url = msg.url("main:/controller#script"),
}
```

Rules:

- GUI-capable screens expose `view(params, navigation)`
- non-GUI screens expose `url` and optional `focus_url`
- `preload = true` triggers automatic preload dispatch on register
- `flow/navigation/core.lua` never calls `view()` directly; GUI adapters do

## Registration

```lua
navigation.register("my_screen", my_screen)
```

Registration is normalized into a screen descriptor and stored in the router registry.

Duplicate ids are rejected unless the same source screen table is registered again.

## Params and Results

Each pushed screen gets its own persistent `params` table.

Push params in:

```lua
navigation.push("profile_editor", { user = current_user }, {
  transition = "slide_left",
  on_result = function(result)
    if result and result.saved then
      current_user = result.user
      navigation.invalidate()
    end
  end,
})
```

Pop result back:

```lua
navigation.pop({ saved = true, user = edited_user }, "none")
```

Message-based result delivery is also supported:

```lua
navigation.push("profile_editor", { user = current_user }, {
  result_url = msg.url("main:/settings#script"),
  result_message_id = hash("navigation_result"),
})
```

## Data Access

Preferred path inside a screen:

- use injected `params`

Accessor path:

```lua
navigation.get_data()                         -- current screen params
navigation.get_data("user")                   -- current screen field
navigation.get_data({ screen_id = "home" })  -- another screen params
navigation.get_data("user", { screen_id = "home" })
```

If the same `screen_id` exists multiple times in the stack, explicit lookup resolves the top-most match.

## Lifecycle Hooks and Messages

Screens may implement optional Lua hooks:

- `on_enter(params, navigation)`
- `on_exit(params, navigation)`
- `on_pause(params, navigation)`
- `on_resume(params, navigation)`

When `url` is present, navigation also posts:

- `hash("navigation_enter")`
- `hash("navigation_exit")`
- `hash("navigation_pause")`
- `hash("navigation_resume")`

Hook timing:

- `push(...)`: old top gets `on_pause`, new top gets `on_enter`
- `pop(...)`: popped screen gets `on_exit`, revealed screen gets `on_resume`
- `replace(...)`: outgoing screen gets `on_exit`, replacement gets `on_enter`
- `reset(...)`: removed screens get `on_exit`, destination gets `on_enter`

Hooks fire when the navigation action begins, not after GUI transition completion.

## Busy Queue

Navigation serializes operations while busy.

Calls to `push/pop/replace/reset` during:

- another navigation operation
- an active transition tracked by `begin_transition()/complete_transition()`

are queued and replayed in order when the router becomes idle.

## GUI Integration

GUI-specific behavior now lives outside the facade:

- `flow/navigation/gui.lua` builds trees from `screen.view(...)`
- it snapshots the outgoing tree for transitions
- it persists scroll offsets in `current.params.scroll_state`
- it calls `navigation.complete_transition()` when adapter-owned animation ends

Preferred integration path is still `flow/flow.lua`.

## Message Transport

For message-driven navigation outside GUI-owned code, use `flow.nav`.
In GUI scripts, prefer the top-level `flow.on_message(...)` facade so navigation transport and your own callback forwarding are handled in one place.

```lua
local flow = require "flow/flow"

function on_message(self, message_id, message, sender)
  return flow.on_message(self, message_id, message, sender)
end
```

Low-level equivalent:

```lua
function on_message(self, message_id, message, sender)
  if flow.nav.on_message(message_id, message) then
    return true
  end
end
```

Supported message ids:

- `hash("navigation_push")`
- `hash("navigation_pop")`
- `hash("navigation_replace")`
- `hash("navigation_reset")`
- `hash("navigation_back")`
- `hash("navigation_invalidate")`

Examples:

```lua
msg.post("main:/navigation_controller#script", "navigation_push", {
  id = "inventory",
  params = { tab = "equipment" },
  options = { transition = "slide_left" },
})

msg.post("main:/navigation_controller#script", "navigation_pop", {
  result = { saved = true },
  transition = "none",
})
```

Message payload rules:

- push/replace/reset use `id` or `screen_id`
- params go in `params`
- transition/options go in `options` or `transition`
- pop/back results go in `result`

Notes:

- `flow.nav.on_message(...)` is the preferred low-level transport helper name
- transport logging is emitted under `nav.messages`

## Proxy Runtime Helper

For collection-proxy-backed screens, use `flow.nav.proxy` as an optional runtime integration.

```lua
local flow = require "flow/flow"

function init(self)
  self.navigation_proxy = flow.nav.proxy.attach(flow.nav)
end

function final(self)
  self.navigation_proxy:detach()
end
```

Screen example:

```lua
flow.nav.register("gameplay", {
  url = msg.url("main:/gameplay_controller#script"),
  proxy_url = msg.url("main:/gameplay_proxy#collectionproxy"),
  preload = true,
})
```

Default behavior:

- on register with `preload = true`, posts `async_load` to `proxy_url`
- when the active screen changes to that screen, posts `enable`
- when the active screen changes away from that screen, posts `disable`
- when attached with default `sync_existing = true`, already-registered preloadable screens are preloaded immediately and the active proxy is synchronized right away

This helper is optional and stays outside `flow/navigation/core.lua`.

## Non-GUI Runtime Helper

For a plain `.script` that wants to own navigation bootstrap and message transport, use `flow.nav.runtime`.

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
    initial_params = { level = 1 },
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

Behavior:

- registers screens into app-wide navigation
- optionally attaches `flow.nav.proxy` (`enable_proxy_runtime ~= false`)
- optionally resets to `initial_screen`
- delegates message-driven navigation through `flow.nav`

## flow/flow.lua

`flow/flow.lua`:

- registers screens into app-wide navigation
- attaches a per-GUI `navigation_gui` adapter
- exposes `self.navigation`
- uses `navigation.invalidate()` for rebuilds

Use `flow.init/flow.update/flow.on_input` unless you explicitly need the low-level modules.

## Observability

Relevant log contexts:

- `nav`
- `nav.messages`
- `nav.proxy`
- `nav.runtime`

Useful events to inspect at debug level:

- screen registration and duplicate/idempotent re-registration
- queued operations while busy
- transition begin/complete
- message-driven push/pop/replace/reset/back dispatch
- proxy preload/enable/disable activity
