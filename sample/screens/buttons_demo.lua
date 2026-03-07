local flow = require "flow/flow"
local rgba = flow.color.rgba

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local ButtonImage = flow.ui.cp.ButtonImage
local Icon = flow.ui.cp.Icon
local Scroll = flow.ui.cp.Scroll
local Text = flow.ui.cp.Text


return {
	view = function(params, navigation)
		if not params then params = {} end
		if params.music   == nil then params.music   = true  end
		if params.sound   == nil then params.sound   = false end
		if params.vibrate == nil then params.vibrate = true  end

		local C = {
			bg       = rgba(0.08, 0.09, 0.12, 1),
			header   = rgba(0.10, 0.12, 0.18, 1),
			primary  = rgba(0.22, 0.52, 0.90, 1),
			secondary= rgba(0.30, 0.35, 0.45, 1),
			danger   = rgba(0.75, 0.20, 0.20, 1),
			purple   = rgba(0.58, 0.32, 0.72, 1),
			green    = rgba(0.20, 0.62, 0.38, 1),
			orange   = rgba(0.87, 0.47, 0.10, 1),
			teal     = rgba(0.12, 0.62, 0.62, 1),
			align_bg = rgba(0.16, 0.20, 0.32, 1),
			on_col   = rgba(0.87, 0.47, 0.10, 1),
			off_col  = rgba(0.24, 0.26, 0.34, 1),
			enabled  = rgba(0.20, 0.60, 0.35, 1),
			disabled = rgba(0.35, 0.35, 0.38, 0.50),
			transp   = rgba(0, 0, 0, 0),
		}

		-- helper: section title (full-width text, height=22)
		local function sec(key, label)
			return Text({ key = "sec_"..key, text = label, style = { height = 22 } })
		end

		-- helper: row container (height=50, flex_direction=row, gap=10)
		local function row(key, items)
			return Box({
				key = "row_"..key,
				style = { height = 50, flex_direction = "row", gap = 10 },
				color = C.transp,
				children = items
			})
		end

		return Box({
			key = "buttons_root",
			style = { width = "100%", height = "100%", flex_direction = "column", gap = 0 },
			color = C.bg,
			children = {
				-- ── Header ──────────────────────────────────────────────────────
				Box({
					key = "header",
					style = { height = 60, flex_direction = "row", gap = 8,
					          align_items = "center", padding_left = 12 },
					color = C.header,
					children = {
						Button({
							key = "btn_back",
							style = { width = 80, height = 40 },
							color = C.danger,
							on_click = function() navigation.pop("slide_right") end,
							children = { Text({ key = "back_lbl", text = "BACK",
							             style = { width = "100%", height = "100%" } }) }
						}),
						Text({ key = "title", text = "Buttons Demo",
						          style = { flex_grow = 1, height = 30 } })
					}
				}),

				-- ── Scrollable body ─────────────────────────────────────────────
				Scroll({
					key = "body",
					style = { flex_grow = 1, flex_direction = "column",
					          gap = 12, padding = 16 },
					children = {

						-- 1. TEXT ONLY ──────────────────────────────────────────
						sec("text", "TEXT ONLY"),
						row("text", {
							Button({
								key = "btn_primary",
								style = { flex_grow = 1, height = 50,
								          align_items = "center", justify_content = "center" },
								color = C.primary,
								on_click = function() end,
								children = { Text({ key = "primary_lbl", text = "Primary",
								             style = { height = 28 } }) }
							}),
							Button({
								key = "btn_secondary",
								style = { flex_grow = 1, height = 50,
								          align_items = "center", justify_content = "center" },
								color = C.secondary,
								on_click = function() end,
								children = { Text({ key = "secondary_lbl", text = "Secondary",
								             style = { height = 28 } }) }
							}),
							Button({
								key = "btn_danger",
								style = { flex_grow = 1, height = 50,
								          align_items = "center", justify_content = "center" },
								color = C.danger,
								on_click = function() end,
								children = { Text({ key = "danger_lbl", text = "Danger",
								             style = { height = 28 } }) }
							})
						}),

						-- 2. ICON + TEXT ────────────────────────────────────────
						sec("icon", "ICON + TEXT"),
						row("icon", {
							Button({
								key = "btn_fav",
								style = { flex_grow = 1, height = 50, align_items = "center", justify_content = "center" },
								color = C.purple,
								on_click = function() end,
								children = {
									Box({
										key = "btn_fav_inner",
										style = { flex_direction = "row", align_items = "center", gap = 8, width = 140, height = 28 },
										color = rgba(0, 0, 0, 0),
										children = {
											Icon({ key = "fav_icon", image = "icon_favorite", style = { width = 28, height = 28 } }),
											Text({ key = "fav_lbl", text = "Favorito", style = { flex_grow = 1, height = 28 }, align = "center" })
										}
									})
								}
							}),
							Button({
								key = "btn_add",
								style = { flex_grow = 1, height = 50, align_items = "center", justify_content = "center" },
								color = C.green,
								on_click = function() end,
								children = {
									Box({
										key = "btn_add_inner",
										style = { flex_direction = "row", align_items = "center", gap = 8, width = 140, height = 28 },
										color = rgba(0, 0, 0, 0),
										children = {
											Icon({ key = "add_icon", image = "icon_plus", style = { width = 28, height = 28 } }),
											Text({ key = "add_lbl", text = "Adicionar", style = { flex_grow = 1, height = 28 }, align = "center" })
										}
									})
								}
							}),
							Button({
								key = "btn_next",
								style = { flex_grow = 1, height = 50, align_items = "center", justify_content = "center" },
								color = C.orange,
								on_click = function() end,
								children = {
									Box({
										key = "btn_next_inner",
										style = { flex_direction = "row", align_items = "center", gap = 8, width = 140, height = 28 },
										color = rgba(0, 0, 0, 0),
										children = {
											Icon({ key = "next_icon", image = "icon_arrow", style = { width = 28, height = 28 } }),
											Text({ key = "next_lbl", text = "Proximo", style = { flex_grow = 1, height = 28 }, align = "center" })
										}
									})
								}
							})
						}),

						-- 3. ROUNDED BACKGROUNDS ───────────────────────────────
						sec("rounded", "ROUNDED BUTTONS"),
						row("rounded", {
							Button({
								key = "btn_round_primary",
								image = "button_rounded",
								texture = "button_shapes",
								border = 18,
								style = { flex_grow = 1, height = 50, align_items = "center", justify_content = "center", padding_left = 18, padding_right = 18 },
								color = C.primary,
								on_click = function() end,
								children = {
									Text({ key = "round_primary_lbl", text = "Rounded", style = { height = 28 } })
								}
							}),
							Button({
								key = "btn_round_green",
								image = "button_rounded",
								texture = "button_shapes",
								border = { left = 18, top = 18, right = 18, bottom = 18 },
								style = { flex_grow = 1, height = 50, align_items = "center", justify_content = "center", padding_left = 18, padding_right = 18 },
								color = C.green,
								on_click = function() end,
								children = {
									Text({ key = "round_green_lbl", text = "Curved", style = { height = 28 } })
								}
							}),
						}),

						-- 4. IMAGE BUTTONS ─────────────────────────────────────
						sec("image", "BUTTON IMAGE"),
						row("image", {
							ButtonImage({
								key = "btn_image_castle",
								image = "castle_siege",
								texture = "guide",
								style = { flex_grow = 1, height = 90, align_items = "end", justify_content = "center", padding_bottom = 8 },
								on_click = function() end,
								children = {
									Text({ key = "img_castle_lbl", text = "Castle", style = { height = 24 } })
								}
							}),
							ButtonImage({
								key = "btn_image_forest",
								image = "forest_path_sunset",
								texture = "guide",
								style = { flex_grow = 1, height = 90, align_items = "end", justify_content = "center", padding_bottom = 8 },
								color = C.teal,
								on_click = function() end,
								children = {
									Text({ key = "img_forest_lbl", text = "Forest", style = { height = 24 } })
								}
							}),
						}),

						-- 5. TEXT ALIGNMENT ─────────────────────────────────────
						sec("align", "TEXT ALIGNMENT"),
						-- Left
						Button({
							key = "btn_align_left",
							style = { height = 50, flex_direction = "row",
							          align_items = "center", justify_content = "start",
							          padding_left = 16 },
							color = C.align_bg,
							on_click = function() end,
							children = { Text({ key = "align_left_lbl", text = "Left aligned",
							             style = { height = 28 } }) }
						}),
						-- Center
						Button({
							key = "btn_align_center",
							style = { height = 50, flex_direction = "row",
							          align_items = "center", justify_content = "center" },
							color = C.align_bg,
							on_click = function() end,
							children = { Text({ key = "align_center_lbl", text = "Center aligned",
							             align = "center", style = { height = 28 } }) }
						}),
						-- Right
						Button({
							key = "btn_align_right",
							style = { height = 50, flex_direction = "row",
							          align_items = "center", justify_content = "end",
							          padding_right = 16 },
							color = C.align_bg,
							on_click = function() end,
							children = { Text({ key = "align_right_lbl", text = "Right aligned",
							             align = "right", style = { height = 28 } }) }
						}),

						-- 6. TOGGLE / SELECTED ──────────────────────────────────
						sec("toggle", "TOGGLE / SELECTED"),
						row("toggle", {
							Button({
								key = "btn_music",
								style = { flex_grow = 1, height = 50,
								          align_items = "center", justify_content = "center" },
								color = params.music and C.on_col or C.off_col,
								on_click = function()
									params.music = not params.music
									navigation.invalidate()
								end,
								children = { Text({ key = "music_lbl",
								             text = params.music and "Music  ON" or "Music OFF",
								             style = { height = 28 } }) }
							}),
							Button({
								key = "btn_sound",
								style = { flex_grow = 1, height = 50,
								          align_items = "center", justify_content = "center" },
								color = params.sound and C.on_col or C.off_col,
								on_click = function()
									params.sound = not params.sound
									navigation.invalidate()
								end,
								children = { Text({ key = "sound_lbl",
								             text = params.sound and "Sound  ON" or "Sound OFF",
								             style = { height = 28 } }) }
							}),
							Button({
								key = "btn_vibrate",
								style = { flex_grow = 1, height = 50,
								          align_items = "center", justify_content = "center" },
								color = params.vibrate and C.on_col or C.off_col,
								on_click = function()
									params.vibrate = not params.vibrate
									navigation.invalidate()
								end,
								children = { Text({ key = "vibrate_lbl",
								             text = params.vibrate and "Vibrate ON" or "Vibrate OFF",
								             style = { height = 28 } }) }
							})
						}),

						-- 7. ENABLED / DISABLED ─────────────────────────────────
						sec("state", "ENABLED / DISABLED"),
						row("state", {
							Button({
								key = "btn_enabled",
								style = { flex_grow = 1, height = 50,
								          align_items = "center", justify_content = "center" },
								color = C.enabled,
								on_click = function() end,
								children = { Text({ key = "enabled_lbl", text = "Enabled",
								             style = { height = 28 } }) }
							}),
							-- Disabled: no on_click, muted color, dim alpha
							Button({
								key = "btn_disabled",
								style = { flex_grow = 1, height = 50,
								          align_items = "center", justify_content = "center" },
								color = C.disabled,
								on_click = nil,
								children = { Text({ key = "disabled_lbl", text = "Disabled",
								             style = { height = 28 } }) }
							})
						})

					}  -- scroll children
				})     -- scroll
			}
		})
	end
}
