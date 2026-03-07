local flow = require "flow/flow"

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Scroll = flow.ui.cp.Scroll
local Text = flow.ui.cp.Text

local C = {
	bg = vmath.vector4(0.07, 0.08, 0.12, 1),
	header = vmath.vector4(0.10, 0.12, 0.18, 1),
	panel = vmath.vector4(0.12, 0.15, 0.22, 1),
	panel_alt = vmath.vector4(0.15, 0.18, 0.27, 1),
	muted = vmath.vector4(0.76, 0.81, 0.90, 1),
	red = vmath.vector4(0.82, 0.33, 0.31, 1),
	orange = vmath.vector4(0.89, 0.56, 0.20, 1),
	yellow = vmath.vector4(0.83, 0.76, 0.29, 1),
	green = vmath.vector4(0.30, 0.67, 0.42, 1),
	teal = vmath.vector4(0.18, 0.63, 0.63, 1),
	blue = vmath.vector4(0.25, 0.49, 0.85, 1),
	purple = vmath.vector4(0.56, 0.38, 0.78, 1),
}

local function label(key, text, h, color, font)
	return Text({
		key = key,
		text = text,
		font = font,
		color = color,
		style = { height = h },
	})
end

local function chip(key, text, color, grow, width)
	return Box({
		key = key,
		style = {
			flex_grow = grow,
			width = width,
			height = 52,
			align_items = "center",
			justify_content = "center",
		},
		color = color,
		children = {
			label(key .. "_label", text, 24),
		},
	})
end

local function section(key, title, subtitle, demo, demo_height)
	return Box({
		key = key,
		style = { height = 54 + demo_height, flex_direction = "column", gap = 10 },
		color = vmath.vector4(0, 0, 0, 0),
		children = {
			Box({
				key = key .. "_head",
				style = { height = 44, flex_direction = "column", gap = 4 },
				color = vmath.vector4(0, 0, 0, 0),
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
			key = "layouts_root",
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
							text = "Layouts Demo",
							font = "heading",
							style = { flex_grow = 1, height = 32 },
						}),
					},
				}),
				Scroll({
					key = "layouts_scroll",
					style = { flex_grow = 1, flex_direction = "column", gap = 16, padding = 16 },
					color = C.bg,
					children = {
						Box({
							key = "hero",
							style = { height = 86, flex_direction = "column", gap = 8, padding = 16 },
							color = C.panel,
							children = {
								label("hero_title", "Layout primitives in one place", 28, nil, "heading"),
								label("hero_copy", "This screen groups flex-grow, percentages, nested rows, and padding/gap examples into reusable patterns.", 18, C.muted),
							},
						}),

						section(
							"growth",
							"Flex Grow Ratios",
							"Remaining space is split in proportion to each child flex_grow value.",
							Box({
								key = "growth_demo",
								style = { height = 92, flex_direction = "row", gap = 10 },
								color = vmath.vector4(0, 0, 0, 0),
								children = {
									chip("growth_1", "1x", C.red, 1),
									chip("growth_2", "2x", C.blue, 2),
									chip("growth_3", "1x", C.green, 1),
								},
							}),
							92
						),

						section(
							"percentages",
							"Percentage Widths",
							"Percentages resolve against the parent inner width after padding is removed.",
							Box({
								key = "percent_demo",
								style = { height = 120, flex_direction = "column", gap = 10, padding = 12 },
								color = C.panel,
								children = {
									Box({
										key = "percent_row",
										style = { height = 54, flex_direction = "row", gap = 10 },
										color = vmath.vector4(0, 0, 0, 0),
										children = {
											chip("percent_left", "25%", C.orange, nil, "25%"),
											chip("percent_mid", "50%", C.purple, nil, "50%"),
											chip("percent_right", "25%", C.teal, nil, "25%"),
										},
									}),
									Box({
										key = "percent_overlay",
										style = { height = 20, flex_direction = "row", gap = 10 },
										color = vmath.vector4(0, 0, 0, 0),
										children = {
											Box({ key = "percent_left_box", style = { width = "25%", height = 20 }, color = C.orange }),
											Box({ key = "percent_mid_box", style = { width = "50%", height = 20 }, color = C.purple }),
											Box({ key = "percent_right_box", style = { width = "25%", height = 20 }, color = C.teal }),
										},
									}),
								},
							}),
							120
						),

						section(
							"nested",
							"Nested Dashboard Layout",
							"Row and column containers combine to form a sidebar + content shell.",
							Box({
								key = "nested_demo",
								style = { height = 196, flex_direction = "row", gap = 12 },
								color = vmath.vector4(0, 0, 0, 0),
								children = {
									Box({
										key = "nested_sidebar",
										style = { width = 120, flex_direction = "column", gap = 8, padding = 10 },
										color = C.panel,
										children = {
											chip("nested_nav_a", "Nav", C.blue),
											chip("nested_nav_b", "Stats", C.teal),
											chip("nested_nav_c", "Logs", C.orange),
										},
									}),
									Box({
										key = "nested_main",
										style = { flex_grow = 1, flex_direction = "column", gap = 10 },
										color = vmath.vector4(0, 0, 0, 0),
										children = {
											Box({
												key = "nested_top",
												style = { height = 64, flex_direction = "row", gap = 10 },
												color = vmath.vector4(0, 0, 0, 0),
												children = {
													chip("nested_stat_a", "64", C.red, 1),
													chip("nested_stat_b", "12", C.yellow, 1),
													chip("nested_stat_c", "98", C.green, 1),
												},
											}),
											Box({
												key = "nested_chart",
												style = { flex_grow = 1, padding = 12, gap = 8, flex_direction = "column" },
												color = C.panel_alt,
												children = {
													label("nested_chart_title", "Main content area", 22, nil, "heading"),
													Box({
														key = "nested_chart_bars",
														style = { flex_grow = 1, flex_direction = "row", gap = 8, align_items = "end" },
														color = vmath.vector4(0, 0, 0, 0),
														children = {
															Box({ key = "bar_a", style = { flex_grow = 1, height = 40 }, color = C.red }),
															Box({ key = "bar_b", style = { flex_grow = 1, height = 86 }, color = C.orange }),
															Box({ key = "bar_c", style = { flex_grow = 1, height = 64 }, color = C.blue }),
															Box({ key = "bar_d", style = { flex_grow = 1, height = 110 }, color = C.purple }),
														},
													}),
												},
											}),
										},
									}),
								},
							}),
							196
						),

						section(
							"spacing",
							"Padding And Gap",
							"The outer shell uses padding while siblings use gap for separation.",
							Box({
								key = "spacing_demo",
								style = { height = 208, padding = 18, flex_direction = "column", gap = 12 },
								color = C.panel,
								children = {
									Box({
										key = "spacing_row_top",
										style = { height = 46, flex_direction = "row", gap = 12 },
										color = vmath.vector4(0, 0, 0, 0),
										children = {
											chip("spacing_a", "Padding edge", C.red, 1),
											chip("spacing_b", "Gap", C.blue, 1),
										},
									}),
									Box({
										key = "spacing_row_bottom",
										style = { flex_grow = 1, flex_direction = "row", gap = 12 },
										color = vmath.vector4(0, 0, 0, 0),
										children = {
											Box({
												key = "spacing_note",
												style = { width = 160, padding = 10, justify_content = "center" },
												color = C.panel_alt,
												children = {
													label("spacing_note_label", "Parent padding protects content from touching edges.", 38, C.muted),
												},
											}),
											Box({
												key = "spacing_stack",
												style = { flex_grow = 1, flex_direction = "column", gap = 10 },
												color = vmath.vector4(0, 0, 0, 0),
												children = {
													chip("spacing_stack_a", "Child 1", C.green),
													chip("spacing_stack_b", "Child 2", C.purple),
												},
											}),
										},
									}),
								},
							}),
							208
						),

						section(
							"full_screen_pattern",
							"Common Screen Structure",
							"Header + toolbar + flexible body is the main composition pattern used across the sample app.",
							Box({
								key = "screen_pattern",
								style = { height = 246, flex_direction = "column", gap = 10 },
								color = vmath.vector4(0, 0, 0, 0),
								children = {
									Box({
										key = "screen_header_box",
										style = { height = 46, padding_left = 14, justify_content = "center" },
										color = C.red,
										children = {
											label("screen_header_label", "Header", 24),
										},
									}),
									Box({
										key = "screen_toolbar_box",
										style = { height = 42, flex_direction = "row", gap = 8 },
										color = vmath.vector4(0, 0, 0, 0),
										children = {
											chip("screen_tool_a", "Filters", C.orange, 1),
											chip("screen_tool_b", "Search", C.yellow, 1),
											chip("screen_tool_c", "Actions", C.green, 1),
										},
									}),
									Box({
										key = "screen_body_box",
										style = { flex_grow = 1, padding = 12, flex_direction = "column", gap = 10 },
										color = C.panel,
										children = {
											chip("screen_body_card_a", "Flexible content body", C.blue),
											chip("screen_body_card_b", "Secondary row", C.teal),
										},
									}),
								},
							}),
							246
						),
					},
				}),
			},
		})
	end,
}
