-- flow/navigation/core.lua
-- Pure stack-based navigation router for the Flow library.
-- No Defold dependencies — works in plain Lua for unit-testable logic.
--
-- A router manages:
--   - A screen registry (id → normalized screen definition)
--   - A navigation stack (array of StackEntry tables)
--   - An event emitter for "push", "pop", "replace", "reset", "changed",
--     "registered", "preload", "transition_begin", "transition_complete"
--   - A transition state machine (busy flag + pending queue)
--
-- Create a router with M.new(); all methods are on the returned table.
local M = {}
local log = require "flow/log"
local unpack_args = unpack
if not unpack_args and table then
	unpack_args = rawget(table, "unpack")
end

--- Defold message id hashes for lifecycle events delivered to screen URLs.
--- Falls back to raw strings when called outside Defold (unit tests).
local MESSAGE_IDS = {
	on_enter = (type(hash) == "function") and hash("navigation_enter") or "navigation_enter",
	on_exit = (type(hash) == "function") and hash("navigation_exit") or "navigation_exit",
	on_pause = (type(hash) == "function") and hash("navigation_pause") or "navigation_pause",
	on_resume = (type(hash) == "function") and hash("navigation_resume") or "navigation_resume",
}

--- Default message id for result delivery when a screen pops with a result.
local DEFAULT_RESULT_MESSAGE_ID = (type(hash) == "function") and hash("navigation_result") or "navigation_result"

--- Normalize a push/replace/reset options argument.
--- Accepts either a string (treated as transition type) or a table.
--- Applies default_transition when options.transition is not set.
---@param options string|Flow.PushOptions|nil  Raw options from caller
---@param default_transition string|nil  Transition to use when options.transition is absent
---@return Flow.PushOptions        Normalized options table with at least {}
local function normalize_options(options, default_transition)
	if type(options) == "string" then
		options = { transition = options }
	elseif options == nil then
		options = {}
	end

	if default_transition ~= nil and options.transition == nil then
		options.transition = default_transition
	end

	return options
end

--- Validate and normalize a raw screen definition from the caller.
--- Produces an internal normalized screen table with only known fields.
--- The original screen_def is stored as _source so re-registration of the
--- exact same table is idempotent (useful for hot-reload).
---@param id string                The screen identifier being registered
---@param screen_def Flow.ScreenDef  The raw screen definition from the caller
---@return Flow.RegisteredScreen   The normalized internal screen record
local function normalize_screen(id, screen_def)
	assert(type(id) == "string", "navigation.register(id, screen_def): id must be a string")
	assert(type(screen_def) == "table", "navigation.register(id, screen_def): screen_def must be a table")

	return {
		id = id,
		view = screen_def.view,
		url = screen_def.url,
		proxy_url = screen_def.proxy_url,
		focus_url = screen_def.focus_url,
		on_enter = screen_def.on_enter,
		on_exit = screen_def.on_exit,
		on_pause = screen_def.on_pause,
		on_resume = screen_def.on_resume,
		preload = screen_def.preload == true and true or nil,
		transition = screen_def.transition,
		meta = screen_def.meta,
		_source = screen_def,
	}
end

--- Create a new navigation router instance.
--- All state is captured in upvalues so multiple independent routers can coexist.
---@return Flow.Navigation  A router object with all navigation methods
function M.new()
	--- Map from screen id string to normalized screen definition.
	---@type table<string, Flow.RegisteredScreen>
	local screens = {}

	--- The navigation stack. Last entry is the current screen.
	---@type Flow.StackEntry[]
	local stack = {}

	--- Event listener groups. Each key is an event name; value is an array of fns.
	---@type table<string, function[]>
	local listeners = {}

	--- Queued operations to run after the current transition completes.
	---@type {name: string, args: any[]}[]
	local queue = {}

	--- The active transition metadata, or nil when no transition is running.
	---@type Flow.TransitionMeta|nil
	local transition = nil

	--- True when a transition is in progress and new operations should be queued.
	local busy = false

	--- True while run_operation's pcall is executing (guards re-entrant calls).
	local processing = false

	--- True when the current screen tree should be rebuilt.
	local invalidated = false

	local router = {}

	--- Return the number of listeners registered for an event.
	---@param event string          The event name
	---@return number               The count of registered handlers
	local function listener_count(event)
		local group = listeners[event]
		return group and #group or 0
	end

	--- Fire all listeners registered for an event, passing varargs.
	---@param event string          The event name to emit
	---@param ... any               Arguments forwarded to each listener function
	local function emit(event, ...)
		local group = listeners[event]
		if not group or #group == 0 then
			return
		end

		for i = 1, #group do
			group[i](...)
		end
	end

	--- Return the topmost stack entry (current screen), or nil if stack is empty.
	---@return Flow.StackEntry|nil
	local function current_entry()
		return stack[#stack]
	end

	--- Build a snapshot of the current router state for "changed" events.
	---@return {current: Flow.StackEntry|nil, stack_depth: number, busy: boolean, transition: Flow.TransitionMeta|nil}
	local function state_snapshot()
		return {
			current = current_entry(),
			stack_depth = #stack,
			busy = busy or processing,
			transition = transition,
		}
	end

	--- Emit the "changed" event with the current state snapshot.
	--- Called after every mutation that changes the navigation state.
	local function emit_changed()
		emit("changed", state_snapshot())
	end

	--- Send a Defold message to a URL, guarding against non-Defold environments.
	--- No-ops gracefully when called outside Defold (unit tests).
	---@param url userdata|nil      Target msg.url(); no-op when nil
	---@param message_id hash|string Defold message id hash, or raw string in test environments
	---@param message table|nil     Message payload (empty table when nil)
	local function post_message(url, message_id, message)
		if not url then return end
		if type(msg) ~= "table" or type(msg.post) ~= "function" then return end
		msg.post(url, message_id, message or {})
	end

	--- Transfer Defold input focus between two script URLs.
	--- Releases focus from previous_url and acquires it for next_url.
	--- No-ops when both URLs are the same.
	---@param previous_url userdata|nil  The script losing focus
	---@param next_url userdata|nil      The script gaining focus
	local function update_focus(previous_url, next_url)
		if previous_url == next_url then
			return
		end
		post_message(previous_url, "release_input_focus")
		post_message(next_url, "acquire_input_focus")
	end

	--- Build the message payload for lifecycle messages (on_enter, on_exit, etc.).
	---@param entry Flow.StackEntry|nil  The stack entry providing params
	---@param from_id string|nil         Screen id being left
	---@param to_id string|nil           Screen id being entered
	---@param result any                 Optional result from a pop operation
	---@return table                     Payload table for msg.post
	local function make_message_payload(entry, from_id, to_id, result)
		return {
			params = entry and entry.params or nil,
			from = from_id,
			to = to_id,
			result = result,
		}
	end

	--- Call a lifecycle hook (on_enter, on_exit, on_pause, on_resume) on a stack entry.
	--- Calls both the Lua callback (if any) and posts a message to screen.url (if set).
	---@param entry Flow.StackEntry|nil  The stack entry whose hook to call
	---@param hook_name string           One of "on_enter", "on_exit", "on_pause", "on_resume"
	---@param from_id string|nil         Screen id being left (for the message payload)
	---@param to_id string|nil           Screen id being entered (for the message payload)
	---@param result any                 Result data (for on_exit / on_resume after pop)
	local function call_hook(entry, hook_name, from_id, to_id, result)
		if not entry or not entry.screen then return end

		local hook = entry.screen[hook_name]
		if hook then
			hook(entry.params, router)
		end

		local message_id = MESSAGE_IDS[hook_name]
		if message_id and entry.screen.url then
			post_message(entry.screen.url, message_id, make_message_payload(entry, from_id, to_id, result))
		end
	end

	--- Deliver a pop result to the screen that originally pushed the popped screen.
	--- Calls popped_entry.on_result(result) if set, and posts to result_url if set.
	---@param popped_entry Flow.StackEntry|nil  The entry that was removed from the stack
	---@param resumed_entry Flow.StackEntry|nil  The entry that becomes current after pop
	---@param result any                        The result data passed to pop()
	local function deliver_result(popped_entry, resumed_entry, result)
		if not popped_entry then return end
		if popped_entry.on_result then
			popped_entry.on_result(result)
		end
		if popped_entry.result_url then
			post_message(popped_entry.result_url, popped_entry.result_message_id or DEFAULT_RESULT_MESSAGE_ID, {
				from = popped_entry.id,
				to = resumed_entry and resumed_entry.id or nil,
				result = result,
			})
		end
	end

	--- Resolve a get_data / set_data options argument to a stack entry.
	--- nil options → current entry. Table with screen_id → search the stack.
	---@param options table|nil     Options; may contain screen_id to target a specific screen
	---@return Flow.StackEntry|nil  The resolved stack entry, or nil if not found
	local function resolve_entry(options)
		if options == nil then
			return current_entry()
		end
		if type(options) ~= "table" then
			return nil
		end

		local screen_id = options.screen_id
		if screen_id == nil then
			return current_entry()
		end

		for i = #stack, 1, -1 do
			if stack[i].id == screen_id then
				return stack[i]
			end
		end

		return nil
	end

	--- Add an operation to the pending queue to be executed after the current transition.
	---@param name string           Router method name ("push", "pop", etc.)
	---@param args any[]            Arguments to forward to the method
	local function queue_operation(name, args)
		queue[#queue + 1] = { name = name, args = args }
		log.debug("nav", "queued operation=%s size=%d", name, #queue)
	end

	--- Dequeue and execute the next pending operation, if not currently busy.
	local function drain_queue()
		if busy or processing then
			return
		end

		local next_op = table.remove(queue, 1)
		if not next_op then
			return
		end

		log.debug("nav", "draining queued operation=%s remaining=%d", next_op.name, #queue)
		router[next_op.name](router, unpack_args(next_op.args))
	end

	--- Execute a navigation operation, queuing it when a transition is active.
	--- Wraps fn in a pcall to catch errors and re-raise them cleanly.
	--- Sets the processing flag while fn runs to detect re-entrant calls.
	---@param name string           The operation name (for queuing)
	---@param args any[]            The raw arguments (for queuing)
	---@param fn fun(): any         The implementation to execute
	---@return any                  The return value of fn, or nil if queued
	local function run_operation(name, args, fn)
		if busy or processing then
			queue_operation(name, args)
			return nil
		end

		processing = true
		local ok, result = pcall(fn)
		processing = false

		if not ok then
			log.error("nav", "operation failed name=%s error=%s", name, tostring(result))
			error(result, 0)
		end

		if not busy then
			drain_queue()
		end

		return result
	end

	--- Start a transition if the options specify one and transition_begin has listeners.
	--- No-ops when transition type is "none" or no listeners are registered.
	---@param action string                  The triggering action ("push", "pop", etc.)
	---@param options table                  Normalized options (may contain .transition)
	---@param from_entry Flow.StackEntry|nil The entry being left
	---@param to_entry Flow.StackEntry|nil   The entry being entered
	---@return boolean                       True when a transition was started
	local function begin_transition_if_needed(action, options, from_entry, to_entry)
		local transition_type = options and options.transition or nil
		if transition_type == nil or transition_type == "none" then
			transition = nil
			return false
		end
		if listener_count("transition_begin") == 0 then
			transition = nil
			return false
		end

		router:begin_transition({
			action = action,
			type = transition_type,
			duration = options.duration or 0.3,
			from_id = from_entry and from_entry.id or nil,
			to_id = to_entry and to_entry.id or nil,
		})
		log.info(
			"nav",
			"transition begin action=%s type=%s from=%s to=%s duration=%.2f",
			action,
			transition_type,
			from_entry and from_entry.id or "nil",
			to_entry and to_entry.id or "nil",
			options.duration or 0.3
		)
		return true
	end

	--- Register a listener for a navigation event.
	--- Multiple listeners for the same event are called in registration order.
	--- Supported events: "push", "pop", "replace", "reset", "changed",
	--- "registered", "preload", "transition_begin", "transition_complete"
	---@param event string          The event name to subscribe to
	---@param fn function           The handler function; receives event-specific args
	---@return function              The same fn, so callers can store it for off()
	function router:on(event, fn)
		assert(type(event) == "string", "navigation.on(event, fn): event must be a string")
		assert(type(fn) == "function", "navigation.on(event, fn): fn must be a function")
		local group = listeners[event]
		if not group then
			group = {}
			listeners[event] = group
		end
		group[#group + 1] = fn
		log.debug("nav", "listener added event=%s count=%d", event, #group)
		return fn
	end

	--- Remove a previously registered listener.
	--- No-op if the listener was never registered for that event.
	---@param event string          The event name the listener was registered for
	---@param fn function           The exact function reference passed to on()
	function router:off(event, fn)
		local group = listeners[event]
		if not group then return end
		for i = #group, 1, -1 do
			if group[i] == fn then
				table.remove(group, i)
			end
		end
		if #group == 0 then
			listeners[event] = nil
		end
		log.debug("nav", "listener removed event=%s remaining=%d", event, group and #group or 0)
	end

	--- Register a screen definition. Idempotent when called with the exact
	--- same screen_def table reference (useful for hot-reload in Defold).
	--- Errors on duplicate id with a different screen_def.
	--- Emits "registered" and "preload" events.
	---@param id string             Unique screen identifier string
	---@param screen_def Flow.ScreenDef  The screen definition table
	---@return Flow.RegisteredScreen The normalized internal screen record
	function router:register(id, screen_def)
		local existing = screens[id]
		if existing and existing._source == screen_def then
			log.debug("nav", "register reused screen id=%s", id)
			return existing
		end
		if existing then
			log.error("nav", "duplicate screen registration id=%s", id)
			error("navigation.register: duplicate screen id '" .. tostring(id) .. "'", 0)
		end

		local screen = normalize_screen(id, screen_def)
		screens[id] = screen
		emit("registered", id, screen)
		if screen.preload then
			emit("preload", id, screen)
		end
		log.info("nav", "registered screen id=%s preload=%s proxy=%s", id, tostring(screen.preload == true), tostring(screen.proxy_url ~= nil))
		return screen
	end

	--- Return the normalized internal screen record for a registered id, or nil.
	---@param id string             The screen id to look up
	---@return Flow.RegisteredScreen|nil  The normalized screen record, or nil if not found
	function router:get_screen(id)
		return screens[id]
	end

	--- Return a shallow copy of all registered screens keyed by id.
	--- Used by runtime.lua to sync collection proxy preloading.
	---@return table<string, Flow.RegisteredScreen>  All registered screens
	function router:list_screens()
		local out = {}
		for id, screen in pairs(screens) do
			out[id] = screen
		end
		return out
	end

	--- Read params from a stack entry. When key is nil, returns the whole params table.
	--- options.screen_id targets a specific screen in the stack by id.
	---@param key string|nil        The param key to read, or nil for the whole params table
	---@param options table|nil     Optional: {screen_id = "..."} to target a specific screen
	---@return any                  The param value, the params table, or nil
	function router:get_data(key, options)
		if type(key) == "table" and options == nil then
			options = key
			key = nil
		end

		local entry = resolve_entry(options)
		if not entry then
			return nil
		end
		if key == nil then
			return entry.params
		end
		return entry.params[key]
	end

	--- Write a value into the current (or targeted) screen's params.
	--- Invalidates the current view and emits "changed" so the UI rebuilds.
	---@param key string            The param key to write (must not be nil)
	---@param value any             The value to store
	---@param options table|nil     Optional: {screen_id = "..."} to target a specific screen
	---@return any                  The stored value, or nil if the entry was not found
	function router:set_data(key, value, options)
		assert(key ~= nil, "navigation.set_data(key, value[, options]): key is required")
		local entry = resolve_entry(options)
		if not entry then
			log.warn("nav", "set_data skipped missing entry key=%s", tostring(key))
			return nil
		end
		entry.params[key] = value
		invalidated = true
		emit_changed()
		log.debug("nav", "set_data screen=%s key=%s", entry.id, tostring(key))
		return value
	end

	--- Read the saved scroll offset for a named scroll container.
	--- Returns 0 when no offset has been saved for that key.
	--- Scroll state is saved by navigation_gui.lua after each scroll event.
	---@param key string            The scroll container's element key
	---@param options table|nil     Optional: {screen_id = "..."} to target a specific screen
	---@return number               The saved vertical scroll offset in pixels (0 when absent)
	function router:get_scroll_offset(key, options)
		local params = self:get_data(nil, options)
		local scroll_state = params and params.scroll_state
		local state = scroll_state and scroll_state[key]
		if not state then
			return 0
		end
		if type(state) == "table" then
			return state.y or 0
		end
		return state
	end

	--- Return the current (topmost) stack entry, or nil when the stack is empty.
	---@return Flow.StackEntry|nil  The current screen entry
	function router:current()
		return current_entry()
	end

	--- Return a stack entry by offset from the top.
	--- offset=1 (default) → current screen; offset=2 → previous screen; etc.
	---@param offset number|nil     How far from the top to look (default 1)
	---@return Flow.StackEntry|nil  The entry at that offset, or nil if out of range
	function router:peek(offset)
		offset = offset or 1
		local index = #stack - offset + 1
		if index < 1 then
			return nil
		end
		return stack[index]
	end

	--- Return the current depth of the navigation stack.
	---@return number               Number of entries in the stack (0 when empty)
	function router:stack_depth()
		return #stack
	end

	--- Invalidate the current screen tree and emit "changed".
	--- Call this from screen render functions when UI state changes and you
	--- want the active view to be rebuilt without a navigation operation.
	function router:invalidate()
		invalidated = true
		emit_changed()
		log.debug("nav", "invalidated")
	end

	--- Return true when the router has been invalidated since last clear_invalidation().
	---@return boolean              True when the active view should be rebuilt
	function router:is_invalidated()
		return invalidated
	end

	--- Clear the invalidation flag. Called after the active view has been rebuilt.
	function router:clear_invalidation()
		invalidated = false
	end

	--- Return true when a transition is in progress or an operation is being processed.
	---@return boolean              True when the router is busy and will queue operations
	function router:is_busy()
		return busy or processing
	end

	--- Return the active transition metadata table, or nil when idle.
	---@return Flow.TransitionMeta|nil  Transition meta: {action, type, duration, from_id, to_id}
	function router:get_transition()
		return transition
	end

	--- Start a manual transition. Sets the busy flag and emits "transition_begin".
	--- Normally called internally by push/pop/replace/reset.
	---@param meta Flow.TransitionMeta  Transition metadata: {action, type, duration, from_id, to_id}
	---@return Flow.TransitionMeta      The stored transition meta table
	function router:begin_transition(meta)
		transition = meta or {}
		busy = true
		emit("transition_begin", transition)
		emit_changed()
		return transition
	end

	--- Mark the active transition as complete. Clears the busy flag, emits
	--- "transition_complete", and drains the pending operation queue.
	---@return boolean              True when there was an active transition to complete
	function router:complete_transition()
		if not transition and not busy then
			return false
		end
		local completed = transition
		transition = nil
		busy = false
		emit("transition_complete", completed)
		emit_changed()
		log.info(
			"nav",
			"transition complete action=%s type=%s from=%s to=%s",
			completed and completed.action or "nil",
			completed and completed.type or "nil",
			completed and completed.from_id or "nil",
			completed and completed.to_id or "nil"
		)
		drain_queue()
		return true
	end

	--- Push a new screen onto the navigation stack.
	--- Calls on_pause on the current screen, then on_enter on the new screen.
	--- If options specifies a transition type and "transition_begin" has listeners,
	--- starts a transition and sets the busy flag (queuing further operations).
	---@param id string             The registered screen id to push
	---@param params table|nil      Initial params for the new screen (default {})
	---@param options string|Flow.PushOptions|nil  Transition options or transition string
	---@return Flow.StackEntry|nil  The new stack entry, or nil if queued
	function router:push(id, params, options)
		return run_operation("push", { id, params, options }, function()
			local screen = screens[id]
			if not screen then
				log.error("nav", "push unknown screen id=%s", tostring(id))
				error("navigation.push: unknown screen id '" .. tostring(id) .. "'", 0)
			end

			local opts = normalize_options(options, screen.transition)
			local from_entry = current_entry()
			local entry = {
				id = id,
				params = params or {},
				screen = screen,
				on_result = opts.on_result,
				result_url = opts.result_url,
				result_message_id = opts.result_message_id or DEFAULT_RESULT_MESSAGE_ID,
			}

			call_hook(from_entry, "on_pause", from_entry and from_entry.id or nil, entry.id)
			table.insert(stack, entry)
			call_hook(entry, "on_enter", from_entry and from_entry.id or nil, entry.id)
			update_focus(from_entry and from_entry.screen.focus_url or nil, screen.focus_url)

			invalidated = true
			emit("push", entry.id, from_entry and from_entry.id or nil, entry.params, opts)
			emit_changed()
			log.info(
				"nav",
				"push id=%s from=%s depth=%d transition=%s",
				entry.id,
				from_entry and from_entry.id or "nil",
				#stack,
				opts.transition or "none"
			)
			begin_transition_if_needed("push", opts, from_entry, entry)
			return entry
		end)
	end

	--- Pop the topmost screen from the stack and return to the previous screen.
	--- No-op (returns nil) when the stack has only one entry.
	--- Calls on_exit on the leaving screen, delivers result to the caller,
	--- then calls on_resume on the screen that becomes current.
	---@param result_or_transition table|string|nil  Result to deliver, or transition string
	---@param maybe_options string|Flow.PushOptions|nil  Transition options (when result is not a string)
	---@return Flow.StackEntry|nil  The entry that became current after pop, or nil
	function router:pop(result_or_transition, maybe_options)
		if #stack <= 1 then
			log.warn("nav", "pop ignored at root depth=%d", #stack)
			return nil
		end

		local result = result_or_transition
		local options = maybe_options
		-- Shorthand: pop("fade") is equivalent to pop(nil, "fade")
		if type(result_or_transition) == "string" and maybe_options == nil then
			result = nil
			options = result_or_transition
		end

		return run_operation("pop", { result_or_transition, maybe_options }, function()
			local from_entry = current_entry()
			local to_entry = stack[#stack - 1]
			local opts = normalize_options(options, from_entry and from_entry.screen.transition or nil)

			call_hook(from_entry, "on_exit", from_entry and from_entry.id or nil, to_entry and to_entry.id or nil, result)
			table.remove(stack)
			deliver_result(from_entry, to_entry, result)
			call_hook(to_entry, "on_resume", from_entry and from_entry.id or nil, to_entry and to_entry.id or nil, result)
			update_focus(from_entry and from_entry.screen.focus_url or nil, to_entry and to_entry.screen.focus_url or nil)

			invalidated = true
			emit("pop", to_entry and to_entry.id or nil, from_entry and from_entry.id or nil, result, opts)
			emit_changed()
			log.info(
				"nav",
				"pop from=%s to=%s depth=%d transition=%s",
				from_entry and from_entry.id or "nil",
				to_entry and to_entry.id or "nil",
				#stack,
				opts.transition or "none"
			)
			begin_transition_if_needed("pop", opts, from_entry, to_entry)
			return to_entry
		end)
	end

	--- Replace the current screen without adding to the stack depth.
	--- Calls on_exit on the current screen, then on_enter on the replacement.
	--- When the stack is empty, behaves like push (adds the first entry).
	---@param id string             The registered screen id to navigate to
	---@param params table|nil      Initial params for the replacement screen (default {})
	---@param options string|Flow.PushOptions|nil  Transition options or transition string
	---@return Flow.StackEntry|nil  The new stack entry, or nil if queued
	function router:replace(id, params, options)
		return run_operation("replace", { id, params, options }, function()
			local screen = screens[id]
			if not screen then
				log.error("nav", "replace unknown screen id=%s", tostring(id))
				error("navigation.replace: unknown screen id '" .. tostring(id) .. "'", 0)
			end

			local opts = normalize_options(options, screen.transition)
			local from_entry = current_entry()
			local entry = {
				id = id,
				params = params or {},
				screen = screen,
				on_result = opts.on_result,
				result_url = opts.result_url,
				result_message_id = opts.result_message_id or DEFAULT_RESULT_MESSAGE_ID,
			}

			call_hook(from_entry, "on_exit", from_entry and from_entry.id or nil, entry.id)
			if from_entry then
				stack[#stack] = entry
			else
				table.insert(stack, entry)
			end
			call_hook(entry, "on_enter", from_entry and from_entry.id or nil, entry.id)
			update_focus(from_entry and from_entry.screen.focus_url or nil, screen.focus_url)

			invalidated = true
			emit("replace", entry.id, from_entry and from_entry.id or nil, entry.params, opts)
			emit_changed()
			log.info(
				"nav",
				"replace id=%s from=%s depth=%d transition=%s",
				entry.id,
				from_entry and from_entry.id or "nil",
				#stack,
				opts.transition or "none"
			)
			begin_transition_if_needed("replace", opts, from_entry, entry)
			return entry
		end)
	end

	--- Clear the entire navigation stack and navigate to a single screen.
	--- Calls on_exit on all screens being cleared, then on_enter on the new root.
	--- Use this when returning to the app home screen or after logout.
	---@param id string             The registered screen id to navigate to
	---@param params table|nil      Initial params for the new root screen (default {})
	---@param options string|Flow.PushOptions|nil  Transition options or transition string
	---@return Flow.StackEntry|nil  The new stack entry (sole entry), or nil if queued
	function router:reset(id, params, options)
		return run_operation("reset", { id, params, options }, function()
			local screen = screens[id]
			if not screen then
				log.error("nav", "reset unknown screen id=%s", tostring(id))
				error("navigation.reset: unknown screen id '" .. tostring(id) .. "'", 0)
			end

			local opts = normalize_options(options, screen.transition)
			local previous_top = current_entry()
			while #stack > 0 do
				local top = current_entry()
				call_hook(top, "on_exit", top and top.id or nil, id)
				table.remove(stack)
			end

			local entry = {
				id = id,
				params = params or {},
				screen = screen,
				result_message_id = DEFAULT_RESULT_MESSAGE_ID,
			}
			table.insert(stack, entry)
			call_hook(entry, "on_enter", previous_top and previous_top.id or nil, entry.id)
			update_focus(previous_top and previous_top.screen.focus_url or nil, screen.focus_url)

			invalidated = true
			emit("reset", entry.id, entry.params, opts)
			emit_changed()
			log.info("nav", "reset id=%s transition=%s", entry.id, opts.transition or "none")
			begin_transition_if_needed("reset", opts, previous_top, entry)
			return entry
		end)
	end

	--- Alias for pop(). Provided for semantic clarity ("go back").
	---@param result_or_transition table|string|nil  See pop()
	---@param maybe_options string|Flow.PushOptions|nil  See pop()
	---@return Flow.StackEntry|nil  See pop()
	function router:back(result_or_transition, maybe_options)
		return self:pop(result_or_transition, maybe_options)
	end

	--- Reset all internal state for unit testing.
	--- Not intended for production use.
	---@return boolean              Always returns true
	function router:_reset_for_tests()
		screens = {}
		stack = {}
		listeners = {}
		queue = {}
		transition = nil
		busy = false
		processing = false
		invalidated = false
		log.debug("nav", "reset router for tests")
		return true
	end

	return router
end

return M
