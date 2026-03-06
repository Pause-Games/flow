local flow = require "flow/flow"

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Text = flow.ui.cp.Text


return {
	view = function(params, navigation)
		-- Initialize counter in params if not exists
		if not params then params = {} end
		if not params.counter then params.counter = 0 end

		-- Helper function to update counter and trigger a view rebuild
		local function update_counter(delta)
			params.counter = params.counter + delta
			navigation.mark_dirty()  -- Tell navigation to rebuild the active view
		end

		return Box({
			key = "counter_root",
			style = { width="100%", height="100%", flex_direction="column", gap=0, padding=0 },
			color = vmath.vector4(0.1, 0.08, 0.12, 1),
			children = {
				-- Header
				Box({
					key="header",
					style={ height=60, flex_direction="row", gap=8, align_items="center" },
					color=vmath.vector4(0.2, 0.2, 0.2, 0.8),
					children = {
						Button({
							key="btn_back",
							style={ width=80, height=40 },
							color=vmath.vector4(0.8, 0.3, 0.3, 1),
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
							text="Dynamic Counter Demo",
							style={ flex_grow=1, height=40 }
						})
					}
				}),
				-- Main content
				Box({
					key="content",
					style={ flex_grow=1, flex_direction="column", gap=20, align_items="center", justify_content="center", padding=20 },
					color=vmath.vector4(0.05, 0.05, 0.1, 1),
					children = {
						-- Info text
						Text({
							key="info",
							text="Click buttons to update the counter dynamically",
							style={ height=25 }
						}),
						-- Counter display
						Box({
							key="counter_display",
							style={ width=300, height=150, flex_direction="column", gap=10, align_items="center", justify_content="center" },
							color=vmath.vector4(0.15, 0.15, 0.2, 1),
							children = {
								Text({
									key="counter_label",
									text="Counter Value:",
									style={ height=25 }
								}),
								Text({
									key="counter_value",
									text=tostring(params.counter),
									style={ height=60 }
								})
							}
						}),
						-- Control buttons
						Box({
							key="controls",
							style={ width=400, height=80, flex_direction="row", gap=10, justify_content="center", align_items="center" },
							children = {
								-- Decrement by 10
								Button({
									key="btn_minus_10",
									style={ width=80, height=60 },
									color=vmath.vector4(0.6, 0.2, 0.2, 1),
									on_click = function()
										update_counter(-10)
									end,
									children = {
										Text({
											key="btn_minus_10_label",
											text="-10",
											style={ width="100%", height="100%" }
										})
									}
								}),
								-- Decrement by 1
								Button({
									key="btn_minus",
									style={ width=80, height=60 },
									color=vmath.vector4(0.8, 0.3, 0.3, 1),
									on_click = function()
										update_counter(-1)
									end,
									children = {
										Text({
											key="btn_minus_label",
											text="-",
											style={ width="100%", height="100%" }
										})
									}
								}),
								-- Increment by 1
								Button({
									key="btn_plus",
									style={ width=80, height=60 },
									color=vmath.vector4(0.3, 0.8, 0.3, 1),
									on_click = function()
										update_counter(1)
									end,
									children = {
										Text({
											key="btn_plus_label",
											text="+",
											style={ width="100%", height="100%" }
										})
									}
								}),
								-- Increment by 10
								Button({
									key="btn_plus_10",
									style={ width=80, height=60 },
									color=vmath.vector4(0.2, 0.6, 0.2, 1),
									on_click = function()
										update_counter(10)
									end,
									children = {
										Text({
											key="btn_plus_10_label",
											text="+10",
											style={ width="100%", height="100%" }
										})
									}
								})
							}
						}),
						-- Reset button
						Button({
							key="btn_reset",
							style={ width=200, height=50 },
							color=vmath.vector4(0.5, 0.4, 0.2, 1),
							on_click = function()
								params.counter = 0
								navigation.mark_dirty()
							end,
							children = {
								Text({
									key="btn_reset_label",
									text="RESET TO 0",
									style={ width="100%", height="100%" }
								})
							}
						}),
						-- Explanation text
						Box({
							key="explanation",
							style={ width="80%", flex_direction="column", gap=10, padding=20 },
							color=vmath.vector4(0.15, 0.12, 0.18, 1),
							children = {
								Text({
									key="explain_title",
									text="How Dynamic Updates Work:",
									style={ height=25 }
								}),
								Text({
									key="explain_1",
									text="1. Counter value is stored in screen params",
									style={ height=20 }
								}),
								Text({
									key="explain_2",
									text="2. When button is clicked, params.counter is updated",
									style={ height=20 }
								}),
								Text({
									key="explain_3",
									text="3. navigation.mark_dirty() triggers a screen view rebuild",
									style={ height=20 }
								}),
								Text({
									key="explain_4",
									text="4. view() is called again with updated params",
									style={ height=20 }
								}),
								Text({
									key="explain_5",
									text="5. UI tree is rebuilt with new counter value",
									style={ height=20 }
								})
							}
						})
					}
				})
			}
		})
	end
}
