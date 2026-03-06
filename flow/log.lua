-- flow/log.lua
-- Centralized logging for the Flow library.
-- Supports a global level, per-context overrides, and a pluggable sink.

local M = {}

local LEVELS = {
	none = 0,
	error = 1,
	warn = 2,
	info = 3,
	debug = 4,
}

local LEVEL_NAMES = {
	[0] = "none",
	[1] = "error",
	[2] = "warn",
	[3] = "info",
	[4] = "debug",
}

local unpack_args = unpack
if not unpack_args and table then
	unpack_args = rawget(table, "unpack")
end

local state = {
	level = LEVELS.none,
	context_levels = {},
	sink = nil,
}

local function default_sink(entry)
	print(entry.line)
end

local function normalize_context(context)
	if context == nil or context == "" then
		return "general"
	end
	return tostring(context)
end

local function normalize_level(level)
	if type(level) == "number" then
		assert(LEVEL_NAMES[level] ~= nil, "flow.log: unknown numeric level")
		return level
	end

	level = tostring(level or ""):lower()
	local normalized = LEVELS[level]
	assert(normalized ~= nil, "flow.log: unknown level '" .. tostring(level) .. "'")
	return normalized
end

local function level_name(level)
	return LEVEL_NAMES[normalize_level(level)]
end

local function current_threshold(context)
	local context_name = normalize_context(context)
	local override = state.context_levels[context_name]
	if override ~= nil then
		return override
	end
	return state.level
end

local function should_emit(level, context)
	local numeric_level = normalize_level(level)
	local threshold = current_threshold(context)
	return threshold > LEVELS.none and numeric_level <= threshold
end

local function message_from_args(...)
	local argc = select("#", ...)
	if argc == 0 then
		return ""
	end

	if argc == 1 then
		return tostring((...))
	end

	local first = select(1, ...)
	if type(first) == "string" then
		local ok, formatted = pcall(string.format, first, unpack_args({ select(2, ...) }))
		if ok then
			return formatted
		end
	end

	local parts = {}
	for i = 1, argc do
		parts[i] = tostring(select(i, ...))
	end
	return table.concat(parts, " ")
end

local function emit(level, context, ...)
	if not should_emit(level, context) then
		return false
	end

	local level_text = string.upper(level_name(level))
	local context_name = normalize_context(context)
	local message = message_from_args(...)
	local entry = {
		level = level_name(level),
		context = context_name,
		message = message,
		line = string.format("[flow][%s][%s] %s", level_text, context_name, message),
	}

	(state.sink or default_sink)(entry)
	return true
end

M.levels = LEVELS

function M.get_level()
	return level_name(state.level)
end

function M.set_level(level)
	state.level = normalize_level(level)
	return M.get_level()
end

function M.get_context_level(context)
	local context_name = normalize_context(context)
	local level = state.context_levels[context_name]
	if level == nil then
		return nil
	end
	return level_name(level)
end

function M.set_context_level(context, level)
	local context_name = normalize_context(context)
	state.context_levels[context_name] = normalize_level(level)
	return M.get_context_level(context_name)
end

function M.clear_context_level(context)
	local context_name = normalize_context(context)
	state.context_levels[context_name] = nil
	return true
end

function M.none(context)
	if context == nil then
		return M.set_level("none")
	end
	return M.set_context_level(context, "none")
end

function M.is_enabled(level, context)
	return should_emit(level, context)
end

function M.set_sink(fn)
	assert(fn == nil or type(fn) == "function", "flow.log.set_sink(fn) expects a function or nil")
	state.sink = fn
	return true
end

function M.debug(context, ...)
	return emit("debug", context, ...)
end

function M.info(context, ...)
	return emit("info", context, ...)
end

function M.warn(context, ...)
	return emit("warn", context, ...)
end

function M.error(context, ...)
	return emit("error", context, ...)
end

function M._reset_for_tests()
	state.level = LEVELS.none
	state.context_levels = {}
	state.sink = nil
	return true
end

return M
