local flow = require "flow/flow"
local rgba = flow.color.rgba

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Scroll = flow.ui.cp.Scroll
local Text = flow.ui.cp.Text

local C = {
	bg = rgba(0.08, 0.11, 0.10, 1),
	header = rgba(0.11, 0.16, 0.15, 1),
	panel = rgba(0.13, 0.20, 0.19, 1),
	panel_alt = rgba(0.16, 0.24, 0.23, 1),
	muted = rgba(0.78, 0.86, 0.84, 1),
	red = rgba(0.81, 0.33, 0.31, 1),
	orange = rgba(0.88, 0.55, 0.21, 1),
	yellow = rgba(0.85, 0.75, 0.30, 1),
	green = rgba(0.28, 0.68, 0.42, 1),
	teal = rgba(0.18, 0.63, 0.63, 1),
	blue = rgba(0.27, 0.53, 0.83, 1),
	purple = rgba(0.55, 0.40, 0.78, 1),
}

local function label(key, text, h, color, font, align)
	return Text({
		key = key,
		text = text,
		font = font,
		color = color,
		align = align,
		style = { height = h },
	})
end

local function block(key, text, height, color, align_self)
	return Box({
		key = key,
		style = {
			width = 72,
			height = height,
			align_self = align_self,
			align_items = "center",
			justify_content = "center",
		},
		color = color,
		children = {
			label(key .. "_label", text, 20),
		},
	})
end

local function section(key, title, subtitle, demo, demo_height)
	return Box({
		key = key,
		style = { height = 54 + demo_height, flex_direction = "column", gap = 10 },
		color = rgba(0, 0, 0, 0),
		children = {
			Box({
				key = key .. "_head",
				style = { height = 44, flex_direction = "column", gap = 4 },
				color = rgba(0, 0, 0, 0),
				children = {
					label(key .. "_title", title, 24, nil, "heading"),
					label(key .. "_subtitle", subtitle, 16, C.muted),
				},
			}),
			demo,
		},
	})
end

return {
	view = function(params, navigation)
		return Box({
			key = "align_root",
			style = { width = "100%", height = "100%", flex_direction = "column", gap = 0 },
			color = C.bg,
			children = {
				Box({
					key = "header",
					style = { height = 64, flex_direction = "row", gap = 10, align_items = "center", padding_left = 12, padding_right = 12 },
					color = C.header,
					children = {
						Button({
							key = "btn_back",
							style = { width = 84, height = 42 },
							color = C.red,
							on_click = function()
								navigation.pop("slide_right")
							end,
							children = {
								label("btn_back_label", "BACK", 24),
							},
						}),
						Text({
							key = "title",
							text = "Alignment Demo",
							font = "heading",
							style = { flex_grow = 1, height = 32 },
						}),
					},
				}),
				Scroll({
					key = "alignment_scroll",
					style = { flex_grow = 1, flex_direction = "column", gap = 16, padding = 16 },
					color = C.bg,
					children = {
						Box({
							key = "hero",
							style = { height = 86, flex_direction = "column", gap = 8, padding = 16 },
							color = C.panel,
							children = {
								label("hero_title", "Cross-axis and main-axis alignment", 28, nil, "heading"),
								label("hero_copy", "Compare align_items, justify_content, align_self, and text alignment without leaving one screen.", 18, C.muted),
							},
						}),

						section(
							"align_items_rows",
							"Align Items In A Row",
							"Cross-axis alignment changes the vertical position of different-height children.",
							Box({
								key = "align_items_rows_demo",
								style = { height = 286, flex_direction = "column", gap = 10 },
								color = rgba(0, 0, 0, 0),
								children = {
									Box({
										key = "align_start_row",
										style = { height = 82, flex_direction = "row", gap = 10, align_items = "start", padding = 10 },
										color = C.panel,
										children = {
											block("as1", "S", 34, C.red),
											block("as2", "S", 58, C.orange),
											block("as3", "S", 46, C.blue),
										},
									}),
									Box({
										key = "align_center_row",
										style = { height = 82, flex_direction = "row", gap = 10, align_items = "center", padding = 10 },
										color = C.panel,
										children = {
											block("ac1", "C", 34, C.red),
											block("ac2", "C", 58, C.orange),
											block("ac3", "C", 46, C.blue),
										},
									}),
									Box({
										key = "align_end_row",
										style = { height = 82, flex_direction = "row", gap = 10, align_items = "end", padding = 10 },
										color = C.panel,
										children = {
											block("ae1", "E", 34, C.red),
											block("ae2", "E", 58, C.orange),
											block("ae3", "E", 46, C.blue),
										},
									}),
								},
							}),
							286
						),

						section(
							"justify_rows",
							"Justify Content",
							"Main-axis alignment moves the whole group horizontally when the container has free space.",
							Box({
								key = "justify_demo",
								style = { height = 214, flex_direction = "column", gap = 10 },
								color = rgba(0, 0, 0, 0),
								children = {
									Box({
										key = "justify_start",
										style = { height = 60, flex_direction = "row", gap = 8, justify_content = "start", align_items = "center", padding = 10 },
										color = C.panel_alt,
										children = {
											block("js1", "1", 36, C.green),
											block("js2", "2", 36, C.teal),
											block("js3", "3", 36, C.blue),
										},
									}),
									Box({
										key = "justify_center",
										style = { height = 60, flex_direction = "row", gap = 8, justify_content = "center", align_items = "center", padding = 10 },
										color = C.panel_alt,
										children = {
											block("jc1", "1", 36, C.green),
											block("jc2", "2", 36, C.teal),
											block("jc3", "3", 36, C.blue),
										},
									}),
									Box({
										key = "justify_between",
										style = { height = 74, flex_direction = "row", justify_content = "space-between", align_items = "center", padding = 10 },
										color = C.panel_alt,
										children = {
											block("jb1", "A", 40, C.red),
											block("jb2", "B", 40, C.yellow),
											block("jb3", "C", 40, C.purple),
										},
									}),
								},
							}),
							214
						),

						section(
							"align_self",
							"Align Self Override",
							"A single child can opt out of the parent align_items value.",
							Box({
								key = "align_self_demo",
								style = { height = 112, flex_direction = "row", gap = 10, align_items = "center", padding = 12 },
								color = C.panel,
								children = {
									block("align_self_base_a", "Auto", 40, C.red),
									block("align_self_top", "Top", 40, C.orange, "start"),
									block("align_self_center", "Auto", 52, C.green),
									block("align_self_bottom", "Bottom", 40, C.blue, "end"),
								},
							}),
							112
						),

						section(
							"column_alignment",
							"Column Cross-Axis Alignment",
							"When the parent stacks vertically, align_items controls left / center / right placement.",
							Box({
								key = "column_alignment_demo",
								style = { height = 176, flex_direction = "row", gap = 12 },
								color = rgba(0, 0, 0, 0),
								children = {
									Box({
										key = "column_start",
										style = { flex_grow = 1, padding = 10, flex_direction = "column", gap = 8, align_items = "start" },
										color = C.panel,
										children = {
											label("column_start_title", "start", 18, C.muted),
											block("column_start_a", "A", 34, C.red),
											block("column_start_b", "B", 34, C.orange),
										},
									}),
									Box({
										key = "column_center",
										style = { flex_grow = 1, padding = 10, flex_direction = "column", gap = 8, align_items = "center" },
										color = C.panel,
										children = {
											label("column_center_title", "center", 18, C.muted),
											block("column_center_a", "A", 34, C.green),
											block("column_center_b", "B", 34, C.teal),
										},
									}),
									Box({
										key = "column_end",
										style = { flex_grow = 1, padding = 10, flex_direction = "column", gap = 8, align_items = "end" },
										color = C.panel,
										children = {
											label("column_end_title", "end", 18, C.muted),
											block("column_end_a", "A", 34, C.blue),
											block("column_end_b", "B", 34, C.purple),
										},
									}),
								},
							}),
							176
						),

						section(
							"text_alignment",
							"Text Alignment In Width-Constrained Labels",
							"Text.align only becomes visible when the label has width to align inside.",
							Box({
								key = "text_alignment_demo",
								style = { height = 174, flex_direction = "column", gap = 10 },
								color = rgba(0, 0, 0, 0),
								children = {
									Box({
										key = "text_align_left_card",
										style = { height = 44, padding_left = 12, padding_right = 12, justify_content = "center" },
										color = C.panel_alt,
										children = {
											Text({ key = "text_align_left", text = "Left aligned label", style = { width = "100%", height = 24 }, align = "left" }),
										},
									}),
									Box({
										key = "text_align_center_card",
										style = { height = 44, padding_left = 12, padding_right = 12, justify_content = "center" },
										color = C.panel_alt,
										children = {
											Text({ key = "text_align_center", text = "Centered label", style = { width = "100%", height = 24 }, align = "center" }),
										},
									}),
									Box({
										key = "text_align_right_card",
										style = { height = 44, padding_left = 12, padding_right = 12, justify_content = "center" },
										color = C.panel_alt,
										children = {
											Text({ key = "text_align_right", text = "Right aligned label", style = { width = "100%", height = 24 }, align = "right" }),
										},
									}),
								},
							}),
							174
						),
					},
				}),
			},
		})
	end,
}
