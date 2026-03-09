local BottomSheet = require "flow/bottom_sheet/component"
local Box = require "flow/components/box"
local navigation_core = require "flow/navigation/core"
local navigation_gui = require "flow/navigation/gui"
local ui = require "flow/ui"

local TRANSPARENT = "#00000000"

local function get_window_size()
	return window.get_size()
end

local function clamp_render_order(value)
	value = tonumber(value) or 15
	if value < 0 then
		return 0
	end
	if value > 15 then
		return 15
	end
	return math.floor(value)
end

local function sync_window_baseline(self)
	self.last_window_w, self.last_window_h = get_window_size()
end

local function set_background_input_enabled(config, enabled)
	if not config or not config.background_focus_url then
		return
	end

	msg.post(config.background_focus_url, enabled and "acquire_input_focus" or "release_input_focus")
end

local function copy_params(params)
	local out = {}
	for key, value in pairs(params or {}) do
		out[key] = value
	end
	return out
end

local function build_idle_tree()
	return Box({
		key = "flow_bottom_sheet_idle_root",
		color = TRANSPARENT,
		style = {
			width = "100%",
			height = "100%",
		},
	})
end

local function register_screens(router, screens)
	for id, screen in pairs(screens or {}) do
		router:register(id, screen)
	end
end

local function build_navigation_facade(router)
	return {
		on = function(event, fn)
			return router:on(event, fn)
		end,
		off = function(event, fn)
			return router:off(event, fn)
		end,
		invalidate = function()
			return router:invalidate()
		end,
		push = function(id, params, options)
			return router:push(id, params, options)
		end,
		pop = function(result_or_transition, options)
			return router:pop(result_or_transition, options)
		end,
		back = function(result_or_transition, options)
			return router:back(result_or_transition, options)
		end,
		reset = function(id, params, options)
			return router:reset(id, params, options)
		end,
		current = function()
			return router:current()
		end,
		get_data = function(key, options)
			return router:get_data(key, options)
		end,
		clear_invalidation = function()
			return router:clear_invalidation()
		end,
		is_invalidated = function()
			return router:is_invalidated()
		end,
		complete_transition = function()
			return router:complete_transition()
		end,
	}
end

local function ensure_navigation_runtime(self)
	local state = self.bottom_sheet_state
	if state.navigation_runtime then
		return state.navigation_runtime
	end

	local router = navigation_core.new()
	register_screens(router, state.config.sheet.screens)

	local navigation = build_navigation_facade(router)
	local adapter = navigation_gui.new(navigation)
	state.navigation_runtime = {
		router = router,
		navigation = navigation,
		adapter = adapter,
	}
	return state.navigation_runtime
end

local build_sheet_api

local function reset_navigation_runtime(self)
	local state = self.bottom_sheet_state
	local sheet_def = state.config.sheet
	local runtime = ensure_navigation_runtime(self)

	local initial_params = sheet_def.initial_params
	if type(initial_params) == "function" then
		initial_params = initial_params(state.params, build_sheet_api(self))
	elseif type(initial_params) == "table" then
		initial_params = copy_params(initial_params)
	else
		initial_params = {}
	end

	runtime.router:reset(sheet_def.initial_screen, initial_params, "none")
	return runtime
end

local function set_tree(self, tree)
	local state = self.bottom_sheet_state
	state.tree = tree
	self.tree = tree
	ui.request_redraw(self)
	return tree
end

build_sheet_api = function(self)
	return {
		dismiss = function(result)
			local state = self.bottom_sheet_state
			if not state or not state.params or state.params._bottom_sheet_closing then
				return false
			end

			state.params._bottom_sheet_open = false
			state.params._bottom_sheet_closing = true
			state.params._bottom_sheet_result = result
			set_tree(self, state.build_tree())
			return true
		end,
		invalidate = function()
			local state = self.bottom_sheet_state
			if not state then
				return false
			end

			set_tree(self, state.build_tree())
			return true
		end,
	}
end

local function build_tree(self)
	local state = self.bottom_sheet_state
	if not state or not state.params then
		return build_idle_tree()
	end

	local sheet_def = state.config.sheet
	local params = state.params
	local content
	local background_screen
	if sheet_def.screens then
		local runtime = ensure_navigation_runtime(self)
		content = runtime.adapter:build_tree()
		runtime.navigation.clear_invalidation()
		if content and content._background_screen then
			background_screen = content._background_screen
			content._background_screen = nil
		end
	else
		content = sheet_def.view and sheet_def.view(params, build_sheet_api(self)) or nil
	end
	assert(content, "bottom_sheet host sheet must return content")

	local root = Box({
		key = state.config.id .. "_bottom_sheet_root",
		color = TRANSPARENT,
		style = {
			width = "100%",
			height = "100%",
		},
		children = {
			BottomSheet({
				key = state.config.id .. "_sheet",
				backdrop_color = sheet_def.backdrop_color or "#00000080",
				_open = params._bottom_sheet_open,
				_anim_y = params._bottom_sheet_anim_y,
				_anim_velocity = params._bottom_sheet_anim_velocity,
				_on_anim_update = function(y, velocity)
					params._bottom_sheet_anim_y = y
					params._bottom_sheet_anim_velocity = velocity
				end,
				on_backdrop_click = sheet_def.dismiss_on_backdrop == false and nil or function()
					build_sheet_api(self).dismiss()
				end,
				children = {
					content,
				},
			}),
		},
	})

	if background_screen then
		root._background_screen = background_screen
	end

	return root
end

local function finalize_close(self)
	local state = self.bottom_sheet_state
	if not state or not state.params or not state.params._bottom_sheet_closing then
		return false
	end

	if state.params._bottom_sheet_anim_y == nil or state.params._bottom_sheet_anim_velocity == nil then
		return false
	end
	if state.params._bottom_sheet_anim_velocity ~= 0 or state.params._bottom_sheet_anim_y <= 1 then
		return false
	end

	local params = state.params
	local result = params._bottom_sheet_result
	state.params = nil
	set_tree(self, build_idle_tree())
	set_background_input_enabled(state.config, true)

	if state.config.sheet.on_dismiss then
		state.config.sheet.on_dismiss(params, result, build_sheet_api(self))
	end

	return true
end

local M = {}

function M.init(self, config)
	assert(type(config) == "table", "bottom_sheet.init(self, config): config must be a table")
	assert(type(config.id) == "string" and config.id ~= "", "bottom_sheet.init: config.id is required")
	assert(type(config.sheet) == "table", "bottom_sheet.init: config.sheet is required")

	msg.post(".", "acquire_input_focus")
	ui.mount(self, { debug = config.debug == true })

	self.bottom_sheet_state = {
		config = config,
		params = nil,
		tree = nil,
	}
	self.bottom_sheet_state.build_tree = function()
		return build_tree(self)
	end

	gui.set_render_order(clamp_render_order(config.render_order))
	sync_window_baseline(self)
	set_tree(self, build_idle_tree())
end

function M.final(self)
	local state = self.bottom_sheet_state
	if state then
		set_background_input_enabled(state.config, true)
		if state.navigation_runtime and state.navigation_runtime.adapter then
			state.navigation_runtime.adapter:destroy()
		end
	end
	msg.post(".", "release_input_focus")
end

function M.update(self, dt)
	local state = self.bottom_sheet_state
	if not state then
		return false
	end

	local animating = ui.update_animations(self, dt)
	local navigation_requested_rebuild = false
	if state.navigation_runtime then
		local runtime = state.navigation_runtime
		local transition_complete = runtime.adapter:update(dt)
		navigation_requested_rebuild = runtime.adapter:needs_rebuild() or transition_complete or runtime.navigation.is_invalidated()
	end
	local hook_requested_rebuild = state.config.on_update and state.config.on_update(self, dt, build_sheet_api(self)) == true or false
	local closed = finalize_close(self)
	if hook_requested_rebuild or navigation_requested_rebuild then
		set_tree(self, state.build_tree())
	end

	local redrew = ui.update(self, self.tree)
	return animating or closed or hook_requested_rebuild or navigation_requested_rebuild or redrew
end

function M.present(self, params)
	local state = self.bottom_sheet_state
	msg.post(".", "acquire_input_focus")
	state.params = copy_params(params)
	state.params._bottom_sheet_open = true
	state.params._bottom_sheet_closing = false
	state.params._bottom_sheet_result = nil
	state.params._bottom_sheet_anim_y = nil
	state.params._bottom_sheet_anim_velocity = nil
	if state.config.sheet.screens then
		reset_navigation_runtime(self)
	end
	set_background_input_enabled(state.config, false)
	set_tree(self, state.build_tree())
end

function M.dismiss(self, result)
	return build_sheet_api(self).dismiss(result)
end

function M.invalidate(self)
	return build_sheet_api(self).invalidate()
end

function M.on_input(self, action_id, action)
	local w, h = get_window_size()
	local size_changed = (self.last_window_w ~= w or self.last_window_h ~= h)
	if size_changed then
		sync_window_baseline(self)
		if self.tree then
			ui.render(self, self.tree)
		end
	end

	return ui.on_input(self, action_id, action)
end

function M.on_message(self, message_id, message, sender)
	local state = self.bottom_sheet_state
	if not state then
		return false
	end

	if message_id == state.config.open_message_id then
		M.present(self, message and message.params or nil)
		return true
	end

	if state.config.close_message_id and message_id == state.config.close_message_id then
		M.dismiss(self, message and message.result or nil)
		return true
	end

	if state.config.on_message then
		return state.config.on_message(self, message_id, message, sender, build_sheet_api(self)) == true
	end

	return false
end

return M
