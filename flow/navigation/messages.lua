-- flow/navigation/messages.lua
-- Defold message-based navigation API for the Flow library.
-- Allows any script in the project to trigger navigation operations by posting
-- Defold messages, enabling non-GUI scripts (game logic, collection proxies) to
-- drive screen transitions without holding a reference to the navigation module.
--
-- Usage in gui_script:
--   function on_message(self, message_id, message, sender)
--     return navigation_messages.on_message(message_id, message)
--   end
--
-- Usage from any script:
--   msg.post("main:/go#gui", navigation_messages.PUSH, { id = "game", params = { level = 1 } })
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

--- Internal map of operation name → message id hash.
--- Used to match incoming message_ids in on_message().
---@type table<string, hash|string>
local IDS = {
	push       = safe_hash("navigation_push"),
	pop        = safe_hash("navigation_pop"),
	replace    = safe_hash("navigation_replace"),
	reset      = safe_hash("navigation_reset"),
	back       = safe_hash("navigation_back"),
	invalidate = safe_hash("navigation_invalidate"),
}

--- Extract navigation options from a message table.
--- Prefers message.options (full PushOptions table); falls back to
--- message.transition (legacy string shorthand).
---@param message table|nil  The raw Defold message payload
---@return Flow.PushOptions|string|nil  Options for the navigation call
local function resolve_options(message)
	if not message then
		return nil
	end
	if message.options ~= nil then
		return message.options
	end
	return message.transition
end

--- Extract the screen id from a message table.
--- Accepts either message.id or the legacy message.screen_id field.
---@param message table|nil  The raw Defold message payload
---@return string|nil        The screen id string, or nil if absent
local function resolve_id(message)
	if not message then
		return nil
	end
	return message.id or message.screen_id
end

-- Public message id constants — use these when posting messages so code
-- remains correct even if the hash strings change.

--- Map of all supported message ids keyed by operation name.
---@type table<string, hash|string>
M.ids = IDS

--- Message id for navigation.push — payload: {id, params?, options?}
---@type hash|string
M.PUSH = IDS.push

--- Message id for navigation.pop — payload: {result?, options?}
---@type hash|string
M.POP = IDS.pop

--- Message id for navigation.replace — payload: {id, params?, options?}
---@type hash|string
M.REPLACE = IDS.replace

--- Message id for navigation.reset — payload: {id, params?, options?}
---@type hash|string
M.RESET = IDS.reset

--- Message id for navigation.back — payload: {result?, options?}
---@type hash|string
M.BACK = IDS.back

--- Message id for navigation.invalidate — no payload required
---@type hash|string
M.INVALIDATE = IDS.invalidate

--- Handle an incoming Defold message and dispatch it to the navigation module.
--- Returns true when the message was a recognized navigation message and was handled.
--- Returns false for all other messages so callers can chain additional handlers.
---
--- Supported message payloads:
---   PUSH/REPLACE/RESET: { id = "screen_id", params = {}, options = {} }
---   POP/BACK:           { result = {}, options = {} }
---   INVALIDATE:         no payload needed
---@param message_id hash|string   The incoming Defold message id hash, or raw string in test environments
---@param message? table           The incoming Defold message payload
---@return boolean                 True when the message was handled by navigation
function M.on_message(message_id, message)
	if message_id == IDS.push then
		log.debug("nav.messages", "dispatch push id=%s", tostring(resolve_id(message)))
		navigation.push(resolve_id(message), message and message.params or nil, resolve_options(message))
		return true
	end
	if message_id == IDS.pop then
		log.debug("nav.messages", "dispatch pop")
		navigation.pop(message and message.result or nil, resolve_options(message))
		return true
	end
	if message_id == IDS.replace then
		log.debug("nav.messages", "dispatch replace id=%s", tostring(resolve_id(message)))
		navigation.replace(resolve_id(message), message and message.params or nil, resolve_options(message))
		return true
	end
	if message_id == IDS.reset then
		log.debug("nav.messages", "dispatch reset id=%s", tostring(resolve_id(message)))
		navigation.reset(resolve_id(message), message and message.params or nil, resolve_options(message))
		return true
	end
	if message_id == IDS.back then
		log.debug("nav.messages", "dispatch back")
		navigation.back(message and message.result or nil, resolve_options(message))
		return true
	end
	if message_id == IDS.invalidate then
		log.debug("nav.messages", "dispatch invalidate")
		navigation.invalidate()
		return true
	end
	return false
end

--- Backwards-compatible alias for older call sites.
M.handle_message = M.on_message

return M
