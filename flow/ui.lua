-- flow/ui.lua
-- Renderer and widget system for the Flow library.
-- Bridges layout space to Defold GUI nodes, manages node lifecycle,
-- handles coordinate conversion, hit testing, and input routing.
--
-- Responsibilities:
--   - Mount a renderer instance onto a gui_script self table (M.mount)
--   - Register custom element type definitions (M.register)
--   - Run layout + apply visual state to GUI nodes (M.update / M.render)
--   - Route touch/scroll input to the correct element (M.on_input)
--   - Advance per-frame animations like scroll bounce (M.update_animations)
local layout = require "flow/layout"
local animation_core = require "flow/ui/animation"
local input_core = require "flow/ui/input"
local log = require "flow/log"
local renderer_core = require "flow/ui/renderer"
local M = {}

--- Map from element type string to its renderer definition table.
--- Populated via M.register(); consumed by renderer_core, input_core, animation_core.
---@type table<string, table>
local registry = {}

--- Dependency bundle injected into input_core on every call.
---@type table
local INPUT_DEPS

--- Dependency bundle injected into animation_core on every call.
---@type table
local ANIMATION_DEPS

--- Dependency bundle injected into renderer_core on every call.
---@type table
local RENDERER_DEPS

--- Pre-allocated scratch vector to avoid per-frame GC pressure when setting positions.
---@type vector3
local SCRATCH_POS = vmath.vector3()

--- Pre-allocated scratch vector to avoid per-frame GC pressure when setting sizes.
---@type vector3
local SCRATCH_SIZE = vmath.vector3()

--- Pre-allocated scratch color to avoid per-frame GC pressure when setting colors.
---@type vector4
local SCRATCH_COLOR = vmath.vector4(1, 1, 1, 1)

--- Register a custom element type definition.
--- Every element type string ("box", "text", "button", etc.) must be registered
--- before it can appear in a UI tree. The definition describes how to create,
--- update, and interact with the corresponding Defold GUI node.
---
--- Required fields in def:
---   create_node(el) -> userdata  — creates and returns a new gui node
---
--- Optional fields in def:
---   apply(self, el, node, alpha)            — update node visuals each frame
---   is_visible(el) -> boolean               — custom visibility check
---   is_hittable(el) -> boolean              — custom hit-test eligibility
---   is_scroll_container -> boolean          — marks element as scroll root
---   clips_children -> boolean               — node is used as parent for children
---   capture_descendant_hits -> boolean      — returns self instead of child on hit
---   is_backdrop_click_target -> boolean     — receives backdrop click events
---   get_text_anchor(el) -> "left"|"center"|"right" — text pivot anchor for positioning
---   hover_begin(self, el, deps)             — called when pointer enters element
---   hover_end(self, el, deps)               — called when pointer leaves element
---   press_begin(self, el, deps)             — called when element is pressed
---   press_update(self, el, is_hot, deps)    — called while dragging over element
---   press_end(self, el, activated, deps)    — called on release
---   on_wheel(self, el, delta, deps)         — called on mouse wheel
---   on_drag_start(self, el, x, y, t, deps) — called when drag begins
---   on_drag_move(self, el, x, y, t, deps)  — called each drag frame
---   on_drag_end(self, el, action, t, deps)  — called when drag ends
---   update_anim(el, dt, deps) -> bool,bool  — per-frame animation tick
---   render_extras(self, el, prefix, alpha, deps) — render auxiliary nodes
---   collect_extra_keys(el, prefix, keys, deps)   — declare extra cached node keys
---   get_child_extra_offset_y(el) -> number  — additional Y offset for children
---@param type_name string         The element type string (e.g. "box", "scroll")
---@param def table                Renderer definition table; must contain create_node
---@return table                   The registered def, same reference as the argument
function M.register(type_name, def)
	assert(type(type_name) == "string" and type_name ~= "", "ui.register(type_name, def) requires a non-empty type name")
	assert(type(def) == "table" and type(def.create_node) == "function", "ui.register(type_name, def) requires def.create_node")
	registry[type_name] = def
	log.debug("ui", "registered primitive type=%s", type_name)
	return def
end

--- Read the logical display size from game.project [display] settings.
--- This is the fixed design resolution, not the actual window size.
--- Used for coordinate conversion and layout space sizing in GUI mode.
---@return number w                Logical display width in pixels (default 960)
---@return number h                Logical display height in pixels (default 640)
local function get_gui_size()
	local w = tonumber(sys.get_config("display.width")) or 960
	local h = tonumber(sys.get_config("display.height")) or 640
	return w, h
end

--- Read the current physical window size from the OS.
--- May differ from gui size when the window is resized or on high-DPI displays.
---@return number w                Physical window width in pixels
---@return number h                Physical window height in pixels
local function get_window_size()
	return window.get_size()
end

--- Return the logical GUI display size (same as the [display] settings).
--- Exposed on the module so external code can query the design resolution.
---@return number w                Logical display width in pixels
---@return number h                Logical display height in pixels
function M.get_size()
	return get_gui_size()
end

--- Set the position of a GUI node using the pre-allocated scratch vector.
--- Avoids allocating a new vector3 on every frame.
---@param node userdata            The Defold GUI node to reposition
---@param x number                 X position in Defold GUI space (center origin)
---@param y number                 Y position in Defold GUI space (center origin)
local function set_node_position(node, x, y)
	SCRATCH_POS.x = x
	SCRATCH_POS.y = y
	SCRATCH_POS.z = 0
	gui.set_position(node, SCRATCH_POS)
end

--- Set the size of a GUI node using the pre-allocated scratch vector.
--- Avoids allocating a new vector3 on every frame.
---@param node userdata            The Defold GUI node to resize
---@param w number                 Width in pixels
---@param h number                 Height in pixels
local function set_node_size(node, w, h)
	SCRATCH_SIZE.x = w
	SCRATCH_SIZE.y = h
	SCRATCH_SIZE.z = 0
	gui.set_size(node, SCRATCH_SIZE)
end

--- Set the color of a GUI node using the pre-allocated scratch color.
--- Avoids allocating a new vector4 on every frame.
---@param node userdata            The Defold GUI node to recolor
---@param r number                 Red component [0..1]
---@param g number                 Green component [0..1]
---@param b number                 Blue component [0..1]
---@param a number                 Alpha component [0..1]
local function set_node_color(node, r, g, b, a)
	SCRATCH_COLOR.x = r
	SCRATCH_COLOR.y = g
	SCRATCH_COLOR.z = b
	SCRATCH_COLOR.w = a
	gui.set_color(node, SCRATCH_COLOR)
end

--- Initialize the renderer state on a gui_script self table.
--- Must be called once in gui_script init() before any other ui calls.
--- Creates self.ui with an empty node cache, redraw flag, and debug toggle.
---@param self table               The gui_script self table to mount onto
---@overload fun(self: table)
---@param opts? Flow.MountOptions  Options table
function M.mount(self, opts)
	opts = opts or {}
	self.ui = {
		nodes = {},           -- cache_key -> gui node
		tree = nil,           -- current element tree
		_needs_redraw = true, -- forces a full re-render on the next update
		_scroll_changed = false, -- set by scroll components when scroll offset changes
		_set_node_color = set_node_color,
		debug = opts.debug == true,
	}
	log.info("ui", "mounted renderer debug=%s", tostring(self.ui.debug))
end

--- Enable or disable debug logging for input and hit-testing.
--- When enabled, every touch press emits debug logs through `flow.log`
--- under the `ui.input` context.
---@param self table               The gui_script self table with a mounted renderer
---@param enabled boolean          True to enable debug output, false to disable
---@return boolean                 The new debug state
function M.set_debug(self, enabled)
	assert(self and self.ui, "ui.set_debug(self, enabled) requires a mounted renderer instance")
	self.ui.debug = enabled == true
	log.info("ui", "set_debug enabled=%s", tostring(self.ui.debug))
	return self.ui.debug
end

--- Internal: switch between "window" and "gui" layout spaces.
--- In "window" mode, layout is computed in physical pixels and nodes are
--- scaled back to GUI space via _scale_x/_scale_y. This gives pixel-perfect
--- rendering on high-DPI displays. Not intended for direct consumer use.
---@param self table               The gui_script self table with a mounted renderer
---@param space string             "window" for physical pixels, anything else for GUI units
function M._set_layout_space_unsafe(self, space)
	if self.ui then
		self.ui._unsafe_window_layout = (space == "window")
		self.ui._needs_redraw = true
		log.warn("ui", "unsafe layout space set to %s", tostring(space))
	end
end

--- Request a renderer redraw so the next M.update() call triggers a full re-render.
--- Call this whenever the data driving the UI tree changes and you want the
--- screen to reflect the new state immediately.
---@param self table               The gui_script self table with a mounted renderer
function M.request_redraw(self)
	if self.ui then
		self.ui._needs_redraw = true
		log.debug("ui", "renderer redraw requested")
	end
end

--- Request a redraw for an element tree so renderer_core.update() re-renders it.
--- Use this when you hold a reference to a tree and want to force a re-layout
--- without going through the full renderer self table.
---@param tree Flow.Element|nil    The root element to flag for redraw; no-op if nil
function M.request_tree_redraw(tree)
	if tree then
		tree._needs_redraw = true
		log.debug("ui", "tree redraw requested key=%s", tree.key or "nil")
	end
end

--- Update the renderer: re-layout and re-apply all nodes if the tree or
--- display size has changed since the last frame.
--- Internally delegates to renderer_core.update() with the full dependency bundle.
---@param self table               The gui_script self table with a mounted renderer
---@param tree Flow.Element|nil    The element tree to render; may be nil (no-op)
---@return boolean                 True if a re-render was performed this frame
function M.update(self, tree)
	return renderer_core.update(self, tree, RENDERER_DEPS)
end

--- Return true when debug logging is currently active on this renderer instance.
--- Used internally by input_core to gate high-detail `flow.log` output.
---@param self table               The gui_script self table
---@return boolean                 True if self.ui.debug is set
local function is_debug_enabled(self)
	return self and self.ui and self.ui.debug == true or false
end

-- Dependency bundles — built once at module load time, passed by reference
-- to sub-modules on every call to avoid repeated table construction.

INPUT_DEPS = {
	--- Read logical GUI display size (from game.project display settings).
	---@type function
	get_gui_size = get_gui_size,
	--- Read physical window size (may differ on resize / high-DPI).
	---@type function
	get_window_size = get_window_size,
	--- Check whether debug logging is active on this renderer instance.
	---@type fun(self: table): boolean
	is_debug_enabled = is_debug_enabled,
	--- Map from element type string to its renderer definition.
	---@type table<string, table>
	registry = registry,
}

ANIMATION_DEPS = {
	--- Request a renderer redraw so the next frame triggers a re-render.
	---@type fun(self: table)
	request_redraw = function(self)
		M.request_redraw(self)
	end,
	--- Map from element type string to its renderer definition.
	---@type table<string, table>
	registry = registry,
}

RENDERER_DEPS = {
	--- Read logical GUI display size.
	---@type function
	get_gui_size = get_gui_size,
	--- Read physical window size.
	---@type function
	get_window_size = get_window_size,
	--- Layout engine — used to compute node rectangles before applying.
	layout = layout,
	--- Map from element type string to its renderer definition.
	---@type table<string, table>
	registry = registry,
	--- Set a GUI node's color (uses scratch color to avoid GC).
	---@type fun(node: userdata, r: number, g: number, b: number, a: number)
	set_node_color = set_node_color,
	--- Set a GUI node's position (uses scratch vector3 to avoid GC).
	---@type fun(node: userdata, x: number, y: number)
	set_node_position = set_node_position,
	--- Set a GUI node's size (uses scratch vector3 to avoid GC).
	---@type fun(node: userdata, w: number, h: number)
	set_node_size = set_node_size,
}

--------------------------------------------------------------------------------
-- Input handling
--------------------------------------------------------------------------------

--- Perform a point hit-test against the current element tree.
--- Coordinates must be in GUI space (as received from on_input action.x/y).
--- Returns the deepest hittable element whose layout bounds contain the point,
--- or nil if nothing was hit.
---@param self table               The gui_script self table with a mounted renderer
---@param x number                 X coordinate in GUI space
---@param y number                 Y coordinate in GUI space
---@return Flow.Element|nil        The hit element, or nil
function M.hit_test(self, x, y)
	return input_core.hit_test(self, x, y, INPUT_DEPS)
end

--- Route a Defold input action to the appropriate element.
--- Handles touch press/move/release, scroll wheel, and drag gestures.
--- Call this from gui_script on_input(); returns true if the input was consumed.
---@param self table               The gui_script self table with a mounted renderer
---@param action_id hash           The Defold action id hash (e.g. hash("touch"))
---@param action table             The Defold action table with x, y, pressed, released fields
---@return boolean                 True if the input was consumed and should not propagate
function M.on_input(self, action_id, action)
	return input_core.on_input(self, action_id, action, INPUT_DEPS)
end

--------------------------------------------------------------------------------
-- Animation updates (scroll bounce, bottom sheet spring)
--------------------------------------------------------------------------------

--- Advance all per-element animations by one frame (dt seconds).
--- Iterates the current tree and calls each element's update_anim handler.
--- Requests a redraw when at least one element is still animating.
--- Call this every frame from gui_script update() before M.update().
---@param self table               The gui_script self table with a mounted renderer
---@param dt number                Delta time in seconds since the last frame
---@return boolean                 True if at least one animation is still running
function M.update_animations(self, dt)
	return animation_core.update(self, dt, ANIMATION_DEPS)
end

--- Force a full layout + render pass using the given tree and dimensions.
--- Bypasses redraw gating — always re-computes and re-applies all nodes.
--- Prefer M.update() for normal frame rendering; use M.render() when you
--- need to guarantee an immediate re-render (e.g. after a window resize event
--- detected in on_input).
---@param self table               The gui_script self table with a mounted renderer
---@param tree Flow.Element        The element tree to render
---@param w number|nil             Available width in pixels (nil/0 = use GUI size)
---@param h number|nil             Available height in pixels (nil/0 = use GUI size)
function M.render(self, tree, w, h)
	return renderer_core.render(self, tree, w, h, RENDERER_DEPS)
end

--- Re-render only if the display size has changed since the last render pass.
--- Cheaper than M.update() — no redraw-flag check, just a size comparison.
--- Returns true when a re-render was performed.
---@param self table               The gui_script self table with a mounted renderer
---@param tree Flow.Element|nil    The element tree to render; falls back to self.ui.tree
---@return boolean                 True if a re-render was performed
function M.render_if_size_changed(self, tree)
	return renderer_core.render_if_size_changed(self, tree, RENDERER_DEPS)
end

return M
