-- flow/navigation/runtime.lua
-- Non-GUI navigation bootstrap helper for the Flow library.
-- Provides M.init() / M.final() / M.on_message() lifecycle methods for
-- use in .script files (non-GUI Defold scripts) that drive navigation
-- without a GUI renderer — e.g. a bootstrap collection script that manages
-- collection proxy routing alongside the main GUI script.
--
-- Typical usage:
--   local nav_runtime = require "flow/navigation/runtime"
--   function init(self) nav_runtime.init(self, { screens = MY_SCREENS }) end
--   function final(self) nav_runtime.final(self) end
--   function on_message(self, id, msg, s) nav_runtime.on_message(self, id, msg, s) end
local navigation = require "flow/navigation/init"
local log = require "flow/log"
local navigation_messages = require "flow/navigation/messages"
local navigation_proxy = require "flow/navigation/proxy"

local M = {}

--- Register all screens from a {id → screen_def} table.
--- No-op when screens is nil or empty.
---@param screens? table<string, Flow.ScreenDef>  Map of screen id to definition
local function register_screens(screens)
	if not screens then return end
	for id, def in pairs(screens) do
		navigation.register(id, def)
	end
end

--- Initialize navigation for a non-GUI script.
--- Registers screens, optionally attaches the collection proxy runtime,
--- and navigates to the initial screen if specified.
---
--- Stores state in self.navigation and self.navigation_runtime so it can be
--- accessed from on_message() and cleaned up in final().
---@param self table               The .script self table
---@param config? Flow.RuntimeConfig  Configuration options
---@return table                   The navigation_runtime state table stored on self
function M.init(self, config)
	config = config or {}

	self.navigation = navigation
	self.navigation_runtime = {
		config = config,
		--- The proxy runtime instance, or nil when proxy runtime is disabled.
		---@type table|nil
		proxy = nil,
	}

	register_screens(config.screens)

	-- Attach collection proxy management unless explicitly disabled
	if config.enable_proxy_runtime ~= false then
		self.navigation_runtime.proxy = navigation_proxy.attach(navigation, config.proxy_options)
	end

	if config.initial_screen then
		navigation.reset(config.initial_screen, config.initial_params, config.initial_options)
	end

	log.info("nav.runtime", "init screens=%s initial_screen=%s proxy_runtime=%s", tostring(config.screens ~= nil), config.initial_screen or "nil", tostring(config.enable_proxy_runtime ~= false))
	return self.navigation_runtime
end

--- Clean up the navigation runtime for a non-GUI script.
--- Detaches the proxy runtime (if any) to remove event listeners.
--- Call this from the .script final() lifecycle function.
---@param self table  The .script self table initialized by M.init()
function M.final(self)
	local runtime = self.navigation_runtime
	if runtime and runtime.proxy then
		runtime.proxy:detach()
		runtime.proxy = nil
	end
	log.info("nav.runtime", "finalized runtime")
end

--- Handle an incoming Defold message and route it to navigation.
--- Delegates to navigation_messages.on_message() which dispatches
--- push/pop/replace/reset/back/invalidate messages.
--- Returns true when the message was consumed by navigation.
---@param self table               The .script self table
---@param message_id hash|string   The incoming message id hash, or raw string in test environments
---@param message? table           The incoming message payload
---@param sender? userdata         The sender's msg.url() (unused, for Defold API compat)
---@return boolean                 True when the message was handled by navigation
function M.on_message(self, message_id, message, sender)
	local handled = navigation_messages.on_message(message_id, message)
	if handled then
		log.debug("nav.runtime", "handled message id=%s", tostring(message_id))
	end
	return handled
end

return M
