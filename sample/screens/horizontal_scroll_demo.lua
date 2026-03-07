local flow = require "flow/flow"
local rgba = flow.color.rgba
local with_alpha = flow.color.with_alpha

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Scroll = flow.ui.cp.Scroll
local Text = flow.ui.cp.Text


return {
	view = function(params, navigation)
		-- Initialize state if needed
		if not params.multipliers then
			params.multipliers = {
				{value = 1.80, color = rgba(0.4, 0.7, 0.3, 1)},
				{value = 1.01, color = rgba(0.8, 0.7, 0.3, 1)},
				{value = 1.85, color = rgba(0.4, 0.7, 0.3, 1)},
				{value = 1.15, color = rgba(0.8, 0.7, 0.3, 1)},
				{value = 1.21, color = rgba(0.8, 0.7, 0.3, 1)},
			}
			params.insert_mode = "end"  -- "start" or "end"
			params.align_mode = "start" -- "start" or "end"
		end

		-- Generate multiplier items
		local items = {}
		for i, mult in ipairs(params.multipliers) do
			local is_new = mult.is_new
			local anim_progress = mult.anim_progress or 1

			-- Color based on value
			local color = mult.color
			if mult.value == 0 then
				color = rgba(0.9, 0.3, 0.4, 1)  -- Red for 0
			end

			-- Animation: slide in from top and fade in
			local y_offset = is_new and (1 - anim_progress) * -30 or 0
			local alpha = is_new and anim_progress or 1

			table.insert(items, Box({
				key = "mult_" .. i,
				style = { width = 100, height = 50 },
				color = with_alpha(color, alpha),
				_offset_y_pixels = y_offset,  -- Custom offset for animation
				children = {
					Text({
						key = "mult_" .. i .. "_text",
						text = string.format("×%.2f", mult.value),
						style = { width = "100%", height = "100%" }
					})
				}
			}))
		end

		-- Control buttons
		local insert_at_start_btn = Button({
			key = "btn_insert_start",
			style = { width = 150, height = 50 },
			color = rgba(0.3, 0.5, 0.7, 1),
			on_click = function()
				-- Generate random multiplier
				local random_mult = math.random(0, 200) / 100  -- 0.00 to 2.00
				local color = rgba(0.4, 0.7, 0.3, 1)
				if random_mult < 1.2 then
					color = rgba(0.8, 0.7, 0.3, 1)  -- Yellow
				end
				if random_mult == 0 then
					color = rgba(0.9, 0.3, 0.4, 1)  -- Red
				end

				-- Insert at start
				table.insert(params.multipliers, 1, {
					value = random_mult,
					color = color,
					is_new = true,
					anim_progress = 0
				})

				params.insert_mode = "start"
				navigation.invalidate()
			end,
			children = {
				Text({
					key = "btn_insert_start_label",
					text = "Insert at Start",
					style = { width = "100%", height = "100%" }
				})
			}
		})

		local insert_at_end_btn = Button({
			key = "btn_insert_end",
			style = { width = 150, height = 50 },
			color = rgba(0.5, 0.3, 0.7, 1),
			on_click = function()
				-- Generate random multiplier
				local random_mult = math.random(0, 200) / 100
				local color = rgba(0.4, 0.7, 0.3, 1)
				if random_mult < 1.2 then
					color = rgba(0.8, 0.7, 0.3, 1)
				end
				if random_mult == 0 then
					color = rgba(0.9, 0.3, 0.4, 1)
				end

				-- Insert at end
				table.insert(params.multipliers, {
					value = random_mult,
					color = color,
					is_new = true,
					anim_progress = 0
				})

				params.insert_mode = "end"
				navigation.invalidate()
			end,
			children = {
				Text({
					key = "btn_insert_end_label",
					text = "Insert at End",
					style = { width = "100%", height = "100%" }
				})
			}
		})

		local align_left_btn = Button({
			key = "btn_align_left",
			style = { width = 120, height = 50 },
			color = params.align_mode == "start" and rgba(0.4, 0.6, 0.4, 1) or rgba(0.3, 0.4, 0.3, 1),
			on_click = function()
				params.align_mode = "start"
				navigation.invalidate()
			end,
			children = {
				Text({
					key = "btn_align_left_label",
					text = "Align Left",
					style = { width = "100%", height = "100%" }
				})
			}
		})

		local align_right_btn = Button({
			key = "btn_align_right",
			style = { width = 120, height = 50 },
			color = params.align_mode == "end" and rgba(0.4, 0.6, 0.4, 1) or rgba(0.3, 0.4, 0.3, 1),
			on_click = function()
				params.align_mode = "end"
				navigation.invalidate()
			end,
			children = {
				Text({
					key = "btn_align_right_label",
					text = "Align Right",
					style = { width = "100%", height = "100%" }
				})
			}
		})

		return Box({
			key = "hscroll_root",
			style = { width="100%", height="100%", flex_direction="column", gap=20, padding=20 },
			color = rgba(0.05, 0.05, 0.1, 1),
			children = {
				-- Header
				Box({
					key="header",
					style={ height=60, flex_direction="row", gap=8, align_items="center" },
					color=rgba(0.2, 0.2, 0.2, 0.8),
					children = {
						Button({
							key="btn_back",
							style={ width=80, height=40 },
							color=rgba(0.8, 0.3, 0.3, 1),
							on_click = function()
								navigation.pop("slide_right")
							end,
							children = {
								Text({
									key="btn_back_label",
									text="BACK",
									style={ width="100%", height="100%" }
								})
							}
						}),
						Text({
							key="title",
							text="Horizontal Scroll - Animated Multipliers",
							style={ flex_grow=1, height=40 }
						})
					}
				}),

				-- Control buttons row
				Box({
					key = "controls",
					style = { height = 60, flex_direction = "row", gap = 10, align_items = "center" },
					color = rgba(0, 0, 0, 0),
					children = {
						insert_at_start_btn,
						insert_at_end_btn,
						align_left_btn,
						align_right_btn
					}
				}),

				-- Horizontal scrollable list
				Scroll({
					key = "multipliers_scroll",
					style = {
						width = "100%",
						height = 80,
						flex_direction = "row",
						gap = 10,
						padding = 10,
						justify_content = params.align_mode
					},
					color = rgba(0.1, 0.1, 0.15, 1),
					_scrollbar = true,
					_bounce = true,
					_momentum = true,
					children = items
				}),

				-- Info text
				Box({
					key = "info",
					style = { flex_grow = 1, padding = 20 },
					color = rgba(0, 0, 0, 0),
					children = {
						Text({
							key = "info_text",
							text = string.format(
								"Items: %d | Insert Mode: %s | Align: %s\n\n" ..
								"Click 'Insert at Start/End' to add random multipliers.\n" ..
								"New items animate in from the top.\n" ..
								"Use Align buttons to position the list.",
								#params.multipliers,
								params.insert_mode,
								params.align_mode
							),
							align = "left",
							style = { width = "100%", height = 120 }
						})
					}
				})
			}
		})
	end
}
