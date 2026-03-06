# log.lua — Centralized Logging

Primary module: `flow/log.lua`

Preferred access:

```lua
local flow = require "flow/flow"
local log = flow.log
```

`flow.log` is the shared observability surface for the library. It replaces ad hoc `print()` calls inside runtime code with leveled, context-aware logging.

The global log level starts at `none`. Library code is silent until the app opts in with `set_level(...)` or per-context overrides.

## Levels

Supported levels:

- `none`
- `error`
- `warn`
- `info`
- `debug`

Severity ordering:

- `none` disables output
- `error` emits only errors
- `warn` emits `warn` + `error`
- `info` emits `info` + `warn` + `error`
- `debug` emits everything

## API

```lua
flow.log.set_level("warn")
flow.log.set_context_level("nav", "debug")

flow.log.debug("nav", "push id=%s", "inventory")
flow.log.info("ui", "mounted renderer")
flow.log.warn("nav.proxy", "missing proxy url")
flow.log.error("nav", "unknown screen id=%s", id)
```

Functions:

- `flow.log.get_level()`
- `flow.log.set_level(level)`
- `flow.log.get_context_level(context)`
- `flow.log.set_context_level(context, level)`
- `flow.log.clear_context_level(context)`
- `flow.log.none()` or `flow.log.none(context)`
- `flow.log.is_enabled(level, context?)`
- `flow.log.set_sink(fn?)`
- `flow.log.debug(context, fmt, ...)`
- `flow.log.info(context, fmt, ...)`
- `flow.log.warn(context, fmt, ...)`
- `flow.log.error(context, fmt, ...)`

## Contexts

Current built-in contexts include:

- `flow`
- `ui`
- `ui.input`
- `ui.renderer`
- `ui.scroll`
- `nav`
- `nav.messages`
- `nav.proxy`
- `nav.runtime`

Context overrides let you increase visibility for one subsystem without turning on global debug noise:

```lua
flow.log.set_level("warn")
flow.log.set_context_level("ui.input", "debug")
```

## Sink

By default, log entries go to `print()` with this shape:

```text
[flow][DEBUG][nav] push id=inventory from=home depth=2 transition=slide_left
```

For tests or custom capture, provide your own sink:

```lua
flow.log.set_sink(function(entry)
  -- entry.level
  -- entry.context
  -- entry.message
  -- entry.line
end)
```

Passing `nil` restores the default sink.
