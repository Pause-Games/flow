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
function vmath.vector4(x, y, z, w)
  return { x = x or 0, y = y or 0, z = z or 0, w = w or 0 }
end

hash = function(value)
  return value
end

window = {
  get_size = function()
    return 800, 600
  end,
}

sys = {
  get_config = function(key)
    if key == "display.width" then
      return "800"
    end
    if key == "display.height" then
      return "600"
    end
    return nil
  end,
}

package.preload["builtins/scripts/socket"] = function()
  return {
    gettime = function()
      return os.clock()
    end,
  }
end

gui = {
  PIVOT_W = "w",
  PIVOT_CENTER = "center",
  PIVOT_E = "e",
  CLIPPING_MODE_STENCIL = "stencil",
}

local function new_node(kind, pos, size)
  return {
    kind = kind,
    position = deepcopy(pos or vmath.vector3()),
    size = deepcopy(size or vmath.vector3()),
    color = vmath.vector4(1, 1, 1, 1),
    alpha = 1,
  }
end

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

function gui.set_position(node, pos)
  node.position = deepcopy(pos)
end

function gui.set_size(node, size)
  node.size = deepcopy(size)
end

function gui.set_parent(node, parent)
  node.parent = parent
end

function gui.delete_node(_node)
end

local ui = require "flow/ui"
local Box = require "flow/components/box"
local Button = require "flow/components/button"
local Scroll = require "flow/components/scroll"
local Text = require "flow/components/text"

local function percentile(sorted, p)
  if #sorted == 0 then return 0 end
  local index = math.max(1, math.ceil(#sorted * p))
  return sorted[index]
end

local function build_row(i)
  return Button({
    key = "row_" .. i,
    style = {
      width = "100%",
      height = 40,
      flex_direction = "row",
      align_items = "center",
      padding_left = 8,
      padding_right = 8,
    },
    color = vmath.vector4(0.15 + (i % 3) * 0.05, 0.18, 0.24, 1),
    children = {
      Text({
        key = "row_" .. i .. "_label",
        text = "Row " .. i,
        style = { width = 120, height = 20 },
      }),
      Box({
        key = "row_" .. i .. "_spacer",
        style = { flex_grow = 1, height = 1 },
        color = vmath.vector4(0, 0, 0, 0),
      }),
      Text({
        key = "row_" .. i .. "_value",
        text = tostring(i * 3),
        style = { width = 60, height = 20 },
        align = "right",
      }),
    },
  })
end

local function build_tree(count)
  local children = {}
  for i = 1, count do
    children[i] = build_row(i)
  end

  return Box({
    key = "root",
    style = { width = "100%", height = "100%", flex_direction = "column" },
    children = {
      Box({
        key = "header",
        style = { width = "100%", height = 56, align_items = "center", justify_content = "center" },
        color = vmath.vector4(0.08, 0.10, 0.14, 1),
        children = {
          Text({ key = "title", text = "Perf Probe", style = { width = 200, height = 24 }, align = "center" }),
        },
      }),
      Scroll({
        key = "list",
        style = { width = "100%", flex_grow = 1, flex_direction = "column" },
        children = children,
      }),
    },
  })
end

local function run_probe(iterations, rows)
  local self = {}
  ui.mount(self)
  local tree = build_tree(rows)
  ui.render(self, tree, 800, 600)

  collectgarbage("collect")
  local gc_before = collectgarbage("count")
  local samples = {}
  local total = 0
  local worst = 0

  for i = 1, iterations do
    local scroll = tree.children[2]
    scroll._scroll_y = (i * 7) % 600
    ui.request_redraw(self)

    local start_t = os.clock()
    ui.update(self, tree)
    local elapsed_ms = (os.clock() - start_t) * 1000

    samples[i] = elapsed_ms
    total = total + elapsed_ms
    worst = math.max(worst, elapsed_ms)
  end

  collectgarbage("collect")
  local gc_after = collectgarbage("count")

  table.sort(samples)
  local average = total / iterations
  local p50 = percentile(samples, 0.50)
  local p95 = percentile(samples, 0.95)
  local p99 = percentile(samples, 0.99)

  print(string.format("Perf probe (%d iterations, %d rows)", iterations, rows))
  print(string.format("avg_ms=%.4f", average))
  print(string.format("p50_ms=%.4f", p50))
  print(string.format("p95_ms=%.4f", p95))
  print(string.format("p99_ms=%.4f", p99))
  print(string.format("worst_ms=%.4f", worst))
  print(string.format("gc_delta_kb=%.2f", gc_after - gc_before))
end

run_probe(300, 120)
