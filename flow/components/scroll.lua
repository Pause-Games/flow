-- flow/components/scroll.lua
-- Scrollable container component for the Flow library.
-- Supports vertical and horizontal scrolling, with optional:
--   - Scrollbar indicator (6px track + proportional thumb)
--   - Bounce / rubber-band resistance at scroll limits
--   - Momentum (inertial) scrolling with automatic deceleration
--   - Virtual height/width for large lists (avoids 512 node limit)
--
-- Scroll direction is inferred from the element's flex_direction:
--   "column" (default) → vertical scroll (_scroll_y)
--   "row"              → horizontal scroll (_scroll_x)
--
-- The scroll container uses stencil clipping so children outside the
-- container bounds are not visible.
local log = require "flow/log"
local ui = require "flow/ui"

--- Return true when the scroll container scrolls horizontally (flex_direction = "row").
---@param scroll_container Flow.ScrollProps  The scroll element to test
---@return boolean                       True for horizontal, false for vertical
local function is_horizontal_scroll(scroll_container)
	local style = scroll_container.style
	return style ~= nil and style.flex_direction == "row" or false
end

--- Compute all scroll metrics for a container in a single pass.
--- Content size is read from _virtual_height/_virtual_width when set (for virtual
--- scrolling with large lists), otherwise measured from children's layout rects.
--- Returns a tuple for callers to use directly without re-measuring.
---@param scroll_container Flow.ScrollProps  The scroll element with a computed layout
---@return boolean is_horizontal          True when scrolling horizontally
---@return number container_size          Viewport size in the scroll axis (px)
---@return number content_size            Total content size in the scroll axis (px)
---@return number min_scroll              Minimum scroll offset (always 0)
---@return number max_scroll              Maximum scroll offset (content_size - container_size)
---@return boolean show_scrollbar         True when content exceeds the viewport
local function get_scroll_metrics(scroll_container)
	if not scroll_container or not scroll_container.layout then
		return false, 0, 0, 0, 0, false
	end

	local is_horizontal = is_horizontal_scroll(scroll_container)
	---@type Flow.LayoutRect
	local l = scroll_container.layout
	local content_size = 0

	if is_horizontal then
		local container_width = l.w
		if scroll_container._virtual_width then
			-- Virtual width: total logical content width declared by the caller
			content_size = scroll_container._virtual_width
		else
			local container_left = l.x
			for _, child in ipairs(scroll_container.children or {}) do
				if child.layout then
					local child_extent = child.layout.x + child.layout.w - container_left
					content_size = math.max(content_size, child_extent)
				end
			end
		end
		content_size = math.max(0, content_size)
		local max_scroll = math.max(0, content_size - container_width)
		return true, container_width, content_size, 0, max_scroll, content_size > container_width
	end

	-- Vertical
	local container_height = l.h
	if scroll_container._virtual_height then
		-- Virtual height: total logical content height declared by the caller
		content_size = scroll_container._virtual_height
	else
		local container_top = l.y + l.h
		for _, child in ipairs(scroll_container.children or {}) do
			if child.layout then
				local child_extent = container_top - child.layout.y
				content_size = math.max(content_size, child_extent)
			end
		end
	end
	content_size = math.max(0, content_size)
	local max_scroll = math.max(0, content_size - container_height)
	return false, container_height, content_size, 0, max_scroll, content_size > container_height
end

--- Return the min/max scroll bounds and total content size for a scroll container.
--- A convenience wrapper around get_scroll_metrics for callers that only need bounds.
---@param scroll_container Flow.ScrollProps  The scroll element with a computed layout
---@return number min_scroll             Always 0
---@return number max_scroll             Maximum scroll offset in pixels
---@return number content_size           Total content size in pixels
local function get_scroll_bounds(scroll_container)
	if not scroll_container.layout then return 0, 0, 0 end
	local _, _, content_size, min_scroll, max_scroll = get_scroll_metrics(scroll_container)
	return min_scroll, max_scroll, content_size
end

--- Apply rubber-band resistance when a scroll value is outside [min_value, max_value].
--- Inside bounds the value is returned unchanged. Outside bounds, the overshoot
--- is reduced by the resistance factor (default 0.3 = 30% of overshoot allowed).
--- This creates the elastic "stretching" feel familiar from iOS scroll views.
---@param value number       The unclamped scroll offset to test
---@param min_value number   The minimum valid scroll offset (usually 0)
---@param max_value number   The maximum valid scroll offset
---@param resistance number|nil  Overshoot multiplier [0..1]; lower = less stretch (default 0.3)
---@return number            The rubber-banded scroll offset
local function apply_rubber_band(value, min_value, max_value, resistance)
	resistance = resistance or 0.3
	if value < min_value then
		local overshoot = min_value - value
		return min_value - overshoot * resistance
	elseif value > max_value then
		local overshoot = value - max_value
		return max_value + overshoot * resistance
	end
	return value
end

--- Render the scrollbar track and thumb for a scroll container.
--- The scrollbar is positioned at the right edge (vertical) or bottom edge (horizontal).
--- Thumb size is proportional to viewport/content ratio (minimum 20px).
--- Thumb position tracks the current scroll offset.
--- Uses the node cache (self.ui.nodes) with "_scrollbar_track" / "_scrollbar_thumb" suffixes.
--- In window layout mode, positions and sizes are scaled by _scale_x/_scale_y.
---@param self table               The gui_script self table with a mounted renderer
---@param scroll_el Flow.ScrollProps  The scroll element with a computed layout and scroll state
---@param prefix string|nil        Node key prefix for this render pass
---@param alpha number             Current accumulated alpha [0..1]
---@param deps table               Renderer dependency bundle (RENDERER_DEPS from flow/ui.lua)
---@return boolean                 True when the scrollbar was rendered (content exceeds viewport)
local function render_scrollbar(self, scroll_el, prefix, alpha, deps)
	local l = scroll_el.layout
	if not l then return false end
	local use_window_layout = self.ui._unsafe_window_layout
	local sx = use_window_layout and (self.ui._scale_x or 1) or 1
	local sy = use_window_layout and (self.ui._scale_y or 1) or 1

	local is_horizontal, container_size, content_size, _, max_scroll, show_scrollbar = get_scroll_metrics(scroll_el)
	if not show_scrollbar then return false end

	if is_horizontal then
		local bar_height = 6
		local bar_y = l.y + 2
		local bar_width = l.w
		local thumb_width = math.max(20, (container_size / content_size) * bar_width)
		local thumb_travel = bar_width - thumb_width
		local thumb_pos = (scroll_el._scroll_x or 0) / max_scroll * thumb_travel
		local thumb_x = l.x + thumb_pos
		local track_key = (prefix or "") .. scroll_el.key .. "_scrollbar_track"
		local thumb_key = (prefix or "") .. scroll_el.key .. "_scrollbar_thumb"

		local track_node = self.ui.nodes[track_key]
		if not track_node then
			track_node = gui.new_box_node(vmath.vector3(), vmath.vector3(bar_width, bar_height, 0))
			self.ui.nodes[track_key] = track_node
		end
		self.ui._set_node_color(track_node, 0.2, 0.2, 0.2, 0.3 * alpha)

		local thumb_node = self.ui.nodes[thumb_key]
		if not thumb_node then
			thumb_node = gui.new_box_node(vmath.vector3(), vmath.vector3(thumb_width, bar_height, 0))
			self.ui.nodes[thumb_key] = thumb_node
		end
		self.ui._set_node_color(thumb_node, 0.6, 0.6, 0.6, 0.7 * alpha)

		deps.set_node_position(track_node, (l.x + bar_width / 2) * sx, (bar_y + bar_height / 2) * sy)
		deps.set_node_size(track_node, bar_width * sx, bar_height * sy)
		deps.set_node_position(thumb_node, (thumb_x + thumb_width / 2) * sx, (bar_y + bar_height / 2) * sy)
		deps.set_node_size(thumb_node, thumb_width * sx, bar_height * sy)
	else
		local bar_width = 6
		local bar_x = l.x + l.w - bar_width - 2
		local bar_height = l.h
		local thumb_height = math.max(20, (container_size / content_size) * bar_height)
		local thumb_travel = bar_height - thumb_height
		local thumb_pos = (scroll_el._scroll_y or 0) / max_scroll * thumb_travel
		local thumb_y = l.y + l.h - thumb_height - thumb_pos
		local track_key = (prefix or "") .. scroll_el.key .. "_scrollbar_track"
		local thumb_key = (prefix or "") .. scroll_el.key .. "_scrollbar_thumb"

		local track_node = self.ui.nodes[track_key]
		if not track_node then
			track_node = gui.new_box_node(vmath.vector3(), vmath.vector3(bar_width, bar_height, 0))
			self.ui.nodes[track_key] = track_node
		end
		self.ui._set_node_color(track_node, 0.2, 0.2, 0.2, 0.3 * alpha)

		local thumb_node = self.ui.nodes[thumb_key]
		if not thumb_node then
			thumb_node = gui.new_box_node(vmath.vector3(), vmath.vector3(bar_width, thumb_height, 0))
			self.ui.nodes[thumb_key] = thumb_node
		end
		self.ui._set_node_color(thumb_node, 0.6, 0.6, 0.6, 0.7 * alpha)

		deps.set_node_position(track_node, (bar_x + bar_width / 2) * sx, (l.y + bar_height / 2) * sy)
		deps.set_node_size(track_node, bar_width * sx, bar_height * sy)
		deps.set_node_position(thumb_node, (bar_x + bar_width / 2) * sx, (thumb_y + thumb_height / 2) * sy)
		deps.set_node_size(thumb_node, bar_width * sx, thumb_height * sy)
	end

	return true
end

--- Handle a mouse wheel event on a scroll container.
--- Clamps the new scroll offset to [min_scroll, max_scroll] (no bounce on wheel).
--- Positive delta scrolls down (increases _scroll_y); negative scrolls up.
---@param self table               The gui_script self table with a mounted renderer
---@param el Flow.ScrollProps      The scroll element receiving the wheel event
---@param delta number             Scroll amount in pixels (positive = down, negative = up)
---@return boolean                 Always true (wheel events are always consumed)
local function on_wheel(self, el, delta)
	local min_scroll, max_scroll = get_scroll_bounds(el)
	if is_horizontal_scroll(el) then
		el._scroll_x = math.max(min_scroll, math.min(max_scroll, (el._scroll_x or 0) + delta))
	else
		el._scroll_y = math.max(min_scroll, math.min(max_scroll, (el._scroll_y or 0) + delta))
	end
	self.ui._scroll_changed = true
	self.ui._needs_redraw = true
	log.debug("ui.scroll", "wheel key=%s delta=%d x=%s y=%s", el.key or "scroll", delta, tostring(el._scroll_x), tostring(el._scroll_y))
	return true
end

--- Begin a touch drag on a scroll container. Captures initial positions and
--- resets momentum and bounce state from any previous gesture.
---@param self table               The gui_script self table with a mounted renderer
---@param el Flow.ScrollProps      The scroll element starting the drag
---@param x number                 Touch X coordinate in GUI space at drag start
---@param y number                 Touch Y coordinate in GUI space at drag start
---@param now number               Current time in seconds (from socket.gettime())
---@return boolean                 Always true (drag is accepted)
local function on_drag_start(self, el, x, y, now)
	el._momentum_active = false
	el._bouncing = false
	el._velocity = 0
	el._dragging_axis = is_horizontal_scroll(el) and "x" or "y"
	el._dragging = true
	el._drag_start_y = y
	el._drag_start_x = x
	el._scroll_start_y = el._scroll_y or 0
	el._scroll_start_x = el._scroll_x or 0
	el._last_drag_y = y
	el._last_drag_x = x
	el._last_drag_time = now
	log.debug("ui.scroll", "drag start key=%s axis=%s", el.key or "scroll", el._dragging_axis or "y")
	return true
end

--- Update scroll position during an active touch drag.
--- When _bounce is true, applies rubber-band resistance beyond the scroll limits.
--- When _bounce is false, hard-clamps to [min_scroll, max_scroll].
---@param self table               The gui_script self table with a mounted renderer
---@param el Flow.ScrollProps      The scroll element being dragged
---@param x number                 Current touch X coordinate in GUI space
---@param y number                 Current touch Y coordinate in GUI space
---@param now number               Current time in seconds (from socket.gettime())
---@return boolean                 Always true
local function on_drag_move(self, el, x, y, now)
	if el._dragging_axis == "x" then
		local target_scroll = el._scroll_start_x - (x - el._drag_start_x)
		el._last_drag_x = x
		el._last_drag_time = now
		if el._bounce then
			local min_scroll, max_scroll = get_scroll_bounds(el)
			el._scroll_x = apply_rubber_band(target_scroll, min_scroll, max_scroll, 0.3)
		else
			local min_scroll, max_scroll = get_scroll_bounds(el)
			el._scroll_x = math.max(min_scroll, math.min(max_scroll, target_scroll))
		end
	else
		local target_scroll = el._scroll_start_y - (y - el._drag_start_y)
		el._last_drag_y = y
		el._last_drag_time = now
		if el._bounce then
			local min_scroll, max_scroll = get_scroll_bounds(el)
			el._scroll_y = apply_rubber_band(target_scroll, min_scroll, max_scroll, 0.3)
		else
			local min_scroll, max_scroll = get_scroll_bounds(el)
			el._scroll_y = math.max(min_scroll, math.min(max_scroll, target_scroll))
		end
	end

	self.ui._scroll_changed = true
	self.ui._needs_redraw = true
	log.debug("ui.scroll", "drag move key=%s x=%s y=%s", el.key or "scroll", tostring(el._scroll_x), tostring(el._scroll_y))
	return true
end

--- End an active touch drag and start momentum scrolling (if enabled).
--- Computes release velocity from the distance moved in the last <100ms interval.
--- If the velocity exceeds 100px/s, enables momentum scrolling (_momentum_active).
--- If out of bounds with bounce enabled, starts the bounce-back animation (_bouncing).
--- If out of bounds without bounce, hard-clamps the scroll offset.
---@param self table               The gui_script self table with a mounted renderer
---@param el Flow.ScrollProps      The scroll element ending the drag
---@param action table             Defold action table at release ({x, y, released=true})
---@param now number               Current time in seconds (from socket.gettime())
---@return boolean                 Always true
local function on_drag_end(self, el, action, now)
	el._dragging = false
	local is_horizontal = el._dragging_axis == "x"
	local dt = now - el._last_drag_time

	-- Compute release velocity from the last drag interval
	if el._momentum and dt > 0 and dt < 0.1 then
		if is_horizontal then
			el._velocity = -(action.x - el._last_drag_x) / dt
		else
			el._velocity = -(action.y - el._last_drag_y) / dt
		end
		if math.abs(el._velocity) > 100 then
			el._momentum_active = true
		else
			el._velocity = 0
		end
	else
		el._velocity = 0
	end

	if not el._momentum_active then
		local min_scroll, max_scroll = get_scroll_bounds(el)
		local current_scroll = is_horizontal and el._scroll_x or el._scroll_y
		if el._bounce then
			if current_scroll < min_scroll or current_scroll > max_scroll then
				el._bouncing = true
			end
		else
			if is_horizontal then
				el._scroll_x = math.max(min_scroll, math.min(max_scroll, el._scroll_x))
			else
				el._scroll_y = math.max(min_scroll, math.min(max_scroll, el._scroll_y))
			end
		end
	end

	self.ui._scroll_changed = true
	self.ui._needs_redraw = true
	log.debug(
		"ui.scroll",
		"drag end key=%s velocity=%.2f momentum=%s bouncing=%s",
		el.key or "scroll",
		el._velocity or 0,
		tostring(el._momentum_active == true),
		tostring(el._bouncing == true)
	)
	return true
end

--- Advance momentum scrolling and bounce-back animations for a scroll element.
--- Called each frame by animation_core.update() via the update_anim hook.
---
--- Momentum deceleration:
---   Normal:     1500 px/s² deceleration
---   Overscroll: 5000 px/s² deceleration (stops quickly before bouncing back)
---   Max overscroll: 50px beyond bounds
---
--- Bounce-back spring:
---   Stiffness: 1200 (fast snap to bounds)
---   Damping:   35   (critically damped, no oscillation)
---   Settles when |delta| < 1px AND |velocity| < 10 px/s
---@param el Flow.ScrollProps  The scroll element with momentum/bounce state
---@param dt number          Delta time in seconds since the last frame
---@return boolean animating      True while momentum or bounce is active
---@return boolean scroll_changed True when the scroll offset changed this frame
local function update_anim(el, dt)
	local animating = false
	local scroll_changed = false

	if el._momentum_active then
		local min_scroll, max_scroll = get_scroll_bounds(el)
		local is_horizontal = is_horizontal_scroll(el)
		local current_scroll = is_horizontal and el._scroll_x or el._scroll_y
		local new_scroll = current_scroll + el._velocity * dt

		if new_scroll < min_scroll or new_scroll > max_scroll then
			if el._bounce then
				-- Allow limited overscroll (max 50px) then decelerate rapidly
				local max_overscroll = 50
				if new_scroll < min_scroll then
					new_scroll = math.max(min_scroll - max_overscroll, new_scroll)
				else
					new_scroll = math.min(max_scroll + max_overscroll, new_scroll)
				end
				if is_horizontal then
					el._scroll_x = new_scroll
				else
					el._scroll_y = new_scroll
				end
				scroll_changed = true

				-- Strong deceleration when out of bounds
				local vel_sign = el._velocity > 0 and 1 or -1
				el._velocity = el._velocity - vel_sign * 5000 * dt
				if math.abs(el._velocity) < 100 or (vel_sign > 0 and el._velocity < 0) or (vel_sign < 0 and el._velocity > 0) then
					el._velocity = 0
					el._momentum_active = false
					el._bouncing = true
				end
			else
				-- No bounce: clamp and stop
				new_scroll = math.max(min_scroll, math.min(max_scroll, new_scroll))
				if is_horizontal then
					el._scroll_x = new_scroll
				else
					el._scroll_y = new_scroll
				end
				scroll_changed = true
				el._velocity = 0
				el._momentum_active = false
			end
		else
			-- Within bounds: apply scroll and decelerate
			if is_horizontal then
				el._scroll_x = new_scroll
			else
				el._scroll_y = new_scroll
			end
			scroll_changed = true

			if math.abs(el._velocity) > 0 then
				local vel_sign = el._velocity > 0 and 1 or -1
				el._velocity = el._velocity - vel_sign * 1500 * dt
				if (vel_sign > 0 and el._velocity <= 0) or (vel_sign < 0 and el._velocity >= 0) then
					el._velocity = 0
					el._momentum_active = false
				end
			else
				el._momentum_active = false
			end
		end

		animating = true
	end

	if el._bouncing then
		local min_scroll, max_scroll = get_scroll_bounds(el)
		local is_horizontal = is_horizontal_scroll(el)
		local current_scroll = is_horizontal and el._scroll_x or el._scroll_y
		local target
		if current_scroll < min_scroll then
			target = min_scroll
		elseif current_scroll > max_scroll then
			target = max_scroll
		else
			-- Already within bounds — settle immediately
			el._bouncing = false
			el._velocity = 0
			return animating, scroll_changed
		end

		-- Spring: acceleration = stiffness * (target - current) - damping * velocity
		local delta = target - current_scroll
		local acceleration = delta * 1200 - el._velocity * 35
		el._velocity = el._velocity + acceleration * dt
		if is_horizontal then
			el._scroll_x = el._scroll_x + el._velocity * dt
		else
			el._scroll_y = el._scroll_y + el._velocity * dt
		end
		scroll_changed = true

		-- Settle when close enough
		if math.abs(delta) < 1 and math.abs(el._velocity) < 10 then
			if is_horizontal then
				el._scroll_x = target
			else
				el._scroll_y = target
			end
			scroll_changed = true
			el._bouncing = false
			el._velocity = 0
		end

		animating = true
	end

	return animating, scroll_changed
end

--- Register the "scroll" element type with the renderer.
ui.register("scroll", {
	--- Create a new stencil-clipped Defold box GUI node for a scroll container.
	--- Stencil clipping masks children that overflow the container's bounds.
	---@param _ Flow.Element  The scroll element being instantiated (unused here)
	---@return userdata       A new gui box node with stencil clipping enabled
	create_node = function(_)
		local node = gui.new_box_node(vmath.vector3(), vmath.vector3(10, 10, 0))
		gui.set_clipping_mode(node, gui.CLIPPING_MODE_STENCIL)
		gui.set_clipping_visible(node, true)
		gui.set_clipping_inverted(node, false)
		return node
	end,

	--- Marks this element as a scroll container.
	--- The renderer and input system use this to manage scroll offsets and
	--- to link child elements back to their scroll ancestor.
	is_scroll_container = true,

	--- When true, children are parented to this node in the GUI hierarchy,
	--- enabling the stencil clip to affect child elements.
	clips_children = true,

	--- Expose get_scroll_bounds for external callers (e.g. virtual scroll helpers).
	get_scroll_bounds = get_scroll_bounds,

	--- Render the scrollbar track and thumb after applying child nodes.
	---@param self table           The gui_script self table with a mounted renderer
	---@param el Flow.ScrollProps  The scroll element (checks el._scrollbar flag)
	---@param prefix string|nil    Node key prefix
	---@param alpha number         Accumulated alpha [0..1]
	---@param deps table           Renderer dependency bundle
	render_extras = function(self, el, prefix, alpha, deps)
		if el._scrollbar ~= false then
			render_scrollbar(self, el, prefix, alpha, deps)
		end
	end,

	--- Declare scrollbar node keys so they are preserved in the node cache.
	--- Without this, the renderer's garbage-collection pass would delete them.
	---@param el Flow.ScrollProps  The scroll element
	---@param prefix string|nil    Node key prefix
	---@param keys table           Accumulator of keys that should survive this frame
	collect_extra_keys = function(el, prefix, keys)
		if el._scrollbar == false then return end
		local _, _, _, _, _, show_scrollbar = get_scroll_metrics(el)
		if show_scrollbar then
			local cache_key = (prefix or "") .. (el.key or "unknown")
			keys[cache_key .. "_scrollbar_track"] = true
			keys[cache_key .. "_scrollbar_thumb"] = true
		end
	end,

	on_wheel = on_wheel,
	on_drag_start = on_drag_start,
	on_drag_move = on_drag_move,
	on_drag_end = on_drag_end,
	update_anim = update_anim,
})

--- Create a scroll element.
--- A scrollable container that clips its children and responds to touch drag
--- and mouse wheel input. Children flow according to the element's flex_direction.
---
--- For large lists (100+ items), set _virtual_height = total_items * item_height
--- and use spacer boxes above/below visible items to avoid the 512-node limit.
---@param t Flow.ScrollProps      Element definition table (mutated in place)
---@return Flow.Element           The table with type = "scroll" and scroll state initialized
local function Scroll(t)
	t.type = "scroll"
	t._scroll_y = t._scroll_y or 0
	t._scroll_x = t._scroll_x or 0
	t._dragging = false
	t._drag_start_y = 0
	t._drag_start_x = 0
	t._scroll_start_y = 0
	t._scroll_start_x = 0
	t._bounce = (t._bounce ~= false)
	t._momentum = (t._momentum ~= false)
	t._velocity = 0
	t._momentum_active = false
	t._last_drag_y = 0
	t._last_drag_x = 0
	t._last_drag_time = 0
	log.debug("ui.scroll", "create key=%s", t.key or "scroll")
	return t
end

return Scroll
