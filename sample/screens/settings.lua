local flow = require "flow/flow"

local BottomSheet = flow.ui.cp.BottomSheet
local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Text = flow.ui.cp.Text


return {
	view = function(params, navigation)
		if not params then params = {} end
		if params.sheet_open == nil then params.sheet_open = false end
		if params.sheet_size == nil then params.sheet_size = "half" end

		-- Reset animation when size changes so it slides in fresh
		if params.sheet_size ~= params._prev_sheet_size then
			params.sheet_anim_y   = nil
			params.sheet_anim_vel = nil
			params._prev_sheet_size = params.sheet_size
		end

		local panel_height = params.sheet_size == "full" and "100%" or "50%"

		-- Sheet content: height driven by selected size
		local sheet_content = Box({
			key = "opts_panel",
			style = {
				width = "100%", height = panel_height,
				flex_direction = "column", gap = 0
			},
			color = vmath.vector4(0.13, 0.15, 0.22, 1),
			children = {
				-- Handle bar
				Box({
					key = "opts_handle_row",
					style = { height = 28, align_items = "center", justify_content = "center" },
					color = vmath.vector4(0, 0, 0, 0),
					children = {
						Box({
							key = "opts_handle",
							style = { width = 40, height = 5 },
							color = vmath.vector4(0.4, 0.4, 0.5, 1)
						})
					}
				}),
				-- Title row: label + close button
				Box({
					key = "opts_title_row",
					style = { height = 50, flex_direction = "row", align_items = "center", padding_left = 20, padding_right = 12 },
					color = vmath.vector4(0, 0, 0, 0),
					children = {
						-- Flexible spacer so title is centered
						Box({ key = "opts_title_spacer_l", style = { flex_grow = 1 }, color = vmath.vector4(0,0,0,0) }),
						Text({ key = "opts_title", text = "Opcoes", style = { height = 28 } }),
						Box({ key = "opts_title_spacer_r", style = { flex_grow = 1 }, color = vmath.vector4(0,0,0,0) }),
						Button({
							key = "opts_close_btn",
							style = { width = 36, height = 36 },
							color = vmath.vector4(0.25, 0.27, 0.35, 1),
							on_click = function()
								params.sheet_open = false
								navigation.mark_dirty()
							end,
							children = {
								Text({ key = "opts_close_label", text = "X", style = { width = "100%", height = "100%" } })
							}
						})
					}
				}),
				-- 2x2 buttons grid
				Box({
					key = "opts_grid",
					style = { flex_grow = 1, flex_direction = "column", gap = 10, padding = 15 },
					color = vmath.vector4(0, 0, 0, 0),
					children = {
						-- Row 1: orange action buttons
						Box({
							key = "opts_row1",
							style = { height = 65, flex_direction = "row", gap = 10 },
							color = vmath.vector4(0, 0, 0, 0),
							children = {
								Button({
									key = "opts_music_btn",
									style = { flex_grow = 1, height = 65, align_items = "center", justify_content = "center" },
									color = vmath.vector4(0.87, 0.47, 0.1, 1),
									on_click = function()
										params.last_action = "Musica"
										navigation.mark_dirty()
									end,
									children = {
										Text({ key = "opts_music_label", text = "Musica", style = { height = 30 } })
									}
								}),
								Button({
									key = "opts_sound_btn",
									style = { flex_grow = 1, height = 65, align_items = "center", justify_content = "center" },
									color = vmath.vector4(0.87, 0.47, 0.1, 1),
									on_click = function()
										params.last_action = "Som"
										navigation.mark_dirty()
									end,
									children = {
										Text({ key = "opts_sound_label", text = "Som", style = { height = 30 } })
									}
								})
							}
						}),
						-- Row 2: secondary action buttons
						Box({
							key = "opts_row2",
							style = { height = 65, flex_direction = "row", gap = 10 },
							color = vmath.vector4(0, 0, 0, 0),
							children = {
								Button({
									key = "opts_rules_btn",
									style = { flex_grow = 1, height = 65, align_items = "center", justify_content = "center" },
									color = vmath.vector4(0.18, 0.20, 0.28, 1),
									on_click = function()
										params.last_action = "Regras"
										navigation.mark_dirty()
									end,
									children = {
										Text({ key = "opts_rules_label", text = "Regras", style = { height = 30 } })
									}
								}),
								Button({
									key = "opts_hist_btn",
									style = { flex_grow = 1, height = 65, align_items = "center", justify_content = "center" },
									color = vmath.vector4(0.18, 0.20, 0.28, 1),
									on_click = function()
										params.last_action = "Historico"
										navigation.mark_dirty()
									end,
									children = {
										Text({ key = "opts_hist_label", text = "Historico", style = { height = 30 } })
									}
								})
							}
						})
					}
				})
			}
		})

		-- Main children: header + content + animated bottom sheet
		local children = {
			-- Header
			Box({
				key = "settings_header",
				style = { height = 60, flex_direction = "row", gap = 8, align_items = "center", padding_left = 12 },
				color = vmath.vector4(0.08, 0.09, 0.15, 1),
				children = {
					Button({
						key = "settings_back",
						style = { width = 80, height = 40 },
						color = vmath.vector4(0.8, 0.3, 0.3, 1),
						on_click = function() navigation.pop("slide_right") end,
						children = { Text({ key = "settings_back_label", text = "BACK", style = { width = "100%", height = "100%" } }) }
					}),
					Text({ key = "settings_title", text = "Settings", style = { flex_grow = 1, height = 30 } })
				}
			}),
			-- Body
			Box({
				key = "settings_body",
				style = { flex_grow = 1, align_items = "center", justify_content = "center", flex_direction = "column", gap = 20 },
				color = vmath.vector4(0.08, 0.09, 0.15, 1),
				children = {
					Text({
						key = "settings_hint",
						text = params.last_action and ("Selecionado: " .. params.last_action) or "Toque para abrir opcoes",
						style = { height = 30 }
					}),
					Box({
						key = "settings_btn_row",
						style = { height = 50, flex_direction = "row", gap = 12 },
						color = vmath.vector4(0, 0, 0, 0),
						children = {
							Button({
								key = "settings_open_half",
								style = { width = 160, height = 50, align_items = "center", justify_content = "center" },
								color = vmath.vector4(0.87, 0.47, 0.1, 1),
								on_click = function()
									params.sheet_size = "half"
									params.sheet_open = true
									navigation.mark_dirty()
								end,
								children = {
									Text({ key = "settings_open_half_label", text = "Meia tela", style = { height = 28 } })
								}
							}),
							Button({
								key = "settings_open_full",
								style = { width = 160, height = 50, align_items = "center", justify_content = "center" },
								color = vmath.vector4(0.3, 0.5, 0.8, 1),
								on_click = function()
									params.sheet_size = "full"
									params.sheet_open = true
									navigation.mark_dirty()
								end,
								children = {
									Text({ key = "settings_open_full_label", text = "Tela cheia", style = { height = 28 } })
								}
							})
						}
					})
				}
			})
		}

		-- Animated bottom sheet — always in tree; _open drives the animation
		table.insert(children, BottomSheet({
			key = "settings_sheet",
			_open = params.sheet_open,
			_size = params.sheet_size,
			_anim_y = params.sheet_anim_y,
			_anim_velocity = params.sheet_anim_vel,
			_on_anim_update = function(y, vel)
				params.sheet_anim_y = y
				params.sheet_anim_vel = vel
			end,
			backdrop_color = vmath.vector4(0, 0, 0, 0.6),
			on_backdrop_click = function()
				params.sheet_open = false
				navigation.mark_dirty()
			end,
			children = { sheet_content }
		}))

	return Box({
			key = "settings_root",
			style = { width = "100%", height = "100%", flex_direction = "column", gap = 0 },
			color = vmath.vector4(0.08, 0.09, 0.15, 1),
			children = children
		})
	end
}
