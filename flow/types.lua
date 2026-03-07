-- flow/types.lua
-- Shared type definitions for the Flow library.
-- This file is annotation-only; it is not required at runtime.

---@class Flow.Style
---@field width? number|string           Fixed width in px, or percentage "50%"
---@field height? number|string          Fixed height in px, or percentage "50%"
---@field min_width? number              Stored for compatibility; currently not enforced by flow/layout.lua
---@field min_height? number             Stored for compatibility; currently not enforced by flow/layout.lua
---@field max_width? number              Stored for compatibility; currently not enforced by flow/layout.lua
---@field max_height? number             Stored for compatibility; currently not enforced by flow/layout.lua
---@field flex_direction? "column"|"row"
---@field flex_grow? number
---@field flex_shrink? number            Stored for compatibility; currently not consumed by flow/layout.lua
---@field flex_basis? number|string      Stored for compatibility; currently not consumed by flow/layout.lua
---@field align_items? "start"|"center"|"end"|"stretch"
---@field align_self? "start"|"center"|"end"|"stretch"|"auto"
---@field justify_content? "start"|"center"|"end"|"space-between"|"space-around"|"space-evenly"
---@field gap? number
---@field padding? number|string
---@field padding_left? number|string
---@field padding_right? number|string
---@field padding_top? number|string
---@field padding_bottom? number|string
---@field margin? number|string          Stored for compatibility; currently not consumed by flow/layout.lua
---@field margin_left? number|string     Stored for compatibility; currently not consumed by flow/layout.lua
---@field margin_right? number|string    Stored for compatibility; currently not consumed by flow/layout.lua
---@field margin_top? number|string      Stored for compatibility; currently not consumed by flow/layout.lua
---@field margin_bottom? number|string   Stored for compatibility; currently not consumed by flow/layout.lua
---@field border? number|string          Stored for compatibility; currently not consumed by flow/layout.lua
---@field border_left? number|string     Stored for compatibility; currently not consumed by flow/layout.lua
---@field border_right? number|string    Stored for compatibility; currently not consumed by flow/layout.lua
---@field border_top? number|string      Stored for compatibility; currently not consumed by flow/layout.lua
---@field border_bottom? number|string   Stored for compatibility; currently not consumed by flow/layout.lua
---@field position_left? number|string   Stored for compatibility; currently not consumed by flow/layout.lua
---@field position_right? number|string  Stored for compatibility; currently not consumed by flow/layout.lua
---@field position_top? number|string    Stored for compatibility; currently not consumed by flow/layout.lua
---@field position_bottom? number|string Stored for compatibility; currently not consumed by flow/layout.lua
---@field position_type? "static"|"relative"|"absolute"
---@field flex_wrap? "no-wrap"|"wrap"|"wrap-reverse"
---@field overflow? "visible"|"hidden"|"scroll"
---@field display? "flex"|"none"
---@field aspect_ratio? number
---@field direction? "inherit"|"ltr"|"rtl"

---@class Flow.Element
---@field key string                     Stable unique identifier for node caching
---@field type? string                   Element type ("box", "text", "button", etc.); filled by constructors like Box()/Text()/Button()
---@field style? Flow.Style
---@field children? Flow.Element[]
---@field layout? Flow.LayoutRect        Computed layout (written by layout engine)
---@field color? vector4
---@field text? string
---@field align? "left"|"center"|"right"
---@field font? string
---@field image? string
---@field texture? string
---@field scale_mode? "stretch"|"fit"
---@field image_aspect? number
---@field border? number|{left?: number, top?: number, right?: number, bottom?: number}
---@field pressed_color? vector4
---@field on_click? fun(element: Flow.Element)
---@field backdrop_color? vector4
---@field on_backdrop_click? fun(element: Flow.Element)
---@field _visible? boolean
---@field _is_overlay? boolean
---@field _alpha? number
---@field _offset_x? number
---@field _offset_y? number
---@field _offset_x_pixels? number
---@field _offset_y_pixels? number
---@field _pressed? boolean
---@field _hovered? boolean
---@field _open? boolean
---@field _anim_y? number
---@field _anim_velocity? number
---@field _on_anim_update? fun(anim_y: number, velocity: number)
---@field _sheet_height? number
---@field _scrollbar? boolean
---@field _bounce? boolean
---@field _momentum? boolean
---@field _virtual_height? number
---@field _virtual_width? number
---@field _scroll_y? number
---@field _scroll_x? number
---@field _momentum_active? boolean
---@field _bouncing? boolean
---@field _velocity? number
---@field _dragging_axis? "x"|"y"
---@field _dragging? boolean
---@field _drag_start_y? number
---@field _drag_start_x? number
---@field _scroll_start_y? number
---@field _scroll_start_x? number
---@field _last_drag_y? number
---@field _last_drag_x? number
---@field _last_drag_time? number
---@field _cache_key? string
---@field _node_prefix? string
---@field _background_screen? Flow.Element
---@field _scroll_ancestor? Flow.Element
---@field _needs_redraw? boolean
---@field _scroll_changed? boolean
---@field _clips_children? boolean
---@field _clipping_visible? boolean

---@class Flow.BoxProps : Flow.Element

---@class Flow.TextProps : Flow.Element
---@field text string
---@field align? "left"|"center"|"right"
---@field font? string

---@class Flow.ButtonProps : Flow.Element
---@field pressed_color? vector4
---@field on_click? fun(element: Flow.Element)
---@field image? string
---@field texture? string
---@field border? number|{left?: number, top?: number, right?: number, bottom?: number}

---@class Flow.ButtonImageProps : Flow.ButtonProps
---@field image string

---@class Flow.IconProps : Flow.Element
---@field image string
---@field texture? string
---@field scale_mode? "stretch"|"fit"
---@field image_aspect? number

---@class Flow.ScrollProps : Flow.Element
---@field _scrollbar? boolean
---@field _bounce? boolean
---@field _momentum? boolean
---@field _virtual_height? number
---@field _virtual_width? number
---@field _scroll_y? number
---@field _scroll_x? number

---@class Flow.PopupProps : Flow.Element
---@field backdrop_color? vector4
---@field on_backdrop_click? fun(element: Flow.Element)

---@class Flow.BottomSheetProps : Flow.Element
---@field backdrop_color? vector4
---@field _open? boolean
---@field _anim_y? number
---@field _anim_velocity? number
---@field _on_anim_update? fun(anim_y: number, velocity: number)
---@field on_backdrop_click? fun(element: Flow.Element)

---@class Flow.LayoutRect
---@field x number
---@field y number
---@field w number
---@field h number

---@alias Flow.LogLevel "none"|"error"|"warn"|"info"|"debug"

---@class Flow.Logger
---@field levels table<string, integer>
---@field get_level fun(): Flow.LogLevel
---@field set_level fun(level: Flow.LogLevel|integer): Flow.LogLevel
---@field get_context_level fun(context: string): Flow.LogLevel|nil
---@field set_context_level fun(context: string, level: Flow.LogLevel|integer): Flow.LogLevel
---@field clear_context_level fun(context: string): boolean
---@field none fun(context?: string): Flow.LogLevel
---@field is_enabled fun(level: Flow.LogLevel|integer, context?: string): boolean
---@field set_sink fun(fn?: fun(entry: table)): boolean
---@field debug fun(context: string, ...): boolean
---@field info fun(context: string, ...): boolean
---@field warn fun(context: string, ...): boolean
---@field error fun(context: string, ...): boolean
---@field _reset_for_tests fun(): boolean

---@class Flow.TransitionMeta
---@field action string
---@field type "fade"|"slide_left"|"slide_right"|"none"
---@field duration number
---@field from_id? string
---@field to_id? string

---@class Flow.ScreenDef
---@field view? fun(params: table, navigation: Flow.Navigation): Flow.Element|nil
---@field url? userdata                  msg.url() for lifecycle message delivery
---@field focus_url? userdata            msg.url() of the script that owns input focus
---@field proxy_url? userdata            msg.url() of a collection proxy to load
---@field preload? boolean
---@field transition? "fade"|"slide_left"|"slide_right"|"none"
---@field meta? any
---@field on_enter? fun(params: table, navigation: Flow.Navigation)
---@field on_exit? fun(params: table, navigation: Flow.Navigation)
---@field on_pause? fun(params: table, navigation: Flow.Navigation)
---@field on_resume? fun(params: table, navigation: Flow.Navigation)

---@class Flow.RegisteredScreen : Flow.ScreenDef
---@field id string
---@field _source Flow.ScreenDef

---@class Flow.PushOptions
---@field transition? "fade"|"slide_left"|"slide_right"|"none"
---@field duration? number
---@field on_result? fun(result: any)
---@field result_url? userdata
---@field result_message_id? hash|string

---@class Flow.StackEntry
---@field id string
---@field params table
---@field screen Flow.RegisteredScreen
---@field on_result? fun(result: any)
---@field result_url? userdata
---@field result_message_id? hash|string

---@class Flow.ScreenScope
---@field screen_id string

---@alias Flow.ScreenRegistry table<string, Flow.ScreenDef>

---@class Flow.Navigation
---@field register fun(id: string, screen_def: Flow.ScreenDef): Flow.RegisteredScreen
---@field get_screen fun(id: string): Flow.RegisteredScreen|nil
---@field push fun(id: string, params?: table, options?: Flow.PushOptions): Flow.StackEntry|nil
---@field pop fun(result?: any, options?: Flow.PushOptions|string): Flow.StackEntry|nil
---@field replace fun(id: string, params?: table, options?: Flow.PushOptions): Flow.StackEntry|nil
---@field reset fun(id: string, params?: table, options?: Flow.PushOptions|string): Flow.StackEntry|nil
---@field back fun(result?: any, options?: Flow.PushOptions|string): Flow.StackEntry|nil
---@field current fun(): Flow.StackEntry|nil
---@field peek fun(offset?: number): Flow.StackEntry|nil
---@field stack_depth fun(): number
---@field invalidate fun()
---@field is_invalidated fun(): boolean
---@field clear_invalidation fun()
---@field is_busy fun(): boolean
---@field get_transition fun(): Flow.TransitionMeta|nil
---@field begin_transition fun(meta: Flow.TransitionMeta): Flow.TransitionMeta
---@field complete_transition fun(): boolean
---@field get_data fun(key_or_opts?: string|Flow.ScreenScope, opts?: Flow.ScreenScope): any
---@field set_data fun(key: string, value: any, opts?: Flow.ScreenScope): any
---@field get_scroll_offset fun(key: string, opts?: Flow.ScreenScope): number
---@field on fun(event: string, fn: function): function
---@field off fun(event: string, fn: function)
---@field _reset_for_tests fun(): boolean
---@field _router fun(): table

---@class Flow.MountOptions
---@field debug? boolean

---@class Flow.InitConfig
---@field screens? Flow.ScreenRegistry
---@field initial_screen? string
---@field initial_params? table
---@field debug? boolean
---@field on_update? fun(self: table, dt: number, nav: Flow.Navigation): boolean
---@field on_message? fun(self: table, message_id: hash|string, message: table|nil, sender: userdata|nil, nav: Flow.Navigation): boolean

---@class Flow.RuntimeConfig
---@field screens? Flow.ScreenRegistry
---@field initial_screen? string
---@field initial_params? table
---@field initial_options? Flow.PushOptions|string
---@field enable_proxy_runtime? boolean
---@field proxy_options? Flow.ProxyAttachOptions

---@class Flow.ProxyAttachOptions
---@field preload_message_id? hash|string
---@field enable_message_id? hash|string
---@field disable_message_id? hash|string
---@field sync_existing? boolean

---@class Flow.MarkdownOptions
---@field text? string
---@field key? string
---@field style? Flow.Style
---@field _scrollbar? boolean
---@field _bounce? boolean
---@field _momentum? boolean

---@class Flow.FlexNodeOptions
---@field key? string
---@field type? string
---@field color? vector4
---@field style? Flow.Style
---@field children? Flow.Element[]

---@class Flow.FlexNode : Flow.Element
---@field style Flow.Style
---@field children Flow.FlexNode[]
---@field measure? function

---@alias Flow.DefRegistry table<string, table>

---@class Flow.InputDeps
---@field registry Flow.DefRegistry
---@field get_window_size function
---@field get_gui_size function
---@field is_debug_enabled fun(self: table): boolean

---@class Flow.AnimationDeps
---@field registry Flow.DefRegistry
---@field request_redraw fun(self: table)

---@class Flow.RendererDeps
---@field registry Flow.DefRegistry
---@field get_window_size function
---@field get_gui_size function
---@field layout table
---@field set_node_color fun(node: userdata, r: number, g: number, b: number, a: number)
---@field set_node_position fun(node: userdata, x: number, y: number)
---@field set_node_size fun(node: userdata, w: number, h: number)
