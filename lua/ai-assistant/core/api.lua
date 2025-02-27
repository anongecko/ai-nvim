local utils = require("ai-assistant.utils")
local config = require("ai-assistant.config")
local provider = require("ai-assistant.provider")
local context = require("ai-assistant.context")
local ui = require("ai-assistant.ui.panel")
local log = utils.log

local M = {}

function M.query(prompt, options)
  options = options or {}
  
  if not prompt or prompt == "" then
    log.error("Empty prompt")
    return nil, "Empty prompt"
  end
  
  -- Get context if needed
  local ctx = ""
  if options.context ~= false then
    ctx = context.build_context({
      include_project = options.include_project,
      include_buffer = options.include_buffer,
      max_files = options.max_files,
      window_size = options.window_size,
    })
  end
  
  -- Prepare provider options
  local provider_options = {
    max_tokens = options.max_tokens,
    temperature = options.temperature,
    model = options.model,
  }
  
  log.debug("Querying provider with prompt: %s", prompt:sub(1, 100) .. (prompt:len() > 100 and "..." or ""))
  
  -- Send request to provider
  local result = provider.complete(prompt, ctx, provider_options)
  
  if result.error then
    log.error("Provider error: %s", result.error)
    return nil, result.error
  end
  
  return result.content, nil
end

function M.stream_query(prompt, callback, options)
  options = options or {}
  
  if not prompt or prompt == "" then
    log.error("Empty prompt")
    callback({ error = "Empty prompt" })
    return nil
  end
  
  if not callback or type(callback) ~= "function" then
    log.error("Invalid callback")
    return nil
  end
  
  -- Get context if needed
  local ctx = ""
  if options.context ~= false then
    ctx = context.build_context({
      include_project = options.include_project,
      include_buffer = options.include_buffer,
      max_files = options.max_files,
      window_size = options.window_size,
    })
  end
  
  -- Prepare provider options
  local provider_options = {
    max_tokens = options.max_tokens,
    temperature = options.temperature,
    model = options.model,
  }
  
  log.debug("Streaming query with prompt: %s", prompt:sub(1, 100) .. (prompt:len() > 100 and "..." or ""))
  
  -- Send streaming request to provider
  local request_id = provider.stream_response(prompt, ctx, provider_options, callback)
  
  return request_id
end

function M.cancel_query(request_id)
  if not request_id then
    return false
  end
  
  return provider.cancel(request_id)
end

function M.get_current_provider()
  return provider.get_current().name
end

function M.set_provider(provider_name)
  if not provider_name or provider_name == "" then
    return false, "Invalid provider name"
  end
  
  local success = provider.set_current(provider_name)
  if not success then
    return false, "Failed to set provider to " .. provider_name
  end
  
  return true, nil
end

function M.list_available_providers()
  return provider.list_available()
end

function M.open_panel(options)
  options = options or {}
  
  if options.with_prompt then
    ui.open()
    ui.set_input(options.with_prompt)
    return true
  end
  
  ui.open()
  return true
end

function M.close_panel()
  ui.close()
  return true
end

function M.toggle_panel()
  ui.toggle()
  return true
end

function M.explain_code(code, options)
  if not code or code == "" then
    return nil, "No code provided"
  end
  
  options = options or {}
  
  local prompt = "Explain the following code:\n```\n" .. code .. "\n```"
  if options.with_focus then
    prompt = prompt .. "\nFocus on: " .. options.with_focus
  end
  
  if options.in_panel then
    ui.open()
    ui.set_input(prompt)
    ui.submit()
    return true, nil
  else
    return M.query(prompt, options)
  end
end

function M.refactor_code(code, options)
  if not code or code == "" then
    return nil, "No code provided"
  end
  
  options = options or {}
  
  local prompt = "Refactor the following code to improve its performance, readability, and maintainability:\n```\n" .. code .. "\n```"
  if options.with_focus then
    prompt = prompt .. "\nFocus on: " .. options.with_focus
  end
  
  if options.in_panel then
    ui.open()
    ui.set_input(prompt)
    ui.submit()
    return true, nil
  else
    return M.query(prompt, options)
  end
end

function M.document_code(code, options)
  if not code or code == "" then
    return nil, "No code provided"
  end
  
  options = options or {}
  
  local prompt = "Add detailed documentation to the following code:\n```\n" .. code .. "\n```"
  if options.with_focus then
    prompt = prompt .. "\nFocus on: " .. options.with_focus
  end
  
  if options.in_panel then
    ui.open()
    ui.set_input(prompt)
    ui.submit()
    return true, nil
  else
    return M.query(prompt, options)
  end
end

function M.generate_tests(code, options)
  if not code or code == "" then
    return nil, "No code provided"
  end
  
  options = options or {}
  
  local prompt = "Generate comprehensive unit tests for the following code:\n```\n" .. code .. "\n```"
  if options.with_focus then
    prompt = prompt .. "\nFocus on: " .. options.with_focus
  end
  
  if options.framework then
    prompt = prompt .. "\nUse the " .. options.framework .. " testing framework."
  end
  
  if options.in_panel then
    ui.open()
    ui.set_input(prompt)
    ui.submit()
    return true, nil
  else
    return M.query(prompt, options)
  end
end

function M.clear_context_cache()
  context.clear_cache()
  return true
end

return M
