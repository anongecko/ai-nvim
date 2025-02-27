local utils = require("ai-assistant.utils")
local config = require("ai-assistant.config")
local log = utils.log

local M = {
  _providers = {},
  _current = nil,
}

local function create_base_provider(name, provider_config)
  return {
    name = name,
    config = provider_config,
    is_available = function() return provider_config.api_key and provider_config.api_key ~= "" end,
    stream_response = function() error("Stream response not implemented") end,
    complete = function() error("Complete not implemented") end,
    cancel = function() end,
  }
end

local function load_provider(name)
  if not M._providers[name] then
    local ok, provider_module = pcall(require, "ai-assistant.provider." .. name)
    
    if not ok then
      log.error("Failed to load provider '%s': %s", name, provider_module)
      return nil
    end
    
    local provider_config = config.get_provider_config(name)
    if not provider_config then
      log.error("Provider '%s' has no configuration", name)
      return nil
    end
    
    local base_provider = create_base_provider(name, provider_config)
    local provider = setmetatable(provider_module, { __index = base_provider })
    provider.init(provider_config)
    
    M._providers[name] = provider
  end
  
  return M._providers[name]
end

function M.setup()
  local cfg = config.get()
  local default_provider = cfg.provider.default
  
  M._current = load_provider(default_provider)
  
  if not M._current then
    log.error("Failed to load default provider '%s'", default_provider)
    
    -- Try to fall back to any available provider
    for name, _ in pairs(cfg.provider) do
      if type(name) == "string" and name ~= "default" then
        local provider = load_provider(name)
        if provider and provider.is_available() then
          M._current = provider
          log.warn("Fell back to provider '%s'", name)
          break
        end
      end
    end
  end
  
  if not M._current then
    log.error("No available provider found. Please check your configuration.")
    return false
  end
  
  return true
end

function M.get_current()
  if not M._current then
    local ok = M.setup()
    if not ok then
      error("Failed to initialize AI provider")
    end
  end
  return M._current
end

function M.set_current(name)
  local provider = load_provider(name)
  if not provider then
    log.error("Failed to set provider to '%s'", name)
    return false
  end
  
  if not provider.is_available() then
    log.error("Provider '%s' is not available", name)
    return false
  end
  
  M._current = provider
  log.info("Current provider set to '%s'", name)
  return true
end

function M.list_available()
  local cfg = config.get()
  local available = {}
  
  for name, _ in pairs(cfg.provider) do
    if type(name) == "string" and name ~= "default" then
      local provider = load_provider(name)
      if provider and provider.is_available() then
        table.insert(available, name)
      end
    end
  end
  
  return available
end

function M.stream_response(prompt, context, options, callback)
  local provider = M.get_current()
  local request_id = utils.uuid()
  
  options = options or {}
  options.max_tokens = options.max_tokens or provider.config.max_tokens
  options.temperature = options.temperature or provider.config.temperature
  
  log.debug("Streaming response with provider '%s'", provider.name)
  
  local ok, err = pcall(function()
    return provider.stream_response(request_id, prompt, context, options, callback)
  end)
  
  if not ok then
    log.error("Error streaming response: %s", err)
    callback({ error = err })
    return request_id
  end
  
  return request_id
end

function M.complete(prompt, context, options)
  local provider = M.get_current()
  
  options = options or {}
  options.max_tokens = options.max_tokens or provider.config.max_tokens
  options.temperature = options.temperature or provider.config.temperature
  
  log.debug("Completing with provider '%s'", provider.name)
  
  local ok, result = pcall(function()
    return provider.complete(prompt, context, options)
  end)
  
  if not ok then
    log.error("Error completing: %s", result)
    return { error = result }
  end
  
  return result
end

function M.cancel(request_id)
  local provider = M.get_current()
  
  log.debug("Cancelling request '%s'", request_id)
  
  local ok, err = pcall(function()
    return provider.cancel(request_id)
  end)
  
  if not ok then
    log.error("Error cancelling request: %s", err)
    return false
  end
  
  return true
end

return M
