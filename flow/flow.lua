-- flow/flow.lua
-- Public facade for the Flow library.
-- Exposes UI and navigation namespaces from a single module.
-- Low-level renderer helpers are exposed as `flow.ui.*`.
-- Primitive constructors are exposed as `flow.ui.cp.*`.
-- Navigation helpers are exposed as `flow.nav.*`.
-- Centralized logging is exposed as `flow.log`.
-- Usage: local flow = require "flow/flow"
local Box = require "flow/components/box"
local Button = require "flow/components/button"
local ButtonImage = require "flow/components/button_image"
local bottom_sheet = require "flow/bottom_sheet"
local color = require "flow/color"
local Flex = require "flow/flex"
local Icon = require "flow/components/icon"
local layout = require "flow/layout"
local log = require "flow/log"
local Markdown = require "flow/components/markdown"
local Popup = require "flow/components/popup"
local Scroll = require "flow/components/scroll"
local Text = require "flow/components/text"
local navigation = require "flow/navigation/init"
local navigation_gui = require "flow/navigation/gui"
local navigation_messages = require "flow/navigation/messages"
local navigation_proxy = require "flow/navigation/proxy"
local navigation_runtime = require "flow/navigation/runtime"
local ui = require "flow/ui"

local function build_ui_namespace()
	local components = {
		Box = Box,
		Button = Button,
		ButtonImage = ButtonImage,
		Icon = Icon,
		Markdown = Markdown,
		Popup = Popup,
		Scroll = Scroll,
		Text = Text,
	}
	local namespace = {
		Flex = Flex,
		color = color,
		flex = Flex,
		layout = layout,
		cp = components,
		components = components,
	}
	return setmetatable(namespace, { __index = ui })
end

local function build_nav_namespace()
	local namespace = {
		messages = navigation_messages,
		runtime = navigation_runtime,
		proxy = navigation_proxy,
		gui = navigation_gui,
	}

	for key, value in pairs(navigation_messages) do
		namespace[key] = value
	end

	return setmetatable(namespace, { __index = navigation })
end

local function get_bottom_sheet_host(self)
	if self and self.bottom_sheet_state then
		return require "flow/bottom_sheet/host"
	end
	return nil
end

local M = {
	ui = build_ui_namespace(),
	nav = build_nav_namespace(),
	bottom_sheet = bottom_sheet,
	log = log,
	color = color,
}

--- Query the current Defold window dimensions in physical pixels.
--- Wraps `window.get_size()` so callers do not need to reference the global directly
--- and the call site can be mocked in unit tests.
---@return number w  Current window width in pixels
---@return number h  Current window height in pixels
local function get_window_size()
	return window.get_size()
end

---@param values table|nil
---@return number
local function count_entries(values)
	if not values then
		return 0
	end
	local count = 0
	for _ in pairs(values) do
		count = count + 1
	end
	return count
end

--- Bulk-register a map of screen definitions with the navigation router.
--- Iterates `screens` and calls `nav.register(id, def)` for each entry.
--- Silently does nothing when either argument is nil/falsy, so callers do not
--- need to guard against an empty screens table.
---@param nav     Flow.Navigation                      The navigation singleton (flow/navigation/init)
---@param screens table<string, Flow.ScreenDef>        Map of screen-id → screen definition
local function register_screens(nav, screens)
	if not nav or not screens then return end
	for id, def in pairs(screens) do
		log.debug("flow", "register screen id=%s", id)
		nav.register(id, def)
	end
end

--- Snapshot the current window size into `self.last_window_w / last_window_h`.
--- Called after every size-change detection so the next frame can diff against
--- the new baseline rather than the old one, preventing repeated re-renders.
---@param self table  The gui_script self table that owns the Flow instance
local function sync_window_baseline(self)
	self.last_window_w, self.last_window_h = get_window_size()
end

--- Rebuild the UI tree from the current navigation or static tree source.
--- When a navigation adapter is active and a screen is on the stack, the tree
--- is produced by `adapter:build_tree()` (which calls the current screen's
--- `view()` function and wraps it in transition overlays).
--- When no navigation is active, the last tree set via `M.set_tree()` is used.
--- After building, requests a renderer redraw so Defold will re-apply nodes,
--- clears both the adapter rebuild flag and `self.fl.needs_rebuild`.
---@param self table  The gui_script self table that owns the Flow instance
---@return Flow.Element|nil  The newly built tree, or nil if no source is available
local function regenerate_tree(self)
	local fl = self.fl
	if not fl then return nil end

	if fl.adapter and fl.navigation.current() then
		self.tree = fl.adapter:build_tree()
	elseif fl.tree then
		self.tree = fl.tree
	end

	if self.tree then
		ui.request_redraw(self)
	end
	if fl.adapter then
		fl.adapter:clear_rebuild_flag()
	end
	fl.needs_rebuild = false
	log.debug(
		"flow",
		"regenerated tree key=%s source=%s",
		self.tree and self.tree.key or "nil",
		(fl.adapter and fl.navigation.current()) and "navigation" or (fl.tree and "static" or "none")
	)
	return self.tree
end

--- Handle the scroll-change signal raised by the renderer after a scroll interaction.
--- When `self.ui._scroll_changed` is set, this function:
---   1. Clears the flag to prevent duplicate handling.
---   2. If navigation is active, saves the current scroll offset into the screen's
---      params via `adapter:save_scroll_state()`, then invalidates navigation so
---      the screen re-renders with updated scroll state on the next frame.
---   3. If navigation is not active (static tree mode), sets `fl.needs_rebuild = true`
---      so `regenerate_tree` is triggered on the next `M.update` call.
--- Returns false immediately when there is no pending scroll-change signal.
---@param self table  The gui_script self table that owns the Flow instance
---@return boolean    True when the scroll-change signal was present and handled
local function handle_scroll_change(self)
	if not self.tree or not self.ui or not self.ui._scroll_changed then
		return false
	end

	self.ui._scroll_changed = false
	if self.fl and self.fl.adapter and self.fl.navigation.current() then
		self.fl.adapter:save_scroll_state(self.tree)
		self.fl.navigation.invalidate()
		log.debug("flow", "scroll change saved into navigation state")
		return true
	end

	if self.fl then
		self.fl.needs_rebuild = true
		log.debug("flow", "scroll change marked static tree for regeneration")
	end
	return true
end

--- Initialize Flow in a gui_script. Mounts the UI renderer and connects navigation.
---@param self table               The gui_script self
---@param config? Flow.InitConfig
function M.init(self, config)
	config = config or {}

	msg.post(".", "acquire_input_focus")
	ui.mount(self, { debug = config.debug == true })

	self.fl = {
		config = config,
		navigation = navigation,
		adapter = navigation_gui.new(navigation),
		tree = nil,
		on_update = config.on_update,
		on_message = config.on_message,
		needs_rebuild = false,
	}

	if config.screens then
		register_screens(navigation, config.screens)
	end
	self.navigation = navigation

	if config.initial_screen then
		navigation.reset(config.initial_screen, config.initial_params)
		regenerate_tree(self)
	end

	sync_window_baseline(self)
	log.info(
		"flow",
		"init screens=%d initial_screen=%s",
		count_entries(config.screens),
		config.initial_screen or "nil"
	)
	return self.fl
end

--- Call in gui_script final(). Releases input focus and cleans up navigation.
---@param self table
function M.final(self)
	local bottom_sheet_host = get_bottom_sheet_host(self)
	if bottom_sheet_host then
		return bottom_sheet_host.final(self)
	end

	msg.post(".", "release_input_focus")
	if self.fl and self.fl.adapter then
		self.fl.adapter:destroy()
	end
	log.info("flow", "finalized flow instance")
end

--- Set a static UI tree for rendering without navigation.
--- Use this when you do not need stack-based navigation — just a fixed layout
--- that you update manually. If `M.init` has not been called yet, it is called
--- automatically with default options so the renderer is mounted.
--- The tree is stored in both `self.tree` (renderer-facing) and `fl.tree`
--- (source-of-truth for regeneration) and the renderer immediately requests
--- redraw so the next `M.update` call re-applies it.
---@param self table         The gui_script self table that owns the Flow instance
---@param tree Flow.Element  Root element of the UI tree to render
---@return Flow.Element      The same tree passed in (for chaining convenience)
function M.set_tree(self, tree)
	if not self.fl then
		M.init(self)
	end
	self.fl.tree = tree
	self.tree = tree
	self.fl.needs_rebuild = true
	ui.request_redraw(self)
	log.info("flow", "set static tree key=%s", tree and tree.key or "nil")
	return tree
end

--- Request a UI redraw on the next `M.update` call.
--- When navigation is active, forwards to `navigation.invalidate()` so the
--- navigation GUI adapter schedules a screen re-render (which also handles
--- scroll state, transition overlays, etc.).
--- When no navigation screen is current, sets `fl.needs_rebuild = true` and requests
--- low-level redraw directly, causing `regenerate_tree` to run on the
--- next update from the static tree stored via `M.set_tree`.
---@param self table  The gui_script self table that owns the Flow instance
function M.invalidate(self)
	local bottom_sheet_host = get_bottom_sheet_host(self)
	if bottom_sheet_host then
		return bottom_sheet_host.invalidate(self)
	end

	if not self.fl then return end
	if self.fl.navigation and self.fl.navigation.current() then
		self.fl.navigation.invalidate()
		log.debug("flow", "invalidate forwarded to navigation")
	else
		self.fl.needs_rebuild = true
		ui.request_redraw(self)
		log.debug("flow", "invalidate queued static tree rebuild")
	end
end

--- Call in gui_script update(). Advances animations, transitions, and redraws when needed.
---@param self table
---@param dt number               Delta time in seconds
---@return boolean                True if the tree was regenerated or the renderer redrew this frame
function M.update(self, dt)
	local bottom_sheet_host = get_bottom_sheet_host(self)
	if bottom_sheet_host then
		return bottom_sheet_host.update(self, dt)
	end

	if not self.fl then return false end

	local fl = self.fl
	local nav = fl.navigation
	local transition_complete = fl.adapter and fl.adapter:update(dt) or false
	local animating = ui.update_animations(self, dt)
	local hook_requested_rebuild = fl.on_update and fl.on_update(self, dt, nav) or false

	local w, h = get_window_size()
	local size_changed = (self.last_window_w ~= w or self.last_window_h ~= h)
	if size_changed then
		sync_window_baseline(self)
	end

	local scroll_changed = handle_scroll_change(self)
	local needs_regenerate = fl.needs_rebuild or animating or hook_requested_rebuild or size_changed or scroll_changed

	if fl.adapter then
		needs_regenerate = needs_regenerate or fl.adapter:needs_rebuild() or transition_complete or nav.is_invalidated()
	end

	if needs_regenerate then
		regenerate_tree(self)
		if nav then
			nav.clear_invalidation()
		end
	end

	local redrew = ui.update(self, self.tree)
	if needs_regenerate or redrew then
		log.debug(
			"flow",
			"update regenerate=%s redraw=%s tree=%s",
			tostring(needs_regenerate),
			tostring(redrew),
			self.tree and self.tree.key or "nil"
		)
	end
	return needs_regenerate or redrew
end

--- Call in gui_script on_input(). Routes input to interactive elements.
---@param self table
---@param action_id hash
---@param action table
---@return boolean                True if input was consumed
function M.on_input(self, action_id, action)
	local bottom_sheet_host = get_bottom_sheet_host(self)
	if bottom_sheet_host then
		return bottom_sheet_host.on_input(self, action_id, action)
	end

	if not self.fl then return false end

	local w, h = get_window_size()
	local size_changed = (self.last_window_w ~= w or self.last_window_h ~= h)
	if size_changed then
		sync_window_baseline(self)
		regenerate_tree(self)
		if self.tree then
			ui.render(self, self.tree)
		end
		log.info("flow", "window resize forced immediate rerender")
	end

	return ui.on_input(self, action_id, action)
end

--- Call in gui_script on_message(). Handles navigation transport automatically,
--- then forwards unhandled messages to config.on_message when provided.
---@param self table
---@param message_id hash|string
---@param message? table
---@param sender? userdata
---@return boolean                True if the message was consumed
function M.on_message(self, message_id, message, sender)
	local bottom_sheet_host = get_bottom_sheet_host(self)
	if bottom_sheet_host then
		return bottom_sheet_host.on_message(self, message_id, message, sender)
	end

	local handled = navigation_messages.on_message(message_id, message)
	if handled then
		log.debug("flow", "handled navigation transport message id=%s", tostring(message_id))
		return true
	end
	if self.fl and self.fl.on_message then
		local forwarded = self.fl.on_message(self, message_id, message, sender, self.fl.navigation) == true
		if forwarded then
			log.debug("flow", "forwarded message to user handler id=%s", tostring(message_id))
		end
		return forwarded
	end
	return false
end

--- Push a new screen onto the navigation stack.
--- Thin wrapper around `navigation.push` so callers can use the Flow facade
--- instead of requiring the navigation module directly.
--- Accepts either a transition string or a full options table.
---@param self        table                              The gui_script self table (unused; kept for method-call symmetry)
---@param id          string                             Registered screen identifier to navigate to
---@param params?     table                              Initial parameter table passed to the screen's `view` function
---@param options?    string|Flow.PushOptions            Transition string or full push options table
function M.push(self, id, params, options)
	navigation.push(id, params, options)
end

--- Pop the top-most screen off the navigation stack, returning to the previous screen.
--- Thin wrapper around `navigation.pop`. If the stack has only one entry, the
--- call is a no-op (the root screen is never popped).
--- Accepts either `flow.pop(self, result_table, options)` or the shorthand
--- `flow.pop(self, "fade")` for transition-only calls.
---@param self                 table                              The gui_script self table (unused; kept for method-call symmetry)
---@param result_or_transition table|string|nil                   Result payload, or a transition string shorthand
---@param options?             string|Flow.PushOptions            Transition string or full options table
function M.pop(self, result_or_transition, options)
	navigation.pop(result_or_transition, options)
end

--- Replace the current screen with a new one without changing stack depth.
--- Thin wrapper around `navigation.replace`. The replaced entry is discarded
--- and cannot be returned to via pop.
--- Accepts either a transition string or a full options table.
---@param self        table                              The gui_script self table (unused; kept for method-call symmetry)
---@param id          string                             Registered screen identifier to navigate to
---@param params?     table                              Initial parameter table passed to the screen's `view` function
---@param options?    string|Flow.PushOptions            Transition string or full replace options table
function M.replace(self, id, params, options)
	navigation.replace(id, params, options)
end

--- Clear the entire navigation stack and navigate to a root screen.
--- Thin wrapper around `navigation.reset`. All previous screens are discarded;
--- the new screen becomes the sole entry in the stack.
--- Accepts either a transition string or a full options table.
---@param self        table                              The gui_script self table (unused; kept for method-call symmetry)
---@param id          string                             Registered screen identifier to navigate to
---@param params?     table                              Initial parameter table passed to the screen's `view` function
---@param options?    string|Flow.PushOptions            Transition string or full reset options table
function M.reset(self, id, params, options)
	navigation.reset(id, params, options)
end

--- Retrieve the saved vertical scroll offset for a named scroll container.
--- Scroll offsets are saved into the current screen's params by the navigation
--- GUI adapter on each frame. This lets a screen's `view` function restore
--- the correct scroll position when the tree is rebuilt (e.g., after an
--- invalidation triggered by a scroll event).
---@param self table   The gui_script self table (unused; kept for method-call symmetry)
---@param key  string  The `key` property of the target scroll container element
---@return number      The saved scroll offset in pixels (0 when not yet scrolled)
function M.get_scroll_offset(self, key)
	return navigation.get_scroll_offset(key)
end

return M
