package.path = table.concat({
  "./?.lua",
  "./?/init.lua",
  package.path,
}, ";")

local function deepcopy(value)
  if type(value) ~= "table" then
    return value
  end
  local out = {}
  for k, v in pairs(value) do
    out[k] = deepcopy(v)
  end
  return out
end

vmath = {}
function vmath.vector3(x, y, z)
  return { x = x or 0, y = y or 0, z = z or 0 }
end
local function rgba(x, y, z, w)
  return { r = x or 0, g = y or 0, b = z or 0, a = w == nil and 1 or w }
end
function vmath.vector4(x, y, z, w)
  return { x = x or 0, y = y or 0, z = z or 0, w = w or 0 }
end

hash = function(value)
  return value
end

local posted_messages = {}

msg = {
  post = function(url, message_id, message)
    posted_messages[#posted_messages + 1] = {
      url = url,
      message_id = message_id,
      message = deepcopy(message),
    }
  end,
  url = function(path)
    return path or "main:/navigation#navigation_bootstrap"
  end,
}

window = {
  get_size = function()
    return 200, 200
  end,
}

sys = {
  get_config = function(key)
    if key == "display.width" or key == "display.height" then
      return "200"
    end
    return nil
  end,
}

package.preload["builtins/scripts/socket"] = function()
  return {
    gettime = function()
      return 0
    end,
  }
end

local gui_nodes = {}
local node_id = 0

local function new_node(kind, pos, size)
  node_id = node_id + 1
  local node = {
    __id = node_id,
    kind = kind,
    position = deepcopy(pos or vmath.vector3()),
    size = deepcopy(size or vmath.vector3()),
    scale = vmath.vector3(1, 1, 1),
    color = rgba(1, 1, 1, 1),
    alpha = 1,
    deleted = false,
  }
  gui_nodes[node_id] = node
  return node
end

gui = {
  PIVOT_W = "w",
  PIVOT_CENTER = "center",
  PIVOT_E = "e",
  CLIPPING_MODE_STENCIL = "stencil",
  SIZE_MODE_MANUAL = "manual",
  SIZE_MODE_AUTO = "auto",
}

function gui.new_box_node(pos, size)
  return new_node("box", pos, size)
end

function gui.new_text_node(pos, text)
  local node = new_node("text", pos, vmath.vector3())
  node.text = text or ""
  return node
end

function gui.set_pivot(node, pivot)
  node.pivot = pivot
end

function gui.set_texture(node, texture)
  node.texture = texture
end

function gui.play_flipbook(node, animation)
  node.animation = animation
end

function gui.set_size_mode(node, mode)
  node.size_mode = mode
end

function gui.set_clipping_mode(node, mode)
  node.clipping_mode = mode
end

function gui.set_clipping_visible(node, visible)
  node.clipping_visible = visible
end

function gui.set_clipping_inverted(node, inverted)
  node.clipping_inverted = inverted
end

function gui.set_color(node, color)
  node.color = deepcopy(color)
end

function gui.set_alpha(node, alpha)
  node.alpha = alpha
end

function gui.set_text(node, text)
  node.text = text
end

function gui.set_font(node, font)
  node.font = font
end

function gui.set_position(node, pos)
  node.position = deepcopy(pos)
end

function gui.set_size(node, size)
  node.size = deepcopy(size)
end

function gui.set_scale(node, scale)
  node.scale = deepcopy(scale)
end

function gui.set_slice9(node, slice9)
  node.slice9 = deepcopy(slice9)
end

function gui.set_parent(node, parent)
  node.parent = parent
end

function gui.delete_node(node)
  node.deleted = true
end

local layout = require "flow/layout"
local flow = require "flow/flow"
local rgba = flow.color.rgba
local color = flow.color
local flow_log = require "flow/log"
local navigation = require "flow/navigation/init"
local navigation_messages = require "flow/navigation/messages"
local navigation_proxy = require "flow/navigation/proxy"
local navigation_runtime = require "flow/navigation/runtime"
local screens = require "sample/screens"
local ui = require "flow/ui"
local Markdown = require "flow/components/markdown"
local Box = require "flow/components/box"
local BottomSheet = require "flow/components/bottom_sheet"
local Button = require "flow/components/button"
local ButtonImage = require "flow/components/button_image"
local Scroll = require "flow/components/scroll"
local Text = require "flow/components/text"

local failures = {}

local function clear_posted_messages()
  for i = #posted_messages, 1, -1 do
    posted_messages[i] = nil
  end
end

local function count_posts(url, message_id)
  local count = 0
  for _, entry in ipairs(posted_messages) do
    if (url == nil or entry.url == url) and (message_id == nil or entry.message_id == message_id) then
      count = count + 1
    end
  end
  return count
end

local function find_post(url, message_id)
  for _, entry in ipairs(posted_messages) do
    if (url == nil or entry.url == url) and (message_id == nil or entry.message_id == message_id) then
      return entry
    end
  end
  return nil
end

local function check(condition, message)
  if not condition then
    failures[#failures + 1] = message
  end
end

local function approx_eq(a, b, epsilon)
  epsilon = epsilon or 0.0001
  return math.abs(a - b) <= epsilon
end

local function test_flow_facade_namespaces()
  check(flow.ui ~= nil, "flow facade: flow.ui namespace should exist")
  check(flow.nav ~= nil, "flow facade: flow.nav namespace should exist")
  check(flow.log ~= nil, "flow facade: flow.log namespace should exist")
  check(flow.ui.mount == ui.mount, "flow facade: flow.ui should expose low-level renderer helpers")
  check(flow.ui.Flex == require "flow/flex", "flow facade: flow.ui should expose the Flex helper")
  check(flow.ui.layout == layout, "flow facade: flow.ui should expose the layout helper")
  check(flow.ui.cp ~= nil, "flow facade: flow.ui.cp namespace should exist")
  check(flow.ui.components == flow.ui.cp, "flow facade: flow.ui.components should alias flow.ui.cp")
  check(flow.Box == nil, "flow facade: top-level component constructors should no longer be exposed")
  check(flow.ui.cp.Box == Box, "flow facade: flow.ui.cp should expose Box")
  check(flow.ui.cp.Text == Text, "flow facade: flow.ui.cp should expose Text")
  check(flow.ui.cp.Button == Button, "flow facade: flow.ui.cp should expose Button")
  check(flow.ui.cp.ButtonImage == ButtonImage, "flow facade: flow.ui.cp should expose ButtonImage")
  check(flow.color ~= nil, "flow facade: flow should expose the color helper module")
  check(flow.ui.color == flow.color, "flow facade: flow.ui should expose the same color helper module")
  check(flow.nav.push == navigation.push, "flow facade: flow.nav should expose navigation singleton methods")
  check(flow.nav.invalidate == navigation.invalidate, "flow facade: flow.nav should expose navigation invalidation")
  check(flow.nav.is_invalidated == navigation.is_invalidated, "flow facade: flow.nav should expose navigation invalidation state")
  check(flow.nav.clear_invalidation == navigation.clear_invalidation, "flow facade: flow.nav should expose navigation invalidation clearing")
  check(flow.nav.mark_dirty == nil, "flow facade: flow.nav should no longer expose mark_dirty")
  check(flow.invalidate ~= nil, "flow facade: flow should expose top-level invalidate")
  check(flow.mark_dirty == nil, "flow facade: flow should no longer expose top-level mark_dirty")
  check(flow.ui.request_redraw == ui.request_redraw, "flow facade: flow.ui should expose redraw helpers")
  check(flow.ui.request_tree_redraw == ui.request_tree_redraw, "flow facade: flow.ui should expose tree redraw helpers")
  check(flow.nav.on_message == navigation_messages.on_message, "flow facade: flow.nav should expose Defold-style message transport helpers")
  check(flow.nav.handle_message == flow.nav.on_message, "flow facade: flow.nav.handle_message should remain as a compatibility alias")
  check(flow.nav.PUSH == navigation_messages.PUSH, "flow facade: flow.nav should expose navigation message ids")
  check(flow.nav.runtime == navigation_runtime, "flow facade: flow.nav.runtime should expose the non-gui runtime helper")
  check(flow.nav.proxy == navigation_proxy, "flow facade: flow.nav.proxy should expose the proxy helper")
  check(flow.log == flow_log, "flow facade: flow.log should expose the centralized logger")
end

local function test_color_api_parses_public_formats()
  local hex = color.resolve("#778899")
  check(approx_eq(hex.x, 0x77 / 255) and approx_eq(hex.y, 0x88 / 255) and approx_eq(hex.z, 0x99 / 255) and approx_eq(hex.w, 1),
    "color api: hex strings should resolve to normalized rgba")

  local rgba_text = color.resolve("rgba(119, 136, 153, 0.5)")
  check(approx_eq(rgba_text.x, 119 / 255) and approx_eq(rgba_text.y, 136 / 255) and approx_eq(rgba_text.z, 153 / 255) and approx_eq(rgba_text.w, 0.5),
    "color api: rgba() strings should resolve to normalized rgba")

  local helper = color.resolve(color.rgba(0.2, 0.4, 0.8, 1))
  check(approx_eq(helper.x, 0.2) and approx_eq(helper.y, 0.4) and approx_eq(helper.z, 0.8) and approx_eq(helper.w, 1),
    "color api: flow.color.rgba should produce valid public color values")

  local array = color.resolve({ 119, 136, 153, 255 })
  check(approx_eq(array.x, 119 / 255) and approx_eq(array.y, 136 / 255) and approx_eq(array.z, 153 / 255) and approx_eq(array.w, 1),
    "color api: array tables should resolve as rgba values")

  local ok, err = pcall(color.resolve, vmath.vector4(1, 1, 1, 1))
  check(ok == false and tostring(err):match("vector4"),
    "color api: vector4 values should be rejected at the public API boundary")
end

local function test_flow_log_levels_and_contexts()
  flow_log._reset_for_tests()

  local entries = {}
  flow_log.set_sink(function(entry)
    entries[#entries + 1] = entry
  end)

  check(flow_log.get_level() == "none", "flow log: default level should be none")
  check(flow_log.info("nav", "hidden") == false, "flow log: info should be suppressed at none level")

  flow_log.set_level("warn")
  check(flow_log.is_enabled("warn", "nav") == true, "flow log: warn should be enabled at warn level")
  check(flow_log.is_enabled("info", "nav") == false, "flow log: info should be disabled at warn level")

  flow_log.warn("nav", "warn message")
  check(#entries == 1 and entries[1].level == "warn" and entries[1].context == "nav",
    "flow log: warn should emit through the configured sink")

  flow_log.set_context_level("nav", "debug")
  check(flow_log.is_enabled("debug", "nav") == true, "flow log: context override should enable debug for nav")
  check(flow_log.is_enabled("info", "ui") == false, "flow log: context override should not affect other contexts")

  flow_log.debug("nav", "debug message")
  check(#entries == 2 and entries[2].level == "debug",
    "flow log: debug should emit when enabled by context override")

  flow_log.none("nav")
  check(flow_log.is_enabled("error", "nav") == false, "flow log: none should disable a context completely")

  flow_log.set_sink(nil)
  flow_log._reset_for_tests()
end

local function test_flow_on_message_facade()
  navigation._reset_for_tests()
  clear_posted_messages()

  local self = {}
  flow.init(self, {
    screens = {
      home = {
        view = function()
          return Box({
            key = "root",
            style = { width = "100%", height = "100%" },
          })
        end,
      },
      detail = {
        view = function()
          return Box({
            key = "detail_root",
            style = { width = "100%", height = "100%" },
          })
        end,
      },
    },
    initial_screen = "home",
    on_message = function(_, message_id, message)
      if message_id == "custom_event" then
        self.custom_message = message.value
        return true
      end
      return false
    end,
  })

  local handled_nav = flow.on_message(self, navigation_messages.PUSH, {
    id = "detail",
    transition = "none",
  })
  check(handled_nav == true, "flow facade: flow.on_message should handle navigation transport messages")
  check(navigation.current() and navigation.current().id == "detail",
    "flow facade: flow.on_message should route navigation messages through app-wide navigation")

  local handled_custom = flow.on_message(self, "custom_event", { value = 42 })
  check(handled_custom == true, "flow facade: flow.on_message should delegate unhandled messages to config.on_message")
  check(self.custom_message == 42, "flow facade: config.on_message should receive custom messages")

  local handled_unknown = flow.on_message(self, "unknown_event", {})
  check(handled_unknown == false, "flow facade: flow.on_message should return false for unhandled messages")

  flow.final(self)
end

local function test_layout_overflow_clamp()
  local root = {
    style = { width = 100, height = 100, flex_direction = "column" },
    children = {
      { key = "fixed_1", style = { height = 80 } },
      { key = "fixed_2", style = { height = 80 } },
      { key = "grow", style = { flex_grow = 1 } },
    },
  }

  layout.compute(root, 0, 0, 100, 100)
  check(root.children[3].layout.h == 0, "layout overflow clamp: flex child height should clamp to 0")
  check(root.children[3].layout.h >= 0, "layout overflow clamp: flex child height should not be negative")
end

local function test_nested_scroll_bounds()
  local self = {}
  ui.mount(self)

  local tree = Box({
    key = "root",
    style = { width = "100%", height = "100%", flex_direction = "column" },
    children = {
      Box({
        key = "header",
        style = { height = 50 },
      }),
      Scroll({
        key = "scroll",
        style = { height = 100, flex_direction = "column" },
        children = {
          Box({ key = "content", style = { height = 200 } }),
        },
      }),
    },
  })

  ui.render(self, tree, 200, 200)

  for _ = 1, 6 do
    ui.on_input(self, hash("scroll_down"), { x = 100, y = 100 })
  end

  check(tree.children[2]._scroll_y == 100, "nested scroll bounds: vertical scroll should clamp to container-relative extent")
end

local function test_button_visual_prefix_lookup()
  local clicked = 0
  local self = {}
  ui.mount(self)

  local tree = Box({
    key = "root",
    style = { width = "100%", height = "100%", align_items = "center", justify_content = "center" },
    children = {
      Button({
        key = "button",
        style = { width = 100, height = 50 },
        color = rgba(1, 0.5, 0.25, 1),
        on_click = function()
          clicked = clicked + 1
        end,
        children = {
          Text({ key = "label", text = "Tap", style = { width = "100%", height = "100%" } })
        }
      })
    }
  })
  tree._node_prefix = "screen_a_"

  ui.render(self, tree, 200, 200)

  ui.on_input(self, hash("touch"), { x = 100, y = 100, pressed = true })
  local node = self.ui.nodes["screen_a_button"]
  check(node ~= nil, "button prefix lookup: rendered node should use prefixed cache key")
  check(approx_eq(node.color.x, 0.7) and approx_eq(node.color.y, 0.35) and approx_eq(node.color.z, 0.175),
    "button prefix lookup: pressed state should dim the prefixed node")

  ui.on_input(self, hash("touch"), { x = 100, y = 100, released = true })
  check(approx_eq(node.color.x, 1) and approx_eq(node.color.y, 0.5) and approx_eq(node.color.z, 0.25),
    "button prefix lookup: release should restore original color on prefixed node")
  check(clicked == 1, "button prefix lookup: click callback should fire on release over same button")
end

local function test_button_hover_visual()
  local self = {}
  ui.mount(self)

  local tree = Box({
    key = "root",
    style = { width = "100%", height = "100%", align_items = "center", justify_content = "center" },
    children = {
      Button({
        key = "button",
        style = { width = 100, height = 50 },
        color = rgba(0.5, 0.4, 0.3, 1),
        children = {
          Text({ key = "label", text = "Hover", style = { width = "100%", height = "100%" } })
        }
      })
    }
  })

  ui.render(self, tree, 200, 200)

  local node = self.ui.nodes["button"]
  ui.on_input(self, nil, { x = 100, y = 100 })
  check(approx_eq(node.scale.x, 1.03) and approx_eq(node.scale.y, 1.03),
    "button hover: hover state should scale the node up slightly when pointer enters")

  ui.on_input(self, nil, { x = 10, y = 10 })
  check(approx_eq(node.scale.x, 1.0) and approx_eq(node.scale.y, 1.0),
    "button hover: leaving the button should restore the base scale")
end

local function test_button_image_and_slice9()
  local self = {}
  ui.mount(self)

  local tree = Box({
    key = "root",
    style = { width = "100%", height = "100%", align_items = "center", justify_content = "center" },
    children = {
      Button({
        key = "rounded",
        image = "button_rounded",
        texture = "button_shapes",
        border = 18,
        style = { width = 120, height = 50 },
        color = rgba(0.2, 0.4, 0.8, 1),
        children = {
          Text({ key = "rounded_label", text = "Rounded", style = { width = "100%", height = "100%" } })
        }
      }),
      ButtonImage({
        key = "image_button",
        image = "castle_siege",
        texture = "guide",
        style = { width = 120, height = 60 },
      }),
    },
  })

  ui.render(self, tree, 240, 180)

  local rounded = self.ui.nodes["rounded"]
  local image_button = self.ui.nodes["image_button"]
  check(rounded and rounded.texture == "button_shapes", "button image: textured Button should set its texture")
  check(rounded and rounded.animation == "button_rounded", "button image: textured Button should play its background flipbook")
  check(rounded and rounded.slice9 and rounded.slice9.x == 18 and rounded.slice9.y == 18 and rounded.slice9.z == 18 and rounded.slice9.w == 18,
    "button image: border should map to slice9 insets")
  check(image_button and image_button.texture == "guide", "button image: ButtonImage should set its texture")
  check(image_button and image_button.animation == "castle_siege", "button image: ButtonImage should play its image flipbook")
end

local function test_text_font_assignment_and_fallback()
  local self = {}
  ui.mount(self)

  local label = Text({
    key = "label",
    text = "Hello",
    font = "heading",
    style = { width = 120, height = 24 },
  })

  local tree = Box({
    key = "root",
    style = { width = "100%", height = "100%" },
    children = { label },
  })

  ui.render(self, tree, 200, 120)

  local node = self.ui.nodes["label"]
  check(node and node.font == "heading",
    "text font: Text should apply the configured gui font name")

  label.font = nil
  ui.render(self, tree, 200, 120)

  check(node and node.font == "default",
    "text font: Text should fall back to the default gui font when font is cleared")
end

local function test_text_alignment_anchors_match_box_edges()
  local self = {}
  ui.mount(self)

  local label = Text({
    key = "label",
    text = "Hello",
    align = "left",
    style = { width = 120, height = 24 },
  })

  local tree = Box({
    key = "root",
    style = { width = "100%", height = "100%", align_items = "start" },
    children = { label },
  })

  ui.render(self, tree, 200, 120)

  local node = self.ui.nodes["label"]
  local left_x = node and node.position and node.position.x or 0

  label.align = "center"
  ui.render(self, tree, 200, 120)
  local center_x = node and node.position and node.position.x or 0

  label.align = "right"
  ui.render(self, tree, 200, 120)
  local right_x = node and node.position and node.position.x or 0

  check(approx_eq(center_x - left_x, 60),
    "text alignment: center-aligned text should anchor at the middle of its layout box")
  check(approx_eq(right_x - center_x, 60),
    "text alignment: right-aligned text should anchor at the right edge of its layout box")
end

local function test_sample_hub_uses_registered_heading_font()
  local self = {}
  ui.mount(self)

  local tree = screens.hub.view({}, navigation)
  ui.render(self, tree, 960, 640)

  local title = self.ui.nodes["hub_title"]
  check(title and title.font == "heading",
    "sample hub: title should demonstrate Text.font with the registered heading font")
end

local function test_sample_screens_remove_redundant_settings_and_merge_options_sheet()
  check(screens.settings == nil,
    "sample screens: redundant settings screen should be removed from the registry")

  local self = {}
  ui.mount(self)

  local params = {
    sheet_type = "menu",
    sheet_size = "half",
    sheet_visible = true,
  }
  local tree = screens.bottom_sheet_demo.view(params, navigation)
  ui.render(self, tree, 960, 640)

  local menu_settings = tree.children[3].children[1].children[4]
  check(menu_settings and menu_settings.key == "menu_settings",
    "sample bottom sheet demo: menu sheet should expose the merged settings action")

  menu_settings.on_click()

  local options_tree = screens.bottom_sheet_demo.view(params, navigation)
  ui.render(self, options_tree, 960, 640)

  local options_title = self.ui.nodes["sheet_options_title"]
  check(options_title and options_title.text == "Quick Settings",
    "sample bottom sheet demo: merged settings should open the options sheet from the menu action")

  local hub_tree = screens.hub.view({}, navigation)
  ui.render(self, hub_tree, 960, 640)
  check(self.ui.nodes["btn_sheet_options"] == nil,
    "sample hub: standalone options button should be removed")
end

local function test_sample_layouts_and_alignment_demos_render_expanded_examples()
  local self = {}
  ui.mount(self)

  local layouts_tree = screens.layouts_demo.view({}, navigation)
  ui.render(self, layouts_tree, 960, 640)

  check(self.ui.nodes["growth_2_label"] and self.ui.nodes["growth_2_label"].text == "2x",
    "sample layouts demo: flex grow ratio example should render")
  check(self.ui.nodes["nested_chart_title"] and self.ui.nodes["nested_chart_title"].text == "Main content area",
    "sample layouts demo: nested dashboard example should render")

  local alignment_tree = screens.alignment_demo.view({}, navigation)
  ui.render(self, alignment_tree, 960, 640)

  check(self.ui.nodes["align_self_bottom_label"] and self.ui.nodes["align_self_bottom_label"].text == "Bottom",
    "sample alignment demo: align_self override example should render")
  check(self.ui.nodes["text_align_right"] and self.ui.nodes["text_align_right"].text == "Right aligned label",
    "sample alignment demo: text alignment examples should render")
end

local function test_sample_popup_demo_renders_responsive_variants()
  local self = {}
  ui.mount(self)

  local tree = screens.popup_demo.view({}, navigation)
  ui.render(self, tree, 960, 640)

  check(self.ui.nodes["trigger_title"] and self.ui.nodes["trigger_title"].text == "Open A Popup",
    "sample popup demo: trigger section should render")
  check(self.ui.nodes["btn_form_label"] and self.ui.nodes["btn_form_label"].text == "Settings Form",
    "sample popup demo: stacked trigger buttons should render")

  local popup_tree = screens.popup_demo.view({
    popup_visible = true,
    popup_type = "alert",
  }, navigation)
  ui.render(self, popup_tree, 960, 640)

  check(self.ui.nodes["popup_alert_title"] and self.ui.nodes["popup_alert_title"].text == "System Alert",
    "sample popup demo: alert popup variant should render inside the overlay")
end

local function test_sample_popup_demo_supports_blocking_modal()
  local self = {}
  ui.mount(self)

  local tree = screens.popup_demo.view({}, navigation)
  ui.render(self, tree, 960, 640)

  check(self.ui.nodes["btn_blocking_label"] and self.ui.nodes["btn_blocking_label"].text == "Blocking Modal",
    "sample popup demo: blocking modal trigger should render")

  local params = {
    popup_visible = true,
    popup_type = "blocking",
  }
  local blocking_tree = screens.popup_demo.view(params, navigation)
  ui.render(self, blocking_tree, 960, 640)

  check(self.ui.nodes["popup_blocking_title"] and self.ui.nodes["popup_blocking_title"].text == "Blocking Modal",
    "sample popup demo: blocking modal variant should render in the popup overlay")
  check(blocking_tree.children[3] and blocking_tree.children[3].on_backdrop_click == nil,
    "sample popup demo: blocking modal should not define a backdrop dismiss handler")
end

local function test_markdown_style_isolation_and_blank_lines()
  local first = Markdown.viewer("alpha", "doc_one", { padding = 7 })
  local second = Markdown.viewer("alpha", "doc_two")
  check(first.style.padding == 7, "markdown style isolation: first viewer should keep override")
  check(second.style.padding == 20, "markdown style isolation: second viewer should keep default padding")

  local parsed = Markdown.parse("line one\n\nline two", "doc")
  check(#parsed == 3, "markdown blank lines: parse should preserve blank lines as spacer elements")
  check(parsed[2].style and parsed[2].style.height == 10, "markdown blank lines: spacer height should be 10")
end

local function test_markdown_atlas_images()
  local parsed = Markdown.parse("![Guide](icon:icon_star)\n![Guide](atlas:icons:icon_plus)", "doc")
  check(#parsed == 2, "markdown images: parse should emit one element per image row")

  local first_icon = parsed[1] and parsed[1].children and parsed[1].children[1]
    and parsed[1].children[1].children and parsed[1].children[1].children[1]
  local second_icon = parsed[2] and parsed[2].children and parsed[2].children[1]
    and parsed[2].children[1].children and parsed[2].children[1].children[1]

  check(first_icon and first_icon.type == "icon", "markdown images: icon: syntax should render a real icon node")
  check(first_icon and first_icon.image == "icon_star", "markdown images: icon: syntax should keep the requested image id")
  check(first_icon and first_icon.texture == "icons", "markdown images: icon: syntax should default to the icons texture")

  check(second_icon and second_icon.type == "icon", "markdown images: atlas: syntax should render a real icon node")
  check(second_icon and second_icon.image == "icon_plus", "markdown images: atlas: syntax should keep the requested image id")
  check(second_icon and second_icon.texture == "icons", "markdown images: atlas: syntax should keep the requested texture")
end

local function test_markdown_image_modifiers_and_scaling()
  local tree = Markdown.viewer("![Guide](atlas:guide:forest_path_sunset|width=100|height=80|scale=fit|aspect=2:1)", "doc_fit")
  local self = {}
  ui.mount(self)
  ui.render(self, tree, 200, 300)

  local fit_frame = self.ui.nodes["doc_fit_line_1_image_frame"]
  local fit_image = self.ui.nodes["doc_fit_line_1_image"]
  check(fit_frame and fit_frame.size.x == 100 and fit_frame.size.y == 80,
    "markdown image modifiers: width and height should size the image frame")
  check(fit_image and fit_image.size_mode == gui.SIZE_MODE_MANUAL,
    "markdown image modifiers: image nodes should use manual size mode")
  check(fit_image and fit_image.size.x == 100 and fit_image.size.y == 50,
    "markdown image modifiers: fit should preserve aspect inside the frame")

  local stretch_tree = Markdown.viewer("![Guide](atlas:guide:forest_path_sunset|width=100|height=80|scale=stretch|aspect=2:1)", "doc_stretch")
  local stretch_self = {}
  ui.mount(stretch_self)
  ui.render(stretch_self, stretch_tree, 200, 300)

  local stretch_image = stretch_self.ui.nodes["doc_stretch_line_1_image"]
  check(stretch_image and stretch_image.size.x == 100 and stretch_image.size.y == 80,
    "markdown image modifiers: stretch should keep the frame size")
end

local function test_debug_is_instance_local()
  local a = {}
  local b = {}
  ui.mount(a)
  ui.mount(b)

  check(a.ui.debug == false, "debug isolation: mount should default debug to false")
  check(b.ui.debug == false, "debug isolation: separate mounts should default debug to false")

  ui.set_debug(a, true)

  check(a.ui.debug == true, "debug isolation: set_debug should update only the target instance")
  check(b.ui.debug == false, "debug isolation: other mounted instances should keep their debug state")
end

local function test_bottom_sheet_closed_not_hittable()
  local self = {}
  ui.mount(self)

  local tree = Box({
    key = "root",
    style = { width = "100%", height = "100%" },
    children = {
      BottomSheet({
        key = "sheet",
        _open = false,
        children = {
          Box({
            key = "sheet_panel",
            style = { width = "100%", height = 80 },
          }),
        },
      }),
    },
  })

  ui.render(self, tree, 200, 200)
  local hit = ui.hit_test(self, 100, 100)
  check(hit ~= nil and hit.key == "root",
    "bottom sheet hit test: closed animated sheet should not capture input before it opens")
end

local function test_navigation_global_router_flow()
  navigation._reset_for_tests()
  clear_posted_messages()

  local preload_events = {}
  local result_ok = false

  navigation.on("preload", function(screen_id)
    preload_events[#preload_events + 1] = screen_id
  end)

  navigation.register("home", {
    view = function(params)
      return Box({
        key = "home_root",
        style = { width = "100%", height = "100%" },
        children = {
          Scroll({
            key = "list",
            style = { width = "100%", height = 100, flex_direction = "column" },
            children = {
              Box({ key = "home_content", style = { height = 200 } }),
            },
          }),
        },
      })
    end,
    preload = true,
  })

  navigation.register("detail", {
    view = function(params)
      check(navigation.get_data("item") == 42, "navigation facade: current screen data should be readable via get_data(key)")
      check(params.item == 42, "navigation facade: pushed params should be injected into the target view")
      return Box({
        key = "detail_root",
        style = { width = "100%", height = "100%" },
      })
    end,
  })

  check(preload_events[1] == "home", "navigation facade: preload should fire automatically on register when preload=true")

  navigation.reset("home", {
    scroll_state = {
      list = { y = 55, x = 0 },
    },
  })

  check(navigation.stack_depth() == 1, "navigation facade: reset should seed the app-wide stack")
  check(navigation.get_scroll_offset("list") == 55, "navigation facade: scroll offsets should be read from current screen params")

  navigation.push("detail", { item = 42 }, {
    transition = "none",
    on_result = function(result)
      result_ok = result and result.ok == true
    end,
  })

  check(navigation.stack_depth() == 2, "navigation facade: push should grow the global stack")
  check(navigation.get_data("item") == 42, "navigation facade: pushed screen should become the current data context")
  check(navigation.get_data({ screen_id = "home" }) ~= nil,
    "navigation facade: cross-screen lookup should return the matching params table")

  local current = navigation.current()
  current.screen.view(current.params, navigation)

  navigation.pop({ ok = true }, "none")

  check(navigation.stack_depth() == 1, "navigation facade: pop should shrink the global stack")
  check(result_ok == true, "navigation facade: pop should deliver result data to the caller callback")
end

local function test_navigation_result_message_delivery()
  navigation._reset_for_tests()
  clear_posted_messages()

  navigation.register("home", {
    view = function(params)
      return Box({ key = "home_root", style = { width = "100%", height = "100%" } })
    end,
  })

  navigation.register("detail", {
    view = function(params)
      return Box({ key = "detail_root", style = { width = "100%", height = "100%" } })
    end,
  })

  navigation.reset("home", {}, "none")
  clear_posted_messages()

  navigation.push("detail", { item = 10 }, {
    transition = "none",
    result_url = "main:/settings#script",
    result_message_id = "navigation_result",
  })

  clear_posted_messages()

  navigation.pop({ saved = true }, "none")

  check(count_posts("main:/settings#script", "navigation_result") == 1,
    "navigation results: pop should post navigation_result when result_url is configured")
  check(posted_messages[1] and posted_messages[1].message and posted_messages[1].message.result.saved == true,
    "navigation results: posted result message should contain the pop result payload")
end

local function test_navigation_message_transport_queue_focus_and_lifecycle()
  navigation._reset_for_tests()
  clear_posted_messages()

  local hook_counts = {
    home = { enter = 0, pause = 0, resume = 0, exit = 0 },
    detail = { enter = 0, pause = 0, resume = 0, exit = 0 },
  }
  local pop_result = nil

  navigation.on("transition_begin", function()
  end)

  navigation.register("home", {
    url = "main:/home#script",
    focus_url = "main:/home#input",
    on_enter = function()
      hook_counts.home.enter = hook_counts.home.enter + 1
    end,
    on_pause = function()
      hook_counts.home.pause = hook_counts.home.pause + 1
    end,
    on_resume = function()
      hook_counts.home.resume = hook_counts.home.resume + 1
    end,
    on_exit = function()
      hook_counts.home.exit = hook_counts.home.exit + 1
    end,
  })

  navigation.register("detail", {
    url = "main:/detail#script",
    focus_url = "main:/detail#input",
    on_enter = function()
      hook_counts.detail.enter = hook_counts.detail.enter + 1
    end,
    on_pause = function()
      hook_counts.detail.pause = hook_counts.detail.pause + 1
    end,
    on_resume = function()
      hook_counts.detail.resume = hook_counts.detail.resume + 1
    end,
    on_exit = function()
      hook_counts.detail.exit = hook_counts.detail.exit + 1
    end,
  })

  navigation.reset("home", { value = 1 }, "none")
  check(hook_counts.home.enter == 1, "navigation lifecycle: reset should call on_enter on the destination screen")
  check(count_posts("main:/home#script", "navigation_enter") == 1,
    "navigation lifecycle: reset should post navigation_enter to the destination url")
  check(count_posts("main:/home#input", "acquire_input_focus") == 1,
    "navigation focus: reset should acquire input focus for the destination focus_url")

  clear_posted_messages()

  local handled_push = navigation_messages.on_message(navigation_messages.PUSH, {
    id = "detail",
    params = { item = 9 },
    options = {
      transition = "fade",
      on_result = function(result)
        pop_result = result
      end,
    },
  })

  check(handled_push == true, "navigation messages: push message should be handled")
  check(navigation.is_busy() == true, "navigation queue: transition-aware push should mark navigation busy")
  check(navigation.stack_depth() == 2, "navigation queue: push should mutate stack before transition completion")
  check(hook_counts.home.pause == 1, "navigation lifecycle: push should call on_pause on the previous top screen")
  check(hook_counts.detail.enter == 1, "navigation lifecycle: push should call on_enter on the pushed screen")
  check(count_posts("main:/home#script", "navigation_pause") == 1,
    "navigation lifecycle: push should post navigation_pause to the previous screen url")
  check(count_posts("main:/detail#script", "navigation_enter") == 1,
    "navigation lifecycle: push should post navigation_enter to the new screen url")
  check(count_posts("main:/home#input", "release_input_focus") == 1,
    "navigation focus: push should release focus from the previous focus_url")
  check(count_posts("main:/detail#input", "acquire_input_focus") == 1,
    "navigation focus: push should acquire focus for the pushed screen")

  local handled_pop = navigation_messages.on_message(navigation_messages.POP, {
    result = { ok = true },
    transition = "none",
  })

  check(handled_pop == true, "navigation messages: pop message should be handled")
  check(navigation.stack_depth() == 2, "navigation queue: queued pop should not execute until the active transition completes")

  navigation.complete_transition()

  check(navigation.is_busy() == false, "navigation queue: completing the transition should release busy state")
  check(navigation.stack_depth() == 1, "navigation queue: queued pop should execute after transition completion")
  check(pop_result and pop_result.ok == true, "navigation results: queued pop should deliver result data after completion")
  check(hook_counts.detail.exit == 1, "navigation lifecycle: pop should call on_exit on the popped screen")
  check(hook_counts.home.resume == 1, "navigation lifecycle: pop should call on_resume on the revealed screen")
  check(count_posts("main:/detail#script", "navigation_exit") == 1,
    "navigation lifecycle: pop should post navigation_exit to the popped screen url")
  check(count_posts("main:/home#script", "navigation_resume") == 1,
    "navigation lifecycle: pop should post navigation_resume to the revealed screen url")
  check(count_posts("main:/detail#input", "release_input_focus") == 1,
    "navigation focus: pop should release focus from the popped screen")
  check(count_posts("main:/home#input", "acquire_input_focus") == 1,
    "navigation focus: pop should re-acquire focus for the revealed screen")
end

local function test_navigation_proxy_runtime()
  navigation._reset_for_tests()
  clear_posted_messages()

  local proxy_runtime = navigation_proxy.attach(navigation)

  navigation.register("world_a", {
    url = "main:/world_a#script",
    proxy_url = "main:/world_a#collectionproxy",
    preload = true,
  })

  navigation.register("world_b", {
    url = "main:/world_b#script",
    proxy_url = "main:/world_b#collectionproxy",
    preload = true,
  })

  check(count_posts("main:/world_a#collectionproxy", "async_load") == 1,
    "navigation proxy: preload=true should async_load the first registered proxy")
  check(count_posts("main:/world_b#collectionproxy", "async_load") == 1,
    "navigation proxy: preload=true should async_load the second registered proxy")

  clear_posted_messages()

  navigation.reset("world_a", { level = 1 }, "none")
  check(count_posts("main:/world_a#collectionproxy", "enable") == 1,
    "navigation proxy: reset should enable the active screen proxy")

  clear_posted_messages()

  navigation.push("world_b", { level = 2 }, "none")
  check(count_posts("main:/world_a#collectionproxy", "disable") == 1,
    "navigation proxy: pushing another proxy screen should disable the previous active proxy")
  check(count_posts("main:/world_b#collectionproxy", "enable") == 1,
    "navigation proxy: pushing another proxy screen should enable the new active proxy")

  clear_posted_messages()

  navigation.pop(nil, "none")
  check(count_posts("main:/world_b#collectionproxy", "disable") == 1,
    "navigation proxy: pop should disable the popped proxy screen")
  check(count_posts("main:/world_a#collectionproxy", "enable") == 1,
    "navigation proxy: pop should re-enable the revealed proxy screen")

  proxy_runtime:detach()
end

local function test_navigation_runtime_helper()
  navigation._reset_for_tests()
  clear_posted_messages()

  local self = {}
  navigation_runtime.init(self, {
    screens = {
      world = {
        url = "main:/world#script",
        proxy_url = "main:/world#collectionproxy",
        preload = true,
      },
    },
    initial_screen = "world",
    initial_params = { level = 3 },
  })

  check(self.navigation == navigation, "navigation runtime: init should expose app-wide navigation on self.navigation")
  check(self.navigation_runtime ~= nil, "navigation runtime: init should attach runtime state to self")
  check(count_posts("main:/world#collectionproxy", "async_load") == 1,
    "navigation runtime: init should attach proxy runtime and preload registered proxy screens")
  check(count_posts("main:/world#collectionproxy", "enable") == 1,
    "navigation runtime: init with initial_screen should enable the active proxy")

  local handled = navigation_runtime.on_message(self, navigation_messages.INVALIDATE, {})
  check(handled == true, "navigation runtime: on_message should delegate navigation transport messages")
  check(navigation.is_invalidated() == true, "navigation runtime: delegated invalidate should affect app-wide navigation state")

  navigation_runtime.final(self)
end

local function test_navigation_bootstrap_sample_flow()
  navigation._reset_for_tests()
  clear_posted_messages()

  local env = setmetatable({}, { __index = _G })
  local chunk = assert(loadfile("sample/navigation_bootstrap.script"))
  if setfenv then
    setfenv(chunk, env)
  else
    chunk = assert(load(string.dump(chunk), "@sample/navigation_bootstrap.script", "b", env))
  end
  chunk()

  local self = {}
  env.init(self)

  check(navigation.current() and navigation.current().id == "hub",
    "sample navigation: bootstrap script should own initial reset to hub")

  env.on_message(self, hash("open_non_gui_flow"), {
    level = 7,
    opened_from = "hub",
  })

  check(navigation.current() and navigation.current().id == "non_gui_flow",
    "sample navigation: script message should push the non_gui_flow screen")
  check(navigation.get_data("level") == 7,
    "sample navigation: pushed params should be readable on the non-gui flow")
  check(navigation.get_data("opened_from") == "hub",
    "sample navigation: controller-driven push should preserve source metadata")

  env.on_message(self, hash("navigation_enter"), {
    from = "hub",
    to = "non_gui_flow",
  })

  check(navigation.get_data("enter_count") == 1,
    "sample navigation: navigation_enter should let the controller mutate current screen data")
  check(navigation.get_data("controller_note") == "navigation_enter handled in navigation_bootstrap.script",
    "sample navigation: controller should store navigation-enter metadata on the active screen")

  local current = navigation.current()
  local tree = current.screen.view(current.params, navigation)
  check(tree and tree.key == "non_gui_flow_root",
    "sample navigation: non-gui registered screen should still provide a gui view")

  clear_posted_messages()
  env.on_message(self, hash("finish_non_gui_flow"), {
    score = 701,
  })

  check(navigation.current() and navigation.current().id == "hub",
    "sample navigation: finish message should pop back to the hub screen")

  local result_message = find_post("main:/navigation#navigation_bootstrap", "non_gui_flow_result")
  check(result_message and result_message.message_id == "non_gui_flow_result",
    "sample navigation: finishing the flow should emit the configured result message")

  env.on_message(self, result_message.message_id, result_message.message, result_message.url)

  local hub_result = navigation.get_data("non_gui_result")
  check(hub_result and hub_result.status == "completed",
    "sample navigation: controller should store returned result data on the hub screen")
  check(hub_result and hub_result.score == 701,
    "sample navigation: returned result score should be preserved on the hub screen")

  navigation_runtime.final(self)
end

local tests = {
  test_flow_facade_namespaces,
  test_color_api_parses_public_formats,
  test_flow_on_message_facade,
  test_flow_log_levels_and_contexts,
  test_layout_overflow_clamp,
  test_nested_scroll_bounds,
  test_button_visual_prefix_lookup,
  test_button_hover_visual,
  test_button_image_and_slice9,
  test_text_font_assignment_and_fallback,
  test_text_alignment_anchors_match_box_edges,
  test_sample_hub_uses_registered_heading_font,
  test_sample_screens_remove_redundant_settings_and_merge_options_sheet,
  test_sample_layouts_and_alignment_demos_render_expanded_examples,
  test_sample_popup_demo_renders_responsive_variants,
  test_sample_popup_demo_supports_blocking_modal,
  test_markdown_style_isolation_and_blank_lines,
  test_markdown_atlas_images,
  test_markdown_image_modifiers_and_scaling,
  test_debug_is_instance_local,
  test_bottom_sheet_closed_not_hittable,
  test_navigation_global_router_flow,
  test_navigation_result_message_delivery,
  test_navigation_message_transport_queue_focus_and_lifecycle,
  test_navigation_proxy_runtime,
  test_navigation_runtime_helper,
  test_navigation_bootstrap_sample_flow,
}

for _, test_fn in ipairs(tests) do
  test_fn()
end

if #failures > 0 then
  io.stderr:write("Smoke tests failed:\n")
  for _, failure in ipairs(failures) do
    io.stderr:write("- " .. failure .. "\n")
  end
  os.exit(1)
end

print("Smoke tests passed: " .. tostring(#tests))
