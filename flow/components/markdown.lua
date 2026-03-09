-- flow/components/markdown.lua
-- Markdown parser and renderer for the Flow library.
-- Converts a markdown string into a scrollable Flow UI element tree.
-- Supports a practical subset of CommonMark:
--   # Headers (h1–h6, height scales with level)
--   --- Horizontal rules
--   - / * Unordered lists
--   1. Ordered lists
--   > Blockquotes
--   ``` Code blocks (multi-line)
--   **bold** Inline highlighted spans (colored background; no font-weight change)
--   `code`   Inline code (darker background)
--   ![alt](icon:icon_star) Real atlas-backed image via the default "icons" texture
--   ![alt](atlas:texture_name:image_name) Real atlas-backed image via an explicit GUI texture
--   ![alt](url) Image placeholder (colored box fallback)
--
-- Entry points:
--   M.parse(text, key_prefix)  → Flow.Element[] (array of line elements)
--   M.viewer(text, key, style) → Scroll element (full viewer component)
--   M(opts)                    → Scroll element (callable shorthand)
local Box = require "flow/components/box"
local rgba = require("flow/color").rgba
local Icon = require "flow/components/icon"
local Scroll = require "flow/components/scroll"
local Text = require "flow/components/text"
local M = {}

--- Default style applied to the outer Scroll container in M.viewer() / M().
--- Callers can override individual fields via the style_override / opts.style argument.
---@type Flow.Style
local DEFAULT_STYLE = {
	flex_grow = 1,
	flex_direction = "column",
	gap = 5,
	padding = 20
}

local function resolve_scale_number(scale)
	if type(scale) == "number" then
		return scale
	end
	if type(scale) == "table" then
		return scale.x or scale.y or 1
	end
	return 1
end

local function derive_wrap_options(options, delta_width)
	if not options then
		return nil
	end

	local derived = {}
	for key, value in pairs(options) do
		derived[key] = value
	end
	if derived.wrap_width then
		derived.wrap_width = math.max(80, derived.wrap_width - (delta_width or 0))
	end
	return derived
end

--- Build a stable element key for a parsed line.
--- Ensures unique keys across all lines in the document.
---@param prefix string|nil  Document-level key prefix (default "markdown")
---@param index number       1-based line index in the source text
---@param suffix string|nil  Optional additional suffix to distinguish sub-elements
---@return string            The composed cache key string
local function line_key(prefix, index, suffix)
	local key = string.format("%s_line_%d", prefix or "markdown", index)
	if suffix then
		key = key .. "_" .. suffix
	end
	return key
end

--- Parse a line of text for inline bold (**...**) and code (`...`) markers.
--- Returns an ordered array of segments, each with {text, bold, code} fields.
--- Segments are returned in source order; plain text segments have bold=false, code=false.
---@param text string|nil  The raw line text to scan; nil returns a single empty segment
---@return {text: string, bold: boolean, code: boolean}[]  Inline formatting segments
local function parse_inline_formatting(text)
	if not text then return {{text = "", bold = false, code = false}} end

	local segments = {}
	local i = 1
	local current_text

	while i <= #text do
		-- Locate the next bold span (**...**) and code span (`...`)
		local bold_start, bold_end, bold_content = text:find("%*%*(.-)%*%*", i)
		local code_start, code_end, code_content = text:find("`(.-)`", i)

		-- Determine which marker comes first in the source
		local next_match_pos = nil
		local match_type = nil

		if bold_start and (not code_start or bold_start < code_start) then
			next_match_pos = bold_start
			match_type = "bold"
		elseif code_start then
			next_match_pos = code_start
			match_type = "code"
		end

		if next_match_pos then
			-- Emit any plain text that precedes the marker
			if next_match_pos > i then
				current_text = text:sub(i, next_match_pos - 1)
				if current_text ~= "" then
					table.insert(segments, {text = current_text, bold = false, code = false})
				end
			end

			-- Emit the formatted segment
			if match_type == "bold" then
				table.insert(segments, {text = bold_content, bold = true, code = false})
				i = bold_end + 1
			else
				table.insert(segments, {text = code_content, bold = false, code = true})
				i = code_end + 1
			end
		else
			-- No more markers; emit the remaining plain text and stop
			current_text = text:sub(i)
			if current_text ~= "" then
				table.insert(segments, {text = current_text, bold = false, code = false})
			end
			break
		end
	end

	-- Fallback: return original text as a single plain segment
	if #segments == 0 then
		table.insert(segments, {text = text, bold = false, code = false})
	end

	return segments
end

--- Estimate the pixel width of a string for layout purposes.
--- Uses a fixed 8px-per-character approximation — good enough for proportional
--- sizing of inline segments without requiring a real font metrics query.
---@param text string  The text to measure
---@return number      Estimated width in pixels
local function get_text_metrics_safe(font, text, scale)
	local ok, metrics = pcall(gui.get_text_metrics, font or "default", text or "")
	if ok and metrics then
		local factor = resolve_scale_number(scale)
		return {
			width = (metrics.width or 0) * factor,
			height = (metrics.height or 0) * factor,
		}
	end

	return {
		width = #(text or "") * 8,
		height = 20,
	}
end

local function estimate_text_width(text, font, scale)
	return get_text_metrics_safe(font, text, scale).width
end

local function estimate_line_height(font, scale)
	local metrics = get_text_metrics_safe(font, "Ag", scale)
	return math.max(20, math.ceil((metrics.height or 0) * 1.15))
end

local function make_space_indent(target_width, font, scale)
	local space_width = math.max(1, estimate_text_width(" ", font, scale))
	local count = math.max(1, math.ceil(target_width / space_width))
	return string.rep(" ", count)
end

local function rstrip(value)
	return (value or ""):gsub("%s+$", "")
end

---@param segments {text: string, bold: boolean, code: boolean}[]
---@return string
local function flatten_segments_text(segments)
	local text = {}
	for i = 1, #segments do
		text[#text + 1] = segments[i].text or ""
	end
	return table.concat(text)
end

local function flatten_segments_plain_text(segments)
	local text = {}
	for i = 1, #segments do
		local seg = segments[i]
		local value = seg.text or ""
		if seg.bold then
			value = string.upper(value)
		elseif seg.code then
			value = "`" .. value .. "`"
		end
		text[#text + 1] = value
	end
	return table.concat(text)
end

---@param text string
---@param max_width number
---@param font string
---@param scale number|table|nil
---@return string, number
local function wrap_text_to_width(text, max_width, font, scale)
	if text == "" or max_width <= 0 then
		return text, 1
	end

	local wrapped_lines = {}

	for paragraph in (text .. "\n"):gmatch("(.-)\n") do
		if paragraph == "" then
			wrapped_lines[#wrapped_lines + 1] = ""
		else
			local current_line = ""
			for word in paragraph:gmatch("%S+") do
				local candidate = current_line == "" and word or (current_line .. " " .. word)
				if current_line ~= "" and estimate_text_width(candidate, font, scale) > max_width then
					wrapped_lines[#wrapped_lines + 1] = current_line
					current_line = word
				else
					current_line = candidate
				end
			end

			if current_line ~= "" then
				wrapped_lines[#wrapped_lines + 1] = current_line
			end
		end
	end

	return table.concat(wrapped_lines, "\n"), math.max(1, #wrapped_lines)
end

local function tokenize_segments_for_wrap(segments)
	local tokens = {}
	for i = 1, #segments do
		local seg = segments[i]
		local text = seg.text or ""
		local start = 1
		while start <= #text do
			local chunk, spacing, finish = text:match("(%s*%S+)(%s*)()", start)
			if not chunk then
				break
			end
			tokens[#tokens + 1] = {
				text = chunk .. spacing,
				bold = seg.bold,
				code = seg.code,
			}
			start = finish
		end
	end
	return tokens
end

local function merge_line_segments(tokens)
	local merged = {}
	for i = 1, #tokens do
		local token = tokens[i]
		if token.text ~= "" then
			local previous = merged[#merged]
			if previous and previous.bold == token.bold and previous.code == token.code then
				previous.text = previous.text .. token.text
			else
				merged[#merged + 1] = {
					text = token.text,
					bold = token.bold,
					code = token.code,
				}
			end
		end
	end

	local last = merged[#merged]
	if last then
		last.text = rstrip(last.text)
	end

	if #merged == 0 then
		merged[1] = { text = "", bold = false, code = false }
	end

	return merged
end

local function wrap_segments_to_lines(segments, max_width, font, scale)
	local tokens = tokenize_segments_for_wrap(segments)
	if #tokens == 0 then
		return {
			{
				{ text = "", bold = false, code = false }
			}
		}
	end

	local lines = {}
	local current_tokens = {}
	local current_width = 0

	for i = 1, #tokens do
		local token = tokens[i]
		local token_width = estimate_text_width(token.text, font, scale)
		if current_width > 0 and current_width + token_width > max_width then
			lines[#lines + 1] = merge_line_segments(current_tokens)
			current_tokens = {}
			current_width = 0
			token.text = token.text:gsub("^%s+", "")
			token_width = estimate_text_width(token.text, font, scale)
		end

		current_tokens[#current_tokens + 1] = {
			text = token.text,
			bold = token.bold,
			code = token.code,
		}
		current_width = current_width + token_width
	end

	if #current_tokens > 0 then
		lines[#lines + 1] = merge_line_segments(current_tokens)
	end

	if #lines == 0 then
		lines[1] = {
			{ text = "", bold = false, code = false }
		}
	end

	return lines
end

local function wrap_prefixed_text(prefix, text, max_width, font, scale)
	local prefix_width = estimate_text_width(prefix, font, scale)
	local content_width = math.max(80, max_width - prefix_width)
	local wrapped_body = wrap_text_to_width(text, content_width, font, scale)
	local indent = make_space_indent(prefix_width, font, scale)
	local lines = {}

	for line in (wrapped_body .. "\n"):gmatch("(.-)\n") do
		if #lines == 0 then
			lines[#lines + 1] = prefix .. line
		else
			lines[#lines + 1] = indent .. line
		end
	end

	return table.concat(lines, "\n")
end

--- Parse markdown image syntax extensions understood by the renderer.
--- Supported real-image forms:
---   icon:icon_star
---   atlas:icons:icon_star
---@param image_url string|nil
---@return {texture: string, image: string}|nil
local function parse_image_source(image_url)
	if not image_url then
		return nil
	end

	local image = image_url:match("^icon:(.+)$")
	if image then
		return {
			texture = "icons",
			image = image,
		}
	end

	local texture, atlas_image = image_url:match("^atlas:([^:]+):(.+)$")
	if texture and atlas_image then
		return {
			texture = texture,
			image = atlas_image,
		}
	end

	return nil
end

---@param value string|nil
---@return number|string|nil
local function parse_width_value(value)
	if not value or value == "" then
		return nil
	end
	return tonumber(value) or value
end

---@param value string|nil
---@return number|nil
local function parse_height_value(value)
	if not value or value == "" then
		return nil
	end
	return tonumber(value)
end

---@param value string|nil
---@return number|nil
local function parse_aspect_value(value)
	if not value or value == "" then
		return nil
	end

	local w, h = value:match("^(%d+%.?%d*):(%d+%.?%d*)$")
	if w and h then
		local width = tonumber(w)
		local height = tonumber(h)
		if width and height and height > 0 then
			return width / height
		end
	end

	local aspect = tonumber(value)
	if aspect and aspect > 0 then
		return aspect
	end

	return nil
end

---@param value string|nil
---@return "stretch"|"fit"
local function parse_scale_mode(value)
	local mode = type(value) == "string" and value:lower() or "stretch"
	if mode == "contain" or mode == "cover" then
		mode = "fit"
	end
	if mode == "fit" then
		return mode
	end
	return "stretch"
end

---@param image_url string|nil
---@return {texture: string, image: string, width: number|string, height: number, scale: "stretch"|"fit", aspect: number|nil}|nil
local function parse_image_spec(image_url)
	if not image_url then
		return nil
	end

	local parts = {}
	for part in image_url:gmatch("[^|]+") do
		parts[#parts + 1] = part
	end

	local image_source = parse_image_source(parts[1])
	if not image_source then
		return nil
	end

	local spec = {
		texture = image_source.texture,
		image = image_source.image,
		width = "100%",
		height = 150,
		scale = "stretch",
		aspect = nil,
	}

	for i = 2, #parts do
		local key, value = parts[i]:match("^%s*([%a_]+)%s*=%s*(.-)%s*$")
		if key and value then
			key = key:lower()
			if key == "width" then
				spec.width = parse_width_value(value) or spec.width
			elseif key == "height" then
				spec.height = parse_height_value(value) or spec.height
			elseif key == "scale" then
				spec.scale = parse_scale_mode(value)
			elseif key == "aspect" or key == "ratio" then
				spec.aspect = parse_aspect_value(value) or spec.aspect
			end
		end
	end

	return spec
end

--- Build a Flow element for a sequence of inline-formatted segments.
--- When there is only one plain-text segment, returns a simple Text element.
--- When there are multiple or formatted segments, returns a row Box with one
--- child per segment (bold segments get a highlighted background, code gets darker).
---@param segments {text: string, bold: boolean, code: boolean}[]  Parsed inline segments
---@param base_key string   Element key prefix for stable caching
---@param height number|nil  Row height in pixels (default 20)
---@param options table|nil
---@return Flow.Element, number
local function create_formatted_text(segments, base_key, height, options)
	local font = options and options.font or "default"
	local scale = options and options.scale or nil
	local line_height = height or estimate_line_height(font, scale)
	if options and options.flatten_formatting then
		local flat_text = flatten_segments_plain_text(segments)
		if options.auto_wrap then
			local prefix_text = options.prefix_text
			local wrap_width = options.wrap_width or 520
			local wrapped_text
			if prefix_text then
				wrapped_text = wrap_prefixed_text(prefix_text .. " ", flat_text, wrap_width, font, scale)
			else
				wrapped_text = wrap_text_to_width(flat_text, wrap_width, font, scale)
			end
			local wrapped_metrics = get_text_metrics_safe(font, wrapped_text, scale)
			local wrapped_height = math.max(line_height, math.ceil(wrapped_metrics.height or 0))
			return Text({
				key = base_key .. "_flat_wrapped_text",
				text = wrapped_text,
				font = font,
				scale = scale,
				line_break = false,
				style = { width = "100%", height = wrapped_height }
			}), wrapped_height
		end

		return Text({
			key = base_key .. "_flat_text",
			text = flat_text,
			font = font,
			scale = scale,
			style = { width = "100%", height = line_height }
		}), line_height
	end
	if options and options.auto_wrap then
		local prefix_text = options.prefix_text
		local prefix_gap = options.prefix_gap or 10
		local prefix_width = options.prefix_width or 0
		local content_width = options.wrap_width or 520
		if prefix_text then
			content_width = math.max(80, content_width - prefix_width - prefix_gap)
		end

		local lines = wrap_segments_to_lines(segments, content_width, font, scale)
		if #lines == 1 then
			local line_element, line_element_height = create_formatted_text(lines[1], base_key .. "_single", line_height, {
				font = font,
				scale = scale,
			})

			if not prefix_text then
				return line_element, line_element_height
			end

			return Box({
				key = base_key .. "_single_row",
				style = {
					width = "100%",
					height = line_element_height,
					flex_direction = "row",
					gap = prefix_gap,
					align_items = "center",
				},
				color = rgba(0, 0, 0, 0),
				children = {
					Text({
						key = base_key .. "_prefix",
						text = prefix_text,
						font = font,
						scale = scale,
						align = "right",
						style = { width = prefix_width, height = line_element_height },
					}),
					line_element,
				},
			}), line_element_height
		end

		local line_children = {}
		for index = 1, #lines do
			local row_children = {}
			if prefix_text then
				if index == 1 then
					row_children[#row_children + 1] = Text({
						key = base_key .. "_prefix",
						text = prefix_text,
						font = font,
						scale = scale,
						align = "right",
						style = { width = prefix_width, height = line_height },
					})
				else
					row_children[#row_children + 1] = Box({
						key = base_key .. "_prefix_spacer_" .. index,
						color = rgba(0, 0, 0, 0),
						style = { width = prefix_width, height = line_height },
					})
				end
			end

			local line_element = create_formatted_text(lines[index], base_key .. "_line_" .. index, line_height, {
				font = font,
				scale = scale,
			})
			row_children[#row_children + 1] = line_element

			line_children[#line_children + 1] = Box({
				key = base_key .. "_row_" .. index,
				style = {
					width = "100%",
					height = line_height,
					flex_direction = "row",
					gap = prefix_text and prefix_gap or 0,
					align_items = "center",
				},
				color = rgba(0, 0, 0, 0),
				children = row_children,
			})
		end

		local wrapped_height = math.max(line_height, line_height * #line_children)
		return Box({
			key = base_key .. "_wrapped_group",
			style = {
				width = "100%",
				height = wrapped_height,
				flex_direction = "column",
			},
			color = rgba(0, 0, 0, 0),
			children = line_children,
		}), wrapped_height
	end

	if #segments == 1 and not segments[1].bold and not segments[1].code then
		-- Fast path: single plain-text segment → simple Text node
		return Text({
			key = base_key .. "_text",
			text = segments[1].text,
			font = font,
			scale = scale,
			style = { flex_grow = 1, height = line_height }
		}), line_height
	end

	-- Multiple or formatted segments: row of child boxes
	local children = {}
	for i, seg in ipairs(segments) do
		local text_width = estimate_text_width(seg.text, font, scale)

		if seg.bold then
			-- Bold: slightly lighter background to highlight
			table.insert(children, Box({
				key = base_key .. "_bold_" .. i,
				style = { width = text_width + 6, height = line_height, padding_left = 3, padding_right = 3 },
				color = rgba(0.3, 0.35, 0.4, 1),
				children = {
					Text({
						key = base_key .. "_bold_text_" .. i,
						text = seg.text,
						font = font,
						scale = scale,
						style = { width = text_width, height = line_height - 2 }
					})
				}
			}))
		elseif seg.code then
			-- Inline code: darker monospace-style background
			table.insert(children, Box({
				key = base_key .. "_code_" .. i,
				style = { width = text_width + 8, height = line_height, padding_left = 4, padding_right = 4 },
				color = rgba(0.15, 0.17, 0.2, 1),
				children = {
					Text({
						key = base_key .. "_code_text_" .. i,
						text = seg.text,
						font = font,
						scale = scale,
						style = { width = text_width, height = line_height - 2 }
					})
				}
			}))
		else
			-- Normal text: transparent box to hold text width
			table.insert(children, Box({
				key = base_key .. "_text_box_" .. i,
				style = { width = text_width, height = line_height },
				color = rgba(0, 0, 0, 0),
				children = {
					Text({
						key = base_key .. "_text_" .. i,
						text = seg.text,
						font = font,
						scale = scale,
						style = { width = text_width, height = line_height }
					})
				}
			}))
		end
	end

	return Box({
		key = base_key .. "_formatted",
		style = { flex_grow = 1, height = line_height, flex_direction = "row", gap = 0, align_items = "center" },
		color = rgba(0, 0, 0, 0),
		children = children
	}), line_height
end

--- Parse a single source line and return the corresponding Flow element(s).
--- Returns nil for code block fence lines (``` markers) — the caller handles these.
--- Recognized patterns (checked in order):
---   blank line          → 10px transparent spacer
---   # header            → variable-height header box (h1=35px, h2=30px, …)
---   --- / *** / ___     → horizontal rule (2px colored line)
---   ![alt](icon:...|width=...|height=...|scale=fit|aspect=16:9)  → configurable atlas image box
---   ![alt](atlas:...|width=...|height=...|scale=stretch)         → configurable atlas image box
---   ![alt](url)         → 180px image placeholder box
---   - item / * item     → bullet list row with "•" prefix
---   1. item             → numbered list row
---   > quote             → blockquote row with left border
---   ``` marker          → nil (code block fence; handled by parse())
---   anything else       → 24px paragraph text row
---@param line string    The raw source line (CR/LF already stripped)
---@param base_key string  Stable element key prefix for this line
---@param options table|nil
---@return Flow.Element|nil  The element for this line, or nil for code fences
local function parse_line(line, base_key, options)
	-- Blank line → spacing
	if line:match("^%s*$") then
		return Box({
			key = base_key .. "_space",
			style = { width = "100%", height = 10 },
			color = rgba(0, 0, 0, 0)
		})
	end

	-- # Header
	local header_level, header_text = line:match("^(#+)%s+(.+)$")
	if header_level then
		local level = #header_level
		local base_line_height = estimate_line_height(options and options.font or "default", options and options.scale or nil)
		local height = math.max(base_line_height, math.floor(base_line_height * (1.5 - ((level - 1) * 0.12))))
		local segments = parse_inline_formatting(header_text)
		local content, content_height = create_formatted_text(segments, base_key, height, options)
		return Box({
			key = base_key,
			style = { width = "100%", height = content_height + 15, padding_top = 10, padding_bottom = 5 },
			color = rgba(0, 0, 0, 0),
			children = { content }
		})
	end

	-- Horizontal rule (---, ***, ___)
	if line:match("^[-*_][-*_][-*_]+$") then
		return Box({
			key = base_key,
			style = { width = "100%", height = 20 },
			color = rgba(0, 0, 0, 0),
			children = {
				Box({
					key = base_key .. "_line",
					style = { width = "100%", height = 2 },
					color = rgba(0.3, 0.3, 0.4, 1)
				})
			}
		})
	end

	-- Image row: real atlas image when recognized, otherwise colored placeholder
	local alt_text, image_url = line:match("^!%[(.-)%]%((.-)%)$")
	if alt_text then
		local image_spec = parse_image_spec(image_url)
		if image_spec then
			return Box({
				key = base_key,
				style = { width = "100%", height = image_spec.height + 30, flex_direction = "column", gap = 8, padding = 10, align_items = "center" },
				color = rgba(0, 0, 0, 0),
				children = {
					Box({
						key = base_key .. "_image_frame",
						style = { width = image_spec.width, height = image_spec.height, flex_direction = "column", align_items = "center", justify_content = "center" },
						color = rgba(0.08, 0.1, 0.14, 1),
						children = {
							Icon({
								key = base_key .. "_image",
								image = image_spec.image,
								texture = image_spec.texture,
								style = { width = "100%", height = "100%" },
								scale_mode = image_spec.scale,
								image_aspect = image_spec.aspect
							})
						}
					}),
					Box({
						key = base_key .. "_caption_container",
						style = { width = "100%", height = 20 },
						color = rgba(0, 0, 0, 0),
						children = {
							Text({
								key = base_key .. "_caption",
								text = alt_text,
								style = { width = "100%", height = 20 },
								align = "center"
							})
						}
					})
				}
			})
		end

		local color = rgba(0.3, 0.4, 0.5, 1)
		-- Optional color hint embedded in URL: color:r,g,b
		local r, g, b = image_url:match("color:([%d%.]+),([%d%.]+),([%d%.]+)")
		if r then
			color = rgba(tonumber(r), tonumber(g), tonumber(b), 1)
		end

		return Box({
			key = base_key,
			style = { width = "100%", height = 180, flex_direction = "column", gap = 5, padding = 10 },
			color = rgba(0, 0, 0, 0),
			children = {
				Box({ key = base_key .. "_img", style = { width = "100%", height = 150 }, color = color }),
				Box({
					key = base_key .. "_caption_container",
					style = { width = "100%", height = 20 },
					color = rgba(0, 0, 0, 0),
					children = {
						Text({ key = base_key .. "_caption", text = alt_text, style = { width = "100%", height = 20 } })
					}
				})
			}
		})
	end

	-- Unordered list: - item / * item
	local bullet_text = line:match("^[%-%*]%s+(.+)$")
	if bullet_text then
		local segments = parse_inline_formatting(bullet_text)
		local content_options = derive_wrap_options(options, 0)
		if content_options and content_options.auto_wrap then
			content_options.prefix_text = "•"
			content_options.prefix_width = math.max(24, estimate_text_width("•", content_options.font or "default", content_options.scale) + 4)
			content_options.prefix_gap = 10
		end
		local content, content_height = create_formatted_text(segments, base_key, 20, content_options)
		if content_options and content_options.auto_wrap then
			return Box({
				key = base_key,
				style = { width = "100%", height = content_height },
				color = rgba(0, 0, 0, 0),
				children = { content }
			})
		end

		return Box({
			key = base_key,
			style = { width = "100%", height = math.max(25, content_height), flex_direction = "row", gap = 10, padding_left = 10, align_items = "start" },
			color = rgba(0, 0, 0, 0),
			children = {
				Text({ key = base_key .. "_bullet", text = "•", style = { width = 20, height = 20 } }),
				content
			}
		})
	end

	-- Ordered list: 1. item
	local number, list_text = line:match("^(%d+)%.%s+(.+)$")
	if number then
		local segments = parse_inline_formatting(list_text)
		local content_options = derive_wrap_options(options, 0)
		if content_options and content_options.auto_wrap then
			local prefix = number .. "."
			content_options.prefix_text = prefix
			content_options.prefix_width = math.max(32, estimate_text_width(prefix, content_options.font or "default", content_options.scale) + 6)
			content_options.prefix_gap = 10
		end
		local content, content_height = create_formatted_text(segments, base_key, 20, content_options)
		if content_options and content_options.auto_wrap then
			return Box({
				key = base_key,
				style = { width = "100%", height = content_height },
				color = rgba(0, 0, 0, 0),
				children = { content }
			})
		end

		return Box({
			key = base_key,
			style = { width = "100%", height = math.max(25, content_height), flex_direction = "row", gap = 10, padding_left = 10, align_items = "start" },
			color = rgba(0, 0, 0, 0),
			children = {
				Text({ key = base_key .. "_number", text = number .. ".", style = { width = 30, height = 20 } }),
				content
			}
		})
	end

	-- Blockquote: > text
	local quote_text = line:match("^>%s+(.+)$")
	if quote_text then
		local segments = parse_inline_formatting(quote_text)
		local content_options = derive_wrap_options(options, 30)
		local content, content_height = create_formatted_text(segments, base_key, 20, content_options)
		return Box({
			key = base_key,
			style = { width = "100%", height = math.max(30, content_height), flex_direction = "row", gap = 10, padding_left = 15, align_items = "start" },
			color = rgba(0, 0, 0, 0),
			children = {
				Box({ key = base_key .. "_border", style = { width = 4, height = 20 }, color = rgba(0.5, 0.6, 0.8, 1) }),
				content
			}
		})
	end

	-- Code block fence: handled by parse(), not here
	if line:match("^```") then
		return nil
	end

	-- Default: paragraph text
	local segments = parse_inline_formatting(line)
	local content, content_height = create_formatted_text(segments, base_key, 20, options)
	return Box({
		key = base_key,
		style = { width = "100%", height = math.max(24, content_height + 4) },
		color = rgba(0, 0, 0, 0),
		children = { content }
	})
end

--- Parse a markdown string into an array of Flow elements, one per source line.
--- Handles multi-line code blocks (``` fences) as a unit, collecting their
--- content and emitting a single dark-background box.
--- Returns an empty array for nil or empty input.
---@param markdown_text string|nil  The raw markdown source text (any line endings)
---@param key_prefix string|nil     Prefix for all generated element keys (default "markdown")
---@param options table|nil
---@return Flow.Element[]           Ordered array of Flow elements for the parsed lines
function M.parse(markdown_text, key_prefix, options)
	local elements = {}
	local lines = {}
	markdown_text = markdown_text or ""
	key_prefix = key_prefix or "markdown"

	if markdown_text == "" then
		return elements
	end

	-- Normalize line endings to \n and split into lines
	markdown_text = markdown_text:gsub("\r\n", "\n"):gsub("\r", "\n")
	local start = 1
	while true do
		local nl = markdown_text:find("\n", start, true)
		if not nl then
			table.insert(lines, markdown_text:sub(start))
			break
		end
		table.insert(lines, markdown_text:sub(start, nl - 1))
		start = nl + 1
	end

	local i = 1
	local in_code_block = false
	local code_lines = {}
	---@type string|nil
	local code_start_key = nil

	while i <= #lines do
		local line = lines[i]

		if line:match("^```") then
			if not in_code_block then
				-- Opening fence: begin collecting code lines
				in_code_block = true
				code_lines = {}
				code_start_key = line_key(key_prefix, i)
			else
				-- Closing fence: emit a code block box
				in_code_block = false
				local code_text = table.concat(code_lines, "\n")
				local code_height = math.max(20, #code_lines * 20)
				local block_key = assert(code_start_key, "markdown parser: code block close without start key")
				table.insert(elements, Box({
					key = block_key,
					style = { width = "100%", height = code_height + 20, padding = 10 },
					color = rgba(0.1, 0.12, 0.15, 1),
					children = {
						Text({
							key = block_key .. "_code",
							text = code_text,
							style = { width = "100%", height = code_height }
						})
					}
				}))
			end
		elseif in_code_block then
			-- Inside a fenced code block: collect raw lines
			table.insert(code_lines, line)
		else
			-- Normal markdown line: parse and emit
			local element = parse_line(line, line_key(key_prefix, i), options)
			if element then
				table.insert(elements, element)
			end
		end

		i = i + 1
	end

	return elements
end

--- Build a scrollable markdown viewer from parsed elements.
--- Merges opts.style over DEFAULT_STYLE. Passes _scrollbar, _bounce, _momentum through.
---@param opts Flow.MarkdownOptions|nil  Options table
---@return Flow.Element             A Scroll element containing all parsed markdown elements
local function build_markdown(opts)
	opts = opts or {}
	local key = opts.key or "markdown_viewer"
	local elements = M.parse(opts.text, key, opts)
	local style = {}
	for k, v in pairs(DEFAULT_STYLE) do
		style[k] = v
	end
	if opts.style then
		for k, v in pairs(opts.style) do
			style[k] = v
		end
	end

	return Scroll({
		key = key,
		style = style,
		color = rgba(0.05, 0.05, 0.1, 1),
		_scrollbar = opts._scrollbar ~= false,
		_bounce = opts._bounce ~= false,
		_momentum = opts._momentum ~= false,
		children = elements
	})
end

--- Create a scrollable markdown viewer component.
--- Convenience function — shorthand for the common viewer pattern.
---@param markdown_text string|nil  The markdown source to render
---@param key string|nil            Element key for the Scroll container (default "markdown_viewer")
---@param style_override Flow.Style|nil  Style overrides for the Scroll container
---@return Flow.Element             A scrollable Scroll element with the rendered content
function M.viewer(markdown_text, key, style_override)
	return build_markdown({
		text = markdown_text,
		key = key,
		style = style_override
	})
end

--- Make the module callable as M(opts) → Scroll element.
--- Equivalent to build_markdown(opts).
return setmetatable(M, {
	--- Create a markdown viewer by calling the module as a function.
	---@param _ table               The M module table (ignored)
	---@param opts table            Options table (see build_markdown)
	---@return Flow.Element         A Scroll element with the rendered markdown
	__call = function(_, opts)
		return build_markdown(opts)
	end
})
