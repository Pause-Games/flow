local flow = require "flow/flow"
local rgba = flow.color.rgba

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Scroll = flow.ui.cp.Scroll
local Text = flow.ui.cp.Text


return {
	view = function(params, navigation)
		-- Virtual scrolling: render all 1000 items virtually with proper scroll height
		local total_items = 1000
		local item_height = 50
		local viewport_height = 580  -- Approximate scroll container height

		-- Get current scroll position from navigation state
		local scroll_offset = navigation.get_scroll_offset("scroll_container") or 0

		-- Calculate visible range with buffer
		local first_visible = math.floor(scroll_offset / item_height) + 1
		local last_visible = math.ceil((scroll_offset + viewport_height) / item_height)

		-- Add buffer items above and below for smooth scrolling
		local buffer = 3
		local first_render = math.max(1, first_visible - buffer)
		local last_render = math.min(total_items, last_visible + buffer)

		-- Create spacers for non-rendered items
		local items = {}

		-- Top spacer for items before visible range
		if first_render > 1 then
			local spacer_height = (first_render - 1) * item_height
			table.insert(items, Box({
				key = "top_spacer",
				style = { height = spacer_height, width = "100%" },
				color = rgba(0, 0, 0, 0)
			}))
		end

		-- Render visible items
		for i = first_render, last_render do
			local row = i
			table.insert(items, Button({
				key = "item_" .. row,
				style = { height = item_height, width = "100%", flex_direction = "row", align_items = "center", padding = 10, gap = 10 },
				color = rgba(
					0.3 + (row % 3) * 0.2,
					0.2 + (row % 5) * 0.15,
					0.4 + (row % 7) * 0.1,
					1
				),
				on_click = function()
					print("Tapped row #" .. tostring(row))
				end,
				children = {
					Box({
						key = "item_" .. row .. "_number",
						style = { width = 40, height = 30 },
						color = rgba(0, 0, 0, 0.3),
						children = {
							Text({
								key = "item_" .. row .. "_number_text",
								text = tostring(row),
								style = { width = "100%", height = "100%" }
							})
						}
					}),
					Text({
						key = "item_" .. row .. "_text",
						text = "List Item #" .. row,
						style = { flex_grow = 1, height = "100%" }
					})
				}
			}))
		end

		-- Bottom spacer for items after visible range
		if last_render < total_items then
			local spacer_height = (total_items - last_render) * item_height
			table.insert(items, Box({
				key = "bottom_spacer",
				style = { height = spacer_height, width = "100%" },
				color = rgba(0, 0, 0, 0)
			}))
		end

		return Box({
			key = "scroll_root",
			style = { width="100%", height="100%", flex_direction="column", gap=0, padding=0 },
			color = rgba(0.1, 0.1, 0.15, 1),
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
							text="Scroll Demo (1000 items - Virtual Scrolling)",
							style={ flex_grow=1, height=40 }
						})
					}
				}),
				-- Scrollable content area
				Scroll({
					key="scroll_container",
					style={ flex_grow=1, flex_direction="column", gap=0, padding=0 },
					color=rgba(0.05, 0.05, 0.1, 1),
					_virtual_height = total_items * item_height,  -- Total virtual content height
					children = items
				})
			}
		})
	end
}
