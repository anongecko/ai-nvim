local utils = require("ai-assistant.utils")
local log = utils.log
local config = require("ai-assistant.config")

local M = {
  _loaded = {},
}

local function load_integration(name)
  if M._loaded[name] then
    return M._loaded[name]
  end
  
  local ok, integration = pcall(require, "ai-assistant.integrations." .. name)
  if not ok then
    log.error("Failed to load integration '%s': %s", name, integration)
    return nil
  end
  
  M._loaded[name] = integration
  return integration
end

function M.setup()
  local cfg = config.get()
  
  if not cfg.integrations then
    log.debug("No integrations configured")
    return true
  end
  
  for name, integration_config in pairs(cfg.integrations) do
    if integration_config.enable then
      log.debug("Loading integration: %s", name)
      local integration = load_integration(name)
      
      if integration and integration.setup then
        local ok, err = pcall(integration.setup, integration_config)
        if not ok then
          log.error("Failed to setup integration '%s': %s", name, err)
        end
      end
    end
  end
  
  return true
end

function M.get(name)
  local cfg = config.get()
  if not cfg.integrations or not cfg.integrations[name] or not cfg.integrations[name].enable then
    return nil
  end
  
  return load_integration(name)
end

return M
