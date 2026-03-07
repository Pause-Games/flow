-- flow/components/bottom_sheet.lua
-- Bottom sheet overlay component for the Flow library.
-- Renders as a full-screen overlay anchored to the bottom of its parent.
-- Supports two display modes:
--   _visible mode: simple show/hide controlled by _visible flag (no animation)
--   _open mode:    spring-animated slide-in/slide-out from the bottom edge
--
-- In _open mode, _anim_y tracks the current slide offset in pixels (0 = fully open,
-- _sheet_height = fully closed). A critically damped spring physics simulation
-- animates toward the target (0 when open, sheet_height when closed).
-- The backdrop alpha fades in proportion to the animation progress.
local ui = require "flow/ui"

--- Advance the bottom sheet spring animation by dt seconds.
--- Only runs when el._open is set (not nil). Estimates the sheet height from
--- the tallest laid-out child and uses that as the animated travel distance.
--- This assumes the sheet content is wrapped in a single sized container.
---
--- Spring physics parameters:
---   stiffness = 600 (snappy response)
---   damping   = 28  (critically damped — no overshoot)
---   tolerance = 0.5px position + 2px/s velocity (stops when close enough)
---@param el Flow.BottomSheetProps    The bottom_sheet element with animation state
---@param dt number          Delta time in seconds since the last frame
---@return boolean animating      True while the spring has not settled
---@return boolean scroll_changed Always false (bottom sheets don't scroll)
local function update_anim(el, dt)
	if el._open == nil then
		return false, false
	end

	local animating = false

	-- Measure content height from children's computed layouts
	local sheet_h = 0
	for _, child in ipairs(el.children or {}) do
		if child.layout then
			sheet_h = math.max(sheet_h, child.layout.h)
		end
	end
	-- Fallback when no children have been laid out yet
	if sheet_h < 10 then sheet_h = el._sheet_height or 300 end
	el._sheet_height = sheet_h

	-- Initialize animation state on first frame
	if el._anim_y == nil then
		el._anim_y = sheet_h      -- start fully closed (off-screen)
		el._anim_velocity = 0
	end

	-- Target: 0 when open (fully visible), sheet_h when closed (off-screen)
	local target_y = el._open and 0 or sheet_h
	local delta = target_y - el._anim_y

	if math.abs(delta) > 0.5 or math.abs(el._anim_velocity or 0) > 2 then
		-- Spring force = stiffness * delta; damping = damping_coeff * velocity
		el._anim_velocity = (el._anim_velocity or 0) + delta * 600 * dt - (el._anim_velocity or 0) * 28 * dt
		el._anim_y = el._anim_y + el._anim_velocity * dt
		-- Clamp to prevent runaway values
		el._anim_y = math.max(-30, math.min(sheet_h + 30, el._anim_y))
		-- Notify caller so they can persist animation state in params
		if el._on_anim_update then
			el._on_anim_update(el._anim_y, el._anim_velocity)
		end
		animating = true
	else
		-- Settled: snap to target
		el._anim_y = target_y
		el._anim_velocity = 0
		if el._on_anim_update then
			el._on_anim_update(el._anim_y, 0)
		end
	end

	return animating, false
end

--- Register the "bottom_sheet" element type with the renderer.
ui.register("bottom_sheet", {
	--- Create a new Defold box GUI node for the bottom sheet backdrop.
	---@param _ Flow.Element  The bottom_sheet element being instantiated (unused here)
	---@return userdata       A new gui box node used as the full-screen backdrop
	create_node = function(_)
		return gui.new_box_node(vmath.vector3(), vmath.vector3(10, 10, 0))
	end,

	--- Apply the backdrop color with animation-aware alpha fading.
	--- In _open mode, backdrop alpha is proportional to the spring progress:
	---   progress = 1 - (anim_y / sheet_height)  → 1 when open, 0 when closed
	--- In _visible mode, full alpha is used when visible.
	---@param self table           The gui_script self table with a mounted renderer
	---@param el Flow.BottomSheetProps  The bottom_sheet element
	---@param node userdata        The backdrop GUI node to color
	---@param alpha number         Accumulated alpha from parent transitions [0..1]
	apply = function(self, el, node, alpha)
		local c = el._backdrop_color
		if el._open ~= nil then
			-- Fade backdrop proportionally to how open the sheet is
			local progress
			if el._anim_y == nil then
				progress = el._open and 1.0 or 0.0
			elseif el._sheet_height and el._sheet_height > 0 then
				progress = 1 - math.min(1, math.max(0, el._anim_y / el._sheet_height))
			else
				progress = el._open and 1.0 or 0.0
			end
			alpha = alpha * progress
		end
		self.ui._set_node_color(node, c.x, c.y, c.z, c.w * alpha)
	end,

	--- Custom hittability check for bottom sheets.
	--- Returns false when _visible = false, or in _open mode when the sheet is
	--- within 5px of fully closed (blocks input while nearly hidden).
	---@param el Flow.BottomSheetProps  The bottom_sheet element
	---@return boolean         True when the sheet can receive input
	is_hittable = function(el)
		if el._visible == false then
			return false
		end
		if el._open ~= nil then
			local sh = el._sheet_height or 300
			-- Block input when the sheet is almost fully closed (within 5px)
			return (el._anim_y or sh) < sh - 5
		end
		return true
	end,

	--- Return the extra Y pixel offset to apply to all children of this sheet.
	--- In _open mode this slides children down by anim_y, creating the slide-up effect.
	---@param el Flow.BottomSheetProps  The bottom_sheet element
	---@return number          Negative Y offset in pixels (0 = no offset / _visible mode)
	get_child_extra_offset_y = function(el)
		if el._open ~= nil then
			return -(el._anim_y or 0)
		end
		return 0
	end,

	--- Marks this element as a backdrop-click target so input_core fires on_backdrop_click
	--- when the user taps the backdrop area (outside the content children).
	is_backdrop_click_target = true,

	--- Per-frame animation tick (spring physics for _open mode).
	update_anim = update_anim,
})

--- Create a bottom sheet element.
--- Renders as a full-screen overlay with children anchored to the bottom edge.
--- Use _visible for simple show/hide, or _open for spring-animated slide-in/out.
---
--- IMPORTANT: content child boxes must have an explicit height in their style.
---
--- Animated usage: persist _anim_y and _anim_velocity in params via _on_anim_update
--- so animation state survives tree rebuilds:
---   _open = params.sheet_open,
---   _anim_y = params.sheet_anim_y,
---   _anim_velocity = params.sheet_anim_vel,
---   _on_anim_update = function(y, v) params.sheet_anim_y = y; params.sheet_anim_vel = v end,
---@param t Flow.BottomSheetProps  Element definition table (mutated in place)
---@return Flow.Element            The table with type = "bottom_sheet" and defaults applied
local function BottomSheet(t)
	t.type = "bottom_sheet"
	-- _is_overlay = true causes layout.lua to skip this in flex flow and lay it at full parent bounds
	t._is_overlay = true
	t.backdrop_color = t.backdrop_color or "rgba(0, 0, 0, 0.5)"
	t.style = t.style or {}
	-- Default style: full screen, content anchored to bottom center
	t.style.width = t.style.width or "100%"
	t.style.height = t.style.height or "100%"
	t.style.justify_content = t.style.justify_content or "end"
	t.style.align_items = t.style.align_items or "center"

	if t._open ~= nil then
		-- Animated mode: always visible (animation controls apparent visibility)
		t._visible = true
	else
		t._visible = t._visible ~= false
	end

	return t
end

return BottomSheet
