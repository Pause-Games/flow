-- flow/ui/input.lua
-- Input routing for the Flow renderer.
-- Receives raw Defold touch/scroll actions, converts coordinates from GUI
-- space to layout space, hit-tests the element tree, and dispatches events
-- to the appropriate element type handler (press, drag, scroll wheel).
--
-- Coordinate conversion handles letterboxing/pillarboxing so that clicks
-- are always correctly mapped regardless of how the window has been stretched.
local socket = require "builtins/scripts/socket"
local log = require "flow/log"

local M = {}

local HASH_SCROLL_UP = hash("scroll_up")
local HASH_SCROLL_DOWN = hash("scroll_down")
local HASH_TOUCH = hash("touch")

--- Look up an element's type definition in the registry.
--- Asserts if the type is not registered — every element in the tree must
--- have been registered via ui.register() before being rendered.
---@param deps Flow.InputDeps      Dependency bundle (INPUT_DEPS from flow/ui.lua)
---@param el Flow.Element          The element whose type definition to retrieve
---@return table                   The renderer definition for el.type
local function get_def(deps, el)
	local def = deps.registry and deps.registry[el.type] or nil
	assert(def, "Unregistered UI primitive type: " .. tostring(el.type))
	return def
end

--- Determine whether an element can receive input events (hit-tests pass through invisible elements).
--- First calls def.is_hittable(el) if present — allows custom per-type logic.
--- Falls back to checking el._visible ~= false.
---@param el Flow.Element          The element to test
---@param deps Flow.InputDeps      Dependency bundle (INPUT_DEPS from flow/ui.lua)
---@param def table|nil            Pre-fetched type definition; fetched if nil
---@return boolean                 True if the element can be hit
local function is_hittable(el, deps, def)
	def = def or get_def(deps, el)
	if def and def.is_hittable then
		local visible = def.is_hittable(el)
		if visible ~= nil then
			return visible
		end
	end
	return el._visible ~= false
end

--- Convert GUI-space coordinates to layout space, accounting for the
--- letterbox/pillarbox offset introduced when the window aspect ratio
--- differs from the design (gui) aspect ratio.
---
--- In "window" layout mode (self.ui._unsafe_window_layout), the returned
--- coordinates are further scaled from GUI units to physical pixels.
---
--- Example: a 1920×1080 window showing a 960×640 design has 0px letterbox
--- (both are 16:9), so the conversion is a simple 2× scale. A 1280×1080
--- window (narrower) would have pillar bars; the visible width shrinks.
---@param self table               The gui_script self table with a mounted renderer
---@param x number                 X coordinate in GUI space (from action.x)
---@param y number                 Y coordinate in GUI space (from action.y)
---@param deps Flow.InputDeps      Dependency bundle (INPUT_DEPS from flow/ui.lua)
---@return number lx               X coordinate in layout space
---@return number ly               Y coordinate in layout space
local function screen_to_layout(self, x, y, deps)
	local ww, wh = deps.get_window_size()
	local gw, gh = deps.get_gui_size()

	if ww <= 0 or wh <= 0 or gw <= 0 or gh <= 0 then
		return x, y
	end

	local window_x = x * ww / gw
	local window_y = y * wh / gh
	local window_aspect = ww / wh
	local gui_aspect = gw / gh

	local visible_w, visible_h, offset_x, offset_y
	if window_aspect > gui_aspect then
		-- Window is wider than design → pillar bars on left/right
		visible_h = wh
		visible_w = wh * gui_aspect
		offset_x = (ww - visible_w) / 2
		offset_y = 0
	else
		-- Window is taller than design → letter bars on top/bottom
		visible_w = ww
		visible_h = ww / gui_aspect
		offset_x = 0
		offset_y = (wh - visible_h) / 2
	end

	local corrected_x = (window_x - offset_x) * gw / visible_w
	local corrected_y = (window_y - offset_y) * gh / visible_h

	-- In window layout mode, further scale from GUI units to physical pixels
	if self.ui._unsafe_window_layout then
		return corrected_x * ww / gw, corrected_y * wh / gh
	end

	return corrected_x, corrected_y
end

--- Test whether a layout-space point (px, py) lies inside a layout rectangle.
--- Uses a simple inclusive axis-aligned bounding box check.
---@param px number                X coordinate in layout space
---@param py number                Y coordinate in layout space
---@param l Flow.LayoutRect        The rectangle to test ({x, y, w, h} bottom-left origin)
---@return boolean                 True when the point is inside or on the edge of l
local function point_in_rect(px, py, l)
	return px >= l.x and px <= l.x + l.w and py >= l.y and py <= l.y + l.h
end

--- Recursively hit-test the element tree at layout-space coordinates (px, py).
--- Children are tested in reverse order (last child is front-most).
--- Scroll containers offset the test point by their current scroll position
--- so that elements scrolled out of view are not incorrectly hit.
---
--- Returns the deepest element whose bounds contain the point, or the
--- nearest ancestor that has capture_descendant_hits = true.
--- Also returns the nearest modal overlay ancestor (popup/bottom_sheet) so
--- callers can consume input even when the exact hit child is non-interactive.
---@param el Flow.Element          The element to test (with its subtree)
---@param px number                X coordinate in layout space (already scroll-adjusted)
---@param py number                Y coordinate in layout space (already scroll-adjusted)
---@param scroll_y number|nil      Accumulated vertical scroll offset from ancestors
---@param scroll_x number|nil      Accumulated horizontal scroll offset from ancestors
---@param modal_owner Flow.Element|nil  Nearest modal overlay ancestor from parents
---@param deps Flow.InputDeps      Dependency bundle (INPUT_DEPS from flow/ui.lua)
---@return Flow.Element|nil        The hit element, or nil if nothing was hit
---@return Flow.Element|nil        The nearest modal overlay ancestor for the hit
local function hit_test_recursive(el, px, py, scroll_y, scroll_x, modal_owner, deps)
	if not el.layout then return nil, nil end
	local def = get_def(deps, el)
	if not is_hittable(el, deps, def) then return nil, nil end

	-- Adjust test coordinates for current scroll offset
	local test_y = py
	local test_x = px
	if scroll_y and scroll_y ~= 0 then
		test_y = py - scroll_y
	end
	if scroll_x and scroll_x ~= 0 then
		test_x = px + scroll_x
	end

	if not point_in_rect(test_x, test_y, el.layout) then return nil, nil end

	local current_modal_owner = modal_owner
	if def.is_backdrop_click_target then
		current_modal_owner = el
	end

	-- Propagate scroll into children: scroll containers reset it to their own offset
	local child_scroll_y = def.is_scroll_container and (el._scroll_y or 0) or scroll_y
	local child_scroll_x = def.is_scroll_container and (el._scroll_x or 0) or scroll_x
	local children = el.children or {}
	for i = #children, 1, -1 do
		local hit, child_modal_owner = hit_test_recursive(children[i], px, py, child_scroll_y, child_scroll_x, current_modal_owner, deps)
		if hit then
			-- capture_descendant_hits: return parent instead of actual hit child
			if def.capture_descendant_hits then
				return el, child_modal_owner
			end
			return hit, child_modal_owner
		end
	end

	return el, current_modal_owner
end

--- Perform a point hit-test against the current element tree.
--- Converts the given GUI-space coordinates to layout space first.
--- Returns the deepest hittable element at that point, or nil.
---@param self table               The gui_script self table with a mounted renderer
---@param x number                 X coordinate in GUI space (from action.x)
---@param y number                 Y coordinate in GUI space (from action.y)
---@param deps Flow.InputDeps      Dependency bundle (INPUT_DEPS from flow/ui.lua)
---@return Flow.Element|nil        The hit element, or nil if nothing was hit
---@return Flow.Element|nil        The nearest modal overlay ancestor for the hit
function M.hit_test(self, x, y, deps)
	if not self.ui or not self.ui.tree then return nil end
	local lx, ly = screen_to_layout(self, x, y, deps)
	return hit_test_recursive(self.ui.tree, lx, ly, nil, nil, nil, deps)
end

---@param self table
---@param hit Flow.Element|nil
---@param deps Flow.InputDeps
local function sync_hover_target(self, hit, deps)
	local current = self.ui and self.ui._hover_element or nil
	if current == hit then
		return
	end

	if current then
		local current_def = get_def(deps, current)
		if current_def.hover_end then
			current_def.hover_end(self, current, deps)
		end
	end

	self.ui._hover_element = nil

	if hit then
		local hit_def = get_def(deps, hit)
		if hit_def.hover_begin then
			hit_def.hover_begin(self, hit, deps)
			self.ui._hover_element = hit
		end
	end
end

--- Route a Defold input action to the appropriate element and handler.
---
--- Dispatch order:
--- 1. Scroll wheel (scroll_up/scroll_down) → nearest scroll_ancestor.on_wheel
--- 2. Touch press → press_begin, then backdrop click, then drag start
--- 3. Touch move → active drag_target.on_drag_move or pressed_element.press_update
--- 4. Touch release → active drag_target.on_drag_end or pressed_element.press_end
---
--- Returns true when the input was consumed (should not propagate to other gui_scripts).
---@param self table               The gui_script self table with a mounted renderer
---@param action_id hash           Defold action id (hash("touch"), hash("scroll_up"), etc.)
---@param action table             Defold action table: {x, y, pressed, released, ...}
---@param deps Flow.InputDeps      Dependency bundle (INPUT_DEPS from flow/ui.lua)
---@return boolean                 True if the input was consumed
function M.on_input(self, action_id, action, deps)
	if not self.ui or not self.ui.tree then return false end

	-- --- Scroll wheel ---
	local scroll_up = action_id == HASH_SCROLL_UP
	local scroll_down = action_id == HASH_SCROLL_DOWN
	if scroll_up or scroll_down then
		local hit, modal_owner = M.hit_test(self, action.x, action.y, deps)
		if hit then
			local scroll_container = hit._scroll_ancestor
			if scroll_container then
				local scroll_def = get_def(deps, scroll_container)
				if scroll_def.on_wheel then
					-- Positive delta scrolls down (increases scroll_y)
					log.debug("ui.input", "wheel target=%s delta=%d", scroll_container.key or "scroll", scroll_down and 50 or -50)
					return scroll_def.on_wheel(self, scroll_container, scroll_down and 50 or -50, deps) == true
				end
			end
		end
		if modal_owner then
			return true
		end
		return false
	end

	local is_pointer_action = action_id == HASH_TOUCH or action_id == nil
	if not is_pointer_action and (type(action.x) ~= "number" or type(action.y) ~= "number") then
		return false
	end

	local x, y = action.x, action.y
	local hit, modal_owner = M.hit_test(self, x, y, deps)

	-- Debug logging: emit coordinates and hit info on press
	if deps.is_debug_enabled(self) and action.pressed and hit then
		local l = hit.layout
		local ww, wh = deps.get_window_size()
		local gw, gh = deps.get_gui_size()
		local lx, ly = screen_to_layout(self, x, y, deps)
		log.debug("ui.input", "press gui=(%.1f, %.1f) layout=(%.1f, %.1f)", x, y, lx, ly)
		log.debug("ui.input", "window=%dx%d gui=%dx%d scale=(%.3f, %.3f)", ww, wh, gw, gh, self.ui._scale_x or 0, self.ui._scale_y or 0)
		if l then
			log.debug("ui.input", "hit key=%s bounds=(%.1f, %.1f, %.1f, %.1f)", hit.key or "unknown", l.x, l.y, l.w, l.h)
		else
			log.debug("ui.input", "hit key=%s bounds=(uncomputed)", hit.key or "unknown")
		end
	end

	-- --- Active drag: route move/release to the captured drag target ---
	if self.ui._drag_target then
		local drag_target = self.ui._drag_target
		local drag_def = get_def(deps, drag_target)
		if action.released then
			local handled = drag_def.on_drag_end and drag_def.on_drag_end(self, drag_target, action, socket.gettime(), deps)
			self.ui._drag_target = nil
			log.debug("ui.input", "drag end target=%s handled=%s", drag_target.key or "unknown", tostring(handled == true))
			return handled == true
		elseif not action.pressed then
			return drag_def.on_drag_move and drag_def.on_drag_move(self, drag_target, action.x, action.y, socket.gettime(), deps) == true or false
		end
	end

	if action.pressed then
		-- 1. Press-begin: interactive elements (e.g. buttons)
		if hit then
			local def = get_def(deps, hit)
			if def.press_begin then
				sync_hover_target(self, hit, deps)
				self.ui._pressed_element = hit
				def.press_begin(self, hit, deps)
				log.debug("ui.input", "press begin key=%s", hit.key or "unknown")
				return true
			end
		end

		-- 2. Backdrop click: overlays (popup, bottom_sheet backdrop)
		if modal_owner and hit == modal_owner then
			local def = get_def(deps, modal_owner)
			if def.is_backdrop_click_target and modal_owner.on_backdrop_click then
				modal_owner.on_backdrop_click(modal_owner)
				log.info("ui.input", "backdrop click key=%s", modal_owner.key or "unknown")
				return true
			end
		end

		-- 3. Drag start: scroll containers
		if hit then
			local scroll_container = hit._scroll_ancestor
			if scroll_container then
				local scroll_def = get_def(deps, scroll_container)
				if scroll_def.on_drag_start then
					local started = scroll_def.on_drag_start(self, scroll_container, x, y, socket.gettime(), deps)
					if started then
						sync_hover_target(self, nil, deps)
						self.ui._drag_target = scroll_container
						log.debug("ui.input", "drag start scroll=%s", scroll_container.key or "scroll")
						return true
					end
				end
			end
		end

		if modal_owner then
			return true
		end

	elseif action.released then
		-- Release: end press on the captured pressed element
		local pressed_el = self.ui._pressed_element
		if pressed_el then
			local pressed_def = get_def(deps, pressed_el)
			self.ui._pressed_element = nil
			if pressed_def.press_end then
				-- activated = true only when released over the same element
				log.debug("ui.input", "press end key=%s activated=%s", pressed_el.key or "unknown", tostring(hit == pressed_el))
				pressed_def.press_end(self, pressed_el, hit == pressed_el, deps)
				sync_hover_target(self, hit, deps)
				return true
			end
		end

		if modal_owner then
			return true
		end

	else
		-- Move: update pressed element's visual hot state
		local pressed_el = self.ui._pressed_element
		if pressed_el then
			local pressed_def = get_def(deps, pressed_el)
			if pressed_def.press_update then
				log.debug("ui.input", "press update key=%s hot=%s", pressed_el.key or "unknown", tostring(hit == pressed_el))
				pressed_def.press_update(self, pressed_el, hit == pressed_el, deps)
			end
			return true
		end

		sync_hover_target(self, hit, deps)
		if self.ui._hover_element ~= nil then
			return true
		end
		return modal_owner ~= nil
	end

	return false
end

return M
