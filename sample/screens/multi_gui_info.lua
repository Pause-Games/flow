local flow = require "flow/flow"

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Scroll = flow.ui.cp.Scroll
local Text = flow.ui.cp.Text


return {
	view = function(params, navigation)
		return Box({
			key = "multi_gui_root",
			style = { width="100%", height="100%", flex_direction="column", gap=0, padding=0 },
			color = vmath.vector4(0.1, 0.1, 0.15, 1),
			children = {
				-- Header
				Box({
					key="header",
					style={ height=60, flex_direction="row", gap=8, align_items="center", padding_left=10 },
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
							text="Multiple GUI Files Setup",
							style={ flex_grow=1, height=40 }
						})
					}
				}),
				-- Scrollable content
				Scroll({
					key="info_scroll",
					style={ flex_grow=1, flex_direction="column", gap=15, padding=20 },
					color=vmath.vector4(0.05, 0.05, 0.1, 1),
					_scrollbar = true,
					_bounce = true,
					_momentum = true,
					children = {
						Box({
							key="intro",
							style={ width="100%", flex_direction="column", gap=8, padding=15 },
							color=vmath.vector4(0.15, 0.2, 0.25, 1),
							children = {
								Text({
									key="intro_title",
									text="Independent GUI Files",
									style={ height=30 }
								}),
								Text({
									key="intro_text",
									text="The Flow UI library can be used across multiple .gui files independently.",
									style={ height=20 }
								})
							}
						}),
						Box({
							key="step1",
							style={ width="100%", flex_direction="column", gap=8, padding=15 },
							color=vmath.vector4(0.2, 0.15, 0.2, 1),
							children = {
								Text({
									key="step1_title",
									text="Step 1: Create sample2.gui",
									style={ height=25 }
								}),
								Text({
									key="step1_text",
									text="In Defold Editor, create a new GUI file: sample/sample2.gui",
									style={ height=20 }
								}),
								Text({
									key="step1_detail",
									text="Add a single Box node named 'ui_root' as the mount point",
									style={ height=20 }
								})
							}
						}),
						Box({
							key="step2",
							style={ width="100%", flex_direction="column", gap=8, padding=15 },
							color=vmath.vector4(0.15, 0.2, 0.15, 1),
							children = {
								Text({
									key="step2_title",
									text="Step 2: Attach the script",
									style={ height=25 }
								}),
								Text({
									key="step2_text",
									text="Set sample2.gui's Script property to: sample/sample2.gui_script",
									style={ height=20 }
								}),
								Text({
									key="step2_detail",
									text="The script has already been created with a full demo!",
									style={ height=20 }
								})
							}
						}),
						Box({
							key="step3",
							style={ width="100%", flex_direction="column", gap=8, padding=15 },
							color=vmath.vector4(0.2, 0.2, 0.15, 1),
							children = {
								Text({
									key="step3_title",
									text="Step 3: Add to collection",
									style={ height=25 }
								}),
								Text({
									key="step3_text",
									text="In main.collection, add a new Game Object",
									style={ height=20 }
								}),
								Text({
									key="step3_detail",
									text="Add a GUI component pointing to sample2.gui",
									style={ height=20 }
								})
							}
						}),
						Box({
							key="features",
							style={ width="100%", flex_direction="column", gap=8, padding=15 },
							color=vmath.vector4(0.15, 0.15, 0.25, 1),
							children = {
								Text({
									key="features_title",
									text="Sample 2 Features:",
									style={ height=25 }
								}),
								Text({
									key="feature1",
									text="- Interactive counter with +/- buttons",
									style={ height=20 }
								}),
								Text({
									key="feature2",
									text="- Scrollable color palette (20 colors)",
									style={ height=20 }
								}),
								Text({
									key="feature3",
									text="- Demonstrates scroll bounce & momentum",
									style={ height=20 }
								}),
								Text({
									key="feature4",
									text="- Shows independent GUI script setup",
									style={ height=20 }
								})
							}
						}),
						Box({
							key="note",
							style={ width="100%", flex_direction="column", gap=8, padding=15 },
							color=vmath.vector4(0.25, 0.2, 0.15, 1),
							children = {
								Text({
									key="note_title",
									text="Important Note:",
									style={ height=25 }
								}),
								Text({
									key="note_text",
									text="Each .gui_script file works completely independently!",
									style={ height=20 }
								}),
								Text({
									key="note_detail",
									text="You can have multiple GUI files in your game, each with their own UI trees.",
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
