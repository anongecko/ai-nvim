local utils = require("ai-assistant.utils")
local config = require("ai-assistant.config")
local log = utils.log

local M = {
  _handlers = {},
  _listeners = {},
  _augroups = {},
}

-- Event types
M.Events = {
  REQUEST_START = "request_start",
  REQUEST_CHUNK = "request_chunk",
  REQUEST_END = "request_end",
  REQUEST_ERROR = "request_error",
  CONTEXT_UPDATE = "context_update",
  CONFIG_CHANGE = "config_change",
  PROVIDER_CHANGE = "provider_change",
  PANEL_OPEN = "panel_open",
  PANEL_CLOSE = "panel_close",
  CODE_CHANGE = "code_change",
  CODE_APPLY = "code_apply",
}

-- Fire an event
function M.fire(event_name, data)
  log.debug("Firing event: %s", event_name)
  
  if not M._handlers[event_name] then
    return
  end
  
  for id, handler in pairs(M._handlers[event_name]) do
    local success, err = pcall(handler, data)
    if not success then
      log.error("Error in event handler %s for event %s: %s", id, event_name, err)
    end
  end
end

-- Register an event handler
function M.on(event_name, handler)
  if not M._handlers[event_name] then
    M._handlers[event_name] = {}
  end
  
  local id = utils.uuid()
  M._handlers[event_name][id] = handler
  
  return id
end

-- Unregister an event handler
function M.off(event_name, id)
  if not M._handlers[event_name] then
    return false
  end
  
  if M._handlers[event_name][id] then
    M._handlers[event_name][id] = nil
    return true
  end
  
  return false
end

-- Create a buffer change listener
function M.listen_buffer_changes(bufnr, callback, debounce_ms)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  debounce_ms = debounce_ms or 500
  
  if not vim.api.nvim_buf_is_valid(bufnr) then
    log.error("Invalid buffer for buffer change listener: %s", bufnr)
    return nil
  end
  
  local group_id = utils.uuid()
  local augroup = "ai_assistant_buffer_" .. group_id
  
  M._augroups[group_id] = vim.api.nvim_create_augroup(augroup, { clear = true })
  
  -- Debounced callback
  local debounced_callback = utils.async.debounce(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      callback(bufnr)
      M.fire(M.Events.CODE_CHANGE, { bufnr = bufnr })
    else
      -- Clean up if buffer is no longer valid
      M.stop_buffer_listener(group_id)
    end
  end, debounce_ms)
  
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
    group = M._augroups[group_id],
    buffer = bufnr,
    callback = debounced_callback,
  })
  
  M._listeners[group_id] = {
    type = "buffer",
    bufnr = bufnr,
    callback = callback,
  }
  
  return group_id
end

-- Stop a buffer listener
function M.stop_buffer_listener(id)
  if not M._listeners[id] or M._listeners[id].type ~= "buffer" then
    return false
  end
  
  if M._augroups[id] then
    vim.api.nvim_del_augroup_by_id(M._augroups[id])
    M._augroups[id] = nil
  end
  
  M._listeners[id] = nil
  
  return true
end

-- Create a context change listener
function M.listen_context_changes(callback, debounce_ms)
  debounce_ms = debounce_ms or 1000
  
  local group_id = utils.uuid()
  local augroup = "ai_assistant_context_" .. group_id
  
  M._augroups[group_id] = vim.api.nvim_create_augroup(augroup, { clear = true })
  
  -- Debounced callback
  local debounced_callback = utils.async.debounce(function()
    callback()
    M.fire(M.Events.CONTEXT_UPDATE, {})
  end, debounce_ms)
  
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "DirChanged" }, {
    group = M._augroups[group_id],
    callback = debounced_callback,
  })
  
  M._listeners[group_id] = {
    type = "context",
    callback = callback,
  }
  
  return group_id
end

-- Stop a context listener
function M.stop_context_listener(id)
  if not M._listeners[id] or M._listeners[id].type ~= "context" then
    return false
  end
  
  if M._augroups[id] then
    vim.api.nvim_del_augroup_by_id(M._augroups[id])
    M._augroups[id] = nil
  end
  
  M._listeners[id] = nil
  
  return true
end

-- Clear all listeners
function M.clear_all_listeners()
  for id, _ in pairs(M._listeners) do
    if M._augroups[id] then
      vim.api.nvim_del_augroup_by_id(M._augroups[id])
      M._augroups[id] = nil
    end
  end
  
  M._listeners = {}
end

-- Setup function
function M.setup()
  -- Set up basic default event handlers
  
  -- Log request events if debug logging is enabled
  local cfg = config.get()
  if cfg.log.level == "DEBUG" then
    M.on(M.Events.REQUEST_START, function(data)
      log.debug("Request started: %s", data.request_id)
    end)
    
    M.on(M.Events.REQUEST_END, function(data)
      log.debug("Request completed: %s", data.request_id)
    end)
    
    M.on(M.Events.REQUEST_ERROR, function(data)
      log.debug("Request error: %s - %s", data.request_id, data.error)
    end)
  end
  
  return true
end

return M
