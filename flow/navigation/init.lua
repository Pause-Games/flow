-- flow/navigation/init.lua
-- Stack-based navigation facade for the Flow library.
-- Exposes all methods of the navigation router (flow/navigation/core.lua)
-- as a module-level singleton so callers do not need to manage a router instance.
--
-- All methods are forwarded to the underlying router via a dynamic proxy.
-- Refer to flow/navigation/core.lua for full per-method documentation.
--
-- Quick reference:
--   navigation.register(id, screen_def)           Register a screen
--   navigation.push(id, params, options)          Push a new screen
--   navigation.pop(result, options)               Return to previous screen
--   navigation.replace(id, params, options)       Replace current screen
--   navigation.reset(id, params, options)         Clear stack and go to screen
--   navigation.current()                          Current stack entry
--   navigation.peek(offset)                       Look back in the stack
--   navigation.stack_depth()                      Stack entry count
--   navigation.get_data(key, opts)                Read current screen params
--   navigation.set_data(key, value, opts)         Write current screen params
--   navigation.get_scroll_offset(key, opts)       Read saved scroll offset
--   navigation.mark_dirty()                       Force a UI re-render
--   navigation.is_dirty() / clear_dirty()         Dirty flag management
--   navigation.is_busy()                          True during transitions
--   navigation.get_transition()                   Active transition metadata
--   navigation.begin_transition(meta)             Start a custom transition
--   navigation.complete_transition()              End the active transition
--   navigation.on(event, fn)                      Subscribe to navigation events
--   navigation.off(event, fn)                     Unsubscribe from events
local navigation_core = require "flow/navigation/core"

--- The singleton router instance backing this module.
local router = navigation_core.new()

local M = {}

--- Internal: create a module-level forwarding function for a router method.
--- All calls to M[name](...) become router[name](router, ...).
---@param name string  The router method name to proxy
local function proxy(name)
	M[name] = function(...)
		return router[name](router, ...)
	end
end

-- Generate forwarding functions for all public router methods.
for _, name in ipairs({
	"register",
	"get_screen",
	"push",
	"pop",
	"replace",
	"reset",
	"back",
	"current",
	"peek",
	"stack_depth",
	"get_data",
	"set_data",
	"get_scroll_offset",
	"mark_dirty",
	"is_dirty",
	"clear_dirty",
	"is_busy",
	"get_transition",
	"begin_transition",
	"complete_transition",
	"on",
	"off",
}) do
	proxy(name)
end

--- Reset all navigation state. Used only in unit tests.
--- Not safe to call in production — the router's internal state is cleared.
---@return boolean  Always true
function M._reset_for_tests()
	return router:_reset_for_tests()
end

--- Return the underlying router instance. Used by proxy.lua to enumerate screens.
--- Not intended for direct consumer use.
---@return table  The navigation_core router instance
function M._router()
	return router
end

return M
