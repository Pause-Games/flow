local M = {}

local function clamp01(value, field)
	assert(type(value) == "number", "flow.color: " .. field .. " must be a number")
	local normalized = value
	if normalized > 1 then
		normalized = normalized / 255
	end
	assert(normalized >= 0 and normalized <= 1, "flow.color: " .. field .. " must be between 0 and 1 or 0 and 255")
	return normalized
end

local function make_color(r, g, b, a)
	return {
		r = clamp01(r, "red"),
		g = clamp01(g, "green"),
		b = clamp01(b, "blue"),
		a = clamp01(a == nil and 1 or a, "alpha"),
	}
end

local function parse_hex_digit_pair(pair)
	local value = tonumber(pair, 16)
	assert(value ~= nil, "flow.color: invalid hex color component")
	return value
end

local function from_hex(value)
	assert(type(value) == "string", "flow.color.hex(value) requires a string")
	local hex = value:match("^#(.+)$")
	assert(hex ~= nil, "flow.color: hex colors must start with #")
	if #hex == 3 or #hex == 4 then
		local chars = {}
		for i = 1, #hex do
			local c = hex:sub(i, i)
			chars[i] = c .. c
		end
		return make_color(
			parse_hex_digit_pair(chars[1]),
			parse_hex_digit_pair(chars[2]),
			parse_hex_digit_pair(chars[3]),
			chars[4] and parse_hex_digit_pair(chars[4]) or 255
		)
	end
	if #hex == 6 or #hex == 8 then
		return make_color(
			parse_hex_digit_pair(hex:sub(1, 2)),
			parse_hex_digit_pair(hex:sub(3, 4)),
			parse_hex_digit_pair(hex:sub(5, 6)),
			#hex == 8 and parse_hex_digit_pair(hex:sub(7, 8)) or 255
		)
	end
	error("flow.color: hex colors must be #RGB, #RGBA, #RRGGBB, or #RRGGBBAA")
end

local function parse_function_color(value)
	local fn_name, args_text = value:match("^%s*([%a]+)%s*%((.*)%)%s*$")
	if not fn_name then
		return nil
	end

	local args = {}
	for token in args_text:gmatch("[^,]+") do
		local trimmed = token:match("^%s*(.-)%s*$")
		local num = tonumber(trimmed)
		assert(num ~= nil, "flow.color: rgb()/rgba() arguments must be numbers")
		args[#args + 1] = num
	end

	if fn_name == "rgb" then
		assert(#args == 3, "flow.color: rgb() requires exactly 3 arguments")
		return make_color(args[1], args[2], args[3], 1)
	end
	if fn_name == "rgba" then
		assert(#args == 4, "flow.color: rgba() requires exactly 4 arguments")
		return make_color(args[1], args[2], args[3], args[4])
	end

	error("flow.color: unsupported color function '" .. tostring(fn_name) .. "'")
end

local function is_array_table(value)
	if type(value) ~= "table" then
		return false
	end
	return value[1] ~= nil or value[2] ~= nil or value[3] ~= nil or value[4] ~= nil
end

local function parse_table(value)
	assert(type(value) == "table", "flow.color: color tables must be tables")
	assert(value.x == nil and value.y == nil and value.z == nil and value.w == nil,
		"flow.color: Defold vector4 values are not supported; use flow.color.rgba(...) or CSS-like strings")

	if is_array_table(value) then
		assert(value[1] ~= nil and value[2] ~= nil and value[3] ~= nil,
			"flow.color: array colors require at least 3 entries")
		return make_color(value[1], value[2], value[3], value[4] == nil and 1 or value[4])
	end

	assert(value.r ~= nil and value.g ~= nil and value.b ~= nil,
		"flow.color: table colors require r/g/b keys")
	return make_color(value.r, value.g, value.b, value.a == nil and 1 or value.a)
end

function M.rgb(r, g, b)
	return make_color(r, g, b, 1)
end

function M.rgba(r, g, b, a)
	return make_color(r, g, b, a)
end

function M.hex(value)
	return from_hex(value)
end

function M.with_alpha(value, alpha)
	local resolved = M.parse(value)
	resolved.a = clamp01(alpha, "alpha")
	return resolved
end

function M.parse(value)
	local kind = type(value)
	if kind == "string" then
		if value:match("^%s*#") then
			return from_hex(value)
		end
		return parse_function_color(value)
	end
	if kind == "table" then
		return parse_table(value)
	end
	error("flow.color: colors must be CSS-like strings or plain Lua tables")
end

function M.resolve(value)
	local c = M.parse(value)
	return vmath.vector4(c.r, c.g, c.b, c.a)
end

return setmetatable(M, {
	__call = function(_, r, g, b, a)
		return M.rgba(r, g, b, a)
	end,
})
