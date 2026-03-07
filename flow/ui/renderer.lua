-- flow/ui/renderer.lua
-- Core render loop for the Flow renderer.
-- Converts a laid-out element tree into live Defold GUI nodes, manages the
-- node cache (create on first use, reuse on subsequent frames, delete when
-- no longer in tree), and handles coordinate space conversion from layout
-- space (bottom-left origin) to Defold GUI space (center origin).
--
-- Supports two layout spaces (set by flow/ui.lua M._set_layout_space_unsafe):
--   "gui"    — layout in logical GUI units; nodes positioned at GUI coords
--   "window" — layout in physical pixels; nodes scaled back via _scale_x/y
local M = {}
local color = require "flow/color"
local log = require "flow/log"

--- Look up an element's type definition in the registry.
--- Asserts if the type is not registered — all element types must be
--- registered via ui.register() before being rendered.
---@param deps Flow.RendererDeps   Dependency bundle (RENDERER_DEPS from flow/ui.lua)
---@param el Flow.Element          The element whose type definition to retrieve
---@return table                   The renderer definition for el.type
local function get_def(deps, el)
	local def = deps.registry[el.type]
	assert(def, "Unregistered UI primitive type: " .. tostring(el.type))
	return def
end

--- Determine whether an element should be rendered this frame.
--- Calls def.is_visible(el) if defined; falls back to el._visible ~= false.
--- Invisible elements are skipped entirely — their nodes are not positioned
--- and their keys are not collected, so they get deleted from the node cache.
---@param el Flow.Element          The element to test
---@param def table                The renderer definition for el.type
---@return boolean                 True if the element should be rendered
local function is_visible(el, def)
	if def and def.is_visible then
		local visible = def.is_visible(el)
		if visible ~= nil then
			return visible
		end
	end
	return el._visible ~= false
end

--- Retrieve or create the Defold GUI node for an element.
--- Uses (prefix .. el.key) as the cache key. On first use, calls
--- def.create_node(el) to create the node and stores it in self.ui.nodes.
--- On subsequent frames the cached node is returned directly.
---@param self table               The gui_script self table with a mounted renderer
---@param el Flow.Element          The element whose node to retrieve or create
---@param prefix string|nil        Node key prefix (used for multi-screen transitions)
---@param deps Flow.RendererDeps   Dependency bundle (RENDERER_DEPS from flow/ui.lua)
---@return userdata                The Defold GUI node for this element
local function ensure(self, el, prefix, deps)
	local cache_key = (prefix or "") .. el.key
	local n = self.ui.nodes[cache_key]
	if n then return n end

	local def = get_def(deps, el)
	n = def.create_node(el)
	self.ui.nodes[cache_key] = n
	return n
end

local function resolve_color_field(el, source_key, resolved_key, cache_key)
	local value = el[source_key]
	if value == nil then
		el[resolved_key] = nil
		el[cache_key] = nil
		return
	end
	if el[cache_key] == value then
		return
	end
	el[resolved_key] = color.resolve(value)
	el[cache_key] = value
end

local function resolve_tree_colors(el)
	if not el then return end

	resolve_color_field(el, "color", "_color", "_color_source")
	resolve_color_field(el, "pressed_color", "_pressed_color", "_pressed_color_source")
	resolve_color_field(el, "backdrop_color", "_backdrop_color", "_backdrop_color_source")

	if el._background_screen then
		resolve_tree_colors(el._background_screen)
	end
	for _, child in ipairs(el.children or {}) do
		resolve_tree_colors(child)
	end
end

--- Apply layout, position, size, alpha, and visual state to a single element
--- and recursively process all its children.
---
--- Position math:
---   Layout space uses bottom-left origin. Defold GUI uses center origin.
---   node_x = layout.x + layout.w/2   (center of the element)
---   node_y = layout.y + layout.h/2
---   In window mode: further multiplied by _scale_x/_scale_y.
---   When a parent node clips children, child positions become relative to
---   the parent center to form a proper GUI hierarchy.
---
--- Alpha is accumulated multiplicatively down the tree:
---   child_alpha = parent_alpha * el._alpha
---
--- Scroll offsets are applied by shifting the position of children inside
--- a scroll container, not by transforming the container itself.
---@param self table               The gui_script self table with a mounted renderer
---@param el Flow.Element          The element to apply
---@param parent_alpha number|nil  Accumulated alpha from parent (1.0 at root)
---@param parent_offset_x number|nil  Accumulated fractional X offset from transitions
---@param parent_offset_y number|nil  Accumulated fractional Y offset from transitions
---@param prefix string|nil        Node key prefix for this render pass
---@param parent_scroll_y number|nil  Vertical scroll offset from nearest scroll ancestor
---@param parent_scroll_x number|nil  Horizontal scroll offset from nearest scroll ancestor
---@param parent_node userdata|nil    Parent GUI node (nil = GUI root)
---@param parent_layout Flow.LayoutRect|nil  Parent layout rect for relative positioning
---@param extra_offset_y number|nil  Additional Y pixel offset (e.g. bottom sheet slide-in)
---@param parent_scroll_ancestor Flow.Element|nil  Nearest scroll container ancestor
---@param deps Flow.RendererDeps   Dependency bundle (RENDERER_DEPS from flow/ui.lua)
local function apply(self, el, parent_alpha, parent_offset_x, parent_offset_y, prefix, parent_scroll_y, parent_scroll_x, parent_node, parent_layout, extra_offset_y, parent_scroll_ancestor, deps)
	local def = get_def(deps, el)
	if not is_visible(el, def) then return end

	local n = ensure(self, el, prefix, deps)
	el._cache_key = (prefix or "") .. (el.key or "")
	-- Track which scroll container owns this element for input routing
	el._scroll_ancestor = def.is_scroll_container and el or parent_scroll_ancestor
	local l = el.layout
	if not l then
		log.warn("ui.renderer", "skipping element without layout key=%s type=%s", el.key or "unknown", el.type or "unknown")
		return
	end
	local use_window_layout = self.ui._unsafe_window_layout
	local sx = use_window_layout and (self.ui._scale_x or 1) or 1
	local sy = use_window_layout and (self.ui._scale_y or 1) or 1

	if parent_node then gui.set_parent(n, parent_node) end

	-- Compute transition offsets (fractional screen units → pixels)
	local offset_x = (parent_offset_x or 0) + (el._offset_x or 0)
	local offset_y = (parent_offset_y or 0) + (el._offset_y or 0)
	local screen_offset_x = offset_x * (self.ui._last_w or 0)
	local screen_offset_y = offset_y * (self.ui._last_h or 0)
	local pixel_offset_x = el._offset_x_pixels or 0
	local pixel_offset_y = el._offset_y_pixels or 0
	local scroll_y = parent_scroll_y or 0
	local scroll_x = parent_scroll_x or 0
	local text_anchor = def and def.get_text_anchor and def.get_text_anchor(el) or "center"

	-- Convert bottom-left layout origin to Defold center-origin GUI coords
	local pos_x, pos_y
	if text_anchor == "left" then
		-- Text with PIVOT_W: position at left edge + vertical center
		pos_x = l.x + screen_offset_x - scroll_x + pixel_offset_x
		pos_y = (l.y + l.h / 2) + screen_offset_y + scroll_y + pixel_offset_y + (extra_offset_y or 0)
	elseif text_anchor == "right" then
		-- Text with PIVOT_E: position at right edge + vertical center
		pos_x = (l.x + l.w) + screen_offset_x - scroll_x + pixel_offset_x
		pos_y = (l.y + l.h / 2) + screen_offset_y + scroll_y + pixel_offset_y + (extra_offset_y or 0)
	else
		pos_x = (l.x + l.w / 2) + screen_offset_x - scroll_x + pixel_offset_x
		pos_y = (l.y + l.h / 2) + screen_offset_y + scroll_y + pixel_offset_y + (extra_offset_y or 0)
	end

	-- When parented to a clipping node, positions must be relative to parent center
	if parent_node and parent_layout then
		pos_x = pos_x - (parent_layout.x + parent_layout.w / 2)
		pos_y = pos_y - (parent_layout.y + parent_layout.h / 2)
	end

	if use_window_layout then
		deps.set_node_position(n, pos_x * sx, pos_y * sy)
		deps.set_node_size(n, l.w * sx, l.h * sy)
	else
		deps.set_node_position(n, pos_x, pos_y)
		deps.set_node_size(n, l.w, l.h)
	end

	-- Apply alpha: multiply into color if element has a color, else set alpha only
	local alpha = (parent_alpha or 1) * (el._alpha or 1)
	if el._color then
		local c = el._color
		deps.set_node_color(n, c.x, c.y, c.z, c.w * alpha)
	else
		gui.set_alpha(n, alpha)
	end

	-- Allow the type definition to apply additional visual state (text content, atlas frame, etc.)
	if def and def.apply then def.apply(self, el, n, alpha) end

	-- Determine scroll and parenting for children
	local child_scroll_y = def.is_scroll_container and (el._scroll_y or 0) or scroll_y
	local child_scroll_x = def.is_scroll_container and (el._scroll_x or 0) or scroll_x
	local clips_children = def.clips_children or el._clips_children == true
	local child_parent = clips_children and n or parent_node
	local child_parent_layout = clips_children and l or parent_layout
	local child_extra_y = extra_offset_y or 0
	if def and def.get_child_extra_offset_y then
		child_extra_y = child_extra_y + (def.get_child_extra_offset_y(el) or 0)
	end

	for _, c in ipairs(el.children or {}) do
		apply(self, c, alpha, offset_x, offset_y, prefix, child_scroll_y, child_scroll_x, child_parent, child_parent_layout, child_extra_y, el._scroll_ancestor, deps)
	end

	-- Render auxiliary nodes defined by the type (e.g. scroll track + thumb)
	if def and def.render_extras then
		def.render_extras(self, el, prefix, alpha, deps)
	end
end

--- Collect all cache keys that should exist after a render pass.
--- Walks the tree depth-first, recording (prefix .. el.key) for every
--- visible element. Also calls def.collect_extra_keys for elements that
--- own additional nodes (e.g. scroll track + thumb).
--- Keys NOT in this set after rendering are stale and must be deleted.
---@param el Flow.Element          The element to collect keys for
---@param prefix string|nil        Node key prefix for this render pass
---@param keys table<string, true> Accumulator: keys that should survive this frame
---@param deps Flow.RendererDeps   Dependency bundle (RENDERER_DEPS from flow/ui.lua)
local function collect_node_keys(el, prefix, keys, deps)
	if not el then return end
	local def = get_def(deps, el)
	if not is_visible(el, def) then return end

	local cache_key = (prefix or "") .. (el.key or "unknown")
	keys[cache_key] = true
	if def and def.collect_extra_keys then
		def.collect_extra_keys(el, prefix, keys, deps)
	end
	for _, child in ipairs(el.children or {}) do
		collect_node_keys(child, prefix, keys, deps)
	end
end

--- Run a full layout + render pass for the given tree at size (w, h).
--- Steps:
---   1. Resolve dimensions (window mode overrides w/h with physical size).
---   2. Run layout.compute on the tree (and on a background transition tree if present).
---   3. collect_node_keys to know which nodes should exist this frame.
---   4. apply() to position/size/color every visible node.
---   5. Delete any cached nodes whose keys are no longer in the tree.
---   6. Update self.ui metadata (tree, last size, redraw flag).
---@param self table               The gui_script self table with a mounted renderer
---@param tree Flow.Element        The element tree to render
---@param w number|nil             Layout width; nil/0 = use GUI or window size
---@param h number|nil             Layout height; nil/0 = use GUI or window size
---@param deps Flow.RendererDeps   Dependency bundle (RENDERER_DEPS from flow/ui.lua)
function M.render(self, tree, w, h, deps)
	local gw, gh = deps.get_gui_size()
	local ww, wh = deps.get_window_size()
	if self.ui._unsafe_window_layout and ww > 0 and wh > 0 and gw > 0 and gh > 0 then
		-- Window mode: layout in physical pixels, store scale factors for node positioning
		w = ww
		h = wh
		self.ui._scale_x = gw / ww
		self.ui._scale_y = gh / wh
	else
		if not w or not h or w == 0 or h == 0 then
			w, h = gw, gh
		end
		self.ui._scale_x = nil
		self.ui._scale_y = nil
	end

	resolve_tree_colors(tree)

	deps.layout.compute(tree, 0, 0, w, h)
	log.debug("ui.renderer", "render start tree=%s size=%dx%d window_mode=%s", tree.key or "unknown", w, h, tostring(self.ui._unsafe_window_layout == true))
	local current_keys = {}

	-- Render background (outgoing) screen during a slide/fade transition
	if tree._background_screen then
		deps.layout.compute(tree._background_screen, 0, 0, w, h)
		local bg_prefix = tree._background_screen._node_prefix
		collect_node_keys(tree._background_screen, bg_prefix, current_keys, deps)
		apply(self, tree._background_screen, nil, nil, nil, bg_prefix, nil, nil, nil, nil, 0, nil, deps)
	end

	local prefix = tree._node_prefix
	collect_node_keys(tree, prefix, current_keys, deps)
	apply(self, tree, nil, nil, nil, prefix, nil, nil, nil, nil, 0, nil, deps)

	-- Garbage-collect nodes that are no longer in the tree
	local deleted = 0
	for key, node in pairs(self.ui.nodes) do
		if not current_keys[key] then
			gui.delete_node(node)
			self.ui.nodes[key] = nil
			deleted = deleted + 1
		end
	end

	self.ui.tree = tree
	self.ui._last_w = w
	self.ui._last_h = h
	self.ui._last_rw = gw
	self.ui._last_rh = gh
	self.ui._needs_redraw = false
	log.debug("ui.renderer", "render complete tree=%s deleted_nodes=%d", tree.key or "unknown", deleted)
end

--- Re-render only if the display size has changed since the last render.
--- Uses GUI size (logical) for the comparison — physical window changes
--- handled separately in the update() path.
---@param self table               The gui_script self table with a mounted renderer
---@param tree Flow.Element|nil    Tree to render; falls back to self.ui.tree
---@param deps Flow.RendererDeps   Dependency bundle (RENDERER_DEPS from flow/ui.lua)
---@return boolean                 True if a re-render was performed
function M.render_if_size_changed(self, tree, deps)
	if not self.ui then return false end
	local w, h = deps.get_gui_size()
	if w == 0 or h == 0 then return false end
	if w == self.ui._last_w and h == self.ui._last_h then return false end
	M.render(self, tree or self.ui.tree, w, h, deps)
	return true
end

--- Conditionally re-render the tree, checking multiple redraw conditions:
---   - self.ui._needs_redraw flag (set by request_redraw or mount)
---   - Display size changed since last render (GUI size or window size in window mode)
---   - Logical render resolution changed (e.g. display profile switch)
---   - tree._needs_redraw flag (set by request_tree_redraw)
---   - tree reference changed (new tree since last frame)
---
--- This is the primary entry point called every frame from flow/ui.lua M.update().
---@param self table               The gui_script self table with a mounted renderer
---@param tree Flow.Element|nil    The element tree to render; may differ from self.ui.tree
---@param deps Flow.RendererDeps   Dependency bundle (RENDERER_DEPS from flow/ui.lua)
---@return boolean                 True if a re-render was performed this frame
function M.update(self, tree, deps)
	if not self.ui then return false end
	if tree and tree ~= self.ui.tree then
		self.ui.tree = tree
		self.ui._needs_redraw = true
	end

	local w, h
	if self.ui._unsafe_window_layout then
		w, h = deps.get_window_size()
	else
		w, h = deps.get_gui_size()
	end
	if w == 0 or h == 0 then return false end

	local needs_redraw = self.ui._needs_redraw
	if w ~= self.ui._last_w or h ~= self.ui._last_h then needs_redraw = true end
	local gw, gh = deps.get_gui_size()
	if gw ~= self.ui._last_rw or gh ~= self.ui._last_rh then needs_redraw = true end
	if self.ui.tree and self.ui.tree._needs_redraw then needs_redraw = true end

	if needs_redraw then
		M.render(self, self.ui.tree, w, h, deps)
		if self.ui.tree then self.ui.tree._needs_redraw = nil end
		return true
	end
	return false
end

return M
