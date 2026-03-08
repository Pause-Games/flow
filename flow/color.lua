local M = {}

local NAMED_COLORS = {
	aliceblue = "#f0f8ff",
	antiquewhite = "#faebd7",
	aqua = "#00ffff",
	aquamarine = "#7fffd4",
	azure = "#f0ffff",
	beige = "#f5f5dc",
	bisque = "#ffe4c4",
	black = "#000000",
	blanchedalmond = "#ffebcd",
	blue = "#0000ff",
	blueviolet = "#8a2be2",
	brown = "#a52a2a",
	burlywood = "#deb887",
	cadetblue = "#5f9ea0",
	chartreuse = "#7fff00",
	chocolate = "#d2691e",
	coral = "#ff7f50",
	cornflowerblue = "#6495ed",
	cornsilk = "#fff8dc",
	crimson = "#dc143c",
	cyan = "#00ffff",
	darkblue = "#00008b",
	darkcyan = "#008b8b",
	darkgoldenrod = "#b8860b",
	darkgray = "#a9a9a9",
	darkgreen = "#006400",
	darkgrey = "#a9a9a9",
	darkkhaki = "#bdb76b",
	darkmagenta = "#8b008b",
	darkolivegreen = "#556b2f",
	darkorange = "#ff8c00",
	darkorchid = "#9932cc",
	darkred = "#8b0000",
	darksalmon = "#e9967a",
	darkseagreen = "#8fbc8f",
	darkslateblue = "#483d8b",
	darkslategray = "#2f4f4f",
	darkslategrey = "#2f4f4f",
	darkturquoise = "#00ced1",
	darkviolet = "#9400d3",
	deeppink = "#ff1493",
	deepskyblue = "#00bfff",
	dimgray = "#696969",
	dimgrey = "#696969",
	dodgerblue = "#1e90ff",
	firebrick = "#b22222",
	floralwhite = "#fffaf0",
	forestgreen = "#228b22",
	fuchsia = "#ff00ff",
	gainsboro = "#dcdcdc",
	ghostwhite = "#f8f8ff",
	gold = "#ffd700",
	goldenrod = "#daa520",
	gray = "#808080",
	green = "#008000",
	greenyellow = "#adff2f",
	grey = "#808080",
	honeydew = "#f0fff0",
	hotpink = "#ff69b4",
	indianred = "#cd5c5c",
	indigo = "#4b0082",
	ivory = "#fffff0",
	khaki = "#f0e68c",
	lavender = "#e6e6fa",
	lavenderblush = "#fff0f5",
	lawngreen = "#7cfc00",
	lemonchiffon = "#fffacd",
	lightblue = "#add8e6",
	lightcoral = "#f08080",
	lightcyan = "#e0ffff",
	lightgoldenrodyellow = "#fafad2",
	lightgray = "#d3d3d3",
	lightgreen = "#90ee90",
	lightgrey = "#d3d3d3",
	lightpink = "#ffb6c1",
	lightsalmon = "#ffa07a",
	lightseagreen = "#20b2aa",
	lightskyblue = "#87cefa",
	lightslategray = "#778899",
	lightslategrey = "#778899",
	lightsteelblue = "#b0c4de",
	lightyellow = "#ffffe0",
	lime = "#00ff00",
	limegreen = "#32cd32",
	linen = "#faf0e6",
	magenta = "#ff00ff",
	maroon = "#800000",
	mediumaquamarine = "#66cdaa",
	mediumblue = "#0000cd",
	mediumorchid = "#ba55d3",
	mediumpurple = "#9370db",
	mediumseagreen = "#3cb371",
	mediumslateblue = "#7b68ee",
	mediumspringgreen = "#00fa9a",
	mediumturquoise = "#48d1cc",
	mediumvioletred = "#c71585",
	midnightblue = "#191970",
	mintcream = "#f5fffa",
	mistyrose = "#ffe4e1",
	moccasin = "#ffe4b5",
	navajowhite = "#ffdead",
	navy = "#000080",
	oldlace = "#fdf5e6",
	olive = "#808000",
	olivedrab = "#6b8e23",
	orange = "#ffa500",
	orangered = "#ff4500",
	orchid = "#da70d6",
	palegoldenrod = "#eee8aa",
	palegreen = "#98fb98",
	paleturquoise = "#afeeee",
	palevioletred = "#db7093",
	papayawhip = "#ffefd5",
	peachpuff = "#ffdab9",
	peru = "#cd853f",
	pink = "#ffc0cb",
	plum = "#dda0dd",
	powderblue = "#b0e0e6",
	purple = "#800080",
	rebeccapurple = "#663399",
	red = "#ff0000",
	rosybrown = "#bc8f8f",
	royalblue = "#4169e1",
	saddlebrown = "#8b4513",
	salmon = "#fa8072",
	sandybrown = "#f4a460",
	seagreen = "#2e8b57",
	seashell = "#fff5ee",
	sienna = "#a0522d",
	silver = "#c0c0c0",
	skyblue = "#87ceeb",
	slateblue = "#6a5acd",
	slategray = "#708090",
	slategrey = "#708090",
	snow = "#fffafa",
	springgreen = "#00ff7f",
	steelblue = "#4682b4",
	tan = "#d2b48c",
	teal = "#008080",
	thistle = "#d8bfd8",
	tomato = "#ff6347",
	transparent = "#00000000",
	turquoise = "#40e0d0",
	violet = "#ee82ee",
	wheat = "#f5deb3",
	white = "#ffffff",
	whitesmoke = "#f5f5f5",
	yellow = "#ffff00",
	yellowgreen = "#9acd32",
}

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

local function to_byte(value, field)
	return math.floor(clamp01(value, field) * 255 + 0.5)
end

local function format_hex_color(r, g, b, a)
	local rr = to_byte(r, "red")
	local gg = to_byte(g, "green")
	local bb = to_byte(b, "blue")
	local aa = a == nil and 255 or to_byte(a, "alpha")

	if aa >= 255 then
		return string.format("#%02x%02x%02x", rr, gg, bb)
	end
	return string.format("#%02x%02x%02x%02x", rr, gg, bb, aa)
end

local function parse_hex_digit_pair(pair)
	local value = tonumber(pair, 16)
	assert(value ~= nil, "flow.color: invalid hex color component")
	return value
end

--- Parse hex colors in `#RGB`, `#RGBA`, `#RRGGBB`, or `#RRGGBBAA` form.
--- Alpha, when present, is encoded in the trailing nibble/pair.
---@param value string
---@return table
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

local function from_named(value)
	local hex = NAMED_COLORS[value:lower()]
	if not hex then
		return nil
	end
	return from_hex(hex)
end

function M.rgb(r, g, b)
	return format_hex_color(r, g, b, 1)
end

function M.rgba(r, g, b, a)
	return format_hex_color(r, g, b, a)
end

--- Parse a hex color string.
--- Supports `#RGB`, `#RGBA`, `#RRGGBB`, and `#RRGGBBAA`.
---@param value string
---@return string
function M.hex(value)
	local c = from_hex(value)
	return format_hex_color(c.r, c.g, c.b, c.a)
end

function M.with_alpha(value, alpha)
	local resolved = M.parse(value)
	return format_hex_color(resolved.r, resolved.g, resolved.b, alpha)
end

--- Parse a color from a supported string format.
--- String formats include hex (`#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`)
--- and common CSS named colors such as
--- `white`, `black`, and `transparent`.
---@param value string
---@return table
function M.parse(value)
	if type(value) == "table" and value.x ~= nil and value.y ~= nil and value.z ~= nil and value.w ~= nil then
		error("flow.color: Defold vector4 values are not supported; use hex or named-color strings, or flow.color helpers")
	end
	assert(type(value) == "string", "flow.color: colors must be strings")
	local trimmed = value:match("^%s*(.-)%s*$")
	if trimmed:match("^#") then
		return from_hex(trimmed)
	end
	local named = from_named(trimmed)
	if named then
		return named
	end
	error("flow.color: unsupported color string '" .. tostring(value) .. "'")
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
