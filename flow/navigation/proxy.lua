-- flow/navigation/proxy.lua
-- Defold collection proxy lifecycle manager for the Flow navigation system.
-- Automatically sends async_load / enable / disable messages to collection
-- proxy components as screens are pushed and popped, enabling screen-level
-- collection isolation and memory management.
--
-- Attach once in your navigation bootstrap script, detach in final():
--   local runtime = proxy.attach(navigation)
--   -- ... later:
--   runtime:detach()
local navigation = require "flow/navigation/init"
local log = require "flow/log"

local M = {}

--- Safely hash a string value. Returns the raw string outside Defold runtime.
---@param value string             The string to hash
---@return hash|string             Hashed value, or raw string in test environments
local function safe_hash(value)
	if type(hash) == "function" then
		return hash(value)
	end
	return value
end

--- Default message ids and behavior options used when none are provided to attach().
---@type Flow.ProxyAttachOptions
local DEFAULTS = {
	--- Message id sent to proxy_url to start async loading the collection.
	preload_message_id = safe_hash("async_load"),
	--- Message id sent to proxy_url when the screen becomes active (visible).
	enable_message_id = safe_hash("enable"),
	--- Message id sent to proxy_url when the screen becomes inactive (hidden).
	disable_message_id = safe_hash("disable"),
	--- When true, preloads and syncs already-registered screens at attach time.
	sync_existing = true,
}

--- Post a Defold message, guarding against non-Defold environments.
--- No-ops when url is nil or msg is not available (unit tests).
---@param url userdata|nil         Target msg.url(); no-op when nil
---@param message_id hash|string   Defold message id hash, or raw string in test environments
---@param message table|nil        Message payload (empty table when nil)
local function post(url, message_id, message)
	if not url then return end
	if type(msg) ~= "table" or type(msg.post) ~= "function" then return end
	msg.post(url, message_id, message or {})
end

--- Merge caller-supplied options over the DEFAULTS table.
--- Creates a new table; does not mutate either input.
---@param opts Flow.ProxyAttachOptions|nil  Caller options; may be nil or partial
---@return Flow.ProxyAttachOptions          Complete options with all fields set
local function merge_options(opts)
	local out = {}
	for k, v in pairs(DEFAULTS) do
		out[k] = v
	end
	for k, v in pairs(opts or {}) do
		out[k] = v
	end
	return out
end

--- Send a preload message to a screen's proxy_url if it has one and hasn't
--- been preloaded yet. Tracks preloaded URLs in runtime.preloaded.
---@param runtime table            The runtime instance (created by M.attach)
---@param screen_id string         The screen id being preloaded
---@param screen Flow.RegisteredScreen  The normalized screen definition from core.lua
local function preload_screen(runtime, screen_id, screen)
	if not screen or not screen.proxy_url or screen.preload ~= true then
		return
	end
	if runtime.preloaded[screen.proxy_url] then
		return
	end
	post(screen.proxy_url, runtime.options.preload_message_id, { screen_id = screen_id })
	runtime.preloaded[screen.proxy_url] = true
	log.info("nav.proxy", "preload screen=%s", screen_id)
end

--- Synchronize the active collection proxy with the current navigation state.
--- When the current screen's proxy_url differs from the previously active one:
---   1. Sends "disable" to the outgoing proxy.
---   2. Sends "enable" to the incoming proxy with screen id and params.
---@param runtime table  The runtime instance tracking active proxy state
local function sync_active_proxy(runtime)
	local current = runtime.navigation.current()
	local next_proxy_url = current and current.screen and current.screen.proxy_url or nil
	if runtime.active_proxy_url == next_proxy_url then
		return
	end

	if runtime.active_proxy_url then
		post(runtime.active_proxy_url, runtime.options.disable_message_id, {
			screen_id = runtime.active_screen_id,
		})
		log.info("nav.proxy", "disable screen=%s", runtime.active_screen_id or "nil")
	end

	if next_proxy_url then
		post(next_proxy_url, runtime.options.enable_message_id, {
			screen_id = current.id,
			params = current.params,
		})
		log.info("nav.proxy", "enable screen=%s", current.id)
	end

	runtime.active_proxy_url = next_proxy_url
	runtime.active_screen_id = current and current.id or nil
end

--- Attach the collection proxy runtime to a navigation instance.
--- Registers "preload" and "changed" event listeners so proxies are
--- managed automatically as screens are navigated.
---
--- When opts.sync_existing is true (the default), immediately preloads
--- all already-registered screens with preload=true, and syncs the current
--- active proxy if a screen is already on the stack.
---@param nav Flow.Navigation|nil  The navigation module; defaults to flow/navigation/init
---@param opts Flow.ProxyAttachOptions|nil  Options overriding DEFAULTS
---@return table                   The runtime instance (call :detach() to clean up)
function M.attach(nav, opts)
	nav = nav or navigation
	local runtime = {
		navigation = nav,
		options = merge_options(opts),
		--- Set of proxy URLs already sent a preload message (prevents duplicates).
		---@type table<userdata, boolean>
		preloaded = {},
		--- The proxy_url of the currently enabled collection, or nil.
		---@type userdata|nil
		active_proxy_url = nil,
		--- The screen id currently loaded in the active collection.
		---@type string|nil
		active_screen_id = nil,
		--- Listener closures stored for removal in detach().
		---@type table
		listeners = {},
	}

	--- Handle the "preload" event emitted when a screen with preload=true is registered.
	runtime.listeners.preload = function(screen_id, screen)
		preload_screen(runtime, screen_id, screen)
	end

	--- Handle the "changed" event: sync which collection proxy is active.
	runtime.listeners.changed = function()
		sync_active_proxy(runtime)
	end

	nav.on("preload", runtime.listeners.preload)
	nav.on("changed", runtime.listeners.changed)

	-- Immediately sync if screens are already registered (e.g. called after init)
	if runtime.options.sync_existing then
		local router = nav._router and nav._router() or nil
		if router and router.list_screens then
			for screen_id, screen in pairs(router:list_screens()) do
				preload_screen(runtime, screen_id, screen)
			end
		end
		sync_active_proxy(runtime)
	end

	log.info("nav.proxy", "attached sync_existing=%s", tostring(runtime.options.sync_existing))
	return setmetatable(runtime, { __index = M })
end

--- Remove all navigation event listeners and clean up the runtime.
--- Call this in your bootstrap script's final() function to prevent
--- leaked listeners after the script is destroyed.
---@param self table  The runtime instance created by M.attach()
function M.detach(self)
	if not self or not self.navigation or not self.listeners then return end
	self.navigation.off("preload", self.listeners.preload)
	self.navigation.off("changed", self.listeners.changed)
	self.listeners = nil
	log.info("nav.proxy", "detached")
end

return M
