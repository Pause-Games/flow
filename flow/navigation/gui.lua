-- flow/navigation/gui.lua
-- GUI adapter for the Flow navigation system.
-- Bridges the pure navigation router (core.lua) to the Defold GUI renderer.
-- Responsibilities:
--   - Render the current screen's view function to a UI element tree
--   - Drive animated transitions (fade, slide_left, slide_right) by interpolating
--     _alpha and _offset_x on the from/to trees
--   - Persist and restore scroll state across screen renders
--   - Track dirtiness so the main update loop knows when to regenerate the tree
local M = {}

--- Cubic ease-in-out easing function for transition animation.
--- Maps t ∈ [0, 1] to a smooth S-curve: slow start, fast middle, slow end.
--- Formula: Hermite interpolation with cubic acceleration and deceleration.
---@param t number   Progress value in [0, 1]
---@return number    Eased value in [0, 1]
local function ease_in_out_cubic(t)
	if t < 0.5 then
		return 4 * t * t * t
	end
	return 1 - math.pow(-2 * t + 2, 3) / 2
end

--- Retrieve (or lazily create) the scroll_state sub-table inside a params table.
--- Scroll state is stored as params.scroll_state = { [container_key] = {x=0, y=0} }.
---@param params table   The screen params table that owns the scroll state
---@return table         The scroll_state sub-table (created if absent)
local function get_scroll_state(params)
	if not params.scroll_state then
		params.scroll_state = {}
	end
	return params.scroll_state
end

--- Walk a UI element tree and save each scroll container's current offset
--- into the params scroll_state table so it survives a tree rebuild.
--- Called by the adapter before regenerating the tree after a scroll event.
---@param params table          The screen params table to write into
---@param tree Flow.Element|nil The UI tree to walk; no-op when nil
local function save_scroll_state_to_params(params, tree)
	if not params or not tree then return end
	local scroll_state = get_scroll_state(params)

	--- Depth-first walk of the element tree.
	---@param el Flow.ScrollProps|Flow.Element  Current element being visited
	local function walk(el)
		if not el then return end
		if el.type == "scroll" then
			local key = el.key or "scroll"
			local state = scroll_state[key] or {}
			state.y = el._scroll_y or 0
			state.x = el._scroll_x or 0
			scroll_state[key] = state
		end
		for _, child in ipairs(el.children or {}) do
			walk(child)
		end
	end

	walk(tree)
end

--- Walk a newly built UI tree and restore each scroll container's offset
--- from the params scroll_state. This makes scroll position persist across
--- tree rebuilds triggered by navigation dirtiness or window resize.
---@param params table          The screen params table containing saved scroll state
---@param tree Flow.Element|nil The UI tree to restore scroll into; no-op when nil
local function restore_scroll_state_from_params(params, tree)
	if not params or not params.scroll_state or not tree then return end
	local scroll_state = params.scroll_state

	--- Depth-first walk of the element tree.
	---@param el Flow.ScrollProps|Flow.Element  Current element being visited
	local function walk(el)
		if not el then return end
		if el.type == "scroll" then
			local key = el.key or "scroll"
			local state = scroll_state[key]
			if state then
				if type(state) == "table" then
					el._scroll_y = state.y or 0
					el._scroll_x = state.x or 0
				else
					-- Legacy: state stored as a plain number (vertical only)
					el._scroll_y = state
					el._scroll_x = 0
				end
			end
		end
		for _, child in ipairs(el.children or {}) do
			walk(child)
		end
	end

	walk(tree)
end

--- Call the screen's view function to produce a UI element tree.
--- Sets _node_prefix on the returned tree so the renderer can namespace
--- cached node keys per screen (preventing key collisions during transitions).
--- Restores scroll state into the tree after building it.
---@param entry Flow.StackEntry    The current stack entry (provides .screen and .params)
---@param navigation Flow.Navigation  The navigation facade passed to the view function
---@return Flow.Element|nil        The rendered UI tree, or nil when no view is defined
local function render_screen(entry, navigation)
	if not entry or not entry.screen or type(entry.screen.view) ~= "function" then
		return nil
	end

	local tree = entry.screen.view(entry.params, navigation)
	if tree then
		tree._node_prefix = entry.id .. "_"
		restore_scroll_state_from_params(entry.params, tree)
	end
	return tree
end

--- Create a new GUI adapter instance bound to the given navigation router.
--- Registers listeners for "changed", "transition_begin", and "transition_complete"
--- so the adapter stays in sync with navigation state automatically.
---@param navigation Flow.Navigation  The navigation facade (flow/navigation/init.lua)
---@return table                      The adapter object with all M methods mixed in
function M.new(navigation)
	local adapter = {
		navigation = navigation,
		--- The most recently built UI tree (nil when stack is empty).
		---@type Flow.Element|nil
		tree = nil,
		--- The active transition state, or nil when idle.
		---@type table|nil
		transition = nil,
		--- True when the tree needs to be rebuilt this frame.
		dirty = true,
		--- Event listener closures, kept here so they can be removed in destroy().
		listeners = {},
	}

	--- Mark dirty whenever the navigation state changes.
	adapter.listeners.changed = function()
		adapter.dirty = true
	end

	--- Capture the from_tree and initialize transition progress when a transition starts.
	---@param meta table  Transition metadata: {type, action, duration, from_id, to_id}
	adapter.listeners.transition_begin = function(meta)
		adapter.transition = {
			type = meta.type,
			action = meta.action,
			progress = 0,
			duration = meta.duration or 0.3,
			from_id = meta.from_id,
			to_id = meta.to_id,
			--- Snapshot of the outgoing tree at the moment the transition begins.
			from_tree = adapter.tree,
		}
		adapter.dirty = true
	end

	--- Clear the transition state when it completes.
	adapter.listeners.transition_complete = function()
		adapter.transition = nil
		adapter.dirty = true
	end

	navigation.on("changed", adapter.listeners.changed)
	navigation.on("transition_begin", adapter.listeners.transition_begin)
	navigation.on("transition_complete", adapter.listeners.transition_complete)

	return setmetatable(adapter, { __index = M })
end

--- Remove all navigation listeners and clean up the adapter.
--- Call this in gui_script final() to prevent leaking event handlers.
---@param adapter table  The adapter instance created by M.new()
function M.destroy(adapter)
	if not adapter or not adapter.navigation or not adapter.listeners then return end
	adapter.navigation.off("changed", adapter.listeners.changed)
	adapter.navigation.off("transition_begin", adapter.listeners.transition_begin)
	adapter.navigation.off("transition_complete", adapter.listeners.transition_complete)
	adapter.listeners = nil
end

--- Mark the adapter as dirty so the next build_tree() call regenerates the tree.
---@param adapter table  The adapter instance
function M.mark_dirty(adapter)
	adapter.dirty = true
end

--- Return true when the adapter's tree needs to be rebuilt.
---@param adapter table  The adapter instance
---@return boolean       True when adapter.dirty is set
function M.is_dirty(adapter)
	return adapter and adapter.dirty == true
end

--- Clear the dirty flag. Called after build_tree() has been invoked.
---@param adapter table  The adapter instance
function M.clear_dirty(adapter)
	if adapter then
		adapter.dirty = false
	end
end

--- Save the current scroll offsets from a UI tree into the navigation params.
--- Typically called just before a tree rebuild so that scroll position is preserved.
---@param adapter table             The adapter instance
---@param tree Flow.Element         The UI tree to extract scroll state from
---@param options table|nil         Optional {screen_id=...} to target a specific screen
function M.save_scroll_state(adapter, tree, options)
	local params = adapter.navigation.get_data(options)
	if not params then return end
	save_scroll_state_to_params(params, tree)
end

--- Build (or rebuild) the UI element tree for the current navigation state.
--- When a transition is active, renders both from and to trees and applies
--- _alpha or _offset_x according to the transition type and eased progress.
---
--- Transition types:
---   "fade"        — cross-fade: from_tree._alpha fades out, to_tree._alpha fades in
---   "slide_left"  — to slides in from the right: from moves left, to comes from right
---   "slide_right" — to slides in from the left: from moves right, to comes from left
---
--- Returns nil and clears adapter.tree when the stack is empty.
---@param adapter table             The adapter instance
---@return Flow.Element|nil         The UI tree to pass to the renderer
function M.build_tree(adapter)
	local navigation = adapter.navigation
	local current = navigation.current()
	if not current then
		adapter.tree = nil
		adapter.dirty = false
		return nil
	end

	local tree
	local transition = adapter.transition
	if not transition or not transition.type or transition.type == "none" then
		-- No transition: just render the current screen
		tree = render_screen(current, navigation)
	else
		local from_tree = transition.from_tree
		local to_tree = render_screen(current, navigation)
		local t = ease_in_out_cubic(math.min(1, transition.progress))

		if transition.type == "fade" then
			-- Cross-fade: from fades out [1→0], to fades in [0→1]
			if from_tree then from_tree._alpha = 1 - t end
			if to_tree then to_tree._alpha = t end
		elseif transition.type == "slide_left" then
			-- Push left: from slides off left, to slides in from right
			if from_tree then from_tree._offset_x = -t end
			if to_tree then to_tree._offset_x = 1 - t end
		elseif transition.type == "slide_right" then
			-- Push right: from slides off right, to slides in from left
			if from_tree then from_tree._offset_x = t end
			if to_tree then to_tree._offset_x = -(1 - t) end
		end

		tree = to_tree or from_tree
		-- Attach from_tree as background so the renderer draws both screens
		if from_tree and tree and from_tree ~= tree then
			tree._background_screen = from_tree
		end
	end

	adapter.tree = tree
	adapter.dirty = false
	return tree
end

--- Advance the active transition by dt seconds.
--- Updates transition.progress and marks the adapter dirty each frame.
--- When progress reaches 1.0, calls navigation.complete_transition() to
--- signal that the transition is done and clear the busy flag.
---@param adapter table   The adapter instance
---@param dt number       Delta time in seconds since the last frame
---@return boolean        True when the transition just completed this frame
function M.update(adapter, dt)
	if not adapter or not adapter.transition then
		return false
	end

	local transition = adapter.transition
	transition.progress = transition.progress + dt / transition.duration
	adapter.dirty = true

	if transition.progress >= 1 then
		transition.progress = 1
		adapter.navigation.complete_transition()
		return true
	end

	return false
end

return M
